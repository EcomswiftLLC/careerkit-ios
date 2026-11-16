import XCTest
import PDFKit
@testable import CareerKit

final class StyleOverridesTests: XCTestCase {
    private let newKeys: [String] = [
        "headingStyle", "headerStyle", "entryLayout", "bullets", "skillStyle", "uppercaseHeadings", "sidebarPosition",
        "sectionSpacing", "entrySpacing", "nameScale", "textHex", "sidebarFillHex", "headerFillHex", "photoShape", "dateFormat"
    ]

    private func spec(_ id: String) -> TemplateSpec {
        guard let found = EngineFixtures.specs.first(where: { $0.id == id }) else {
            XCTFail("missing fixture spec \(id)")
            return EngineFixtures.spec(id: id)
        }
        return found
    }

    private func fullOverrides() -> StyleOverrides {
        var o = StyleOverrides()
        o.accentHex = "#8A2BE2"
        o.bodyFont = .georgia
        o.headingFont = .futura
        o.fontScale = 1.05
        o.lineSpacing = 1.1
        o.marginPoints = 50
        o.showPhoto = false
        o.headingStyle = .dottedRule
        o.headerStyle = .centered
        o.entryLayout = .stacked
        o.bullets = .chevron
        o.skillStyle = .pipeList
        o.uppercaseHeadings = false
        o.sidebarPosition = .right
        o.sectionSpacing = 1.3
        o.entrySpacing = 0.8
        o.nameScale = 1.2
        o.textHex = "#222222"
        o.sidebarFillHex = "#EEF1F4"
        o.headerFillHex = "#1B2F4E"
        o.photoShape = .square
        o.dateFormat = .numeric
        return o
    }

    // MARK: Decoding

    func testEmptyJSONDecodesToDefaults() throws {
        let data: Data = Data("{}".utf8)
        let decoded: StyleOverrides = try JSONDecoder().decode(StyleOverrides.self, from: data)
        XCTAssertEqual(decoded, StyleOverrides())
    }

    func testOldStyleJSONWithoutNewKeysDecodes() throws {
        let json: String = ##"{"accentHex":"#112233","bodyFont":"georgia","fontScale":1.1,"lineSpacing":1.2,"marginPoints":40,"showPhoto":false}"##
        let decoded: StyleOverrides = try JSONDecoder().decode(StyleOverrides.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.accentHex, "#112233")
        XCTAssertEqual(decoded.bodyFont, .georgia)
        XCTAssertNil(decoded.headingFont)
        XCTAssertEqual(decoded.fontScale, 1.1, accuracy: 0.0001)
        XCTAssertEqual(decoded.lineSpacing, 1.2, accuracy: 0.0001)
        XCTAssertEqual(decoded.marginPoints, 40)
        XCTAssertFalse(decoded.showPhoto)
        XCTAssertNil(decoded.headerStyle)
        XCTAssertNil(decoded.headingStyle)
        XCTAssertNil(decoded.dateFormat)
        XCTAssertEqual(decoded.sectionSpacing, 1)
        XCTAssertEqual(decoded.entrySpacing, 1)
        XCTAssertEqual(decoded.nameScale, 1)
    }

    func testOldResumeDocumentWithoutNewKeysDecodes() throws {
        guard let base = EngineFixtures.cases().first(where: { $0.name == "one page" }) else {
            XCTFail("fixture missing")
            return
        }
        var resume: Resume = base.resume
        resume.style.accentHex = "#1F3A5F"
        let encoded: Data = try JSONEncoder().encode(resume)
        guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any],
              var styleObject = object["style"] as? [String: Any] else {
            XCTFail("unexpected JSON shape")
            return
        }
        for key in newKeys {
            styleObject.removeValue(forKey: key)
        }
        object["style"] = styleObject
        let stripped: Data = try JSONSerialization.data(withJSONObject: object)
        let decoded: Resume = try JSONDecoder().decode(Resume.self, from: stripped)
        XCTAssertEqual(decoded.style, resume.style)
        XCTAssertEqual(decoded.sections, resume.sections)
    }

    func testUnknownEnumValuesFallBackToTemplate() throws {
        let json: String = #"{"headerStyle":"zigzag","bullets":"star","dateFormat":"roman","fontScale":1.0,"lineSpacing":1.0,"showPhoto":true}"#
        let decoded: StyleOverrides = try JSONDecoder().decode(StyleOverrides.self, from: Data(json.utf8))
        XCTAssertNil(decoded.headerStyle)
        XCTAssertNil(decoded.bullets)
        XCTAssertNil(decoded.dateFormat)
    }

    func testRoundTripKeepsEveryField() throws {
        let original: StyleOverrides = fullOverrides()
        let data: Data = try JSONEncoder().encode(original)
        let decoded: StyleOverrides = try JSONDecoder().decode(StyleOverrides.self, from: data)
        XCTAssertEqual(decoded, original)

        let empty: StyleOverrides = try JSONDecoder().decode(StyleOverrides.self, from: try JSONEncoder().encode(StyleOverrides()))
        XCTAssertEqual(empty, StyleOverrides())
    }

    // MARK: applying()

    func testNoOverridesKeepsTheTemplate() {
        for template in EngineFixtures.specs {
            XCTAssertEqual(template.applying(StyleOverrides()), template, template.id)
        }
    }

    func testEachOverrideChangesTheSpec() {
        let base: TemplateSpec = spec("t.single.left")

        var o = StyleOverrides()
        o.headingStyle = .boxedLabel
        XCTAssertEqual(base.applying(o).headingStyle, .boxedLabel)

        o = StyleOverrides()
        o.headerStyle = .banner
        XCTAssertEqual(base.applying(o).header, .banner)

        o = StyleOverrides()
        o.entryLayout = .dateGutter
        XCTAssertEqual(base.applying(o).entryLayout, .dateGutter)

        o = StyleOverrides()
        o.bullets = .square
        XCTAssertEqual(base.applying(o).bullets, .square)

        o = StyleOverrides()
        o.skillStyle = .bulletColumns
        XCTAssertEqual(base.applying(o).skillStyle, .bulletColumns)

        o = StyleOverrides()
        o.uppercaseHeadings = true
        XCTAssertTrue(base.applying(o).uppercaseHeadings)

        o = StyleOverrides()
        o.sectionSpacing = 1.5
        o.entrySpacing = 0.7
        o.nameScale = 1.25
        let spaced: TemplateSpec = base.applying(o)
        XCTAssertEqual(spaced.sectionSpacing, base.sectionSpacing * 1.5, accuracy: 0.0001)
        XCTAssertEqual(spaced.entrySpacing, base.entrySpacing * 0.7, accuracy: 0.0001)
        XCTAssertEqual(spaced.nameSize, base.nameSize * 1.25, accuracy: 0.0001)

        o = StyleOverrides()
        o.textHex = "#333366"
        o.headerFillHex = "abcdef"
        let colored: TemplateSpec = base.applying(o)
        XCTAssertEqual(colored.textHex, "#333366")
        XCTAssertEqual(colored.headerFillHex, "#ABCDEF")
        // Accent stays with RenderStyle so its "follow the accent" rules keep working.
        XCTAssertEqual(colored.accentHex, base.accentHex)

        let sidebar: TemplateSpec = spec("t.sidebarleft.card")
        o = StyleOverrides()
        o.sidebarPosition = .right
        o.sidebarFillHex = "#E9F0EC"
        let moved: TemplateSpec = sidebar.applying(o)
        XCTAssertEqual(moved.layout, .sidebarRight)
        XCTAssertEqual(moved.sidebarFillHex, "#E9F0EC")
        XCTAssertNil(moved.sidebarTextHex, "text colour is recomputed for a custom sidebar fill")
    }

    func testInvalidCombinationsFallBack() {
        let sidebar: TemplateSpec = spec("t.sidebarleft.card")
        let single: TemplateSpec = spec("t.single.left")
        let twoColumn: TemplateSpec = spec("t.twocol.split")

        var o = StyleOverrides()
        o.headerStyle = .banner
        XCTAssertEqual(sidebar.applying(o).header, .sidebarCard, "no banner beside a full height sidebar")

        o = StyleOverrides()
        o.headerStyle = .sidebarCard
        XCTAssertEqual(single.applying(o).header, single.header, "no sidebar card without a sidebar")

        o = StyleOverrides()
        o.headingStyle = .sideLabel
        XCTAssertEqual(sidebar.applying(o).headingStyle, sidebar.headingStyle)
        XCTAssertEqual(twoColumn.applying(o).headingStyle, twoColumn.headingStyle)
        XCTAssertEqual(single.applying(o).headingStyle, .sideLabel)

        o = StyleOverrides()
        o.sidebarPosition = .right
        XCTAssertEqual(single.applying(o).layout, .singleColumn)
        XCTAssertEqual(twoColumn.applying(o).layout, .headerThenTwoColumn)

        o = StyleOverrides()
        o.sidebarFillHex = "#123456"
        XCTAssertEqual(single.applying(o).sidebarFillHex, single.sidebarFillHex, "fill only applies to sidebar layouts")

        o = StyleOverrides()
        o.textHex = "not a colour"
        o.headerFillHex = "#12345"
        let bad: TemplateSpec = single.applying(o)
        XCTAssertEqual(bad.textHex, single.textHex)
        XCTAssertEqual(bad.headerFillHex, single.headerFillHex)

        o = StyleOverrides()
        o.sectionSpacing = 9
        o.entrySpacing = -3
        o.nameScale = Double.nan
        let clamped: TemplateSpec = single.applying(o)
        XCTAssertEqual(clamped.sectionSpacing, single.sectionSpacing * 1.6, accuracy: 0.0001)
        XCTAssertEqual(clamped.entrySpacing, single.entrySpacing * 0.7, accuracy: 0.0001)
        XCTAssertEqual(clamped.nameSize, single.nameSize, accuracy: 0.0001)
    }

    func testReplacingTheSidebarCardMovesThePhotoToTheHeader() {
        let sidebar: TemplateSpec = spec("t.sidebarleft.card")
        XCTAssertEqual(sidebar.photo, .sidebarTop)
        var o = StyleOverrides()
        o.headerStyle = .centered
        let applied: TemplateSpec = sidebar.applying(o)
        XCTAssertEqual(applied.header, .centered)
        XCTAssertEqual(applied.photo, .headerRight)
    }

    func testNormalizedHex() {
        XCTAssertEqual(TemplateSpec.normalizedHex("#a1b2c3"), "#A1B2C3")
        XCTAssertEqual(TemplateSpec.normalizedHex("A1B2C3"), "#A1B2C3")
        XCTAssertNil(TemplateSpec.normalizedHex("#A1B2C"))
        XCTAssertNil(TemplateSpec.normalizedHex("#GGGGGG"))
        XCTAssertNil(TemplateSpec.normalizedHex(nil))
    }

    // MARK: Dates

    func testDateFormats() {
        var entry = ResumeEntry()
        entry.start = MonthYear(year: 2020, month: 3)
        entry.end = MonthYear(year: 2023, month: 11)
        XCTAssertEqual(entry.dateRange(format: .numeric), "03/2020 – 11/2023")
        XCTAssertEqual(entry.dateRange(format: .yearOnly), "2020 – 2023")
        XCTAssertEqual(entry.dateRange(format: nil), entry.dateRange())
        XCTAssertEqual(entry.dateRange(format: .monthName), entry.dateRange())

        entry.end = MonthYear(year: 2020, month: 9)
        XCTAssertEqual(entry.dateRange(format: .yearOnly), "2020", "same year collapses")

        entry.isCurrent = true
        XCTAssertEqual(entry.dateRange(format: .numeric), "03/2020 – Present")

        var yearOnly = ResumeEntry()
        yearOnly.start = MonthYear(year: 2015, month: nil)
        XCTAssertEqual(yearOnly.dateRange(format: .numeric), "2015")
    }

    // MARK: Rendering

    private func assertRenders(_ resume: Resume, _ template: TemplateSpec, _ label: String,
                               file: StaticString = #filePath, line: UInt = #line) {
        let doc: RenderedDocument = DocumentRenderer.render(resume, template: template)
        XCTAssertGreaterThanOrEqual(doc.pageCount, 1, label, file: file, line: line)
        let report: PDFValidationReport = PDFValidator.validate(doc, resume: resume)
        XCTAssertTrue(report.passed, "\(label): \(report.issues.joined(separator: " | "))", file: file, line: line)
    }

    func testEveryStructuralOverrideRendersWithoutLosingContent() {
        guard let base = EngineFixtures.cases().first(where: { $0.name == "one page" }) else {
            XCTFail("fixture missing")
            return
        }
        var resume: Resume = base.resume
        resume.personal.photoData = EngineFixtures.photoData()

        let templates: [TemplateSpec] = [spec("t.single.left"), spec("t.sidebarleft.card"),
                                         spec("t.sidebarright.card"), spec("t.twocol.banner")]
        let headers: [HeaderStyle] = TemplateSpec.offeredHeaderStyles + [.sidebarCard]
        let headings: [SectionHeadingStyle] = TemplateSpec.offeredHeadingStyles
        let entries: [EntryLayout] = TemplateSpec.offeredEntryLayouts
        let bullets: [BulletStyle] = TemplateSpec.offeredBullets
        let skills: [SkillStyle] = TemplateSpec.offeredSkillStyles
        let shapes: [PhotoShape?] = [nil, .circle, .rounded, .square]
        let dates: [ResumeDateFormat?] = [nil, .monthName, .numeric, .yearOnly]

        for template in templates {
            // Every value of every option appears at least once per template.
            let rounds: Int = max(headers.count, headings.count, entries.count, bullets.count, skills.count)
            for i in 0..<rounds {
                var styled: Resume = resume
                styled.style.headerStyle = headers[i % headers.count]
                styled.style.headingStyle = headings[i % headings.count]
                styled.style.entryLayout = entries[i % entries.count]
                styled.style.bullets = bullets[i % bullets.count]
                styled.style.skillStyle = skills[i % skills.count]
                styled.style.uppercaseHeadings = i % 3 == 0 ? nil : (i % 3 == 1)
                styled.style.sidebarPosition = i % 2 == 0 ? .left : .right
                styled.style.sectionSpacing = i % 2 == 0 ? 0.7 : 1.6
                styled.style.entrySpacing = i % 2 == 0 ? 1.6 : 0.7
                styled.style.nameScale = i % 2 == 0 ? 0.8 : 1.3
                styled.style.textHex = i % 2 == 0 ? "#333333" : nil
                styled.style.sidebarFillHex = i % 2 == 0 ? "#1F4D3A" : "#F4F0E6"
                styled.style.headerFillHex = i % 2 == 0 ? nil : "#4A2340"
                styled.style.photoShape = shapes[i % shapes.count]
                styled.style.dateFormat = dates[i % dates.count]
                assertRenders(styled, template, "\(template.id) round \(i)")
            }
        }
    }

    func testDateFormatReachesThePDF() {
        guard let base = EngineFixtures.cases().first(where: { $0.name == "one page" }) else {
            XCTFail("fixture missing")
            return
        }
        var resume: Resume = base.resume
        resume.style.dateFormat = .numeric
        let doc: RenderedDocument = DocumentRenderer.render(resume, template: spec("t.single.left"))
        let text: String = PDFValidator.normalise(PDFValidator.extractText(from: doc.pdfData))
        XCTAssertTrue(PDFValidator.appears("03/2022", in: text), "numeric dates are drawn")
    }

    func testLetterStyleOverridesRender() {
        var letter: CoverLetter = EngineFixtures.letter()
        letter.style.textHex = "#222222"
        letter.style.headerFillHex = "#4A2340"
        letter.style.nameScale = 1.3
        letter.style.sectionSpacing = 1.6
        for template in EngineFixtures.coverLetterSpecs() {
            let doc: RenderedDocument = CoverLetterRenderer.render(letter, template: template)
            XCTAssertGreaterThanOrEqual(doc.pageCount, 1, template.id)
            let text: String = PDFValidator.normalise(PDFValidator.extractText(from: doc.pdfData))
            XCTAssertTrue(PDFValidator.appears("Jordan Whitfield", in: text), template.id)
            XCTAssertTrue(PDFValidator.appears("Northwind Studio", in: text), template.id)
        }
    }
}
