import XCTest
@testable import CareerKit

final class TemplateResumeFactoryTests: XCTestCase {

    func testNewResumeCreatesEmptySectionsInTemplateOrder() {
        for template in TemplateLibrary.all {
            let resume = ResumeFactory.newResume(template: template, title: "Test", pageSize: .usLetter)
            XCTAssertEqual(resume.templateID, template.id)
            XCTAssertEqual(resume.title, "Test")
            XCTAssertEqual(resume.pageSize, .usLetter)
            XCTAssertFalse(resume.isBlank)
            XCTAssertEqual(resume.sections.map { $0.kind }, template.mainSections + template.sidebarSections, template.name)
            for section in resume.sections {
                XCTAssertFalse(section.hasContent, "\(template.name): \(section.kind.rawValue) should start empty")
                XCTAssertTrue(section.isVisible)
                XCTAssertEqual(section.title, section.kind.defaultTitle)
            }
            for kind in [SectionKind.summary, .experience, .education, .skills] {
                XCTAssertTrue(resume.sections.contains { $0.kind == kind }, "\(template.name) lacks \(kind.rawValue)")
            }
        }
    }

    func testNewResumeStartsWithEmptyPersonalDetails() {
        guard let template = TemplateLibrary.all.first else { return XCTFail("No templates") }
        let resume = ResumeFactory.newResume(template: template, title: "Mine", pageSize: .a4)
        XCTAssertEqual(resume.personal, PersonalInfo())
        XCTAssertNil(resume.linkedCoverLetterID)
    }

    func testBlankResume() {
        let resume = ResumeFactory.blankResume(title: "Blank", pageSize: .a4)
        XCTAssertTrue(resume.isBlank)
        XCTAssertEqual(resume.title, "Blank")
        XCTAssertEqual(resume.sections.count, 1)
        XCTAssertEqual(resume.sections.first?.kind, .summary)
        XCTAssertEqual(resume.sections.first?.hasContent, false)
        XCTAssertNotNil(TemplateLibrary.spec(id: resume.templateID))
    }

    func testNewCoverLetterCopiesSenderFromResume() {
        guard let template = TemplateLibrary.all.first else { return XCTFail("No templates") }
        var resume = ResumeFactory.newResume(template: template, title: "Source", pageSize: .usLetter)
        resume.personal.fullName = "Test Person"
        resume.personal.professionalTitle = "Test Title"
        resume.personal.email = "test.person@example.com"
        resume.personal.phone = "+1 555 0100"
        resume.personal.city = "Springfield"
        resume.personal.country = "United States"

        let letter = ResumeFactory.newCoverLetter(templateID: "ck.letter.executive", title: "Letter", from: resume)
        XCTAssertEqual(letter.templateID, "ck.letter.executive")
        XCTAssertEqual(letter.title, "Letter")
        XCTAssertEqual(letter.senderName, "Test Person")
        XCTAssertEqual(letter.senderTitle, "Test Title")
        XCTAssertEqual(letter.senderEmail, "test.person@example.com")
        XCTAssertEqual(letter.senderPhone, "+1 555 0100")
        XCTAssertEqual(letter.senderLocation, "Springfield, United States")
        XCTAssertEqual(letter.linkedResumeID, resume.id)
        XCTAssertEqual(letter.pageSize, .usLetter)
        XCTAssertTrue(letter.bodyParagraphs.isEmpty)
        XCTAssertTrue(letter.recipientName.isEmpty)
    }

    func testNewCoverLetterWithoutResumeIsEmpty() {
        let letter = ResumeFactory.newCoverLetter(templateID: "ck.letter.minimal", title: "Fresh", from: nil)
        XCTAssertEqual(letter.templateID, "ck.letter.minimal")
        XCTAssertTrue(letter.senderName.isEmpty)
        XCTAssertNil(letter.linkedResumeID)
        XCTAssertEqual(letter.pageSize, .a4)
        XCTAssertEqual(letter.effectiveGreeting, "Dear Hiring Manager,")
    }
}
