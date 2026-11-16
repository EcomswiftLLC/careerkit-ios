import XCTest
@testable import CareerKit

final class TemplateCoverLetterTests: XCTestCase {

    private var all: [CoverLetterTemplateSpec] { CoverLetterTemplateLibrary.all }

    func testThereAreExactlyTenTemplates() {
        XCTAssertEqual(all.count, 10)
    }

    func testIdsAndNamesAreUnique() {
        XCTAssertEqual(Set(all.map { $0.id }).count, 10)
        XCTAssertEqual(Set(all.map { $0.name }).count, 10)
        for t in all {
            XCTAssertTrue(t.id.hasPrefix("ck.letter."), t.id)
            XCTAssertFalse(t.tagline.isEmpty, t.name)
            XCTAssertFalse(t.tagline.contains("\u{2014}"), t.name)
        }
    }

    func testEveryHeaderLayoutIsUsed() {
        let expected: Set<CoverLetterTemplateSpec.HeaderLayout> = [.leftBlock, .rightBlock, .centered, .banner, .sideRule, .letterhead]
        XCTAssertEqual(Set(all.map { $0.header }), expected)
    }

    func testDesignsAreDistinct() {
        var seen: Set<String> = []
        for t in all {
            let key = [t.header.rawValue, t.headingFont.rawValue, t.bodyFont.rawValue, t.accentHex].joined(separator: "|")
            XCTAssertFalse(seen.contains(key), "\(t.name) repeats another design")
            seen.insert(key)
        }
    }

    func testLookup() {
        for t in all {
            XCTAssertEqual(CoverLetterTemplateLibrary.spec(id: t.id)?.id, t.id)
        }
        XCTAssertNil(CoverLetterTemplateLibrary.spec(id: "ck.letter.missing"))
    }

    func testMatchingResumeTemplatesAreRealAndShareTheDesign() {
        for t in all {
            guard let resume = TemplateLibrary.spec(id: t.matchingResumeTemplateID) else {
                XCTFail("\(t.name) points at a missing resume template \(t.matchingResumeTemplateID)")
                continue
            }
            XCTAssertEqual(t.headingFont, resume.headingFont, "\(t.name) heading font")
            XCTAssertEqual(t.bodyFont, resume.bodyFont, "\(t.name) body font")
            XCTAssertEqual(t.accentHex, resume.accentHex, "\(t.name) accent")
            XCTAssertEqual(t.textHex, resume.textHex, "\(t.name) text colour")
            XCTAssertEqual(t.headerFillHex, resume.headerFillHex, "\(t.name) banner colour")
        }
    }

    func testEachMatchingResumeTemplateIsUsedOnce() {
        let ids = all.map { $0.matchingResumeTemplateID }
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testNumbersAreInSaneRanges() {
        for t in all {
            XCTAssertTrue((10.0...11.5).contains(t.baseSize), "\(t.name) base size")
            XCTAssertTrue((20.0...34.0).contains(t.nameSize), "\(t.name) name size")
            XCTAssertTrue((1.15...1.4).contains(t.lineSpacing), "\(t.name) line spacing")
            XCTAssertTrue((6.0...16.0).contains(t.paragraphSpacing), "\(t.name) paragraph spacing")
            XCTAssertTrue((30.0...80.0).contains(t.marginTop), "\(t.name) top margin")
            XCTAssertTrue((40.0...80.0).contains(t.marginSide), "\(t.name) side margin")
            XCTAssertTrue((40.0...80.0).contains(t.marginBottom), "\(t.name) bottom margin")
        }
    }

    func testColoursHaveEnoughContrast() {
        for t in all {
            for value in [t.accentHex, t.textHex, t.mutedHex] {
                XCTAssertTrue(TemplateTestColor.isValidHex(value), "\(t.name) bad colour \(value)")
            }
            XCTAssertGreaterThanOrEqual(TemplateTestColor.contrast(t.textHex, TemplateTestColor.white), 7.0, "\(t.name) text")
            XCTAssertGreaterThanOrEqual(TemplateTestColor.contrast(t.mutedHex, TemplateTestColor.white), 4.5, "\(t.name) muted")
            XCTAssertGreaterThanOrEqual(TemplateTestColor.contrast(t.accentHex, TemplateTestColor.white), 4.5, "\(t.name) accent")
            XCTAssertEqual(t.header == .banner, t.headerFillHex != nil, "\(t.name) banner fill")
            if let band = t.headerFillHex {
                XCTAssertTrue(TemplateTestColor.isValidHex(band), t.name)
                XCTAssertGreaterThanOrEqual(TemplateTestColor.contrast(TemplateTestColor.white, band), 4.5, "\(t.name) banner")
            }
        }
    }
}
