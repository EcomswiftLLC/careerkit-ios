import XCTest
@testable import CareerKit

final class EngineATSTests: XCTestCase {
    private func report(_ resume: Resume, spec: TemplateSpec = EngineFixtures.specs[0]) -> ATSReport {
        let doc = DocumentRenderer.render(resume, template: spec)
        return ATSAnalyzer.analyze(resume: resume, template: spec, pdfData: doc.pdfData)
    }

    private func titles(_ report: ATSReport, _ severity: ATSFinding.Severity) -> [String] {
        return report.findings.filter { $0.severity == severity }.map { $0.title }
    }

    private func goodResume() -> Resume {
        var jobs = EngineFixtures.jobs(2, bulletsEach: 3)
        for i in jobs.indices where jobs[i].end == nil && !jobs[i].isCurrent {
            jobs[i].end = EngineFixtures.month(2020)
        }
        return EngineFixtures.resume("Good", person: EngineFixtures.person("Taylor Brooks"), sections: [
            EngineFixtures.section(.summary, text: "Product designer with eight years of experience shipping consumer and business software for teams of every size, focused on clear and accessible interfaces."),
            EngineFixtures.section(.experience, entries: jobs),
            EngineFixtures.section(.education, entries: [EngineFixtures.entry("BA Design", "State University", start: EngineFixtures.month(2010), end: EngineFixtures.month(2014))]),
            EngineFixtures.section(.skills, skills: EngineFixtures.standardSkills())
        ])
    }

    func testDisclaimerIsHonest() {
        let r = report(goodResume())
        XCTAssertTrue(r.disclaimer.lowercased().contains("not a score"))
        XCTAssertTrue(r.disclaimer.lowercased().contains("does not guarantee"))
    }

    func testWellFormedSingleColumnResumeHasNoWarnings() {
        let r = report(goodResume())
        XCTAssertEqual(r.warningCount, 0, "warnings: \(titles(r, .warning))")
        XCTAssertFalse(titles(r, .good).isEmpty)
    }

    func testMissingContactDetailsWarn() {
        var resume = goodResume()
        resume.personal.email = ""
        resume.personal.fullName = ""
        let r = report(resume)
        let warnings = titles(r, .warning)
        XCTAssertTrue(warnings.contains("Add an email address"), "\(warnings)")
        XCTAssertTrue(warnings.contains("Add your name"), "\(warnings)")
    }

    func testBadEmailAndPhoneWarn() {
        var resume = goodResume()
        resume.personal.email = "not-an-email"
        resume.personal.phone = "12"
        let warnings = titles(report(resume), .warning)
        XCTAssertTrue(warnings.contains("Check your email address"))
        XCTAssertTrue(warnings.contains("Check your phone number"))
    }

    func testUndatedRolesWarn() {
        var resume = goodResume()
        resume.sections[1].entries.append(EngineFixtures.entry("Undated role", "Somewhere"))
        let r = report(resume)
        XCTAssertTrue(titles(r, .warning).contains("Some roles have no dates"))
    }

    func testOpenEndedRoleIsANote() {
        var resume = goodResume()
        var open = EngineFixtures.entry("Open ended", "Somewhere", start: EngineFixtures.month(2021))
        open.isCurrent = false
        resume.sections[1].entries.append(open)
        XCTAssertTrue(titles(report(resume), .info).contains("Some roles have no end date"))
    }

    func testMissingSummaryIsANote() {
        var resume = goodResume()
        resume.sections.removeAll(where: { $0.kind == .summary })
        XCTAssertTrue(titles(report(resume), .info).contains("No summary"))
    }

    func testLongSummaryIsANote() {
        var resume = goodResume()
        resume.sections[0].text = (0..<150).map { "word\($0)" }.joined(separator: " ")
        XCTAssertTrue(titles(report(resume), .info).contains("Summary is long"))
    }

    func testUnusualHeadingWarns() {
        var resume = goodResume()
        resume.sections[1].title = "My Adventures"
        let r = report(resume)
        XCTAssertTrue(titles(r, .warning).contains("Some headings are unusual"))
        let detail = r.findings.first(where: { $0.title == "Some headings are unusual" })?.detail ?? ""
        XCTAssertTrue(detail.contains("My Adventures"))
    }

    func testSidebarAndTwoColumnTemplatesWarn() {
        let resume = goodResume()
        for spec in EngineFixtures.specs where spec.layout != .singleColumn {
            let r = report(resume, spec: spec)
            let warnings = titles(r, .warning)
            XCTAssertTrue(warnings.contains("Sidebar layout") || warnings.contains("Two column layout"), "\(spec.id): \(warnings)")
        }
        XCTAssertTrue(titles(report(resume), .good).contains("Single column layout"))
    }

    func testPhotoWarnsOnlyWhenShown() {
        var resume = goodResume()
        resume.personal.photoData = EngineFixtures.photoData()
        let withPhotoSpec = EngineFixtures.specs[2]
        XCTAssertTrue(titles(report(resume, spec: withPhotoSpec), .warning).contains("Photo included"))
        resume.style.showPhoto = false
        XCTAssertFalse(titles(report(resume, spec: withPhotoSpec), .warning).contains("Photo included"))
        XCTAssertFalse(titles(report(resume, spec: EngineFixtures.specs[0]), .warning).contains("Photo included"))
    }

    func testUnusualSymbolsWarn() {
        var resume = goodResume()
        resume.sections[1].entries[0].bullets.append("Shipped the launch \u{1F680} and earned \u{2605}\u{2605}\u{2605} reviews")
        let r = report(resume)
        XCTAssertTrue(titles(r, .warning).contains("Unusual symbols found"))
        XCTAssertTrue(titles(report(goodResume()), .good).contains("No unusual symbols"))
    }

    func testLongDocumentWarns() {
        let resume = EngineFixtures.resume("Long", person: EngineFixtures.person("Taylor Brooks"), sections: [
            EngineFixtures.section(.experience, entries: EngineFixtures.jobs(14, bulletsEach: 6))
        ])
        let r = report(resume)
        XCTAssertTrue(r.findings.contains(where: { $0.severity == .warning && $0.title.hasPrefix("Document runs to") }))
    }

    func testLongBulletsAreANote() {
        var resume = goodResume()
        resume.sections[1].entries[0].bullets = [EngineFixtures.bullet(1, long: true)]
        XCTAssertTrue(titles(report(resume), .info).contains("Some bullet points are long"))
    }

    func testEmptyPdfDataGivesAClearWarning() {
        let resume = goodResume()
        let r = ATSAnalyzer.analyze(resume: resume, template: EngineFixtures.specs[0], pdfData: Data())
        XCTAssertTrue(titles(r, .warning).contains("Preview is not ready"))
    }

    func testFindingsAreOrderedWarningsFirst() {
        var resume = goodResume()
        resume.personal.email = ""
        let r = report(resume)
        var seenNonWarning = false
        for finding in r.findings {
            if finding.severity != .warning { seenNonWarning = true }
            if seenNonWarning { XCTAssertNotEqual(finding.severity, .warning) }
        }
    }

    func testWordingHasNoDashesOrEmoji() {
        var resume = goodResume()
        resume.personal.email = ""
        resume.sections[1].entries.append(EngineFixtures.entry("Undated"))
        let r = report(resume)
        for finding in r.findings {
            for text in [finding.title, finding.detail] {
                XCTAssertFalse(text.contains("\u{2014}"), text)
                XCTAssertFalse(text.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation }), text)
            }
        }
        XCTAssertFalse(r.disclaimer.contains("\u{2014}"))
    }
}
