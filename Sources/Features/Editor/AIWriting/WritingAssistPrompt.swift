import Foundation

/// Instructions and prompts for the on-device model. Plain strings so they can be tested without FoundationModels.
enum WritingAssistPrompt {
    /// Longest text sent to the model, in characters.
    static let inputLimit = 2_000

    static let instructions = """
    You are a careful resume editor. You rewrite text that a person wrote for their own resume.
    Rules you must always follow:
    - Keep every fact exactly as written: employers, job titles, schools, names, numbers, dates, skills, tools and achievements.
    - Never invent or add employers, numbers, percentages, amounts, dates, years of experience, skills, tools, certifications or achievements. If a detail is not in the text, leave it out.
    - Write in the same language as the text. Do not translate.
    - Output only the rewritten text. No introduction, no explanation, no notes, no quotation marks, no markdown, no headings.
    - When the text has several lines, each line is a separate bullet point. Return separate lines, one per bullet, in the same order, without bullet symbols or numbers.
    - Keep the person's point of view and keep it plain and professional.
    """

    static func task(for mode: WritingAssistMode) -> String {
        switch mode {
        case .improveWording:
            return "Improve the wording so it reads clearly and professionally. Keep the meaning and every fact."
        case .makeConcise:
            return "Make the text shorter and tighter. Remove filler words and repetition. Keep every fact."
        case .strongerActionVerbs:
            return "Start each line with a strong, specific action verb. Keep the tense the text already uses. Keep every fact."
        case .fixGrammar:
            return "Fix spelling, grammar and punctuation only. Do not change the wording otherwise."
        case .professionalSummaryFromExperience:
            return "Write a professional summary of two to four sentences for the top of this resume, using only facts from the work experience below. Do not state a number of years of experience. Return one paragraph."
        }
    }

    static func prompt(for mode: WritingAssistMode, text: String, context: String) -> String {
        let text = truncated(text)
        let context = truncated(context)
        var parts: [String] = ["Task: " + task(for: mode)]
        if mode.usesContextAsSource {
            parts.append("Work experience:\n" + context)
            if !WritingAssistText.isBlank(text) {
                parts.append("Current summary, for tone only:\n" + text)
            }
        } else {
            if !WritingAssistText.isBlank(context) {
                parts.append("About the role, for reference only. Do not add these details to the text: " + context)
            }
            parts.append("Text:\n" + text)
        }
        return parts.joined(separator: "\n\n")
    }

    /// Cuts text to `limit` characters, at the last line break or space when there is one near the end.
    static func truncated(_ text: String, limit: Int = inputLimit) -> String {
        guard text.count > limit else { return text }
        let head = String(text.prefix(limit))
        if let cut = head.lastIndex(where: { $0 == "\n" || $0 == " " }),
           head.distance(from: head.startIndex, to: cut) > limit / 2 {
            return String(head[..<cut])
        }
        return head
    }
}

/// Small pure helpers shared by the editor call sites and the sheet.
enum WritingAssistText {
    static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Bullets as the model sees them: one per line, empty ones left out.
    static func joinBullets(_ bullets: [String]) -> String {
        bullets
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// A sanitized suggestion back into bullets.
    static func splitBullets(_ text: String) -> [String] {
        text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Same words and order, ignoring spacing and line breaks.
    static func isSameText(_ a: String, _ b: String) -> Bool {
        collapsed(a) == collapsed(b)
    }

    static func collapsed(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// "Role: Designer at Acme" for a bullet block. Empty when the entry has neither.
    static func roleLine(heading: String, subheading: String) -> String {
        let role = heading.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = subheading.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (role.isEmpty, place.isEmpty) {
        case (true, true): return ""
        case (false, true): return "Role: " + role
        case (true, false): return "Organisation: " + place
        case (false, false): return "Role: " + role + " at " + place
        }
    }

    /// Visible work experience and internships, as text for "Summary from my experience". Dates are left out
    /// on purpose so the model has no numbers to turn into "years of experience".
    static func experienceContext(from sections: [ResumeSection]) -> String {
        var lines: [String] = []
        for section in sections where section.isVisible && (section.kind == .experience || section.kind == .internships) {
            for entry in section.entries {
                let role = roleLine(heading: entry.heading, subheading: entry.subheading)
                if !role.isEmpty { lines.append(role) }
                let detail = entry.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                if !detail.isEmpty { lines.append(detail) }
                for bullet in entry.bullets {
                    let trimmed = bullet.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { lines.append("- " + trimmed) }
                }
            }
        }
        return WritingAssistPrompt.truncated(lines.joined(separator: "\n"))
    }
}
