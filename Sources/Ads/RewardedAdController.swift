import SwiftUI
import UIKit
import Combine
import GoogleMobileAds

/// Backoff rules for failed rewarded loads. Pure, so it can be unit tested.
struct RewardedRetryPolicy: Equatable {
    var baseDelay: TimeInterval = 4
    var maxDelay: TimeInterval = 60
    var maxAutomaticRetries: Int = 4

    /// Delay before automatic retry number `failureCount` (1 for the first failure).
    /// Returns nil when automatic retrying should stop. The user can still tap "Try again".
    func delay(afterFailure failureCount: Int) -> TimeInterval? {
        guard failureCount >= 1, failureCount <= maxAutomaticRetries else { return nil }
        let raw = baseDelay * pow(2, Double(failureCount - 1))
        return min(maxDelay, raw)
    }
}

/// Timing rules for finishing a presentation. Pure, so it can be unit tested.
enum RewardedPresentationTiming {
    /// The earned-reward handler can arrive just after the dismiss callback. Wait this long for it.
    static let rewardGrace: TimeInterval = 0.25
    /// Poll step while waiting for the reward flag.
    static let rewardPollStep: TimeInterval = 0.05
    /// If the SDK has not said the video started within this time, treat it as "could not present".
    static let presentWatchdog: TimeInterval = 6

    /// Result of a showing, from the flags the SDK callbacks set.
    static func earned(rewardEarned: Bool, failedToPresent: Bool, cancelled: Bool) -> Bool {
        rewardEarned && !failedToPresent && !cancelled
    }

    /// A reward earned after the caller was already answered (the watchdog fired, or the caller was cancelled, and the
    /// video then played anyway) must still count: the person watched the whole video.
    static func isLateReward(earned: Bool, callerAlreadyAnswered: Bool) -> Bool {
        earned && callerAlreadyAnswered
    }
}

/// Loads and shows one rewarded video at a time.
///
/// `present()` returns true only when the SDK's user-earned-reward handler fired for that showing.
/// It is `@MainActor` (a small tightening of the contract): every caller is a SwiftUI view.
@MainActor
final class RewardedAdController: NSObject, ObservableObject, FullScreenContentDelegate {
    enum State: Equatable {
        case idle
        case loading
        case ready
        case presenting
        /// Carries a plain-language message that is safe to show to the user.
        case unavailable(String)
    }

    @Published var state: State = .idle

    /// Why the controller is (or last was) unavailable. Set together with `.unavailable`.
    @Published private(set) var unavailableReason: RewardedUnavailableReason?

    /// True when the last `present()` returned false because the ad could not be shown (not because the user closed it).
    private(set) var lastPresentationFailed = false

    /// Goes up by one when a video was watched to the end after `present()` had already returned false (the 6 second
    /// watchdog answered first and the video started later). The export sheet watches it and grants the export.
    /// A counter, not a closure, so the sheet and the controller never hold each other.
    @Published private(set) var lateRewardCount = 0

    // Loaded ad and bookkeeping.
    private var ad: RewardedAd?
    private var loadedAt: Date?
    private var loadGeneration = 0
    private var failureCount = 0
    private var retryTask: Task<Void, Never>?
    private var waitingForSDK = false
    private let retryPolicy: RewardedRetryPolicy
    private let maxAdAge: TimeInterval = 55 * 60   // loaded ads expire; refresh a little early

    // Presentation bookkeeping. The continuation is resumed exactly once.
    /// B1: the ad on screen is held strongly until it is dismissed, so the delegate callbacks always arrive.
    private var presentingAd: RewardedAd?
    private var continuation: CheckedContinuation<Bool, Never>?
    private var rewardEarned = false
    private var didStartPresenting = false
    private var finishScheduled = false
    private var watchdogTask: Task<Void, Never>?

    private let preloadEnabled: Bool
    private var readinessObserver: AnyCancellable?

    /// - Parameter preload: load an ad right away and whenever ads become available.
    init(preload: Bool = true, retryPolicy: RewardedRetryPolicy = RewardedRetryPolicy()) {
        self.preloadEnabled = preload
        self.retryPolicy = retryPolicy
        super.init()
        let manager = AdsManager.shared
        readinessObserver = Publishers.CombineLatest(manager.$canRequestAds, manager.$sdkReady)
            .map { (pair: (Bool, Bool)) -> Bool in AdsRequestPolicy.adsReady(canRequestAds: pair.0, sdkReady: pair.1) }
            .removeDuplicates()
            .sink { [weak self] ready in
                Task { @MainActor in self?.readinessChanged(ready: ready) }
            }
        if preload { load() }
    }

    // MARK: Loading

    /// Starts a load. Does nothing while loading or presenting. Resets the retry counter.
    func load() {
        switch state {
        case .loading, .presenting:
            return
        default:
            break
        }
        expireIfStale()
        if ad != nil {
            setReady()
            return
        }
        retryTask?.cancel()
        retryTask = nil
        failureCount = 0
        beginLoad(showSpinner: true)
    }

    /// Loads in the background when ads are ready. Never shows anything. Used when the export sheet opens.
    func preload() {
        guard AdsManager.shared.adsReady else { return }
        switch state {
        case .idle, .unavailable: load()
        default: break
        }
    }

    /// Drops an ad that has been waiting too long. Call before relying on `.ready`.
    func expireIfStale() {
        guard ad != nil, let loadedAt = loadedAt else { return }
        if Date().timeIntervalSince(loadedAt) > maxAdAge {
            ad = nil
            self.loadedAt = nil
            if state == .ready { state = .idle }
        }
    }

    /// Stops quiet retries, for example when the sheet goes away.
    func cancelRetries() {
        retryTask?.cancel()
        retryTask = nil
    }

    private func setReady() {
        unavailableReason = nil
        state = .ready
    }

    private func setUnavailable(_ reason: RewardedUnavailableReason) {
        unavailableReason = reason
        state = .unavailable(reason.exportMessage)
    }

    private func beginLoad(showSpinner: Bool) {
        guard let unitID = AdsConfiguration.rewardedUnitID else {
            setUnavailable(.notConfigured)
            return
        }
        let manager = AdsManager.shared
        guard manager.canRequestAds else {
            setUnavailable(.noConsent)
            return
        }
        guard manager.sdkReady else {
            // B3: wait for MobileAds.start to finish. `readinessChanged` continues the load.
            waitingForSDK = true
            if showSpinner { state = .loading }
            return
        }
        waitingForSDK = false
        loadGeneration += 1
        let generation = loadGeneration
        if showSpinner { state = .loading }
        Task { [weak self] in
            do {
                let loaded = try await RewardedAd.load(with: unitID, request: Request())
                self?.didLoad(loaded, generation: generation)
            } catch {
                self?.didFail(error, generation: generation)
            }
        }
    }

    private func didLoad(_ loaded: RewardedAd, generation: Int) {
        guard generation == loadGeneration, state != .presenting else { return }
        loaded.fullScreenContentDelegate = self
        ad = loaded
        loadedAt = Date()
        failureCount = 0
        setReady()
    }

    private func didFail(_ error: Error, generation: Int) {
        guard generation == loadGeneration, state != .presenting else { return }
        AdsLog.logger.info("Rewarded load failed: \(error.localizedDescription, privacy: .public)")
        failureCount += 1
        setUnavailable(.loadFailed)
        guard let delay = retryPolicy.delay(afterFailure: failureCount) else { return }
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self = self else { return }
            // Retry quietly: the state stays "unavailable" until a video is ready.
            if case .unavailable = self.state { self.beginLoad(showSpinner: false) }
        }
    }

    private func readinessChanged(ready: Bool) {
        if ready {
            if waitingForSDK {
                waitingForSDK = false
                beginLoad(showSpinner: state == .loading)
                return
            }
            guard preloadEnabled else { return }
            switch state {
            case .idle, .unavailable: load()
            default: break
            }
        } else if state != .presenting && !AdsManager.shared.canRequestAds {
            // Consent was withdrawn: drop the ad and stop requesting.
            retryTask?.cancel()
            waitingForSDK = false
            ad = nil
            loadedAt = nil
            loadGeneration += 1
            setUnavailable(.noConsent)
        }
    }

    // MARK: Presenting

    /// Shows the loaded video. Returns true ONLY if the earned-reward handler fired.
    /// Returns false when the user closes the video early, when it fails to show, when no video is loaded,
    /// or when the calling task is cancelled. It never waits forever.
    func present() async -> Bool {
        lastPresentationFailed = false
        expireIfStale()
        guard continuation == nil, !finishScheduled else {
            lastPresentationFailed = true
            return false
        }
        guard state == .ready, let readyAd = ad else {
            lastPresentationFailed = true
            return false
        }
        guard AdsManager.shared.canRequestAds, let presenter = AdsPresenter.topViewController() else {
            lastPresentationFailed = true
            return false
        }
        if Task.isCancelled { return false }

        state = .presenting
        rewardEarned = false
        didStartPresenting = false
        finishScheduled = false
        presentingAd = readyAd   // B1: strong reference until dismissal
        ad = nil                 // a loaded ad is single use
        loadedAt = nil

        return await withTaskCancellationHandler {
            await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                continuation = cont
                startWatchdog()
                readyAd.present(from: presenter) { [weak self] in
                    // Official user-earned-reward handler. The only place a reward can be recorded.
                    guard let self = self, !self.rewardEarned else { return }
                    self.rewardEarned = true
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.resumeIfWaiting(cancelled: true) }
        }
    }

    /// Resolves a presentation that is still pending. Safe to call from any callback; resumes at most once.
    private func resumeIfWaiting(cancelled: Bool) {
        guard let cont = continuation else { return }
        continuation = nil
        watchdogTask?.cancel()
        watchdogTask = nil
        let earned = RewardedPresentationTiming.earned(rewardEarned: rewardEarned, failedToPresent: false, cancelled: cancelled)
        if cancelled { lastPresentationFailed = false }
        cont.resume(returning: earned)
    }

    private func startWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(RewardedPresentationTiming.presentWatchdog * 1_000_000_000))
            guard !Task.isCancelled, let self = self else { return }
            guard self.continuation != nil, !self.didStartPresenting, !self.finishScheduled else { return }
            AdsLog.logger.info("Rewarded video did not start in time")
            // Answer the caller now so the sheet never hangs. `presentingAd` stays referenced, so a late
            // dismiss or failure callback still arrives and tidies up through `finishPresentation`.
            if let cont = self.continuation {
                self.continuation = nil
                self.lastPresentationFailed = true
                if self.state == .presenting { self.state = .idle }
                cont.resume(returning: false)
            }
        }
    }

    /// B2: the reward handler and the dismiss callback can arrive in either order.
    /// Wait one main-queue hop, then up to `rewardGrace` for the reward flag, then finish.
    private func scheduleFinish(failedToPresent: Bool) {
        guard !finishScheduled else { return }
        finishScheduled = true
        watchdogTask?.cancel()
        watchdogTask = nil
        Task { @MainActor in
            await Task.yield()
            if !failedToPresent {
                var waited: TimeInterval = 0
                while !self.rewardEarned && waited < RewardedPresentationTiming.rewardGrace {
                    try? await Task.sleep(nanoseconds: UInt64(RewardedPresentationTiming.rewardPollStep * 1_000_000_000))
                    waited += RewardedPresentationTiming.rewardPollStep
                }
            }
            self.finishPresentation(failedToPresent: failedToPresent)
        }
    }

    private func finishPresentation(failedToPresent: Bool) {
        watchdogTask?.cancel()
        watchdogTask = nil
        let earned = RewardedPresentationTiming.earned(rewardEarned: rewardEarned, failedToPresent: failedToPresent, cancelled: false)
        rewardEarned = false
        didStartPresenting = false
        finishScheduled = false
        presentingAd = nil
        if state == .presenting { state = .idle }
        if let cont = continuation {    // already resumed (cancelled): never resume twice
            continuation = nil
            lastPresentationFailed = failedToPresent
            cont.resume(returning: earned)
        } else if RewardedPresentationTiming.isLateReward(earned: earned, callerAlreadyAnswered: true) {
            // The caller was answered earlier (watchdog or cancel), but the video played and was earned: do not lose it.
            AdsLog.logger.info("Rewarded video finished after the watchdog; counting the reward")
            lateRewardCount += 1
        }
        load()   // reload after each use
    }

    // MARK: FullScreenContentDelegate

    /// Callbacks for any ad other than the one on screen (for example a late callback from an older showing) are ignored.
    private func isCurrent(_ ad: FullScreenPresentingAd) -> Bool {
        guard let current = presentingAd else { return false }
        return (ad as AnyObject) === current
    }

    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        guard isCurrent(ad) else { return }
        didStartPresenting = true
    }

    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        guard isCurrent(ad) else { return }
        didStartPresenting = true
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        guard isCurrent(ad) else { return }
        scheduleFinish(failedToPresent: false)
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        AdsLog.logger.info("Rewarded failed to present: \(error.localizedDescription, privacy: .public)")
        guard isCurrent(ad) else { return }
        scheduleFinish(failedToPresent: true)
    }
}
