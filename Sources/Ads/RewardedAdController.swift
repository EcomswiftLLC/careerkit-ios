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

    /// True when the last `present()` returned false because the ad could not be shown (not because the user closed it).
    private(set) var lastPresentationFailed = false

    // Loaded ad and bookkeeping.
    private var ad: RewardedAd?
    private var loadedAt: Date?
    private var loadGeneration = 0
    private var failureCount = 0
    private var retryTask: Task<Void, Never>?
    private let retryPolicy: RewardedRetryPolicy
    private let maxAdAge: TimeInterval = 55 * 60   // loaded ads expire; refresh a little early

    // Presentation bookkeeping. The continuation is resumed exactly once.
    private var continuation: CheckedContinuation<Bool, Never>?
    private var rewardEarned = false

    private let preloadEnabled: Bool
    private var consentObserver: AnyCancellable?

    /// - Parameter preload: load an ad right away and whenever consent becomes available.
    init(preload: Bool = true, retryPolicy: RewardedRetryPolicy = RewardedRetryPolicy()) {
        self.preloadEnabled = preload
        self.retryPolicy = retryPolicy
        super.init()
        consentObserver = AdsManager.shared.$canRequestAds
            .removeDuplicates()
            .sink { [weak self] allowed in
                Task { @MainActor in self?.consentChanged(allowed: allowed) }
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
            state = .ready
            return
        }
        retryTask?.cancel()
        retryTask = nil
        failureCount = 0
        beginLoad(showSpinner: true)
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

    private func beginLoad(showSpinner: Bool) {
        guard let unitID = AdsConfiguration.rewardedUnitID else {
            state = .unavailable(String(localized: "Videos are not set up in this version of the app."))
            return
        }
        guard AdsManager.shared.canRequestAds else {
            state = .unavailable(String(localized: "Videos can only play after you make a privacy choice."))
            return
        }
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
        state = .ready
    }

    private func didFail(_ error: Error, generation: Int) {
        guard generation == loadGeneration, state != .presenting else { return }
        AdsLog.logger.info("Rewarded load failed: \(error.localizedDescription, privacy: .public)")
        failureCount += 1
        state = .unavailable(String(localized: "No video is available right now. Check your internet connection and try again."))
        guard let delay = retryPolicy.delay(afterFailure: failureCount) else { return }
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self = self else { return }
            // Retry quietly: the state stays "unavailable" until a video is ready.
            if case .unavailable = self.state { self.beginLoad(showSpinner: false) }
        }
    }

    private func consentChanged(allowed: Bool) {
        if allowed {
            guard preloadEnabled else { return }
            switch state {
            case .idle, .unavailable: load()
            default: break
            }
        } else if state != .presenting {
            // Consent was withdrawn: drop the ad and stop requesting.
            retryTask?.cancel()
            ad = nil
            loadedAt = nil
            loadGeneration += 1
            state = .unavailable(String(localized: "Videos can only play after you make a privacy choice."))
        }
    }

    // MARK: Presenting

    /// Shows the loaded video. Returns true ONLY if the earned-reward handler fired.
    /// Returns false when the user closes the video early, when it fails to show, or when no video is loaded.
    func present() async -> Bool {
        lastPresentationFailed = false
        expireIfStale()
        guard continuation == nil, state == .ready, let readyAd = ad else { return false }
        guard AdsManager.shared.canRequestAds else {
            lastPresentationFailed = true
            return false
        }
        guard let presenter = AdsPresenter.topViewController() else {
            lastPresentationFailed = true
            return false
        }

        state = .presenting
        rewardEarned = false
        ad = nil          // a loaded ad is single use
        loadedAt = nil

        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            continuation = cont
            readyAd.present(from: presenter) { [weak self] in
                // Official user-earned-reward handler. The only place a reward can be recorded.
                guard let self = self, !self.rewardEarned else { return }
                self.rewardEarned = true
            }
        }
    }

    private func finishPresentation(failedToPresent: Bool) {
        guard let cont = continuation else { return }   // already finished: never resume twice
        continuation = nil
        let earned = rewardEarned && !failedToPresent
        rewardEarned = false
        lastPresentationFailed = failedToPresent
        state = .idle
        cont.resume(returning: earned)
        load()   // reload after each use
    }

    // MARK: FullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finishPresentation(failedToPresent: false)
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        AdsLog.logger.info("Rewarded failed to present: \(error.localizedDescription, privacy: .public)")
        finishPresentation(failedToPresent: true)
    }
}
