import Foundation

/// The blank builder shows sample text for anything the user has not written yet, so the page layout is easy to judge.
/// The result is only used for the on-screen preview and is never saved or exported.
enum BlankPreviewMapper {
    static func previewResume(from resume: Resume, now: Date = Date()) -> Resume {
        var copy = resume
        if copy.personal.fullName.isEmpty { copy.personal.fullName = String(localized: "Your Name") }
        if copy.personal.professionalTitle.isEmpty { copy.personal.professionalTitle = String(localized: "Your professional title") }
        if copy.personal.email.isEmpty { copy.personal.email = "you@example.com" }
        if copy.personal.phone.isEmpty { copy.personal.phone = "555 010 0100" }
        if copy.personal.city.isEmpty { copy.personal.city = String(localized: "City") }
        if copy.personal.country.isEmpty { copy.personal.country = String(localized: "Country") }

        let year = MonthYearHelper.currentYear(now: now)
        for index in copy.sections.indices {
            let section = copy.sections[index]
            guard section.isVisible, !section.hasContent else { continue }
            copy.sections[index] = filled(section, year: year)
        }
        return copy
    }

    private static func filled(_ section: ResumeSection, year: Int) -> ResumeSection {
        var result = section
        switch section.kind.shape {
        case .text:
            if section.kind == .summary {
                result.text = WritingExamples.summaryCategories.first?.items.first
                    ?? String(localized: "A short summary of your experience and strengths.")
            } else {
                result.text = String(localized: "Reading, hiking and volunteering.")
            }
        case .entries:
            let labels = EntryLabels.labels(for: section.kind)
            var entry = ResumeEntry()
            entry.heading = labels.heading
            entry.subheading = labels.subheading
            if labels.showsLocation { entry.location = String(localized: "City, Country") }
            if labels.showsDates {
                entry.start = MonthYear(year: year - 3, month: 1)
                entry.end = MonthYear(year: year - 1, month: 6)
            }
            if labels.showsBullets {
                entry.bullets = [
                    String(localized: "Describe a result you achieved, with a number if you have one."),
                    String(localized: "Say what you were responsible for and how it helped the team.")
                ]
            }
            result.entries = [entry]
        case .skillGroups:
            let items: [String] = [String(localized: "First item"), String(localized: "Second item"), String(localized: "Third item")]
            if result.skillGroups.isEmpty {
                result.skillGroups = [SkillGroup(name: "", items: items)]
            } else {
                result.skillGroups[0].items = items
            }
        }
        return result
    }
}
