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
        case .greeting: return "Greeting"
        case .introduction: return "Introduction"
        case .experience: return "Relevant experience"
        case .interest: return "Why this company"
        case .closing: return "Closing"
        case .signOff: return "Sign-off"
        }
    }

    var suggestionTitle: String {
        switch self {
        case .greeting: return "Greeting suggestions"
        case .introduction: return "Introduction suggestions"
        case .experience: return "Experience suggestions"
        case .interest: return "Interest suggestions"
        case .closing: return "Closing suggestions"
        case .signOff: return "Sign-off suggestions"
        }
    }
}

/// Professionally written suggestion sentences. Placeholders in braces are filled from the letter when inserted:
/// {role}, {company}, {manager}. Everything is generic and meant to be edited.
enum CoverLetterSuggestions {
    static func items(for field: CoverLetterField) -> [String] {
        switch field {
        case .greeting:
            return [
                "Dear {manager},",
                "Dear Hiring Manager,",
                "Dear {company} hiring team,",
                "Hello {manager},"
            ]
        case .introduction:
            return [
                "I am writing to apply for the {role} position at {company}. My background in the field has prepared me well for this work, and I would like to contribute to your team.",
                "I was glad to see the {role} opening at {company}. The role matches both my experience and the kind of work I want to do next.",
                "Please accept my application for the {role} role at {company}. I bring several years of relevant experience and a steady record of delivering what I promise.",
                "I am applying for the {role} position because it combines the skills I have built over my career with work I find worthwhile."
            ]
        case .experience:
            return [
                "In my current role I manage day-to-day priorities, work closely with colleagues in other teams and report clearly on progress. These habits would carry over directly to the {role} position.",
                "Over the past few years I have taken on larger responsibilities each year, and I have a record of meeting deadlines and keeping people informed. I would bring the same approach to {company}.",
                "One example from my recent work: I found a recurring problem, proposed a simple fix and followed it through until the results were visible. I would take the same practical approach in the {role} position.",
                "My experience includes planning work, communicating with customers and colleagues, and learning new tools quickly. I am comfortable working independently and as part of a team."
            ]
        case .interest:
            return [
                "I am drawn to {company} because of the way it serves its customers, and I would like to be part of that work.",
                "What interests me most about {company} is the focus on doing the basics well. I work the same way.",
                "I have followed {company} for some time and respect the quality of what it delivers. I would value the chance to learn from the team and contribute from the start.",
                "The {role} position fits where I want to grow, and {company} is a place where I believe I could do that."
            ]
        case .closing:
            return [
                "Thank you for your time and consideration. I would welcome the chance to discuss how I can help {company}, and I am available for a conversation whenever suits you.",
                "I have attached my resume for your review. I would be glad to talk through my experience in more detail.",
                "Thank you for considering my application. I look forward to hearing from you.",
                "I would appreciate the opportunity to speak with you about the {role} position. Please contact me by email or phone at any time."
            ]
        case .signOff:
            return ["Sincerely,", "Kind regards,", "Best regards,", "With thanks,", "Respectfully,"]
        }
    }

    /// Fills the placeholders. Missing details fall back to neutral wording so no braces are left in the letter.
    static func fill(_ text: String, company: String, role: String, manager: String) -> String {
        func clean(_ value: String, fallback: String) -> String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? fallback : trimmed
        }
        let managerValue = clean(manager, fallback: "Hiring Manager")
        return text
            .replacingOccurrences(of: "{company}", with: clean(company, fallback: "your company"))
            .replacingOccurrences(of: "{role}", with: clean(role, fallback: "advertised"))
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
