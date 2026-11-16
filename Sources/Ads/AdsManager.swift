import SwiftUI
import UIKit
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform

/// Owns the consent, tracking prompt and SDK start sequence.
///
/// Order: UMP consent -> (only if ads are allowed) ATT prompt -> MobileAds start.
/// Nothing here can crash when there is no window, no network, or no ad id.
@MainActor
final class AdsManager: ObservableObject {
    static let shared = AdsManager()

    /// Mirrors `ConsentInformation.shared.canRequestAds`. False until the first consent update finishes.
    @Published private(set) var canRequestAds: Bool = false

    /// Bumped whenever consent state is re-read, so views that show the privacy row refresh.
    @Published private(set) var consentRevision: Int = 0

    private var startTask: Task<Void, Never>?
    private var sdkStarted = false

    private init() {}

    /// True when Google says the user must be able to reopen their privacy choices (Settings row).
    var privacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    // MARK: Start

    /// Safe to call more than once. Concurrent callers share one run.
    func start() async {
        if let running = startTask {
            await running.value
            return
        }
        let task = Task { await self.runStartSequence() }
        startTask = task
        await task.value
        startTask = nil
    }

    private func runStartSequence() async {
        // The consent form and the ATT prompt both need a foreground app with a window.
        await waitUntilReadyToPresent(timeout: 10)

        // 1. Consent (UMP). Offline or failed updates are tolerated: a cached decision may still allow ads.
        let updateError = await requestConsentInfoUpdate()
        if let updateError = updateError {
            AdsLog.logger.info("Consent info update failed: \(updateError.localizedDescription, privacy: .public)")
        } else if let presenter = AdsPresenter.topViewController() {
            do {
                try await ConsentForm.loadAndPresentIfRequired(from: presenter)
            } catch {
                AdsLog.logger.info("Consent form failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        refreshConsentState()
        guard canRequestAds else { return }

        // 2. ATT, only after consent allows ads. The system shows this at most once.
        await requestTrackingIfNeeded()

        // 3. Start the SDK once.
        startSDKIfNeeded()
    }

    private func requestConsentInfoUpdate() async -> Error? {
        let parameters = consentRequestParameters()
        return await withCheckedContinuation { (continuation: CheckedContinuation<Error?, Never>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                continuation.resume(returning: error)
            }
        }
    }

    private func consentRequestParameters() -> RequestParameters {
        let parameters = RequestParameters()
        #if DEBUG
        let ids = AdsConfiguration.testDeviceIdentifiers
        if !ids.isEmpty {
            let debug = DebugSettings()
            debug.testDeviceIdentifiers = ids
            // debug.geography = .EEA   // uncomment to test the European consent form
            parameters.debugSettings = debug
        }
        #endif
        return parameters
    }

    private func requestTrackingIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        // The system ignores the request unless the app is active.
        await waitUntilReadyToPresent(timeout: 10)
        guard UIApplication.shared.applicationState == .active else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    private func startSDKIfNeeded() {
        guard !sdkStarted else { return }
        sdkStarted = true
        let ids = AdsConfiguration.testDeviceIdentifiers
        if !ids.isEmpty {
            MobileAds.shared.requestConfiguration.testDeviceIdentifiers = ids
        }
        MobileAds.shared.start(completionHandler: nil)
    }

    private func waitUntilReadyToPresent(timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !AdsPresenter.isReady && Date() < deadline {
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    private func refreshConsentState() {
        let allowed = ConsentInformation.shared.canRequestAds
        if canRequestAds != allowed { canRequestAds = allowed }
        consentRevision += 1
    }

    // MARK: Privacy options (Settings row)

    /// Shows Google's privacy options form. Does nothing when it is not required or no window exists.
    func presentPrivacyOptions() {
        guard privacyOptionsRequired, let presenter = AdsPresenter.topViewController() else { return }
        Task { [weak self] in
            do {
                try await ConsentForm.presentPrivacyOptionsForm(from: presenter)
            } catch {
                AdsLog.logger.info("Privacy options form failed: \(error.localizedDescription, privacy: .public)")
            }
            guard let self = self else { return }
            self.refreshConsentState()
            if self.canRequestAds && !self.sdkStarted {
                await self.start()
            }
        }
    }

    #if DEBUG
    /// Debug only: forget the stored consent so the form can be tested again.
    func resetConsentForTesting() {
        ConsentInformation.shared.reset()
        canRequestAds = false
        sdkStarted = false
        consentRevision += 1
    }
    #endif
}
