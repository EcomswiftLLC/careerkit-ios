import Foundation

/// Where the writing help is used. Decides which modes the menu offers and how text is shown.
enum WritingAssistTarget: Equatable {
    case summary
    case bullets
}

enum WritingAssistMode: String, CaseIterable, Identifiable {
    case improveWording
    case makeConcise
    case strongerActionVerbs
    case fixGrammar
    case professionalSummaryFromExperience

    var id: String { rawValue }

    var title: String {
        switch self {
        case .improveWording: return "Improve wording"
        case .makeConcise: return "Make it shorter"
        case .strongerActionVerbs: return "Stronger action verbs"
        case .fixGrammar: return "Fix grammar and spelling"
        case .professionalSummaryFromExperience: return "Summary from my experience"
        }
    }

    var systemImage: String {
        switch self {
        case .improveWording: return "wand.and.stars"
        case .makeConcise: return "arrow.down.right.and.arrow.up.left"
        case .strongerActionVerbs: return "bolt"
        case .fixGrammar: return "checkmark.circle"
        case .professionalSummaryFromExperience: return "text.badge.plus"
        }
    }

    /// This mode writes new text from the context (the work experience) instead of rewriting the field.
    var usesContextAsSource: Bool { self == .professionalSummaryFromExperience }

    /// Whether there is enough to work with. Menu items are disabled otherwise.
    func canRun(text: String, context: String) -> Bool {
        if usesContextAsSource { return !WritingAssistText.isBlank(context) }
        return !WritingAssistText.isBlank(text)
    }

    static func modes(for target: WritingAssistTarget) -> [WritingAssistMode] {
        switch target {
        case .summary: return [.improveWording, .makeConcise, .fixGrammar, .professionalSummaryFromExperience]
        case .bullets: return [.improveWording, .strongerActionVerbs, .makeConcise, .fixGrammar]
        }
    }
}

/// One tap on a menu item. The text is captured at that moment so the sheet compares against it.
struct WritingAssistRequest: Identifiable, Equatable {
    let id = UUID()
    let mode: WritingAssistMode
    let target: WritingAssistTarget
    let original: String
    let context: String
}
