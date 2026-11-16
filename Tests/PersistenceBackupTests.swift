import XCTest
@testable import CareerKit

/// Pure merge, naming and parsing rules for "Restore from backup".
final class PersistenceBackupMergeTests: XCTestCase {
    private func resume(_ title: String, id: UUID = UUID(), updated: TimeInterval, version: Int = CKSchema.current) -> Resume {
        var value = Resume(title: title, templateID: TemplateLibrary.defaultTemplateID, sections: [])
        value.id = id
        value.createdAt = Date(timeIntervalSince1970: 1_600_000_000)
        value.updatedAt = Date(timeIntervalSince1970: updated)
        value.schemaVersion = version
        return value
    }

    func testNewDocumentsAreInserted() {
        let incoming: [Resume] = [resume("A", updated: 100), resume("B", updated: 200)]
        let result = CKBackupMerge.merge(incoming: incoming, existing: [])
        XCTAssertEqual(result.inserts.count, 2)
        XCTAssertEqual(result.restoredCount, 2)
        XCTAssertEqual(result.skippedCount, 0)
    }

    func testIdenticalDocumentIsSkipped() {
        let id = UUID()
        let local: Resume = resume("A", id: id, updated: 100)
        let result = CKBackupMerge.merge(incoming: [local], existing: [local])
        XCTAssertEqual(result.restoredCount, 0)
        XCTAssertEqual(result.skippedSame, 1)
    }

    func testSubSecondDifferenceStillCountsAsTheSameDocument() {
        let id = UUID()
        let local: Resume = resume("A", id: id, updated: 100.75)
        let fromBackup: Resume = resume("A", id: id, updated: 100)
        let result = CKBackupMerge.merge(incoming: [fromBackup], existing: [local])
        XCTAssertEqual(result.skippedSame, 1)
        XCTAssertTrue(result.inserts.isEmpty)
    }

    func testNewerBackupVersionReplacesOlderLocal() {
        let id = UUID()
        let local: Resume = resume("Old title", id: id, updated: 100)
        let newer: Resume = resume("New title", id: id, updated: 500)
        let result = CKBackupMerge.merge(incoming: [newer], existing: [local])
        XCTAssertEqual(result.replacements.map { $0.title }, ["New title"])
        XCTAssertTrue(result.inserts.isEmpty)
        XCTAssertEqual(result.keptBoth, 0)
    }

    func testNewerLocalIsNeverOverwrittenAndBothAreKept() {
        let id = UUID()
        let fixedID = UUID()
        let local: Resume = resume("CV", id: id, updated: 900)
        let older: Resume = resume("CV edited elsewhere", id: id, updated: 100)
        let result = CKBackupMerge.merge(incoming: [older], existing: [local], makeID: { fixedID })
        XCTAssertTrue(result.replacements.isEmpty)
        XCTAssertEqual(result.inserts.count, 1)
        XCTAssertEqual(result.inserts.first?.id, fixedID)
        XCTAssertEqual(result.inserts.first?.title, "CV edited elsewhere (restored)")
        XCTAssertEqual(result.keptBoth, 1)
        XCTAssertEqual(result.restoredCount, 1)
    }

    func testSameTimeDifferentContentKeepsBoth() {
        let id = UUID()
        let local: Resume = resume("Mine", id: id, updated: 300)
        let other: Resume = resume("Theirs", id: id, updated: 300)
        let result = CKBackupMerge.merge(incoming: [other], existing: [local])
        XCTAssertEqual(result.keptBoth, 1)
        XCTAssertNotEqual(result.inserts.first?.id, id)
    }

    func testNewerSchemaDocumentsAreSkipped() {
        let future: Resume = resume("Future", updated: 100, version: CKSchema.current + 1)
        let result = CKBackupMerge.merge(incoming: [future], existing: [])
        XCTAssertEqual(result.skippedNewerSchema, 1)
        XCTAssertEqual(result.restoredCount, 0)
    }

    func testRepeatedIDInsideBackupKeepsNewest() {
        let id = UUID()
        let result = CKBackupMerge.merge(incoming: [resume("Old", id: id, updated: 1), resume("New", id: id, updated: 9)],
                                         existing: [])
        XCTAssertEqual(result.inserts.map { $0.title }, ["New"])
        XCTAssertEqual(result.skippedSame, 1)
    }

    func testReservedIDsAreNeverReused() {
        let id = UUID()
        let result = CKBackupMerge.merge(incoming: [resume("A", id: id, updated: 5)], existing: [], reservedIDs: [id])
        XCTAssertEqual(result.inserts.count, 1)
        XCTAssertNotEqual(result.inserts.first?.id, id)
        XCTAssertEqual(result.keptBoth, 1)
    }

    // MARK: Names

    func testCopyTitles() {
        XCTAssertEqual(CKDocumentNaming.copyTitle(for: "Design CV", existingTitles: ["Design CV"]), "Design CV copy")
        XCTAssertEqual(CKDocumentNaming.copyTitle(for: "Design CV copy", existingTitles: ["Design CV", "Design CV copy"]), "Design CV copy 2")
        XCTAssertEqual(CKDocumentNaming.copyTitle(for: "Design CV copy 2", existingTitles: ["Design CV", "Design CV copy", "Design CV copy 2"]), "Design CV copy 3")
        XCTAssertEqual(CKDocumentNaming.copyTitle(for: "Design CV copy copy", existingTitles: ["Design CV copy", "Design CV copy copy"]), "Design CV copy 2")
        XCTAssertEqual(CKDocumentNaming.baseTitle(removingCopySuffixFrom: "Copy editor"), "Copy editor")
        XCTAssertEqual(CKDocumentNaming.baseTitle(removingCopySuffixFrom: "Room 2 copy 12"), "Room 2")
    }

    func testRestoredTitles() {
        XCTAssertEqual(CKDocumentNaming.restoredTitle(for: "CV", existingTitles: ["CV"]), "CV (restored)")
        XCTAssertEqual(CKDocumentNaming.restoredTitle(for: "CV", existingTitles: ["CV", "CV (restored)"]), "CV (restored 2)")
    }

    func testSummaryMessage() {
        XCTAssertEqual(CKRestoreSummary(restored: 3, skipped: 1).message, "Restored 3 documents, skipped 1.")
        XCTAssertEqual(CKRestoreSummary(restored: 1, skipped: 0).message, "Restored 1 document, skipped 0.")
        XCTAssertTrue(CKRestoreSummary(restored: 2, skipped: 0, keptBoth: 1).message.contains("separate copy"))
    }

    // MARK: Parsing

    func testParserRejectsBadInput() {
        XCTAssertThrowsError(try CKBackupParser.parse(Data())) { error in
            XCTAssertEqual(error as? CKBackupError, .empty)
        }
        XCTAssertThrowsError(try CKBackupParser.parse(Data("nope".utf8))) { error in
            XCTAssertEqual(error as? CKBackupError, .unreadable)
        }
        XCTAssertThrowsError(try CKBackupParser.parse(Data(#"{"format":"something-else","resumes":[]}"#.utf8))) { error in
            XCTAssertEqual(error as? CKBackupError, .notABackup)
        }
        let future: String = #"{"format":"careerkit-backup","schemaVersion":99,"resumes":[],"coverLetters":[]}"#
        XCTAssertThrowsError(try CKBackupParser.parse(Data(future.utf8))) { error in
            XCTAssertEqual(error as? CKBackupError, .newerVersion)
        }
    }

    func testParserIsTolerantInsideAValidBackup() throws {
        let json: String = #"{"format":"careerkit-backup","schemaVersion":1,"resumes":[{"title":"A"}, 5],"extra":true}"#
        let payload: CKBackupPayload = try CKBackupParser.parse(Data(json.utf8))
        XCTAssertEqual(payload.resumes.map { $0.title }, ["A"])
        XCTAssertTrue(payload.coverLetters.isEmpty)
        XCTAssertEqual(payload.unreadableItems, 1)
    }
}

/// Restore, quarantine and newer-version files through a real `DocumentStore` in a temporary folder.
@MainActor
final class PersistenceStoreRestoreTests: XCTestCase {
    private let root: URL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("CareerKitRestoreTests-" + UUID().uuidString, isDirectory: true)

    private var folder: URL {
        let target: URL = root
        addTeardownBlock {
            try? FileManager.default.removeItem(at: target)
        }
        return target
    }

    private func otherFolder() -> URL {
        let target: URL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CareerKitRestoreTests-" + UUID().uuidString, isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: target)
        }
        return target
    }

    func testBackupRestoresIntoAnEmptyDevice() throws {
        let source = DocumentStore(directory: folder)
        source.upsert(Resume(title: "One", templateID: TemplateLibrary.defaultTemplateID, sections: []))
        source.upsert(Resume(title: "Two", templateID: TemplateLibrary.defaultTemplateID, sections: []))
        source.upsert(CoverLetter(title: "Letter", templateID: "x"))
        let url: URL = try source.makeBackupFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let data: Data = try Data(contentsOf: url)

        let target = DocumentStore(directory: otherFolder())
        let summary: CKRestoreSummary = try target.restoreBackup(from: data)
        XCTAssertEqual(summary.restored, 3)
        XCTAssertEqual(summary.skipped, 0)
        XCTAssertEqual(target.resumes.count, 2)
        XCTAssertEqual(target.coverLetters.count, 1)

        // Restoring the same file again changes nothing.
        let again: CKRestoreSummary = try target.restoreBackup(from: data)
        XCTAssertEqual(again.restored, 0)
        XCTAssertEqual(again.skipped, 3)
        XCTAssertEqual(target.resumes.count, 2)
    }

    func testRestoreKeepsANewerLocalEdit() throws {
        let store = DocumentStore(directory: folder)
        store.upsert(Resume(title: "CV", templateID: TemplateLibrary.defaultTemplateID, sections: []))
        let url: URL = try store.makeBackupFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let data: Data = try Data(contentsOf: url)

        guard var local = store.resumes.first else {
            XCTFail("missing resume")
            return
        }
        local.title = "CV edited today"
        local.updatedAt = Date().addingTimeInterval(60)
        store.upsert(local)

        let summary: CKRestoreSummary = try store.restoreBackup(from: data)
        XCTAssertEqual(summary.keptBoth, 1)
        XCTAssertEqual(store.resumes.count, 2)
        XCTAssertNotNil(store.resumes.first(where: { $0.title == "CV edited today" }))
        XCTAssertNotNil(store.resumes.first(where: { $0.title == "CV (restored)" }))
    }

    func testNewerVersionFileIsNeverQuarantinedOrLoaded() throws {
        let setup = DocumentStore(directory: folder)
        let id = UUID()
        let file: URL = setup.resumesDirectory.appendingPathComponent(id.uuidString + ".json")
        let json: String = #"{"id":"\#(id.uuidString)","title":"From the future","schemaVersion":\#(CKSchema.current + 1)}"#
        try Data(json.utf8).write(to: file)

        let store = DocumentStore(directory: folder)
        XCTAssertTrue(store.resumes.isEmpty)
        XCTAssertEqual(store.newerVersionFileCount, 1)
        XCTAssertTrue(store.quarantinedFiles.isEmpty)
        XCTAssertEqual(try Data(contentsOf: file), Data(json.utf8))
    }

    func testQuarantinedFilesAreListedAndCanBeDeleted() throws {
        let setup = DocumentStore(directory: folder)
        try Data("{ broken".utf8).write(to: setup.resumesDirectory.appendingPathComponent(UUID().uuidString + ".json"))

        let store = DocumentStore(directory: folder)
        XCTAssertEqual(store.quarantinedFiles.count, 1)
        try store.deleteQuarantinedFiles()
        XCTAssertTrue(store.quarantinedFiles.isEmpty)
    }

    func testFileNameWinsWhenTheIDInsideIsMissing() throws {
        let setup = DocumentStore(directory: folder)
        let id = UUID()
        try Data(#"{"title":"No id inside"}"#.utf8).write(to: setup.resumesDirectory.appendingPathComponent(id.uuidString + ".json"))
        let store = DocumentStore(directory: folder)
        XCTAssertEqual(store.resumes.first?.id, id)
    }

    func testDuplicateOfACopyIsNumbered() {
        let store = DocumentStore(directory: folder)
        let original = Resume(title: "Design CV", templateID: TemplateLibrary.defaultTemplateID, sections: [])
        store.upsert(original)
        guard let first = store.duplicate(resumeID: original.id) else {
            XCTFail("no copy")
            return
        }
        XCTAssertEqual(first.title, "Design CV copy")
        XCTAssertEqual(store.duplicate(resumeID: first.id)?.title, "Design CV copy 2")
    }
}
