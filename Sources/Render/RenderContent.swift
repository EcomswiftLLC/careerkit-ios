import Foundation

/// Decides what is rendered. The renderer, the validator and the ATS check all use these
/// rules, so "what should be in the PDF" has one definition.
enum RenderContent {
    static func trimmed(_ s: String) -> String {
        return s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    /// Drops a leading bullet marker typed or pasted by the user, so the template bullet is not doubled.
    static func cleanBullet(_ raw: String) -> String {
        var s: String = trimmed(raw)
        let markers: Set<Character> = ["\u{2022}", "-", "\u{2013}", "\u{2014}", "*", "\u{00B7}", "\u{25AA}", "\u{2023}", "\u{25E6}", "\u{203A}"]
        if let first = s.first, markers.contains(first) {
            let rest = s.dropFirst()
            if let next = rest.first, next.isWhitespace {
                s = trimmed(String(rest))
            }
        }
        return s
    }

    static func paragraphs(_ text: String) -> [String] {
        return text.components(separatedBy: "\n")
            .map { trimmed($0) }
            .filter { !$0.isEmpty }
    }

    static func renderableBullets(_ entry: ResumeEntry) -> [String] {
        return entry.bullets.map { cleanBullet($0) }.filter { !$0.isEmpty }
    }

    static func entryIsRenderable(_ entry: ResumeEntry) -> Bool {
        if !trimmed(entry.heading).isEmpty { return true }
        if !trimmed(entry.subheading).isEmpty { return true }
        if !trimmed(entry.detail).isEmpty { return true }
        if !trimmed(entry.extra).isEmpty { return true }
        return !renderableBullets(entry).isEmpty
    }

    static func renderableEntries(_ section: ResumeSection) -> [ResumeEntry] {
        return section.entries.filter { entryIsRenderable($0) }
    }

    static func renderableSkillGroups(_ section: ResumeSection) -> [SkillGroup] {
        var out: [SkillGroup] = []
        for group in section.skillGroups {
            let items: [String] = group.items.map { trimmed($0) }.filter { !$0.isEmpty }
            if items.isEmpty { continue }
            var copy = group
            copy.name = trimmed(group.name)
            copy.items = items
            out.append(copy)
        }
        return out
    }

    static func sectionIsRenderable(_ section: ResumeSection) -> Bool {
        guard section.isVisible else { return false }
        if !paragraphs(section.text).isEmpty { return true }
        if !renderableEntries(section).isEmpty { return true }
        return !renderableSkillGroups(section).isEmpty
    }

    static func visibleSections(_ resume: Resume) -> [ResumeSection] {
        return resume.sections.filter { sectionIsRenderable($0) }
    }

    static func label(for section: ResumeSection) -> String {
        let title: String = trimmed(section.title)
        return title.isEmpty ? section.kind.defaultTitle : title
    }

    /// Strings that must be present in the text of the exported PDF.
    static func expectedStrings(for resume: Resume) -> [String] {
        var out: [String] = []
        let p = resume.personal
        for value in [p.fullName, p.email, p.phone] {
            let t = trimmed(value)
            if !t.isEmpty { out.append(t) }
        }
        for section in visibleSections(resume) {
            out.append(label(for: section))
            out.append(contentsOf: paragraphs(section.text))
            for entry in renderableEntries(section) {
                let heading = trimmed(entry.heading)
                let sub = trimmed(entry.subheading)
                if !heading.isEmpty { out.append(heading) }
                if !sub.isEmpty { out.append(sub) }
                out.append(contentsOf: renderableBullets(entry))
            }
        }
        return out
    }
}
