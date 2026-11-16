import XCTest
@testable import CareerKit

final class TemplateSampleContentTests: XCTestCase {

    // MARK: Helpers

    private func texts(in resume: Resume) -> [String] {
        var result: [String] = [
            resume.personal.fullName, resume.personal.professionalTitle, resume.personal.email,
            resume.personal.phone, resume.personal.city, resume.personal.country
        ]
        for section in resume.sections {
            result.append(section.title)
            result.append(section.text)
            for entry in section.entries {
                result.append(entry.heading)
                result.append(entry.subheading)
                result.append(entry.location)
                result.append(entry.detail)
                result.append(entry.extra)
                result.append(contentsOf: entry.bullets)
            }
            for group in section.skillGroups {
                result.append(group.name)
                result.append(contentsOf: group.items)
            }
        }
        return result
    }

    private func wordCount(_ resume: Resume) -> Int {
        return texts(in: resume).reduce(0) { total, text in
            total + text.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
        }
    }

    private func section(_ kind: SectionKind, in resume: Resume) -> ResumeSection? {
        return resume.sections.first { $0.kind == kind }
    }

    // MARK: Required content

    func testEveryTemplateSampleHasTheFourCoreSections() {
        for template in TemplateLibrary.all {
            let resume = SampleContent.resume(for: template)
            XCTAssertEqual(resume.templateID, template.id)
            for kind in [SectionKind.summary, .experience, .education, .skills] {
                guard let found = section(kind, in: resume) else {
                    XCTFail("\(template.name) sample lacks \(kind.rawValue)")
                    continue
                }
                XCTAssertTrue(found.hasContent, "\(template.name) sample has an empty \(kind.rawValue)")
            }
        }
    }

    func testSampleSectionsFollowTemplateOrderAndHaveContent() {
        for template in TemplateLibrary.all {
            let resume = SampleContent.resume(for: template)
            let allowed = ResumeFactory.sectionKinds(for: template)
            var lastIndex = -1
            for section in resume.sections {
                XCTAssertTrue(section.hasContent, "\(template.name) has an empty \(section.kind.rawValue) section")
                guard let index = allowed.firstIndex(of: section.kind) else {
                    XCTFail("\(template.name) sample has a section its template does not list: \(section.kind.rawValue)")
                    continue
                }
                XCTAssertGreaterThan(index, lastIndex, "\(template.name) sections are out of order")
                lastIndex = index
            }
        }
    }

    func testEveryExperienceEntryHasDatesAndBullets() {
        for template in TemplateLibrary.all {
            let resume = SampleContent.resume(for: template)
            guard let experience = section(.experience, in: resume) else { continue }
            for entry in experience.entries {
                XCTAssertFalse(entry.heading.isEmpty, template.name)
                XCTAssertFalse(entry.subheading.isEmpty, template.name)
                XCTAssertNotNil(entry.start, "\(template.name): \(entry.heading) has no start date")
                XCTAssertTrue(entry.end != nil || entry.isCurrent, "\(template.name): \(entry.heading) has no end date")
                XCTAssertFalse(entry.bullets.isEmpty, "\(template.name): \(entry.heading) has no bullets")
            }
        }
    }

    func testPersonalDetailsAreFilled() {
        for template in TemplateLibrary.all {
            let personal = SampleContent.resume(for: template).personal
            XCTAssertFalse(personal.fullName.isEmpty, template.name)
            XCTAssertFalse(personal.professionalTitle.isEmpty, template.name)
            XCTAssertTrue(personal.email.contains("@"), template.name)
            XCTAssertFalse(personal.phone.isEmpty, template.name)
            XCTAssertFalse(personal.city.isEmpty, template.name)
            XCTAssertFalse(personal.country.isEmpty, template.name)
            XCTAssertTrue(personal.email.hasSuffix(".example.com") || personal.email.hasSuffix("@example.com"),
                          "\(template.name) email should use the reserved example domain")
        }
    }

    // MARK: Wording

    func testNoPlaceholderTextOrBannedPunctuation() {
        for template in TemplateLibrary.all {
            let resume = SampleContent.resume(for: template)
            for text in texts(in: resume) {
                let lower = text.lowercased()
                XCTAssertFalse(lower.contains("lorem"), "\(template.name): \(text)")
                XCTAssertFalse(lower.contains("ipsum"), "\(template.name): \(text)")
                XCTAssertFalse(lower.contains("placeholder"), "\(template.name): \(text)")
                XCTAssertFalse(text.contains("\u{2014}"), "\(template.name) has an em dash: \(text)")
            }
        }
    }

    func testCoverLetterSample() {
        let letter = SampleContent.coverLetter()
        XCTAssertNotNil(CoverLetterTemplateLibrary.spec(id: letter.templateID))
        XCTAssertFalse(letter.senderName.isEmpty)
        XCTAssertTrue(letter.senderEmail.contains("@"))
        XCTAssertFalse(letter.recipientName.isEmpty)
        XCTAssertFalse(letter.companyName.isEmpty)
        XCTAssertFalse(letter.jobTitle.isEmpty)
        XCTAssertEqual(letter.bodyParagraphs.count, 4)
        let everything = ([letter.greeting, letter.signOff, letter.jobDescription] + letter.bodyParagraphs).joined(separator: " ")
        XCTAssertFalse(everything.lowercased().contains("lorem"))
        XCTAssertFalse(everything.contains("\u{2014}"))
        XCTAssertEqual(letter.effectiveGreeting, letter.greeting)
    }

    func testSampleLabel() {
        XCTAssertEqual(SampleContent.sampleLabel, "Sample content, fictional person")
    }

    // MARK: Variety and length

    func testAtLeastEightDistinctPersonas() {
        var names: Set<String> = []
        for template in TemplateLibrary.all {
            names.insert(SampleContent.resume(for: template).personal.fullName)
        }
        XCTAssertGreaterThanOrEqual(names.count, 8)
    }

    func testPersonasFitTheirCategory() {
        for template in TemplateLibrary.all where template.category == .academic && template.id != "ck.academic.university-graduate" {
            let resume = SampleContent.resume(for: template)
            XCTAssertNotNil(section(.publications, in: resume), "\(template.name) sample should list publications")
        }
        for template in TemplateLibrary.all where template.levels == [.student] {
            let resume = SampleContent.resume(for: template)
            XCTAssertNotNil(section(.education, in: resume))
        }
    }

    func testSampleLengthMatchesTypicalPages() {
        var onePage: [Int] = []
        var twoPage: [Int] = []
        for template in TemplateLibrary.all {
            let words = wordCount(SampleContent.resume(for: template))
            if template.typicalPages == 1 {
                onePage.append(words)
                XCTAssertLessThanOrEqual(words, 560, "\(template.name) has too much text for one page")
                XCTAssertGreaterThanOrEqual(words, 220, "\(template.name) has too little text for one page")
            } else {
                twoPage.append(words)
                XCTAssertGreaterThanOrEqual(words, 400, "\(template.name) has too little text for two pages")
            }
        }
        XCTAssertFalse(onePage.isEmpty)
        XCTAssertFalse(twoPage.isEmpty)
        let onePageAverage = Double(onePage.reduce(0, +)) / Double(onePage.count)
        let twoPageAverage = Double(twoPage.reduce(0, +)) / Double(twoPage.count)
        XCTAssertGreaterThan(twoPageAverage, onePageAverage * 1.15)
    }

    func testEachCallReturnsFreshIdsButSameContent() {
        guard let template = TemplateLibrary.spec(id: TemplateLibrary.defaultTemplateID) else {
            return XCTFail("No default template")
        }
        let first = SampleContent.resume(for: template)
        let second = SampleContent.resume(for: template)
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.personal, second.personal)
        XCTAssertEqual(first.sections.map { $0.title }, second.sections.map { $0.title })
    }
}
