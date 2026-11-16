import XCTest
import PDFKit
@testable import CareerKit

/// Documents written in a chosen language: the fixed words the renderer draws, Chinese and German content in
/// every template, and monogram initials. PDFKit extraction varies in spacing, so text is compared through
/// `PDFValidator.normalise` (NFKC, lowercased, whitespace removed).
final class DocumentLanguageRenderTests: XCTestCase {

    private let others: [ResumeLanguage] = [.es, .fr, .de, .zhHans]

    // MARK: Fixtures

    /// A resume long enough for two or more pages, with a current role starting March 2022.
    private func longResume(language: ResumeLanguage?) -> Resume {
        var resume = EngineFixtures.resume("Language", person: EngineFixtures.person("Jordan Whitfield"), sections: [
            EngineFixtures.section(.summary, text: "Product designer with eight years of experience shipping consumer and business software."),
            EngineFixtures.section(.experience, entries: EngineFixtures.jobs(8, bulletsEach: 6, long: true)),
            EngineFixtures.section(.skills, skills: EngineFixtures.standardSkills())
        ])
        resume.style.language = language
        return resume
    }

    private func chineseResume() -> Resume {
        var person = EngineFixtures.person("王小明", title: "高级产品设计师", city: "上海", country: "中国")
        person.email = "xiaoming.wang@example.cn"
        var resume = EngineFixtures.resume("中文简历", person: person, sections: [
            EngineFixtures.section(.summary, text: "八年后端开发经验，熟悉分布式系统设计，带领过十人以上的研发团队，负责多个核心项目从零到一的落地，擅长性能优化与稳定性建设。"),
            EngineFixtures.section(.experience, entries: [
                EngineFixtures.entry("高级工程师", "腾讯科技有限公司", location: "深圳", start: EngineFixtures.month(2020, 3), current: true,
                                     bullets: ["负责支付系统核心模块的设计与开发，并带领团队在三个月内完成上线，交易成功率提升百分之十五。",
                                               "推动代码评审与自动化测试流程，线上故障数量同比下降一半，团队交付速度明显提高。",
                                               "与产品和设计团队紧密合作，梳理用户反馈并持续优化体验。"]),
                EngineFixtures.entry("软件工程师", "阿里巴巴集团", location: "杭州", start: EngineFixtures.month(2016, 7), end: EngineFixtures.month(2020, 2),
                                     bullets: ["参与电商平台订单系统重构，接口平均响应时间缩短百分之四十。",
                                               "编写技术文档并培训新同事。"])
            ]),
            EngineFixtures.section(.education, entries: [
                EngineFixtures.entry("计算机科学学士", "浙江大学", start: EngineFixtures.month(2012), end: EngineFixtures.month(2016))
            ]),
            EngineFixtures.section(.skills, skills: [
                EngineFixtures.group("技术", ["分布式系统", "数据库优化", "Swift", "Go"]),
                EngineFixtures.group("工具", ["Git", "Docker", "持续集成"])
            ]),
            EngineFixtures.section(.languages, skills: [EngineFixtures.group("", ["中文（母语）", "英语（流利）"])])
        ])
        resume.style.language = .zhHans
        return resume
    }

    private func germanResume() -> Resume {
        var person = EngineFixtures.person("Élodie Müller", title: "Produktdesignerin", city: "München", country: "Deutschland")
        person.email = "elodie.mueller@example.de"
        var resume = EngineFixtures.resume("Lebenslauf", person: person, sections: [
            EngineFixtures.section(.summary, text: "Produktdesignerin mit acht Jahren Erfahrung in der Gestaltung digitaler Dienste für Banken, Behörden und Start-ups."),
            EngineFixtures.section(.experience, entries: [
                EngineFixtures.entry("Leitende Produktdesignerin", "Größenwahn Digital GmbH", location: "München", start: EngineFixtures.month(2021, 3), current: true,
                                     bullets: ["Verantwortung für die Neugestaltung der Straßenverkehrs-App übernommen und die Zufriedenheit um 20 % gesteigert.",
                                               "Ein Team aus fünf Designerinnen und Designern aufgebaut und fachlich geführt.",
                                               "Barrierefreiheit nach WCAG 2.1 in allen Projekten eingeführt."]),
                EngineFixtures.entry("UX-Designerin", "Öffentliche Dienste AG", location: "Köln", start: EngineFixtures.month(2017, 10), end: EngineFixtures.month(2021, 2),
                                     bullets: ["Formulare für über eine Million Bürgerinnen und Bürger vereinfacht.",
                                               "Nutzertests geplant, durchgeführt und ausgewertet."])
            ]),
            EngineFixtures.section(.education, entries: [
                EngineFixtures.entry("Master Interaktionsdesign", "Hochschule für Gestaltung Schwäbisch Gmünd", start: EngineFixtures.month(2015), end: EngineFixtures.month(2017))
            ]),
            EngineFixtures.section(.skills, skills: [
                EngineFixtures.group("Design", ["Interaktionsdesign", "Prototyping", "Designsysteme"]),
                EngineFixtures.group("Werkzeuge", ["Figma", "Sketch", "Swift"])
            ]),
            EngineFixtures.section(.languages, skills: [EngineFixtures.group("", ["Deutsch (Muttersprache)", "Französisch (fließend)", "Englisch (verhandlungssicher)"])])
        ])
        resume.style.language = .de
        return resume
    }

    private func normalisedText(_ doc: RenderedDocument) -> String {
        return PDFValidator.normalise(PDFValidator.extractText(from: doc.pdfData))
    }

    private func normalisedPage(_ doc: RenderedDocument, _ index: Int) -> String {
        guard let pdf = PDFDocument(data: doc.pdfData), let page = pdf.page(at: index) else { return "" }
        return PDFValidator.normalise(page.string ?? "")
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        return text.components(separatedBy: needle).count - 1
    }

    // MARK: Fixed words

    func testPresentMonthsAndFooterFollowTheDocumentLanguage() {
        let spec: TemplateSpec = EngineFixtures.specs[0]
        for language in others {
            let resume: Resume = longResume(language: language)
            let doc: RenderedDocument = DocumentRenderer.render(resume, template: spec)
            let label: String = language.rawValue
            XCTAssertGreaterThanOrEqual(doc.pageCount, 2, label)
            let text: String = normalisedText(doc)

            // "Present" in the current role's date range.
            let present: String = DocumentStrings.present(language)
            XCTAssertNotEqual(present, "Present", label)
            XCTAssertTrue(text.contains(PDFValidator.normalise(present)), "\(label): no \(present)")
            XCTAssertFalse(PDFValidator.extractText(from: doc.pdfData).contains("Present"), "\(label): English word left")

            // Month names in the document language.
            let month: String = MonthYear(year: 2022, month: 3).formatted(locale: language.locale)
            XCTAssertNotEqual(month, MonthYear(year: 2022, month: 3).formatted(locale: Locale(identifier: "en_US")), label)
            XCTAssertTrue(text.contains(PDFValidator.normalise(month)), "\(label): no \(month)")
            switch language {
            case .de: XCTAssertTrue(text.contains("märz"), label)
            case .fr: XCTAssertTrue(text.contains("mars"), label)
            case .zhHans: XCTAssertTrue(text.contains("2022年3月"), label)
            default: break
            }

            // Default headings in the document language.
            XCTAssertTrue(PDFValidator.appears(DocumentStrings.defaultTitle(.experience, language: language), in: text), label)

            // Footer on page 2.
            if let footer = RenderPageFooter.text(name: resume.personal.fullName, page: 2, of: doc.pageCount) {
                XCTAssertTrue(normalisedPage(doc, 1).contains(PDFValidator.normalise(footer)), "\(label): footer missing on page 2")
            } else {
                XCTFail("\(label): expected a footer on page 2")
            }

            let report: PDFValidationReport = PDFValidator.validate(doc, resume: resume)
            XCTAssertTrue(report.passed, "\(label): \(report.issues.joined(separator: " | "))")
        }
    }

    func testNoChoiceKeepsTheAppLanguageWords() {
        let spec: TemplateSpec = EngineFixtures.specs[0]
        let resume: Resume = longResume(language: nil)
        let doc: RenderedDocument = DocumentRenderer.render(resume, template: spec)
        let app: ResumeLanguage = ResumeLanguage.resolved(nil)
        XCTAssertTrue(normalisedText(doc).contains(PDFValidator.normalise(DocumentStrings.present(app))))
        XCTAssertTrue(PDFValidator.validate(doc, resume: resume).passed)
    }

    func testEnglishChoiceOnAnyDeviceWritesEnglish() {
        let spec: TemplateSpec = EngineFixtures.specs[0]
        let resume: Resume = longResume(language: .en)
        let doc: RenderedDocument = DocumentRenderer.render(resume, template: spec)
        let text: String = normalisedText(doc)
        XCTAssertTrue(text.contains("present"))
        XCTAssertTrue(text.contains(PDFValidator.normalise(MonthYear(year: 2022, month: 3).formatted(locale: ResumeLanguage.en.locale))))
        XCTAssertTrue(PDFValidator.appears("Work Experience", in: text))
    }

    func testSidebarContactHeadingUsesTheDocumentLanguage() {
        guard let card = EngineFixtures.specs.first(where: { $0.id == "t.sidebarleft.card" }) else {
            XCTFail("fixture missing")
            return
        }
        for language in ResumeLanguage.allCases {
            var resume: Resume = germanResume()
            resume.style.language = language
            let doc: RenderedDocument = DocumentRenderer.render(resume, template: card)
            XCTAssertTrue(PDFValidator.appears(DocumentStrings.contact(language), in: normalisedText(doc)), language.rawValue)
        }
    }

    func testDateFormatOptionStillWorksInEveryLanguage() {
        let spec: TemplateSpec = EngineFixtures.specs[0]
        for language in others {
            var resume: Resume = longResume(language: language)
            resume.style.dateFormat = .numeric
            let text: String = normalisedText(DocumentRenderer.render(resume, template: spec))
            XCTAssertTrue(text.contains(PDFValidator.normalise("03/2022 – " + DocumentStrings.present(language))), language.rawValue)

            resume.style.dateFormat = .yearOnly
            let years: String = normalisedText(DocumentRenderer.render(resume, template: spec))
            XCTAssertTrue(years.contains(PDFValidator.normalise("2022 – " + DocumentStrings.present(language))), language.rawValue)
        }
    }

    func testCoverLetterDateGreetingAndSignOffFollowTheDocumentLanguage() {
        guard let spec = EngineFixtures.coverLetterSpecs().first else {
            XCTFail("fixture missing")
            return
        }
        for language in ResumeLanguage.allCases {
            var letter: CoverLetter = EngineFixtures.letter()
            letter.recipientName = ""
            letter.greeting = ""
            letter.signOff = "Sincerely,"
            letter.date = Date(timeIntervalSince1970: 1_763_251_200) // 16 November 2025
            letter.style.language = language
            let doc: RenderedDocument = CoverLetterRenderer.render(letter, template: spec)
            let text: String = normalisedText(doc)
            let label: String = language.rawValue
            XCTAssertTrue(PDFValidator.appears(DocumentStrings.letterDate(letter.date, language: language), in: text), label)
            XCTAssertTrue(PDFValidator.appears(DocumentStrings.greetingWithoutName(language), in: text), label)
            XCTAssertTrue(PDFValidator.appears(DocumentStrings.signOff(language), in: text), label)
        }
    }

    // MARK: Every template

    func testEveryTemplateRendersChineseAndGerman() {
        let templates: [TemplateSpec] = TemplateLibrary.all
        XCTAssertGreaterThanOrEqual(templates.count, 30)
        let fixtures: [(String, Resume)] = [("zh-Hans", chineseResume()), ("de", germanResume())]
        for (name, resume) in fixtures {
            for template in templates {
                let doc: RenderedDocument = DocumentRenderer.render(resume, template: template)
                let label: String = "\(name) / \(template.id)"
                XCTAssertGreaterThanOrEqual(doc.pageCount, 1, label)
                let report: PDFValidationReport = PDFValidator.validate(doc, resume: resume)
                let extractedPreview: String = report.passed ? "" : " || EXTRACTED: " + report.extractedText.replacingOccurrences(of: "\n", with: "⏎").prefix(500)
                XCTAssertTrue(report.passed, "\(label): \(report.issues.joined(separator: " | "))\(extractedPreview)")
                let text: String = normalisedText(doc)
                XCTAssertTrue(text.contains(PDFValidator.normalise(DocumentStrings.present(resume.style.language ?? .en))), label)
                XCTAssertFalse(report.extractedText.contains("\u{FFFD}"), label)
            }
        }
    }

    func testChineseTextKeepsItsCharactersInDecoratedHeadings() {
        // Uppercase, tracked and small caps heading styles must leave Chinese untouched.
        let resume: Resume = chineseResume()
        for spec in EngineFixtures.specs {
            let doc: RenderedDocument = DocumentRenderer.render(resume, template: spec)
            let text: String = normalisedText(doc)
            for kind in [SectionKind.summary, .experience, .education] {
                XCTAssertTrue(PDFValidator.appears(DocumentStrings.defaultTitle(kind, language: .zhHans), in: text), "\(spec.id) \(kind)")
            }
            XCTAssertTrue(text.contains("王小明"), spec.id)
        }
    }

    // MARK: Monograms

    private var monogramTemplates: [TemplateSpec] {
        return TemplateLibrary.all.filter { $0.header == .monogramBadge || $0.header == .initialLetter }
            + EngineFixtures.specs.filter { $0.header == .monogramBadge || $0.header == .initialLetter }
    }

    private func monogramResume(_ name: String) -> Resume {
        var person = PersonalInfo()
        person.fullName = name
        person.email = "monogram.test@example.com"
        return EngineFixtures.resume("Monogram", person: person, sections: [
            EngineFixtures.section(.summary, text: "Short summary for the monogram test.")
        ])
    }

    func testMonogramShowsAChineseFamilyName() {
        let templates: [TemplateSpec] = monogramTemplates
        XCTAssertFalse(templates.isEmpty)
        let resume: Resume = monogramResume("王小明")
        for template in templates {
            let doc: RenderedDocument = DocumentRenderer.render(resume, template: template)
            let text: String = normalisedText(doc)
            // Once in the name, once in the monogram or the big initial.
            XCTAssertGreaterThanOrEqual(occurrences(of: "王", in: text), 2, template.id)
            XCTAssertTrue(PDFValidator.validate(doc, resume: resume).passed, template.id)
        }
    }

    func testMonogramKeepsAccents() {
        let resume: Resume = monogramResume("Élodie Müller")
        for template in monogramTemplates {
            let doc: RenderedDocument = DocumentRenderer.render(resume, template: template)
            let text: String = normalisedText(doc)
            XCTAssertGreaterThanOrEqual(occurrences(of: "é", in: text), 2, template.id)
            if template.header == .monogramBadge {
                XCTAssertTrue(text.contains("ém"), "\(template.id): no ÉM badge")
            }
            XCTAssertTrue(PDFValidator.validate(doc, resume: resume).passed, template.id)
        }
    }
}
