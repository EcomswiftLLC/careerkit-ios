import Foundation

/// Search and filter state for the template browser. Pure value type, no UI.
struct CKTemplateFilter: Equatable {
    enum Length: String, CaseIterable, Identifiable {
        case onePage = "One page"
        case multiPage = "Multi page"
        var id: String { rawValue }

        /// Localized label for the filter menu.
        var displayName: String {
            switch self {
            case .onePage: return String(localized: "One page")
            case .multiPage: return String(localized: "Multi page")
            }
        }
    }

    var query: String = ""
    var category: TemplateCategory?
    var industry: Industry?
    var level: ProfessionalLevel?
    var style: DesignStyle?
    var length: Length?
    var atsOnly: Bool = false
    var photoOnly: Bool = false

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when any chip is set (the search text is not counted).
    var hasFacets: Bool {
        category != nil || industry != nil || level != nil || style != nil || length != nil || atsOnly || photoOnly
    }

    /// True when anything narrows the list, including search text.
    var isActive: Bool {
        hasFacets || !trimmedQuery.isEmpty
    }

    mutating func reset() {
        self = CKTemplateFilter()
    }

    func apply(to templates: [TemplateSpec]) -> [TemplateSpec] {
        let tokens: [String] = CKTemplateFilter.fold(trimmedQuery)
            .split(whereSeparator: { $0.isWhitespace })
            .map { String($0) }

        return templates.filter { (template: TemplateSpec) -> Bool in
            if let category = self.category, template.category != category { return false }
            if let industry = self.industry, !template.industries.contains(industry) { return false }
            if let level = self.level, !template.levels.contains(level) { return false }
            if let style = self.style, template.designStyle != style { return false }
            if self.atsOnly && !template.isATSFriendly { return false }
            if self.photoOnly && !template.supportsPhoto { return false }
            if let length = self.length {
                switch length {
                case .onePage:
                    if template.typicalPages != 1 { return false }
                case .multiPage:
                    if template.typicalPages < 2 { return false }
                }
            }
            if tokens.isEmpty { return true }
            let haystack = CKTemplateFilter.searchText(for: template)
            return tokens.allSatisfy { haystack.contains($0) }
        }
    }

    /// Lower-cased text a search query is matched against. Holds the localized words and the English
    /// raw values, so a search works in the app language and in English.
    /// `name` and `tagline` are already localized by the template library.
    static func searchText(for template: TemplateSpec) -> String {
        var parts: [String] = [
            template.name,
            template.tagline,
            template.category.displayName,
            template.category.rawValue,
            template.designStyle.displayName,
            template.designStyle.rawValue
        ]
        parts.append(contentsOf: template.industries.map { $0.displayName })
        parts.append(contentsOf: template.industries.map { $0.rawValue })
        parts.append(contentsOf: template.levels.map { $0.displayName })
        parts.append(contentsOf: template.levels.map { $0.rawValue })
        // English search words stay as they are (not shown anywhere), the localized badge words are added.
        if template.isATSFriendly {
            parts.append("ats friendly")
            parts.append(String(localized: "ATS friendly"))
        }
        if template.supportsPhoto {
            parts.append("photo picture")
            parts.append(String(localized: "Photo"))
        }
        return fold(parts.joined(separator: " "))
    }

    /// Lower case without accents, so "tecnico" finds "Técnico" and "modele" finds "Modèle".
    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil).lowercased()
    }

    /// Groups templates by category in the enum's order, skipping empty groups.
    static func grouped(_ templates: [TemplateSpec]) -> [(category: TemplateCategory, templates: [TemplateSpec])] {
        var groups: [(category: TemplateCategory, templates: [TemplateSpec])] = []
        for category in TemplateCategory.allCases {
            let items = templates.filter { $0.category == category }
            if !items.isEmpty {
                groups.append((category: category, templates: items))
            }
        }
        return groups
    }

    /// One plain sentence per category, shown under each section title.
    static func summary(for category: TemplateCategory) -> String {
        switch category {
        case .professional: return String(localized: "Conservative, readable layouts for established fields.")
        case .modern: return String(localized: "Clean, current layouts with a clear hierarchy.")
        case .creative: return String(localized: "More expressive layouts for design and marketing work.")
        case .academic: return String(localized: "Space for research, publications and long histories.")
        case .entryLevel: return String(localized: "Layouts that lead with education and skills.")
        case .technical: return String(localized: "Scannable layouts for engineering and data roles.")
        }
    }
}
