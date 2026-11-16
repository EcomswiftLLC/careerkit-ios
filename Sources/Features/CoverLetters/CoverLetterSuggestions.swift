import Foundation

/// The editable parts of a cover letter that offer suggestion sentences.
enum CoverLetterField: String, CaseIterable, Identifiable {
    case greeting
    case introduction
    case experience
    case interest
    case closing
    case signOff

    var id: String { rawValue }

    var title: String {
        switch self {
        case .greeting: return String(localized: "Greeting")
        case .introduction: return String(localized: "Introduction")
        case .experience: return String(localized: "Relevant experience")
        case .interest: return String(localized: "Why this company")
        case .closing: return String(localized: "Closing")
        case .signOff: return String(localized: "Sign-off")
        }
    }

    var suggestionTitle: String {
        switch self {
        case .greeting: return String(localized: "Greeting suggestions")
        case .introduction: return String(localized: "Introduction suggestions")
        case .experience: return String(localized: "Experience suggestions")
        case .interest: return String(localized: "Interest suggestions")
        case .closing: return String(localized: "Closing suggestions")
        case .signOff: return String(localized: "Sign-off suggestions")
        }
    }
}

/// Professionally written suggestion sentences. Placeholders in braces are filled from the letter when inserted:
/// {role}, {company}, {manager}, and {position} (a whole noun phrase such as "the Designer position", used by the
/// translations in Localizable.xcstrings). The sentences are localized with String(localized:).
/// Everything is generic and meant to be edited.
enum CoverLetterSuggestions {
    static func items(for field: CoverLetterField) -> [String] {
        switch field {
        case .greeting:
            return [
                String(localized: "Dear {manager},"),
                String(localized: "Dear Hiring Manager,"),
                String(localized: "Dear {company} hiring team,"),
                String(localized: "Hello {manager},")
            ]
        case .introduction:
            return [
                String(localized: "I am writing to apply for the {role} position at {company}. My background in the field has prepared me well for this work, and I would like to contribute to your team."),
                String(localized: "I was glad to see the {role} opening at {company}. The role matches both my experience and the kind of work I want to do next."),
                String(localized: "Please accept my application for the {role} role at {company}. I bring several years of relevant experience and a steady record of delivering what I promise."),
                String(localized: "I am applying for the {role} position because it combines the skills I have built over my career with work I find worthwhile.")
            ]
        case .experience:
            return [
                String(localized: "In my current role I manage day-to-day priorities, work closely with colleagues in other teams and report clearly on progress. These habits would carry over directly to the {role} position."),
                String(localized: "Over the past few years I have taken on larger responsibilities each year, and I have a record of meeting deadlines and keeping people informed. I would bring the same approach to {company}."),
                String(localized: "One example from my recent work: I found a recurring problem, proposed a simple fix and followed it through until the results were visible. I would take the same practical approach in the {role} position."),
                String(localized: "My experience includes planning work, communicating with customers and colleagues, and learning new tools quickly. I am comfortable working independently and as part of a team.")
            ]
        case .interest:
            return [
                String(localized: "I am drawn to {company} because of the way it serves its customers, and I would like to be part of that work."),
                String(localized: "What interests me most about {company} is the focus on doing the basics well. I work the same way."),
                String(localized: "I have followed {company} for some time and respect the quality of what it delivers. I would value the chance to learn from the team and contribute from the start."),
                String(localized: "The {role} position fits where I want to grow, and {company} is a place where I believe I could do that.")
            ]
        case .closing:
            return [
                String(localized: "Thank you for your time and consideration. I would welcome the chance to discuss how I can help {company}, and I am available for a conversation whenever suits you."),
                String(localized: "I have attached my resume for your review. I would be glad to talk through my experience in more detail."),
                String(localized: "Thank you for considering my application. I look forward to hearing from you."),
                String(localized: "I would appreciate the opportunity to speak with you about the {role} position. Please contact me by email or phone at any time.")
            ]
        case .signOff:
            return [
                String(localized: "Sincerely,"),
                String(localized: "Kind regards,"),
                String(localized: "Best regards,"),
                String(localized: "With thanks,"),
                String(localized: "Respectfully,")
            ]
        }
    }

    /// Fills the placeholders. Missing details fall back to neutral wording so no braces are left in the letter.
    static func fill(_ text: String, company: String, role: String, manager: String) -> String {
        func clean(_ value: String, fallback: String) -> String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? fallback : trimmed
        }
        let managerValue = clean(manager, fallback: String(localized: "Hiring Manager",
                                                           comment: "Fallback for {manager} in cover letter suggestions, e.g. Dear Hiring Manager,"))
        let roleValue = role.trimmingCharacters(in: .whitespacesAndNewlines)
        // {position} is a whole noun phrase ("the Designer position"). Translations use it instead of {role},
        // so the fallback reads naturally in every language and grammatical case.
        let positionValue = roleValue.isEmpty
            ? String(localized: "the advertised position", comment: "Fallback for {position} in translated cover letter suggestions")
            : String(localized: "the \(roleValue) position", comment: "Value for {position} in translated cover letter suggestions. The argument is the job title.")
        return text
            .replacingOccurrences(of: "{company}", with: clean(company, fallback: String(localized: "your company",
                                                                                          comment: "Fallback for {company} in cover letter suggestions")))
            .replacingOccurrences(of: "{position}", with: positionValue)
            .replacingOccurrences(of: "{role}", with: roleValue.isEmpty
                ? String(localized: "advertised", comment: "Fallback for {role} in English cover letter suggestions: the advertised position")
                : roleValue)
            .replacingOccurrences(of: "{manager}", with: managerValue)
    }
}

/// Copies sender details from a resume into a cover letter.
enum CoverLetterPrefill {
    /// With `overwrite == false` only empty fields are filled.
    static func apply(_ resume: Resume, to letter: inout CoverLetter, overwrite: Bool) {
        func set(_ keyPath: WritableKeyPath<CoverLetter, String>, _ value: String) {
            guard !value.isEmpty else { return }
            if overwrite || letter[keyPath: keyPath].isEmpty { letter[keyPath: keyPath] = value }
        }
        set(\.senderName, resume.personal.fullName)
        set(\.senderTitle, resume.personal.professionalTitle)
        set(\.senderEmail, resume.personal.email)
        set(\.senderPhone, resume.personal.phone)
        set(\.senderLocation, resume.personal.locationLine)
    }
}
