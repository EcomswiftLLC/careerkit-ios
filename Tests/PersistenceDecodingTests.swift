import XCTest
@testable import CareerKit

/// Tolerant decoding of saved documents: missing keys, extra keys, unknown enum values, round trips.
final class PersistenceDecodingTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        return try CKJSON.decoder().decode(type, from: Data(json.utf8))
    }

    private func sampleResume() -> Resume {
        var entry = ResumeEntry()
        entry.heading = "Analyst"
        entry.subheading = "Northwind"
        entry.start = MonthYear(year: 2020, month: 4)
        entry.isCurrent = true
        entry.bullets = ["Built the monthly report", "Cut close time by two days"]
        var experience = ResumeSection(kind: .experience)
        experience.entries = [entry]
        var skills = ResumeSection(kind: .skills)
        var group = SkillGroup()
        group.name = "Tools"
        group.items = ["Excel", "SQL"]
        skills.skillGroups = [group]
        var resume = Resume(title: "Finance CV", templateID: TemplateLibrary.defaultTemplateID, sections: [experience, skills])
        resume.personal.fullName = "Sample Person"
        resume.personal.email = "sample@example.com"
        resume.style.accentHex = "#1F4D3A"
        resume.style.fontScale = 1.1
        resume.pageSize = .usLetter
        // Whole seconds, so the ISO 8601 round trip is exact.
        resume.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        resume.updatedAt = Date(timeIntervalSince1970: 1_700_000_500)
        return resume
    }

    // MARK: Round trips

    func testResumeRoundTripIsExact() throws {
        let original: Resume = sampleResume()
        let data: Data = try CKJSON.encoder().encode(original)
        let decoded: Resume = try CKJSON.decoder().decode(Resume.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testCoverLetterRoundTripIsExact() throws {
        var letter = CoverLetter(title: "Letter", templateID: "ck.letter.classic")
        letter.recipientName = "Alex Rivera"
        letter.introduction = "I am writing about the analyst role."
        letter.signOff = "Kind regards,"
        letter.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        letter.updatedAt = Date(timeIntervalSince1970: 1_700_000_100)
        letter.date = Date(timeIntervalSince1970: 1_700_000_000)
        let data: Data = try CKJSON.encoder().encode(letter)
        XCTAssertEqual(try CKJSON.decoder().decode(CoverLetter.self, from: data), letter)
    }

    func testEncodingKeepsTheOriginalKeys() throws {
        let data: Data = try CKJSON.encoder().encode(sampleResume())
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("not an object")
            return
        }
        for key in ["id", "title", "templateID", "createdAt", "updatedAt", "isArchived", "pageSize",
                    "personal", "sections", "style", "isBlank", "schemaVersion"] {
            XCTAssertNotNil(object[key], "missing key \(key)")
        }
    }

    // MARK: Missing keys

    func testVersionOneResumeWithMostKeysRemovedStillOpens() throws {
        let json: String = #"{"title":"Old CV","sections":[{"kind":"experience","entries":[{"heading":"Clerk"}]}]}"#
        let resume: Resume = try decode(Resume.self, json)
        XCTAssertEqual(resume.title, "Old CV")
        XCTAssertEqual(resume.templateID, TemplateLibrary.defaultTemplateID)
        XCTAssertEqual(resume.pageSize, .a4)
        XCTAssertEqual(resume.schemaVersion, 1)
        XCTAssertFalse(resume.isArchived)
        XCTAssertEqual(resume.sections.count, 1)
        XCTAssertEqual(resume.sections.first?.kind, .experience)
        XCTAssertEqual(resume.sections.first?.title, SectionKind.experience.defaultTitle)
        XCTAssertEqual(resume.sections.first?.isVisible, true)
        XCTAssertEqual(resume.sections.first?.entries.first?.heading, "Clerk")
        XCTAssertEqual(resume.sections.first?.entries.first?.bullets, [])
        XCTAssertEqual(resume.style, StyleOverrides())
    }

    func testEmptyObjectDecodesToDefaults() throws {
        let resume: Resume = try decode(Resume.self, "{}")
        XCTAssertTrue(resume.sections.isEmpty)
        XCTAssertFalse(resume.title.isEmpty)
        let letter: CoverLetter = try decode(CoverLetter.self, "{}")
        XCTAssertEqual(letter.signOff, "Sincerely,")
        XCTAssertFalse(letter.title.isEmpty)
    }

    func testMissingUpdatedAtFallsBackToCreatedAt() throws {
        let json: String = #"{"title":"A","createdAt":"2024-01-02T03:04:05Z"}"#
        let resume: Resume = try decode(Resume.self, json)
        XCTAssertEqual(resume.updatedAt, resume.createdAt)
    }

    func testWrongTypesFallBackToDefaults() throws {
        let json: String = #"{"title":42,"isArchived":"yes","pageSize":7,"personal":{"fullName":["x"],"email":"a@b.co"}}"#
        let resume: Resume = try decode(Resume.self, json)
        XCTAssertFalse(resume.title.isEmpty)
        XCTAssertFalse(resume.isArchived)
        XCTAssertEqual(resume.pageSize, .a4)
        XCTAssertEqual(resume.personal.fullName, "")
        XCTAssertEqual(resume.personal.email, "a@b.co")
    }

    // MARK: Extra keys and unknown values

    func testUnknownKeysAreIgnored() throws {
        let json: String = #"{"title":"CV","futureField":{"a":1},"sections":[{"kind":"summary","text":"Hi","glow":true}],"personal":{"fullName":"P","pronouns":"they"}}"#
        let resume: Resume = try decode(Resume.self, json)
        XCTAssertEqual(resume.title, "CV")
        XCTAssertEqual(resume.sections.first?.text, "Hi")
        XCTAssertEqual(resume.personal.fullName, "P")
    }

    func testUnknownSectionKindBecomesCustomAndKeepsContent() throws {
        let json: String = #"{"title":"CV","sections":[{"kind":"achievements","title":"Highlights","entries":[{"heading":"Top seller"}]}]}"#
        let resume: Resume = try decode(Resume.self, json)
        XCTAssertEqual(resume.sections.first?.kind, .custom)
        XCTAssertEqual(resume.sections.first?.title, "Highlights")
        XCTAssertEqual(resume.sections.first?.entries.first?.heading, "Top seller")
        XCTAssertEqual(try decode(SectionKind.self, #""volunteer""#), .volunteer)
    }

    func testUnknownPageSizeAndStyleValuesFallBack() throws {
        let json: String = ##"{"title":"CV","pageSize":"a3","style":{"headerStyle":"zigzag","accentHex":"#112233","dateFormat":"roman"}}"##
        let resume: Resume = try decode(Resume.self, json)
        XCTAssertEqual(resume.pageSize, .a4)
        XCTAssertNil(resume.style.headerStyle)
        XCTAssertNil(resume.style.dateFormat)
        XCTAssertEqual(resume.style.accentHex, "#112233")
    }

    func testOldStyleOverridesJSONStillWorks() throws {
        let json: String = ##"{"title":"CV","style":{"accentHex":"#1F3A5F","fontScale":1.1,"lineSpacing":1.2,"marginPoints":40,"showPhoto":false}}"##
        let resume: Resume = try decode(Resume.self, json)
        XCTAssertEqual(resume.style.accentHex, "#1F3A5F")
        XCTAssertEqual(resume.style.fontScale, 1.1, accuracy: 0.0001)
        XCTAssertEqual(resume.style.lineSpacing, 1.2, accuracy: 0.0001)
        XCTAssertEqual(resume.style.marginPoints, 40)
        XCTAssertFalse(resume.style.showPhoto)
        XCTAssertEqual(resume.style.sectionSpacing, 1)
    }

    // MARK: Arrays

    func testOneBadArrayItemDoesNotLoseTheOthers() throws {
        let json: String = #"{"title":"CV","sections":[{"kind":"summary","text":"One"}, 17, null, {"kind":"skills","skillGroups":[{"items":["A", 3, "B"]}]}]}"#
        let resume: Resume = try decode(Resume.self, json)
        XCTAssertEqual(resume.sections.count, 2)
        XCTAssertEqual(resume.sections.first?.text, "One")
        XCTAssertEqual(resume.sections.last?.skillGroups.first?.items, ["A", "B"])
    }

    func testMonthYearWithoutYearIsDroppedAndBadMonthBecomesYearOnly() throws {
        let json: String = #"{"heading":"Job","start":{"month":3},"end":{"year":2022,"month":"May"}}"#
        let entry: ResumeEntry = try decode(ResumeEntry.self, json)
        XCTAssertNil(entry.start)
        XCTAssertEqual(entry.end, MonthYear(year: 2022, month: nil))
    }

    // MARK: Schema helpers

    func testSchemaPeekReadsOnlyTheVersion() {
        XCTAssertEqual(CKSchemaPeek.version(of: Data(#"{"schemaVersion":7,"title":"x"}"#.utf8)), 7)
        XCTAssertEqual(CKSchemaPeek.version(of: Data(#"{"title":"x"}"#.utf8)), 1)
        XCTAssertNil(CKSchemaPeek.version(of: Data("not json".utf8)))
    }

    func testMigrationRaisesOldVersionsAndLeavesCurrentAlone() {
        var resume = sampleResume()
        resume.schemaVersion = 0
        XCTAssertEqual(CKSchemaMigration.migrate(resume).schemaVersion, CKSchema.current)
        resume.schemaVersion = CKSchema.current
        XCTAssertEqual(CKSchemaMigration.migrate(resume), resume)
        XCTAssertTrue(CKSchemaMigration.isFromNewerApp(CKSchema.current + 1))
        XCTAssertFalse(CKSchemaMigration.isFromNewerApp(CKSchema.current))
    }
}
