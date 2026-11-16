import SwiftUI

/// The five top-level destinations of the app.
enum AppTab: String, Hashable, CaseIterable {
    case home
    case resumes
    case templates
    case coverLetters
    case profile
}

/// User choice for light / dark mode. `system` follows the device.
enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return String(localized: "System")
        case .light: return String(localized: "Light")
        case .dark: return String(localized: "Dark")
        }
    }

    /// `nil` hands control back to the system setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// App-wide settings, backed by UserDefaults. Nothing here leaves the device.
@MainActor
final class AppState: ObservableObject {
    private enum Key {
        static let onboarded = "ck.hasCompletedOnboarding"
        static let pageSize = "ck.defaultPageSize"
        static let appearance = "ck.appearance"
        static let displayName = "ck.displayName"
    }

    private let defaults: UserDefaults

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.onboarded) }
    }

    /// Used by the new resume flow and cover letters when a page size is not chosen explicitly.
    @Published var defaultPageSize: PageSize {
        didSet { defaults.set(defaultPageSize.rawValue, forKey: Key.pageSize) }
    }

    @Published var appearance: AppearancePreference {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    /// Optional local name for the Home greeting. Never uploaded.
    @Published var displayName: String {
        didSet { defaults.set(displayName, forKey: Key.displayName) }
    }

    /// Not persisted. Lets any screen jump to another tab.
    @Published var selectedTab: AppTab = .home

    /// Not persisted. Goes up by one after "Delete all local data" or a restore that replaced documents.
    /// `RootTabView` uses it as the identity of the browse tabs, so every NavigationStack (and any editor
    /// left open in another tab) is rebuilt and cannot write a deleted or replaced document back.
    @Published private(set) var dataResetGeneration: Int = 0

    func resetNavigation() {
        dataResetGeneration += 1
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasCompletedOnboarding = defaults.bool(forKey: Key.onboarded)

        if let raw = defaults.string(forKey: Key.pageSize), let size = PageSize(rawValue: raw) {
            self.defaultPageSize = size
        } else {
            self.defaultPageSize = AppState.suggestedPageSize(regionCode: Locale.current.region?.identifier)
        }

        if let raw = defaults.string(forKey: Key.appearance), let value = AppearancePreference(rawValue: raw) {
            self.appearance = value
        } else {
            self.appearance = .system
        }

        self.displayName = defaults.string(forKey: Key.displayName) ?? ""
    }

    /// First name style value for greetings, trimmed. Empty when the user has not set one.
    var greetingName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// US Letter in the countries that use it, A4 everywhere else. Pure, so it is easy to test.
    nonisolated static func suggestedPageSize(regionCode: String?) -> PageSize {
        let letterRegions: Set<String> = ["US", "CA", "MX", "PH", "CL", "CO", "VE", "CR", "GT", "PA", "DO", "PR"]
        guard let regionCode else { return .a4 }
        return letterRegions.contains(regionCode.uppercased()) ? .usLetter : .a4
    }
}
