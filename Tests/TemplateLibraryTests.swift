import XCTest
@testable import CareerKit

/// Colour helpers shared by the template tests.
enum TemplateTestColor {
    static func components(_ hex: String) -> (r: Double, g: Double, b: Double)? {
        guard hex.hasPrefix("#"), hex.count == 7 else { return nil }
        guard let value = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return (r, g, b)
    }

    static func isValidHex(_ hex: String) -> Bool {
        return components(hex) != nil
    }

    private static func linear(_ channel: Double) -> Double {
        if channel <= 0.03928 { return channel / 12.92 }
        return pow((channel + 0.055) / 1.055, 2.4)
    }

    /// WCAG relative luminance.
    static func luminance(_ hex: String) -> Double {
        guard let c = components(hex) else { return 0 }
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
    }

    /// WCAG contrast ratio, 1...21.
    static func contrast(_ a: String, _ b: String) -> Double {
        let la = luminance(a)
        let lb = luminance(b)
        let lighter = max(la, lb)
        let darker = min(la, lb)
        return (lighter + 0.05) / (darker + 0.05)
    }

    static let white = "#FFFFFF"
}

final class TemplateLibraryTests: XCTestCase {

    private var all: [TemplateSpec] { TemplateLibrary.all }

    // MARK: Counts and identity

    func testThereAreExactlyThirtyTemplates() {
        XCTAssertEqual(all.count, 30)
    }

    func testIdsAreUniqueAndWellFormed() {
        let ids = all.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count, "Template ids must be unique")
        for id in ids {
            XCTAssertTrue(id.hasPrefix("ck."), "\(id) should start with ck.")
            XCTAssertEqual(id.split(separator: ".").count, 3, "\(id) should look like ck.category.name")
        }
    }

    func testNamesAreUniqueAndNotEmpty() {
        let names = all.map { $0.name }
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertFalse(names.contains { $0.isEmpty })
    }

    func testCategoryCounts() {
        func count(_ category: TemplateCategory) -> Int {
            return all.filter { $0.category == category }.count
        }
        XCTAssertEqual(count(.professional), 6)
        XCTAssertEqual(count(.modern), 6)
        XCTAssertEqual(count(.creative), 5)
        XCTAssertEqual(count(.academic), 4)
        XCTAssertEqual(count(.entryLevel), 4)
        XCTAssertEqual(count(.technical), 5)
    }

    func testRequiredNamesExist() {
        let required: [String] = [
            "Executive", "Corporate", "Modern Professional", "Classic Professional", "Business Elite", "Senior Management",
            "Modern Minimal", "Contemporary", "Elegant", "Clean Lines", "Modern Classic", "Professional Grid",
            "Creative Designer", "Marketing Professional", "Visual Portfolio", "Creative Minimal", "Editorial",
            "Academic CV", "Researcher", "University Graduate", "Scientific CV",
            "Fresh Graduate", "Student Resume", "Internship Resume", "First Job",
            "Software Engineer", "IT Professional", "Data Analyst", "Product Manager", "Project Manager"
        ]
        let names = Set(all.map { $0.name })
        for name in required {
            XCTAssertTrue(names.contains(name), "Missing template \(name)")
        }
    }

    func testSpecLookup() {
        for template in all {
            XCTAssertEqual(TemplateLibrary.spec(id: template.id)?.id, template.id)
        }
        XCTAssertNil(TemplateLibrary.spec(id: "ck.unknown.template"))
    }

    func testDefaultTemplateIsATSFriendlyAndExists() {
        guard let spec = TemplateLibrary.spec(id: TemplateLibrary.defaultTemplateID) else {
            return XCTFail("Default template id does not resolve")
        }
        XCTAssertTrue(spec.isATSFriendly)
        XCTAssertEqual(spec.layout, .singleColumn)
        XCTAssertEqual(spec.photo, .none)
    }

    // MARK: Variety

    func testAllLayoutsHeadersHeadingsAndEntryLayoutsAreUsed() {
        let layouts: Set<PageLayout> = [.singleColumn, .sidebarLeft, .sidebarRight, .headerThenTwoColumn]
        let headers: Set<HeaderStyle> = [.leftAligned, .centered, .banner, .splitContact, .sidebarCard, .ruledMonogram,
                                         .monogramBadge, .accentRuleLeft, .centeredAccent, .doubleRule]
        let headings: Set<SectionHeadingStyle> = [.uppercaseRule, .smallCapsAccent, .accentBar, .boxedLabel, .plainBold, .sideLabel, .dottedRule,
                                                  .underlineAccent, .centeredRule, .leftBorder, .tintedBand]
        let entries: Set<EntryLayout> = [.dateRight, .dateBelow, .dateGutter, .stacked]
        let skills: Set<SkillStyle> = [.commaList, .pipeList, .groupedLines, .bulletColumns]
        XCTAssertEqual(Set(all.map { $0.layout }), layouts)
        XCTAssertEqual(Set(all.map { $0.header }), headers)
        XCTAssertEqual(Set(all.map { $0.headingStyle }), headings)
        XCTAssertEqual(Set(all.map { $0.entryLayout }), entries)
        XCTAssertEqual(Set(all.map { $0.skillStyle }), skills)
    }

    func testLayoutMix() {
        let sidebars = all.filter { $0.layout == .sidebarLeft || $0.layout == .sidebarRight }
        let rails = all.filter { $0.layout == .headerThenTwoColumn }
        XCTAssertGreaterThanOrEqual(sidebars.count, 6)
        XCTAssertGreaterThanOrEqual(rails.count, 3)
    }

    func testNoTwoTemplatesShareTheSameDesignTuple() {
        var seen: [String: String] = [:]
        for t in all {
            let key = [t.layout.rawValue, t.header.rawValue, t.headingStyle.rawValue, t.entryLayout.rawValue,
                       t.headingFont.rawValue, t.bodyFont.rawValue].joined(separator: "|")
            if let other = seen[key] {
                XCTFail("\(t.name) and \(other) share the tuple \(key)")
            }
            seen[key] = t.name
        }
    }

    func testTemplatesAreVisuallyDistinctBeyondTheTuple() {
        // No two templates may match on the whole look: tuple plus bullets, skills, accent and base size.
        var seen: Set<String> = []
        for t in all {
            let key = [t.layout.rawValue, t.header.rawValue, t.headingStyle.rawValue, t.entryLayout.rawValue,
                       t.bullets.rawValue, t.skillStyle.rawValue, t.accentHex, String(t.baseSize)].joined(separator: "|")
            XCTAssertFalse(seen.contains(key), "\(t.name) looks like another template")
            seen.insert(key)
        }
    }

    // MARK: ATS

    func testAtLeastTwelveTemplatesAreATSFriendly() {
        XCTAssertGreaterThanOrEqual(all.filter { $0.isATSFriendly }.count, 12)
    }

    func testATSFlagMatchesStructure() {
        for t in all {
            // The monogram badge prints initials as decoration, so it counts as non-plain like a banner.
            let plainHeader = t.header != .banner && t.header != .sidebarCard && t.header != .monogramBadge
            let plainHeading = t.headingStyle != .boxedLabel && t.headingStyle != .sideLabel
            let structurallyPlain = t.layout == .singleColumn
                && t.photo == .none
                && t.sidebarSections.isEmpty
                && plainHeader
                && plainHeading
                && t.entryLayout != .dateGutter
                && t.skillStyle != .bulletColumns
            XCTAssertEqual(t.isATSFriendly, structurallyPlain, "ATS flag does not match structure for \(t.name)")
            if t.layout != .singleColumn || t.photo != .none || t.header == .banner {
                XCTAssertFalse(t.isATSFriendly, "\(t.name) has a sidebar, photo or banner and must not be ATS friendly")
            }
        }
    }

    // MARK: Ranges

    func testNumericFieldsAreInSaneRanges() {
        for t in all {
            XCTAssertTrue(t.typicalPages == 1 || t.typicalPages == 2, t.name)
            XCTAssertTrue((9.5...11.0).contains(t.baseSize), "\(t.name) base size")
            XCTAssertTrue((24.0...38.0).contains(t.nameSize), "\(t.name) name size")
            XCTAssertTrue((10.0...13.0).contains(t.headingSize), "\(t.name) heading size")
            XCTAssertTrue((1.0...1.3).contains(t.lineSpacing), "\(t.name) line spacing")
            XCTAssertTrue((0.0...2.0).contains(t.letterSpacingHeadings), "\(t.name) tracking")
            XCTAssertTrue((0.28...0.36).contains(t.sidebarFraction), "\(t.name) sidebar fraction")
            for margin in [t.marginTop, t.marginSide, t.marginBottom] {
                XCTAssertTrue((28.0...56.0).contains(margin), "\(t.name) margin \(margin)")
            }
            XCTAssertTrue((6.0...24.0).contains(t.sectionSpacing), "\(t.name) section spacing")
            XCTAssertTrue((4.0...16.0).contains(t.entrySpacing), "\(t.name) entry spacing")
            XCTAssertGreaterThan(t.nameSize, t.baseSize * 2, "\(t.name) name should be clearly larger than body")
        }
    }

    func testTextFieldsAreFilledAndPlain() {
        for t in all {
            XCTAssertFalse(t.tagline.isEmpty, t.name)
            XCTAssertLessThanOrEqual(t.tagline.count, 90, "\(t.name) tagline is too long")
            XCTAssertFalse(t.tagline.contains("\u{2014}"), "\(t.name) tagline has an em dash")
            XCTAssertFalse(t.tagline.contains("!"), "\(t.name) tagline sounds like hype")
            XCTAssertFalse(t.industries.isEmpty, t.name)
            XCTAssertFalse(t.levels.isEmpty, t.name)
        }
    }

    // MARK: Structure

    func testSectionListsAreConsistent() {
        for t in all {
            let kinds = t.mainSections + t.sidebarSections
            XCTAssertEqual(Set(kinds).count, kinds.count, "\(t.name) repeats a section")
            for required in [SectionKind.summary, .experience, .education, .skills] {
                XCTAssertTrue(kinds.contains(required), "\(t.name) lacks \(required.rawValue)")
            }
            XCTAssertFalse(t.mainSections.isEmpty, t.name)
            switch t.layout {
            case .singleColumn:
                XCTAssertTrue(t.sidebarSections.isEmpty, "\(t.name) is single column but lists sidebar sections")
            case .sidebarLeft, .sidebarRight, .headerThenTwoColumn:
                XCTAssertFalse(t.sidebarSections.isEmpty, "\(t.name) has a sidebar or rail but no sections in it")
            }
        }
    }

    func testHeaderPhotoAndFillRulesMatchLayout() {
        for t in all {
            let hasSidebar = t.layout == .sidebarLeft || t.layout == .sidebarRight
            XCTAssertEqual(t.header == .sidebarCard, hasSidebar, "\(t.name) sidebar card header must go with a sidebar layout")
            XCTAssertEqual(t.header == .banner, t.headerFillHex != nil, "\(t.name) banner fill")
            XCTAssertEqual(t.sidebarFillHex == nil, t.sidebarTextHex == nil, "\(t.name) sidebar fill and text come as a pair")
            if hasSidebar { XCTAssertNotNil(t.sidebarFillHex, t.name) }
            if t.layout == .singleColumn { XCTAssertNil(t.sidebarFillHex, t.name) }
            if t.photo == .sidebarTop { XCTAssertTrue(hasSidebar, "\(t.name) photo in sidebar needs a sidebar") }
            if hasSidebar { XCTAssertNotEqual(t.photo, .headerRight, t.name) }
        }
    }

    // MARK: Colour

    func testHexValuesAreValid() {
        for t in all {
            let values: [String?] = [t.accentHex, t.textHex, t.mutedHex, t.sidebarFillHex, t.sidebarTextHex, t.headerFillHex]
            for value in values {
                guard let value = value else { continue }
                XCTAssertTrue(TemplateTestColor.isValidHex(value), "\(t.name) has a bad colour \(value)")
            }
        }
    }

    func testTextContrastOnPaper() {
        for t in all {
            XCTAssertGreaterThanOrEqual(TemplateTestColor.contrast(t.textHex, TemplateTestColor.white), 7.0, "\(t.name) text")
            XCTAssertGreaterThanOrEqual(TemplateTestColor.contrast(t.mutedHex, TemplateTestColor.white), 4.5, "\(t.name) muted")
            XCTAssertGreaterThanOrEqual(TemplateTestColor.contrast(t.accentHex, TemplateTestColor.white), 4.5, "\(t.name) accent")
        }
    }

    func testTextContrastOnFills() {
        for t in all {
            if let fill = t.sidebarFillHex, let text = t.sidebarTextHex {
                XCTAssertGreaterThanOrEqual(TemplateTestColor.contrast(text, fill), 4.5, "\(t.name) sidebar text")
                if TemplateTestColor.luminance(fill) > 0.5 {
                    XCTAssertGreaterThanOrEqual(TemplateTestColor.contrast(t.accentHex, fill), 4.5, "\(t.name) accent on sidebar")
                    XCTAssertGreaterThanOrEqual(TemplateTestColor.contrast(t.mutedHex, fill), 4.5, "\(t.name) muted on sidebar")
                }
            }
            if let band = t.headerFillHex {
                // Banner text is white.
                XCTAssertGreaterThanOrEqual(TemplateTestColor.contrast(TemplateTestColor.white, band), 4.5, "\(t.name) banner")
            }
        }
    }

    func testAccentsAreRestrained() {
        // Dark, low-luminance accents only: no neon.
        for t in all {
            XCTAssertLessThan(TemplateTestColor.luminance(t.accentHex), 0.3, "\(t.name) accent is too bright")
        }
    }
}
