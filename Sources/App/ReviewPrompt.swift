import SwiftUI
// StoreKit use outside Sources/Purchases: the system review prompt only.
import StoreKit

/// Key-value storage for the review prompt. `UserDefaults` conforms; tests use an in-memory fake.
protocol ReviewPromptStorage: AnyObject {
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: ReviewPromptStorage {}

/// Decides when to ask for an App Store rating, following Apple's guidance: rarely, and at a happy moment.
///
/// Rules:
/// - Only right after an export that really finished (Share or Save completed, not cancelled).
/// - Only once the person has finished at least 2 exports, or has used the app on 3 or more different days.
/// - Never in the first session (first launch).
/// - Never more than once per app version.
/// - Never shortly after an export error.
///
/// Everything is stored on the device. The system still decides whether the prompt is actually shown.
struct ReviewPromptPolicy {
    static let minimumExports: Int = 2
    static let minimumActiveDays: Int = 3
    /// A finished export within this time after an error does not trigger the prompt.
    static let errorCooldown: TimeInterval = 10 * 60

    enum Key {
        static let sessionCount = "ck.review.sessionCount"
        static let activeDays = "ck.review.activeDays"
        static let lastActiveDay = "ck.review.lastActiveDay"
        static let completedExports = "ck.review.completedExports"
        static let lastErrorAt = "ck.review.lastErrorAt"
        static let promptedVersion = "ck.review.promptedVersion"
    }

    let storage: ReviewPromptStorage
    let appVersion: String
    let now: () -> Date
    let calendar: Calendar

    init(storage: ReviewPromptStorage,
         appVersion: String,
         calendar: Calendar = Calendar.current,
         now: @escaping () -> Date = { Date() }) {
        self.storage = storage
        self.appVersion = appVersion
        self.calendar = calendar
        self.now = now
    }

    /// The marketing version from Info.plist, for example "1.0.0".
    static var currentAppVersion: String {
        let value: Any? = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
        return (value as? String) ?? "0"
    }

    // MARK: Stored values

    var sessionCount: Int { int(Key.sessionCount) }
    var activeDays: Int { int(Key.activeDays) }
    var completedExports: Int { int(Key.completedExports) }

    var promptedVersion: String? {
        storage.object(forKey: Key.promptedVersion) as? String
    }

    var lastErrorAt: Date? {
        guard let seconds = storage.object(forKey: Key.lastErrorAt) as? Double else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    private func int(_ key: String) -> Int {
        if let value = storage.object(forKey: key) as? Int { return value }
        if let number = storage.object(forKey: key) as? NSNumber { return number.intValue }
        return 0
    }

    // MARK: Events

    /// Call once per app launch.
    func startSession() {
        storage.set(sessionCount + 1, forKey: Key.sessionCount)
        let today: Double = calendar.startOfDay(for: now()).timeIntervalSince1970
        let lastDay: Double? = storage.object(forKey: Key.lastActiveDay) as? Double
        if lastDay != today {
            storage.set(activeDays + 1, forKey: Key.activeDays)
            storage.set(today, forKey: Key.lastActiveDay)
        }
    }

    /// An export failed (the sheet could not be shown or reported an error).
    func recordExportFailure() {
        storage.set(now().timeIntervalSince1970, forKey: Key.lastErrorAt)
    }

    /// An export really finished. Returns true when the review prompt should be requested now,
    /// and in that case remembers this version so it is never asked again for it.
    @discardableResult
    func recordExportSuccess() -> Bool {
        storage.set(completedExports + 1, forKey: Key.completedExports)
        guard shouldRequestReview() else { return false }
        storage.set(appVersion, forKey: Key.promptedVersion)
        return true
    }

    /// Pure check of the rules above, without changing anything.
    func shouldRequestReview() -> Bool {
        // The first session is never the moment to ask.
        guard sessionCount >= 2 else { return false }
        // Once per app version at most.
        guard promptedVersion != appVersion else { return false }
        // Not right after something went wrong.
        if let errorAt = lastErrorAt, abs(now().timeIntervalSince(errorAt)) < ReviewPromptPolicy.errorCooldown {
            return false
        }
        // Enough real use.
        return completedExports >= ReviewPromptPolicy.minimumExports
            || activeDays >= ReviewPromptPolicy.minimumActiveDays
    }
}

/// Connects export results to the policy and tells the root view when to ask.
@MainActor
final class ReviewPromptCenter: ObservableObject {
    static let shared = ReviewPromptCenter(policy: ReviewPromptPolicy(storage: UserDefaults.standard,
                                                                      appVersion: ReviewPromptPolicy.currentAppVersion))

    /// Goes up by one each time the system review prompt should be requested.
    @Published private(set) var requestCount: Int = 0

    let policy: ReviewPromptPolicy

    /// Counts this launch as one session. The shared instance is created once per launch.
    init(policy: ReviewPromptPolicy) {
        self.policy = policy
        policy.startSession()
    }

    /// Called by the export flow with the real outcome of Share, Save to Files or Print.
    func exportFinished(_ outcome: ExportOutcome) {
        #if DEBUG
        if CKScreenshotSupport.isActive { return }
        #endif
        switch outcome {
        case .completed:
            if policy.recordExportSuccess() {
                requestCount += 1
            }
        case .failed:
            policy.recordExportFailure()
        case .cancelled:
            break
        }
    }
}

/// Asks the system for the review prompt when `ReviewPromptCenter` says so.
/// Waits a moment so the "Your export is done" screen is visible first.
private struct ReviewPromptHost: ViewModifier {
    @ObservedObject var center: ReviewPromptCenter
    @Environment(\.requestReview) private var requestReview

    func body(content: Content) -> some View {
        content
            .onChange(of: center.requestCount) { _, _ in
                let action: RequestReviewAction = requestReview
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    action()
                }
            }
    }
}

extension View {
    /// Attach once, at the root of the window.
    @MainActor
    func ckReviewPromptHost() -> some View {
        modifier(ReviewPromptHost(center: ReviewPromptCenter.shared))
    }
}
