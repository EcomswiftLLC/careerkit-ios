import XCTest
@testable import CareerKit

final class EditorWritingExamplesTests: XCTestCase {
    func testSummaryAndAchievementLibrariesAreNotEmpty() {
        XCTAssertGreaterThanOrEqual(WritingExamples.summaryCategories.count, 6)
        XCTAssertGreaterThanOrEqual(WritingExamples.achievementCategories.count, 8)
        for category in WritingExamples.summaryCategories + WritingExamples.achievementCategories {
            XCTAssertFalse(category.name.isEmpty)
            XCTAssertGreaterThanOrEqual(category.items.count, 3, category.name)
        }
        XCTAssertFalse(WritingExamples.allSummaries.isEmpty)
        XCTAssertFalse(WritingExamples.allAchievements.isEmpty)
    }

    func testCategoryIDsAreUnique() {
        let ids = (WritingExamples.summaryCategories + WritingExamples.achievementCategories).map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testExamplesFollowTheWritingRules() {
        let all = WritingExamples.allSummaries + WritingExamples.allAchievements
        for text in all {
            XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(text.contains("\u{2014}"), "No em-dashes: \(text)")
            XCTAssertFalse(text.lowercased().contains("lorem"), text)
            XCTAssertFalse(text.contains("{"), text)
        }
        XCTAssertEqual(all.count, Set(all).count, "Examples should not repeat")
    }
}

final class EditorEntryLabelsTests: XCTestCase {
    func testEveryEntryKindHasLabels() {
        for kind in SectionKind.allCases where kind.shape == .entries {
            let labels = EntryLabels.labels(for: kind)
            XCTAssertFalse(labels.heading.isEmpty, kind.rawValue)
            XCTAssertFalse(labels.subheading.isEmpty, kind.rawValue)
            XCTAssertFalse(labels.addButton.isEmpty, kind.rawValue)
        }
    }

    func testReferencesHaveNoDatesOrBullets() {
        let labels = EntryLabels.labels(for: .references)
        XCTAssertFalse(labels.showsDates)
        XCTAssertFalse(labels.showsBullets)
    }

    func testExperienceOffersCurrentToggleAndExamples() {
        let labels = EntryLabels.labels(for: .experience)
        XCTAssertNotNil(labels.currentToggle)
        XCTAssertTrue(labels.offersExamples)
    }
}

final class EditorBlankPreviewTests: XCTestCase {
    private func blank() -> Resume {
        var resume = Resume(title: "Blank", templateID: "any", sections: [])
        resume.sections = [
            ResumeSection(kind: .summary),
            ResumeSection(kind: .experience),
            SectionOps.newSection(kind: .skills, existing: []),
            ResumeSection(kind: .custom, title: "Hobbies")
        ]
        return resume
    }

    func testEmptyPartsGetSampleContent() {
        let preview = BlankPreviewMapper.previewResume(from: blank())
        XCTAssertFalse(preview.personal.fullName.isEmpty)
        for section in preview.sections {
            XCTAssertTrue(section.hasContent, section.title)
        }
    }

    func testUserContentIsKept() {
        var resume = blank()
        resume.personal.fullName = "Real Name"
        resume.sections[0].text = "My own summary."
        let preview = BlankPreviewMapper.previewResume(from: resume)
        XCTAssertEqual(preview.personal.fullName, "Real Name")
        XCTAssertEqual(preview.sections[0].text, "My own summary.")
    }

    func testPreviewDoesNotChangeTheOriginal() {
        let resume = blank()
        _ = BlankPreviewMapper.previewResume(from: resume)
        XCTAssertTrue(resume.personal.fullName.isEmpty)
        XCTAssertFalse(resume.sections[1].hasContent)
    }

    func testHiddenSectionsStayEmpty() {
        var resume = blank()
        resume.sections[1].isVisible = false
        let preview = BlankPreviewMapper.previewResume(from: resume)
        XCTAssertFalse(preview.sections[1].hasContent)
    }
}

final class EditorCoverLetterSuggestionTests: XCTestCase {
    func testEveryFieldHasSuggestions() {
        for field in CoverLetterField.allCases {
            XCTAssertGreaterThanOrEqual(CoverLetterSuggestions.items(for: field).count, 3, field.rawValue)
        }
    }

    func testFillLeavesNoPlaceholders() {
        for field in CoverLetterField.allCases {
            for item in CoverLetterSuggestions.items(for: field) {
                let filled = CoverLetterSuggestions.fill(item, company: "", role: "", manager: "")
                XCTAssertFalse(filled.contains("{"), filled)
                XCTAssertFalse(filled.contains("\u{2014}"), filled)
            }
        }
    }

    func testFillUsesLetterDetails() {
        let filled = CoverLetterSuggestions.fill("Dear {manager}, I want the {role} job at {company}.",
                                                 company: "Northfield Labs", role: "Designer", manager: "Ms. Ortiz")
        XCTAssertEqual(filled, "Dear Ms. Ortiz, I want the Designer job at Northfield Labs.")
    }

    func testPrefillFillsOnlyEmptyFieldsUnlessOverwriting() {
        var resume = Resume(title: "R", templateID: "x", sections: [])
        resume.personal.fullName = "Sam Rivera"
        resume.personal.email = "sam@example.com"
        resume.personal.city = "Austin"
        resume.personal.country = "USA"

        var letter = CoverLetter(title: "L", templateID: "y")
        letter.senderName = "Existing Name"
        CoverLetterPrefill.apply(resume, to: &letter, overwrite: false)
        XCTAssertEqual(letter.senderName, "Existing Name")
        XCTAssertEqual(letter.senderEmail, "sam@example.com")
        XCTAssertEqual(letter.senderLocation, "Austin, USA")

        CoverLetterPrefill.apply(resume, to: &letter, overwrite: true)
        XCTAssertEqual(letter.senderName, "Sam Rivera")
    }
}
