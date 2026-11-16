import Foundation

/// Sort orders offered in My Resumes. Pure, so it can be unit tested.
enum CKResumeSort: String, CaseIterable, Identifiable {
    case lastEdited
    case created
    case title
    case completion
    case template

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lastEdited: return String(localized: "Last edited")
        case .created: return String(localized: "Date created")
        case .title: return String(localized: "Name, A to Z")
        case .completion: return String(localized: "Most complete")
        case .template: return String(localized: "Template")
        }
    }

    /// The sort order as it reads after "sorted by" in the My Resumes summary line. Separate keys
    /// (not `title.lowercased()`), so languages that capitalise nouns keep their own casing.
    var inlineTitle: String {
        switch self {
        case .lastEdited: return String(localized: "last edited", comment: "Used in 'sorted by last edited'.")
        case .created: return String(localized: "date created", comment: "Used in 'sorted by date created'.")
        case .title: return String(localized: "name, A to Z", comment: "Used in 'sorted by name, A to Z'.")
        case .completion: return String(localized: "most complete", comment: "Used in 'sorted by most complete'.")
        case .template: return String(localized: "template", comment: "Used in 'sorted by template'.")
        }
    }

    func sorted(_ resumes: [Resume]) -> [Resume] {
        switch self {
        case .lastEdited:
            return resumes.sorted { $0.updatedAt > $1.updatedAt }
        case .created:
            return resumes.sorted { $0.createdAt > $1.createdAt }
        case .title:
            return resumes.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .completion:
            return resumes.sorted {
                if $0.completion != $1.completion { return $0.completion > $1.completion }
                return $0.updatedAt > $1.updatedAt
            }
        case .template:
            return resumes.sorted {
                let left = TemplateLibrary.spec(id: $0.templateID)?.name ?? ""
                let right = TemplateLibrary.spec(id: $1.templateID)?.name ?? ""
                let order = left.localizedCaseInsensitiveCompare(right)
                if order != .orderedSame { return order == .orderedAscending }
                return $0.updatedAt > $1.updatedAt
            }
        }
    }
}

enum CKResumeSearch {
    /// Every word of the query must appear in the title, template name, person name or job title.
    static func matches(_ resume: Resume, query: String) -> Bool {
        let tokens = query.lowercased().split(whereSeparator: { $0.isWhitespace }).map { String($0) }
        if tokens.isEmpty { return true }
        let templateName = TemplateLibrary.spec(id: resume.templateID)?.name ?? ""
        let haystack = [resume.title, templateName, resume.personal.fullName, resume.personal.professionalTitle]
            .joined(separator: " ")
            .lowercased()
        return tokens.allSatisfy { haystack.contains($0) }
    }
}

/// Plain counts used by "Compare versions".
struct CKResumeStats: Equatable {
    let sectionsWithContent: Int
    let entries: Int
    let bullets: Int
    let words: Int

    init(_ resume: Resume) {
        var sectionCount = 0
        var entryCount = 0
        var bulletCount = 0
        var wordCount = CKResumeStats.words(in: resume.personal.professionalTitle)

        for section in resume.sections where section.isVisible && section.hasContent {
            sectionCount += 1
            wordCount += CKResumeStats.words(in: section.text)
            for entry in section.entries where !entry.isEmpty {
                entryCount += 1
                let nonEmptyBullets = entry.bullets.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                bulletCount += nonEmptyBullets.count
                wordCount += CKResumeStats.words(in: entry.heading)
                wordCount += CKResumeStats.words(in: entry.subheading)
                wordCount += CKResumeStats.words(in: entry.detail)
                wordCount += CKResumeStats.words(in: entry.extra)
                for bullet in nonEmptyBullets { wordCount += CKResumeStats.words(in: bullet) }
            }
            for group in section.skillGroups {
                for item in group.items { wordCount += CKResumeStats.words(in: item) }
            }
        }

        self.sectionsWithContent = sectionCount
        self.entries = entryCount
        self.bullets = bulletCount
        self.words = wordCount
    }

    static func words(in text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}
