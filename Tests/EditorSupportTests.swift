import XCTest
import UIKit
@testable import CareerKit

final class EditorListEditingTests: XCTestCase {
    func testMoveByOffsetWithinBounds() {
        var items = ["a", "b", "c"]
        XCTAssertTrue(ListEditing.move(&items, index: 2, by: -1))
        XCTAssertEqual(items, ["a", "c", "b"])
        XCTAssertTrue(ListEditing.move(&items, index: 0, by: 1))
        XCTAssertEqual(items, ["c", "a", "b"])
    }

    func testMoveOutOfBoundsDoesNothing() {
        var items = ["a", "b"]
        XCTAssertFalse(ListEditing.move(&items, index: 0, by: -1))
        XCTAssertFalse(ListEditing.move(&items, index: 1, by: 1))
        XCTAssertFalse(ListEditing.move(&items, index: 5, by: -1))
        XCTAssertEqual(items, ["a", "b"])
    }

    func testMoveFromOffsetsMatchesListSemantics() {
        var down = ["a", "b", "c", "d"]
        ListEditing.move(&down, fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(down, ["b", "c", "a", "d"])

        var up = ["a", "b", "c", "d"]
        ListEditing.move(&up, fromOffsets: IndexSet(integer: 2), toOffset: 0)
        XCTAssertEqual(up, ["c", "a", "b", "d"])

        var many = ["a", "b", "c", "d"]
        ListEditing.move(&many, fromOffsets: IndexSet([0, 1]), toOffset: 4)
        XCTAssertEqual(many, ["c", "d", "a", "b"])
    }

    func testRemoveIgnoresBadIndex() {
        var items = [1, 2, 3]
        XCTAssertNil(ListEditing.remove(&items, at: 9))
        XCTAssertEqual(ListEditing.remove(&items, at: 1), 2)
        XCTAssertEqual(items, [1, 3])
    }
}

final class EditorSectionOpsTests: XCTestCase {
    func testUniqueTitleNumbersRepeatedCustomSections() {
        var sections: [ResumeSection] = []
        let first = SectionOps.newSection(kind: .custom, existing: sections)
        XCTAssertEqual(first.title, "Custom Section")
        sections.append(first)
        let second = SectionOps.newSection(kind: .custom, existing: sections)
        XCTAssertEqual(second.title, "Custom Section 2")
        sections.append(second)
        XCTAssertEqual(SectionOps.newSection(kind: .custom, existing: sections).title, "Custom Section 3")
    }

    func testSkillSectionsStartWithOneGroup() {
        XCTAssertEqual(SectionOps.newSection(kind: .skills, existing: []).skillGroups.count, 1)
        XCTAssertEqual(SectionOps.newSection(kind: .languages, existing: []).skillGroups.count, 1)
        XCTAssertTrue(SectionOps.newSection(kind: .experience, existing: []).entries.isEmpty)
    }

    func testNormalizedRestoresBlankHeadings() {
        var section = ResumeSection(kind: .education)
        section.title = "   "
        let result = SectionOps.normalized([section])
        XCTAssertEqual(result[0].title, SectionKind.education.defaultTitle)
    }

    func testDuplicateEntryGetsNewIdAndSitsAfterOriginal() {
        var section = ResumeSection(kind: .experience)
        var entry = ResumeEntry()
        entry.heading = "Analyst"
        section.entries = [entry, ResumeEntry()]
        SectionOps.duplicateEntry(in: &section, at: 0)
        XCTAssertEqual(section.entries.count, 3)
        XCTAssertEqual(section.entries[1].heading, "Analyst")
        XCTAssertNotEqual(section.entries[0].id, section.entries[1].id)
    }

    func testSummaryLine() {
        var text = ResumeSection(kind: .summary)
        XCTAssertEqual(SectionOps.summaryLine(for: text), "Nothing added yet")
        text.text = "one two three"
        XCTAssertEqual(SectionOps.summaryLine(for: text), "3 words")

        var jobs = ResumeSection(kind: .experience)
        var job = ResumeEntry()
        job.heading = "Manager"
        jobs.entries = [job, ResumeEntry()]
        XCTAssertEqual(SectionOps.summaryLine(for: jobs), "1 item")

        var skills = ResumeSection(kind: .skills)
        skills.skillGroups = [SkillGroup(name: "", items: ["A", "B"])]
        XCTAssertEqual(SectionOps.summaryLine(for: skills), "2 items")
    }
}

final class EditorMonthYearTests: XCTestCase {
    private func date(year: Int) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = 6
        parts.day = 15
        return Calendar(identifier: .gregorian).date(from: parts) ?? Date()
    }

    func testYearsAreNewestFirstAndIncludeNearFuture() {
        let years = MonthYearHelper.years(now: date(year: 2026))
        XCTAssertEqual(years.first, 2032)
        XCTAssertEqual(years.last, MonthYearHelper.earliestYear)
        XCTAssertEqual(years, years.sorted(by: >))
    }

    func testYearsIncludeOutOfRangeValue() {
        let years = MonthYearHelper.years(now: date(year: 2026), including: 1950)
        XCTAssertTrue(years.contains(1950))
        XCTAssertEqual(years, years.sorted(by: >))
    }

    func testMake() {
        XCTAssertNil(MonthYearHelper.make(year: 0, month: 3))
        XCTAssertEqual(MonthYearHelper.make(year: 2020, month: 3), MonthYear(year: 2020, month: 3))
        XCTAssertEqual(MonthYearHelper.make(year: 2020, month: 13), MonthYear(year: 2020, month: nil))
        XCTAssertEqual(MonthYearHelper.make(year: 2020, month: nil), MonthYear(year: 2020, month: nil))
    }

    func testRangeValidation() {
        XCTAssertTrue(MonthYearHelper.isValidRange(start: nil, end: MonthYear(year: 2020, month: 1)))
        XCTAssertTrue(MonthYearHelper.isValidRange(start: MonthYear(year: 2019, month: 5), end: MonthYear(year: 2020, month: 1)))
        XCTAssertFalse(MonthYearHelper.isValidRange(start: MonthYear(year: 2021, month: 5), end: MonthYear(year: 2020, month: 1)))
        XCTAssertFalse(MonthYearHelper.isValidRange(start: MonthYear(year: 2020, month: 6), end: MonthYear(year: 2020, month: 2)))
        XCTAssertTrue(MonthYearHelper.isValidRange(start: MonthYear(year: 2020, month: nil), end: MonthYear(year: 2020, month: 2)))
    }

    func testMonthNamesHaveTwelveEntries() {
        XCTAssertEqual(MonthYearHelper.shortMonthNames(locale: Locale(identifier: "en_US")).count, 12)
    }
}

final class EditorTextHelperTests: XCTestCase {
    func testTokenSplitting() {
        XCTAssertEqual(TokenParsing.split(" Swift, SwiftUI;Core Data \n Combine,, "), ["Swift", "SwiftUI", "Core Data", "Combine"])
        XCTAssertTrue(TokenParsing.split("  , ; ").isEmpty)
    }

    func testAppendUniqueIsCaseInsensitive() {
        let result = TokenParsing.appendUnique(existing: ["Swift"], new: ["swift", "Kotlin", "KOTLIN"])
        XCTAssertEqual(result, ["Swift", "Kotlin"])
    }

    func testTextInsertion() {
        XCTAssertEqual(TextInsertion.insert("New", into: "  "), "New")
        XCTAssertEqual(TextInsertion.insert("New", into: "Old\n"), "Old\n\nNew")
    }

    func testSafeFileName() {
        XCTAssertEqual(FileNaming.safeFileName("Sales/Lead", fallback: "Resume"), "Sales-Lead")
        XCTAssertEqual(FileNaming.safeFileName("   Jane  Doe   Resume ", fallback: "Resume"), "Jane Doe Resume")
        XCTAssertEqual(FileNaming.safeFileName("", fallback: "Resume"), "Resume")
        XCTAssertEqual(FileNaming.safeFileName("....", fallback: "Resume"), "Resume")
        XCTAssertLessThanOrEqual(FileNaming.safeFileName(String(repeating: "a", count: 300), fallback: "x").count, 80)
    }
}

final class EditorPhotoTests: XCTestCase {
    func testTargetSizeNeverUpscales() {
        XCTAssertEqual(PhotoProcessor.targetSize(for: CGSize(width: 300, height: 200)), CGSize(width: 300, height: 200))
    }

    func testTargetSizeScalesLongestSideTo600() {
        XCTAssertEqual(PhotoProcessor.targetSize(for: CGSize(width: 1200, height: 800)), CGSize(width: 600, height: 400))
        XCTAssertEqual(PhotoProcessor.targetSize(for: CGSize(width: 900, height: 3000)), CGSize(width: 180, height: 600))
        XCTAssertEqual(PhotoProcessor.targetSize(for: .zero), .zero)
    }

    func testDownscaledJPEGIsAtMost600Pixels() throws {
        let size = CGSize(width: 1200, height: 800)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let source = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let png = try XCTUnwrap(source.pngData())
        let jpeg = try XCTUnwrap(PhotoProcessor.downscaledJPEG(from: png))
        let result = try XCTUnwrap(UIImage(data: jpeg))
        XCTAssertLessThanOrEqual(max(result.size.width, result.size.height) * result.scale, 600)
        XCTAssertEqual(result.size.width * result.scale, 600, accuracy: 1)
    }

    func testBadImageDataReturnsNil() {
        XCTAssertNil(PhotoProcessor.downscaledJPEG(from: Data([0x00, 0x01, 0x02])))
    }
}

final class EditorStyleLimitsTests: XCTestCase {
    func testStandardClamp() {
        var style = StyleOverrides()
        style.fontScale = 2
        style.lineSpacing = 0.1
        style.marginPoints = 500
        let result = StyleLimits.standard.clamped(style)
        XCTAssertEqual(result.fontScale, 1.2, accuracy: 0.0001)
        XCTAssertEqual(result.lineSpacing, 0.9, accuracy: 0.0001)
        XCTAssertEqual(result.marginPoints, 72)
    }

    func testBlankLimitsAreStricter() {
        var style = StyleOverrides()
        style.fontScale = 1.2
        style.marginPoints = 20
        let result = StyleLimits.blank.clamped(style)
        XCTAssertEqual(result.fontScale, 1.1, accuracy: 0.0001)
        XCTAssertEqual(result.marginPoints, 28)
    }

    func testNilMarginStaysNil() {
        XCTAssertNil(StyleLimits.blank.clamped(StyleOverrides()).marginPoints)
    }
}
