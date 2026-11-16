import Foundation

// Optional writing help that runs on the device (Apple's on-device model, iOS 26 and later).
// Nothing in this folder talks to a server. Only `FoundationModelsWritingEngine.swift` imports
// FoundationModels; everything else is plain Swift so it builds on iOS 17 and can be unit tested.

// MARK: - Availability

/// Whether writing help can be offered on this device right now.
enum WritingAssistAvailability: Equatable {
    case available
    case unavailable(Reason)

    enum Reason: Equatable {
        /// iOS older than 26, or an SDK without FoundationModels.
        case systemTooOld
        /// The device cannot run Apple Intelligence.
        case deviceNotEligible
        /// Apple Intelligence is turned off in Settings.
        case appleIntelligenceOff
        /// The model is still downloading or otherwise not ready.
        case modelNotReady
        /// Hidden on purpose (for example during screenshot runs) or a reason added in a later iOS.
        case other
    }

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    /// The entry point is only shown when the feature works. Unsupported devices see the app exactly as before.
    var showsEntryPoint: Bool { isAvailable }
}

// MARK: - Engine

/// Something that rewrites resume text. The real one wraps Apple's on-device model;
/// tests use a fake. Implementations return the model's raw text; the caller sanitizes it.
protocol WritingAssistEngine {
    var availability: WritingAssistAvailability { get }
    func rewrite(_ text: String, mode: WritingAssistMode, context: String) async throws -> String
}

// MARK: - Failures

/// Plain-language reasons a suggestion was not offered. The user's text is never changed in any of these cases.
enum WritingAssistFailure: Error, Equatable {
    case nothingToRewrite
    case noExperience
    case inputTooLong
    case unavailable
    case unsupportedLanguage
    case declined
    case emptySuggestion
    case suggestionTooLong
    case addedDetails
    case generic

    var message: String {
        switch self {
        case .nothingToRewrite:
            return String(localized: "Write something first, then ask for a suggestion.")
        case .noExperience:
            return String(localized: "Add some work experience first, then try again.")
        case .inputTooLong:
            return String(localized: "This text is too long for writing help. Try it on a shorter part.")
        case .unavailable:
            return String(localized: "Writing help is not ready on this device right now. Your text is unchanged.")
        case .unsupportedLanguage:
            return String(localized: "Writing help does not support this language yet. Your text is unchanged.")
        case .declined:
            return String(localized: "A suggestion could not be made for this text. Your text is unchanged.")
        case .addedDetails:
            return String(localized: "The suggestion added details that are not in your text, so it was not used.")
        case .emptySuggestion, .suggestionTooLong, .generic:
            return String(localized: "A suggestion could not be made this time. Your text is unchanged.")
        }
    }

    /// Whether "Try again" is worth offering. Asking again can give a different result for model output problems.
    var canRetry: Bool {
        switch self {
        case .emptySuggestion, .suggestionTooLong, .addedDetails, .generic, .unavailable:
            return true
        case .nothingToRewrite, .noExperience, .inputTooLong, .unsupportedLanguage, .declined:
            return false
        }
    }
}

// MARK: - Factory

enum WritingAssist {
    /// The on-device engine, or nil where FoundationModels does not exist (iOS 17 to 25, older SDKs).
    static func makeEngine() -> (any WritingAssistEngine)? {
        #if DEBUG
        // Keep CI screenshots identical on every simulator.
        if CKScreenshotSupport.isActive { return nil }
        #endif
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return FoundationModelsWritingEngine()
        }
        #endif
        return nil
    }

    static var availability: WritingAssistAvailability {
        guard let engine = makeEngine() else { return .unavailable(.systemTooOld) }
        return engine.availability
    }

    /// Call sites check this before adding any writing help UI, so nothing changes where it is unavailable.
    static var isAvailable: Bool { availability.showsEntryPoint }
}

// MARK: - One-step undo

/// Remembers the text before a suggestion was accepted. Undo is offered only while the field
/// still holds exactly the accepted suggestion, so it never throws away edits made afterwards.
struct WritingAssistUndo<Value: Equatable>: Equatable {
    let previous: Value
    let applied: Value

    func canUndo(current: Value) -> Bool { current == applied }
}
