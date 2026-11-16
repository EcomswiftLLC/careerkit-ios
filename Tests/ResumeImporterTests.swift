import XCTest
import UIKit
@testable import CareerKit

final class ResumeImporterTests: XCTestCase {

    // MARK: Fixtures

    private let oneColumnCV: String = """
    Jordan Avery
    Senior Product Designer
    jordan.avery@example.com | +1 (555) 014-2290 | Austin, TX
    linkedin.com/in/jordan-avery

    Professional Summary
    Product designer with nine years of experience shaping consumer apps and internal tools.
    Known for clear research and calm collaboration.

    Work Experience
    Senior Product Designer | Northwind Labs | Austin, TX
    Jan 2020 – Present
    • Led the redesign of the onboarding flow, lifting completion by 18 percent.
    • Built a shared design system used by six product teams.

    Product Designer | Bluebird Studio
    Mar 2016 – Dec 2019
    • Designed booking features for a travel app with two million users.
    • Ran weekly usability sessions and shared findings with
      engineering and product.

    Education
    BA Interaction Design
    State University, 2012 - 2016

    Skills
    Design: Figma, Prototyping, User research
    Tools: Jira, Notion
    Accessibility

    Certifications
    Certified Usability Analyst, 2018
    Google UX Design Certificate

    Languages
    English (native), Spanish (fluent)

    Hobbies: hiking, film photography
    """

    /// A sidebar CV as PDF text extraction often returns it: the sidebar first, then the main column.
    private let twoColumnFlattenedCV: String = """
    CONTACT
    maria.lopez@example.com
    +44 20 7946 0958
    London, United Kingdom
    www.marialopez.dev
    SKILLS
    Python
    SQL
    Tableau
    LANGUAGES
    English
    Portuguese
    MARIA LOPEZ
    Data Analyst
    PROFILE
    Data analyst with five years of experience turning messy data into clear reporting for retail and logistics teams.
    EXPERIENCE
    Data Analyst
    Contoso Retail
    06/2021 - Present
    Built weekly sales dashboards used by 40 store managers.
    Automated stock reports, saving 6 hours a week.
    Junior Analyst
    Fabrikam Logistics
    09/2019 - 05/2021
    Cleaned shipment data for monthly reviews.
    EDUCATION
    MSc Data Science
    University of Leeds
    2018 - 2019
    """

    private let spanishCV: String = """
    Lucía Fernández García
    Ingeniera de Software
    lucia.fernandez@example.es · +34 612 345 678 · Madrid, España

    Perfil profesional
    Ingeniera con seis años de experiencia en desarrollo de aplicaciones móviles para banca y comercio.

    Experiencia laboral
    Desarrolladora iOS — Acme Soluciones
    ene 2019 - actualidad
    • Diseño de la arquitectura de la app principal.

    Educación
    Grado en Ingeniería Informática
    Universidad de Sevilla, 2012 - 2016

    Habilidades
    Swift, Kotlin, SQL

    Idiomas
    Español (nativo), Inglés (C1)
    """

    // MARK: Helpers

    private func section(_ draft: ResumeImportDraft, _ kind: SectionKind) -> ResumeSection? {
        return draft.sections.first(where: { $0.section.kind == kind && !$0.isFallback })?.section
    }

    private func kinds(_ draft: ResumeImportDraft) -> [SectionKind] {
        return draft.sections.filter { !$0.isFallback }.map { $0.section.kind }
    }

    private func items(_ section: ResumeSection?) -> [String] {
        return (section?.skillGroups ?? []).flatMap { $0.items }
    }

    private func compact(_ text: String) -> String {
        return text.lowercased().filter { !$0.isWhitespace }
    }

    // MARK: One column

    func testOneColumnCVPersonalDetails() {
        let draft = ResumeImporter.parse(oneColumnCV)
        XCTAssertEqual(draft.personal.fullName, "Jordan Avery")
        XCTAssertEqual(draft.personal.professionalTitle, "Senior Product Designer")
        XCTAssertEqual(draft.personal.email, "jordan.avery@example.com")
        XCTAssertTrue(draft.personal.phone.filter { $0.isNumber }.contains("5550142290"), draft.personal.phone)
        XCTAssertEqual(draft.personal.city, "Austin")
        XCTAssertTrue(draft.personal.linkedIn.lowercased().contains("linkedin.com"), draft.personal.linkedIn)
    }

    func testOneColumnCVSections() {
        let draft = ResumeImporter.parse(oneColumnCV)
        let found = kinds(draft)
        for kind in [SectionKind.summary, .experience, .education, .skills, .certifications, .languages, .interests] {
            XCTAssertTrue(found.contains(kind), "missing \(kind) in \(found)")
        }
        XCTAssertTrue(section(draft, .summary)?.text.contains("calm collaboration") == true)

        let jobs = section(draft, .experience)?.entries ?? []
        XCTAssertEqual(jobs.count, 2, "\(jobs.map { $0.heading })")
        if jobs.count == 2 {
            XCTAssertEqual(jobs[0].heading, "Senior Product Designer")
            XCTAssertEqual(jobs[0].subheading, "Northwind Labs")
            XCTAssertEqual(jobs[0].location, "Austin, TX")
            XCTAssertEqual(jobs[0].start, MonthYear(year: 2020, month: 1))
            XCTAssertTrue(jobs[0].isCurrent)
            XCTAssertEqual(jobs[0].bullets.count, 2)
            XCTAssertEqual(jobs[1].heading, "Product Designer")
            XCTAssertEqual(jobs[1].start, MonthYear(year: 2016, month: 3))
            XCTAssertEqual(jobs[1].end, MonthYear(year: 2019, month: 12))
            // A bullet wrapped onto two lines is joined back together.
            XCTAssertEqual(jobs[1].bullets.count, 2)
            XCTAssertTrue(jobs[1].bullets.last?.contains("engineering and product") == true)
        }

        let degree = section(draft, .education)?.entries.first
        XCTAssertEqual(degree?.heading, "BA Interaction Design")
        XCTAssertEqual(degree?.subheading, "State University")
        XCTAssertEqual(degree?.start?.year, 2012)
        XCTAssertEqual(degree?.end?.year, 2016)

        let skills = section(draft, .skills)
        XCTAssertTrue(skills?.skillGroups.contains(where: { $0.name == "Tools" && $0.items.contains("Jira") }) == true)
        XCTAssertTrue(items(skills).contains("Figma"))
        XCTAssertTrue(items(skills).contains("Accessibility"))

        let certificates = section(draft, .certifications)?.entries ?? []
        XCTAssertEqual(certificates.count, 2)
        XCTAssertEqual(certificates.first?.heading, "Certified Usability Analyst")
        XCTAssertEqual(certificates.first?.end?.year, 2018)

        XCTAssertTrue(items(section(draft, .languages)).contains("English (native)"))
        XCTAssertTrue(section(draft, .interests)?.text.contains("hiking") == true)
    }

    func testMakeResumeUsesRealModelAndRespectsRemovals() {
        var draft = ResumeImporter.parse(oneColumnCV)
        if let index = draft.sections.firstIndex(where: { $0.section.kind == .certifications }) {
            draft.sections[index].isIncluded = false
        }
        let resume = draft.makeResume(title: draft.suggestedTitle,
                                      templateID: TemplateLibrary.defaultTemplateID,
                                      pageSize: .a4)
        XCTAssertEqual(resume.title, "Jordan Avery Resume")
        XCTAssertEqual(resume.templateID, TemplateLibrary.defaultTemplateID)
        XCTAssertEqual(resume.personal.fullName, "Jordan Avery")
        XCTAssertFalse(resume.sections.contains(where: { $0.kind == .certifications }))
        for kind in ResumeFactory.requiredKinds {
            XCTAssertTrue(resume.sections.contains(where: { $0.kind == kind }), "\(kind)")
        }
    }

    // MARK: Two column, flattened

    func testTwoColumnFlattenedCV() {
        let draft = ResumeImporter.parse(twoColumnFlattenedCV)
        XCTAssertEqual(draft.personal.fullName, "Maria Lopez")
        XCTAssertEqual(draft.personal.professionalTitle, "Data Analyst")
        XCTAssertEqual(draft.personal.email, "maria.lopez@example.com")
        XCTAssertEqual(draft.personal.city, "London")
        XCTAssertEqual(draft.personal.country, "United Kingdom")

        let found = kinds(draft)
        for kind in [SectionKind.skills, .languages, .summary, .experience, .education] {
            XCTAssertTrue(found.contains(kind), "missing \(kind) in \(found)")
        }
        let skills = items(section(draft, .skills))
        XCTAssertTrue(skills.contains("Python") && skills.contains("SQL") && skills.contains("Tableau"), "\(skills)")
        let languages = items(section(draft, .languages))
        XCTAssertTrue(languages.contains("Portuguese"))
        XCTAssertFalse(languages.contains("MARIA LOPEZ"), "\(languages)")

        let jobs = section(draft, .experience)?.entries ?? []
        XCTAssertEqual(jobs.count, 2, "\(jobs.map { $0.heading })")
        if jobs.count == 2 {
            XCTAssertEqual(jobs[0].heading, "Data Analyst")
            XCTAssertEqual(jobs[0].subheading, "Contoso Retail")
            XCTAssertEqual(jobs[0].start, MonthYear(year: 2021, month: 6))
            XCTAssertTrue(jobs[0].isCurrent)
            XCTAssertTrue(jobs[0].detail.contains("dashboards"))
            XCTAssertEqual(jobs[1].heading, "Junior Analyst")
            XCTAssertEqual(jobs[1].subheading, "Fabrikam Logistics")
            XCTAssertEqual(jobs[1].start, MonthYear(year: 2019, month: 9))
            XCTAssertEqual(jobs[1].end, MonthYear(year: 2021, month: 5))
        }
        let degree = section(draft, .education)?.entries.first
        XCTAssertEqual(degree?.heading, "MSc Data Science")
        XCTAssertEqual(degree?.subheading, "University of Leeds")
    }

    // MARK: Minimal, empty, garbage

    func testMinimalCV() throws {
        let draft = try ResumeImporter.draft(fromPastedText: "Sam Lee\nsam.lee@example.com")
        XCTAssertEqual(draft.personal.fullName, "Sam Lee")
        XCTAssertEqual(draft.personal.email, "sam.lee@example.com")
        XCTAssertTrue(draft.hasContent)
        let resume = draft.makeResume(title: draft.suggestedTitle, templateID: TemplateLibrary.defaultTemplateID, pageSize: .usLetter)
        XCTAssertEqual(resume.pageSize, .usLetter)
        XCTAssertEqual(resume.sections.map { $0.kind }, ResumeFactory.requiredKinds)
    }

    func testEmptyInput() {
        let draft = ResumeImporter.parse("")
        XCTAssertFalse(draft.hasContent)
        XCTAssertTrue(draft.sections.isEmpty)
        XCTAssertEqual(draft.suggestedTitle, "Imported resume")
        XCTAssertThrowsError(try ResumeImporter.draft(fromPastedText: "   \n\n \t")) { error in
            XCTAssertEqual(error as? ResumeImportError, .emptyText)
        }
    }

    func testGarbageIsKeptNotLost() {
        let garbage = "@@@ ### $$$\n%%%%%%\n!!! ??? ***\n~~~~\n\u{0000}\u{0007}\u{FFFD}\u{FFFD}"
        let draft = ResumeImporter.parse(garbage)
        XCTAssertEqual(draft.personal.fullName, "")
        let fallback = draft.fallbackSection
        XCTAssertNotNil(fallback)
        let text = fallback?.section.entries.first?.detail ?? ""
        XCTAssertTrue(text.contains("%%%%%%"), text)
        XCTAssertTrue(text.contains("~~~~"), text)
    }

    func testTextWithoutHeadingsIsNeverLost() {
        var lines: [String] = []
        for i in 1...14 {
            lines.append("Line number \(i) about gardening and allotment planning.")
        }
        let draft = ResumeImporter.parse(lines.joined(separator: "\n"))
        let all = draft.allText
        for line in lines {
            XCTAssertTrue(all.contains(line), "lost: \(line)")
        }
        XCTAssertNotNil(draft.fallbackSection)
        XCTAssertEqual(draft.fallbackSection?.section.title, "Imported text")
    }

    func testUnrecognisedHeaderTextGoesToImportedText() {
        let text = """
        Alex Kim
        Open to relocation | Available from March
        Experience
        Barista | Corner Cafe
        2021 - 2023
        """
        let draft = ResumeImporter.parse(text)
        XCTAssertEqual(draft.personal.fullName, "Alex Kim")
        XCTAssertTrue(draft.allText.contains("Open to relocation"), draft.allText)
        XCTAssertEqual(section(draft, .experience)?.entries.first?.heading, "Barista")
    }

    // MARK: Other languages

    func testSpanishCV() {
        let draft = ResumeImporter.parse(spanishCV)
        XCTAssertEqual(draft.personal.fullName, "Lucía Fernández García")
        XCTAssertEqual(draft.personal.email, "lucia.fernandez@example.es")
        XCTAssertEqual(draft.personal.city, "Madrid")
        let found = kinds(draft)
        for kind in [SectionKind.summary, .experience, .education, .skills, .languages] {
            XCTAssertTrue(found.contains(kind), "missing \(kind) in \(found)")
        }
        let job = section(draft, .experience)?.entries.first
        XCTAssertEqual(job?.heading, "Desarrolladora iOS")
        XCTAssertEqual(job?.subheading, "Acme Soluciones")
        XCTAssertEqual(job?.start, MonthYear(year: 2019, month: 1))
        XCTAssertEqual(job?.isCurrent, true)
        XCTAssertEqual(section(draft, .education)?.entries.first?.end?.year, 2016)
        XCTAssertTrue(items(section(draft, .skills)).contains("Kotlin"))
    }

    func testGermanAndFrenchHeadings() {
        let text = """
        Jonas Weber
        Berufserfahrung
        Entwickler | Beispiel GmbH
        März 2018 – heute
        Ausbildung
        B.Sc. Informatik, 2014 - 2017
        Compétences
        Java, Kotlin
        """
        let draft = ResumeImporter.parse(text)
        let found = kinds(draft)
        XCTAssertTrue(found.contains(.experience), "\(found)")
        XCTAssertTrue(found.contains(.education), "\(found)")
        XCTAssertTrue(found.contains(.skills), "\(found)")
        let job = section(draft, .experience)?.entries.first
        XCTAssertEqual(job?.start, MonthYear(year: 2018, month: 3))
        XCTAssertEqual(job?.isCurrent, true)
    }

    // MARK: Very long

    func testVeryLongInputIsCappedAndFinishes() {
        var text = "Pat Morgan\npat@example.com\n\nWork Experience\n"
        var i = 0
        while text.count <= ResumeImporter.maxTextLength + 5_000 {
            text += "Role \(i) | Company \(i)\nJan 2010 - Dec 2011\n• Delivered project \(i) on time and on budget.\n\n"
            i += 1
        }
        let started = Date()
        let draft = ResumeImporter.parse(text)
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertTrue(draft.wasTruncated)
        XCTAssertEqual(draft.personal.fullName, "Pat Morgan")
        XCTAssertGreaterThan(section(draft, .experience)?.entries.count ?? 0, 100)
        XCTAssertLessThan(elapsed, 30.0, "Parsing took \(elapsed) s")
    }

    // MARK: Dates and bullets

    func testDateParsing() {
        let a = ImportDateParser.find(in: "Jan 2020 – Present", allowSingle: false)
        XCTAssertEqual(a?.start, MonthYear(year: 2020, month: 1))
        XCTAssertEqual(a?.isCurrent, true)
        XCTAssertEqual(a?.remainder, "")

        let b = ImportDateParser.find(in: "Acme | 03/2018 - 06/2021", allowSingle: false)
        XCTAssertEqual(b?.start, MonthYear(year: 2018, month: 3))
        XCTAssertEqual(b?.end, MonthYear(year: 2021, month: 6))
        XCTAssertEqual(b?.remainder, "Acme")

        let c = ImportDateParser.find(in: "Sept. 2019 to Dec 2020", allowSingle: false)
        XCTAssertEqual(c?.start, MonthYear(year: 2019, month: 9))
        XCTAssertEqual(c?.end, MonthYear(year: 2020, month: 12))

        let d = ImportDateParser.find(in: "Mars 2018 – Juin 2020", allowSingle: false)
        XCTAssertEqual(d?.start, MonthYear(year: 2018, month: 3))
        XCTAssertEqual(d?.end, MonthYear(year: 2020, month: 6))

        let e = ImportDateParser.find(in: "ene 2019 - actualidad", allowSingle: false)
        XCTAssertEqual(e?.start, MonthYear(year: 2019, month: 1))
        XCTAssertEqual(e?.isCurrent, true)

        XCTAssertNil(ImportDateParser.find(in: "Graduated 2014", allowSingle: false))
        let single = ImportDateParser.find(in: "Graduated 2014", allowSingle: true)
        XCTAssertEqual(single?.end?.year, 2014)
        XCTAssertNil(single?.start)
        XCTAssertNil(ImportDateParser.find(in: "Managed 40 people", allowSingle: true))
    }

    func testBulletDetection() {
        XCTAssertTrue(ResumeImporter.isBulletLine("\u{2022} Led the team"))
        XCTAssertTrue(ResumeImporter.isBulletLine("- Led the team"))
        XCTAssertTrue(ResumeImporter.isBulletLine("* Led the team"))
        XCTAssertFalse(ResumeImporter.isBulletLine("-Led the team"))
        XCTAssertFalse(ResumeImporter.isBulletLine("+44 20 7946 0958"))
        XCTAssertEqual(ResumeImporter.stripBullet("\u{2022} Led the team"), "Led the team")
    }

    // MARK: PDF

    func testPDFRoundTripRecoversNameEmailAndSections() throws {
        var jobs = EngineFixtures.jobs(2, bulletsEach: 2)
        for index in jobs.indices where jobs[index].end == nil && !jobs[index].isCurrent {
            jobs[index].end = EngineFixtures.month(2020)
        }
        let resume = EngineFixtures.resume("Round trip", person: EngineFixtures.person("Taylor Brooks"), sections: [
            EngineFixtures.section(.summary, text: "Product designer with eight years of experience shipping consumer and business software."),
            EngineFixtures.section(.experience, entries: jobs),
            EngineFixtures.section(.education, entries: [EngineFixtures.entry("BA Design", "State University",
                                                                               start: EngineFixtures.month(2010),
                                                                               end: EngineFixtures.month(2014))]),
            EngineFixtures.section(.skills, skills: EngineFixtures.standardSkills())
        ])
        let document = DocumentRenderer.render(resume, template: EngineFixtures.specs[0])
        let text = try ResumeImporter.text(fromPDFData: document.pdfData)
        let draft = ResumeImporter.parse(text)

        XCTAssertEqual(compact(draft.personal.fullName), "taylorbrooks", "extracted text starts: \(text.prefix(300))")
        XCTAssertEqual(draft.personal.email.lowercased(), "sample.person@example.com")
        let found = kinds(draft)
        for kind in [SectionKind.summary, .experience, .education, .skills] {
            XCTAssertTrue(found.contains(kind), "missing \(kind) in \(found); text: \(text.prefix(600))")
        }
    }

    func testImagePDFIsReportedAsNoText() {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let data = renderer.pdfData { context in
            context.beginPage()
            UIColor.darkGray.setFill()
            context.fill(CGRect(x: 60, y: 60, width: 475, height: 300))
        }
        XCTAssertThrowsError(try ResumeImporter.text(fromPDFData: data)) { error in
            XCTAssertEqual(error as? ResumeImportError, .noText)
        }
    }

    func testTooManyPagesAndBadData() {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 200))
        let data = renderer.pdfData { context in
            for _ in 0..<11 { context.beginPage() }
        }
        XCTAssertThrowsError(try ResumeImporter.text(fromPDFData: data)) { error in
            XCTAssertEqual(error as? ResumeImportError, .tooManyPages(11))
        }
        XCTAssertThrowsError(try ResumeImporter.text(fromPDFData: Data("not a pdf".utf8))) { error in
            XCTAssertEqual(error as? ResumeImportError, .unreadable)
        }
    }
}
