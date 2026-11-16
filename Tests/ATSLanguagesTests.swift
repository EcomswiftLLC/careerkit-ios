import XCTest
@testable import CareerKit

/// ATS checks on resumes written in Spanish, French, German and Chinese.
final class ATSLanguagesTests: XCTestCase {
    private func report(_ resume: Resume, spec: TemplateSpec = EngineFixtures.specs[0]) -> ATSReport {
        let doc = DocumentRenderer.render(resume, template: spec)
        return ATSAnalyzer.analyze(resume: resume, template: spec, pdfData: doc.pdfData)
    }

    private func titles(_ report: ATSReport, _ severity: ATSFinding.Severity) -> [String] {
        return report.findings.filter { $0.severity == severity }.map { $0.title }
    }

    private func resume(titles: [SectionKind: String], summary: String, jobs: [ResumeEntry]) -> Resume {
        return EngineFixtures.resume("Localized", person: EngineFixtures.person("Taylor Brooks"), sections: [
            EngineFixtures.section(.summary, title: titles[.summary], text: summary),
            EngineFixtures.section(.experience, title: titles[.experience], entries: jobs),
            EngineFixtures.section(.education, title: titles[.education],
                                   entries: [EngineFixtures.entry("Grado", "Universidad",
                                                                  start: EngineFixtures.month(2010),
                                                                  end: EngineFixtures.month(2014))]),
            EngineFixtures.section(.skills, title: titles[.skills], skills: EngineFixtures.standardSkills())
        ])
    }

    private func datedJobs() -> [ResumeEntry] {
        return [
            EngineFixtures.entry("Analista", "Empresa", start: EngineFixtures.month(2020, 1), current: true),
            EngineFixtures.entry("Asistente", "Otra empresa", start: EngineFixtures.month(2016, 3), end: EngineFixtures.month(2019, 12))
        ]
    }

    private let longSummary: String = "Analista con experiencia en datos, informes y automatización de procesos para equipos de ventas, finanzas y operaciones en empresas medianas y grandes de varios sectores."

    // MARK: Headings

    func testLocalizedHeadingsAreStandard() {
        let sets: [[SectionKind: String]] = [
            [.summary: "Resumen profesional", .experience: "Experiencia laboral", .education: "Formación académica", .skills: "Habilidades"],
            [.summary: "Profil", .experience: "Expérience professionnelle", .education: "Formation", .skills: "Compétences"],
            [.summary: "Profil", .experience: "Berufserfahrung", .education: "Ausbildung", .skills: "Kenntnisse"],
            [.summary: "个人简介", .experience: "工作经历", .education: "教育背景", .skills: "专业技能"]
        ]
        for names in sets {
            let r = report(resume(titles: names, summary: longSummary, jobs: datedJobs()))
            XCTAssertFalse(titles(r, .warning).contains("Some headings are unusual"), "\(names): \(titles(r, .warning))")
            XCTAssertTrue(titles(r, .good).contains("Section headings are standard"), "\(names)")
        }
    }

    func testUnusualLocalizedHeadingStillWarns() {
        let names: [SectionKind: String] = [.experience: "Mis aventuras"]
        let r = report(resume(titles: names, summary: longSummary, jobs: datedJobs()))
        XCTAssertTrue(titles(r, .warning).contains("Some headings are unusual"))
    }

    func testStandardHeadingHelper() {
        XCTAssertTrue(ATSAnalyzer.isStandardHeading("Experiencia laboral", kind: .experience))
        XCTAssertTrue(ATSAnalyzer.isStandardHeading("工作经验", kind: .experience))
        XCTAssertTrue(ATSAnalyzer.isStandardHeading("Work Experience", kind: .experience))
        XCTAssertFalse(ATSAnalyzer.isStandardHeading("Things I Did", kind: .experience))
    }

    // MARK: Dates

    func testDatesWrittenInTextCountAsDates() {
        let texts: [String] = ["enero 2020 - actual", "janvier 2020 - présent", "Jan. 2020 - heute", "2020年1月 - 至今", "2020.01-至今"]
        for text in texts {
            let jobs = [EngineFixtures.entry("Analista", text)]
            let r = report(resume(titles: [:], summary: longSummary, jobs: jobs))
            XCTAssertFalse(titles(r, .warning).contains("Some roles have no dates"), "\(text): \(titles(r, .warning))")
        }
        let undated = [EngineFixtures.entry("Analista", "Empresa")]
        let r = report(resume(titles: [:], summary: longSummary, jobs: undated))
        XCTAssertTrue(titles(r, .warning).contains("Some roles have no dates"))
    }

    func testWrittenDateHelper() {
        XCTAssertTrue(ATSAnalyzer.hasWrittenDate(EngineFixtures.entry("Ingeniero", "Acme", detail: "marzo 2018 - diciembre 2020")))
        XCTAssertTrue(ATSAnalyzer.hasWrittenDate(EngineFixtures.entry("工程师", "腾讯 2018年9月-2022年6月")))
        XCTAssertFalse(ATSAnalyzer.hasWrittenDate(EngineFixtures.entry("Ingeniero", "Acme")))
    }

    // MARK: Length

    func testChineseSummaryLengthIsJudgedFairly() {
        // About 80 characters, roughly 40 words: neither very short nor long.
        let summary = "八年后端开发经验，熟悉分布式系统设计，带领过十人以上的研发团队，负责多个核心项目从零到一的落地，擅长性能优化与稳定性建设，注重代码质量和团队协作。"
        let names: [SectionKind: String] = [.summary: "个人简介", .experience: "工作经历", .education: "教育背景", .skills: "专业技能"]
        let r = report(resume(titles: names, summary: summary, jobs: datedJobs()))
        XCTAssertFalse(titles(r, .info).contains("Summary is very short"), "\(titles(r, .info))")
        XCTAssertFalse(titles(r, .info).contains("Summary is long"))
        XCTAssertTrue(titles(r, .good).contains("Summary is present"))
    }

    func testWordCountIsLanguageNeutral() {
        XCTAssertEqual(CJKText.wordCount("one two three"), 3)
        XCTAssertEqual(CJKText.wordCount("负责支付系统核心模块的设计与开发"), 8)
        XCTAssertEqual(CJKText.wordCount("使用 Swift 开发"), 3)
        XCTAssertEqual(CJKText.wordCount(""), 0)
    }

    func testFindingsHaveNoDashesInAnyLanguageInput() {
        let names: [SectionKind: String] = [.summary: "个人简介", .experience: "工作经历"]
        let r = report(resume(titles: names, summary: "简介", jobs: [EngineFixtures.entry("工程师")]))
        for finding in r.findings {
            XCTAssertFalse(finding.title.isEmpty)
            XCTAssertFalse(finding.detail.contains("\u{2014}"), finding.detail)
        }
    }
}
