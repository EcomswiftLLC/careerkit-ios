import Foundation

/// Why a rewarded video could not be provided for an export. Pure, so it can be unit tested.
enum RewardedUnavailableReason: Equatable {
    /// No rewarded unit id in Info.plist (for example an unresolved build setting).
    case notConfigured
    /// Google's consent state does not allow ad requests (declined or not yet given).
    case noConsent
    /// The ad request failed (no fill, offline, server error).
    case loadFailed
    /// Nothing loaded before the wait limit.
    case timedOut
    /// A video was loaded but could not be shown, or never started.
    case couldNotPresent

    /// Plain text for the export sheet. Never calls an export an ad reward.
    var exportMessage: String {
        switch self {
        case .notConfigured:
            return String(localized: "Videos are not available in this version of the app.")
        case .noConsent:
            return String(localized: "Videos cannot play with your current ad privacy choices.")
        case .loadFailed:
            return String(localized: "No video is available right now.")
        case .timedOut:
            return String(localized: "The video did not load in time.")
        case .couldNotPresent:
            return String(localized: "The video could not start.")
        }
    }
}

/// What happened after the person tapped "Watch an ad to export".
enum ExportVideoOutcome: Equatable {
    /// The SDK's earned-reward handler fired.
    case earned
    /// The video played but was closed before the end. This is the person's choice, not a failure.
    case closedEarly
    /// No video could be provided.
    case unavailable(RewardedUnavailableReason)
}

/// The next screen of the export sheet for an outcome.
enum ExportFlowDecision: Equatable {
    /// Grant one export and go to Share / Save to Files / Print.
    case unlock
    /// Say why no video can play and point to the other ways to export (export pack or Premium).
    /// A missing video never unlocks an export by itself.
    case videoUnavailable(RewardedUnavailableReason)
    /// Offer "Watch again" and "Not now". The export stays locked.
    case offerWatchAgain
}

/// Export fallback rules.
///
/// Decision (export gate, 2026-11-17): a video that cannot be provided never unlocks an export. The person is told
/// why and can try again, or use an export pack or Premium. Closing a video early does not unlock the export either.
enum ExportFallbackPolicy {
    /// Load attempts made by the sheet for one tap before it reports that no video is available (first try plus one retry).
    static let loadAttemptsBeforeFallback = 2
    /// How long the sheet waits for a video after the tap before reporting that no video is available.
    static let adWaitTimeout: TimeInterval = 20

    static func decision(for outcome: ExportVideoOutcome) -> ExportFlowDecision {
        switch outcome {
        case .earned:
            return .unlock
        case .closedEarly:
            return .offerWatchAgain
        case .unavailable(let reason):
            return .videoUnavailable(reason)
        }
    }

    /// True when the sheet should send one more load request instead of giving up.
    /// Only plain load failures are retried. Consent, configuration and presentation problems will not fix themselves.
    static func shouldRetryLoad(after reason: RewardedUnavailableReason, attemptsSoFar: Int) -> Bool {
        guard reason == .loadFailed else { return false }
        return attemptsSoFar < loadAttemptsBeforeFallback
    }

    /// True when "Review privacy choices" helps: ads are blocked by consent and Google says the form is available.
    static func offersPrivacyOptions(for reason: RewardedUnavailableReason, privacyOptionsRequired: Bool) -> Bool {
        reason == .noConsent && privacyOptionsRequired
    }
}
