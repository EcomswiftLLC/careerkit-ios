import XCTest
@testable import CareerKit

@MainActor
final class EngineStoreTests: XCTestCase {
    /// XCTest makes one instance per test method, so this folder is unique to each test.
    private let root: URL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("CareerKitStoreTests-" + UUID().uuidString, isDirectory: true)

    /// Registers clean-up the first time a test asks for the folder.
    private var folder: URL {
        let target: URL = root
        addTeardownBlock {
            try? FileManager.default.removeItem(at: target)
        }
        return target
    }

    private func sampleResume(_ title: String = "My resume") -> Resume {
        return EngineFixtures.resume(title, person: EngineFixtures.person("Store Person"), sections: [
            EngineFixtures.section(.experience, entries: EngineFixtures.jobs(2, bulletsEach: 2))
        ])
    }

    private func resumeFile(_ store: DocumentStore, _ id: UUID) -> URL {
        return store.resumesDirectory.appendingPathComponent(id.uuidString + ".json")
    }

    func testRoundTripThroughDisk() {
        let store = DocumentStore(directory: folder)
        let resume = sampleResume()
        let letter = EngineFixtures.letter()
        store.upsert(resume)
        store.upsert(letter)
        store.flushNow()

        let reloaded = DocumentStore(directory: folder)
        XCTAssertEqual(reloaded.resumes.count, 1)
        XCTAssertEqual(reloaded.coverLetters.count, 1)
        XCTAssertEqual(reloaded.resume(id: resume.id)?.title, "My resume")
        XCTAssertEqual(reloaded.resume(id: resume.id)?.sections.first?.entries.count, 2)
        XCTAssertEqual(reloaded.coverLetter(id: letter.id)?.recipientName, "Alex Rivera")
        XCTAssertEqual(reloaded.resume(id: resume.id)?.personal.fullName, "Store Person")
    }

    func testUpsertStampsUpdatedAtAndReplaces() {
        let store = DocumentStore(directory: folder)
        var resume = sampleResume()
        resume.updatedAt = Date(timeIntervalSince1970: 1000)
        store.upsert(resume)
        let stamped = store.resume(id: resume.id)?.updatedAt ?? Date(timeIntervalSince1970: 0)
        XCTAssertGreaterThan(stamped.timeIntervalSince1970, 1_000_000)

        resume.title = "Renamed"
        store.upsert(resume)
        XCTAssertEqual(store.resumes.count, 1)
        XCTAssertEqual(store.resume(id: resume.id)?.title, "Renamed")
    }

    func testDuplicateAddsCopyWithNewID() {
        let store = DocumentStore(directory: folder)
        let resume = sampleResume("Design CV")
        store.upsert(resume)
        let copy = store.duplicate(resumeID: resume.id)
        XCTAssertNotNil(copy)
        XCTAssertEqual(copy?.title, "Design CV copy")
        XCTAssertNotEqual(copy?.id, resume.id)
        XCTAssertEqual(store.resumes.count, 2)
        if let copy = copy {
            XCTAssertTrue(FileManager.default.fileExists(atPath: resumeFile(store, copy.id).path))
        }
        XCTAssertNil(store.duplicate(resumeID: UUID()))

        let letter = EngineFixtures.letter()
        store.upsert(letter)
        let letterCopy = store.duplicate(coverLetterID: letter.id)
        XCTAssertEqual(letterCopy?.title, "Letter for Northwind copy")
        XCTAssertEqual(store.coverLetters.count, 2)
    }

    func testDeleteRemovesFilesAndEntry() {
        let store = DocumentStore(directory: folder)
        let resume = sampleResume()
        store.upsert(resume)
        store.flushNow()
        store.upsert(resume)
        store.flushNow()
        let file = resumeFile(store, resume.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.appendingPathExtension("bak").path))

        store.delete(resumeID: resume.id)
        XCTAssertNil(store.resume(id: resume.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.appendingPathExtension("bak").path))

        let letter = EngineFixtures.letter()
        store.upsert(letter)
        store.flushNow()
        store.delete(coverLetterID: letter.id)
        XCTAssertTrue(store.coverLetters.isEmpty)
    }

    func testDeletedDocumentIsNotWrittenByAPendingSave() async throws {
        let store = DocumentStore(directory: folder, debounceInterval: 0.2)
        let resume = sampleResume()
        store.upsert(resume)
        store.delete(resumeID: resume.id)
        try await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertFalse(FileManager.default.fileExists(atPath: resumeFile(store, resume.id).path))
    }

    func testCorruptFileIsQuarantinedAndNeverCrashes() throws {
        let setup = DocumentStore(directory: folder)
        let good = sampleResume("Good one")
        setup.upsert(good)
        setup.flushNow()

        let badID = UUID()
        let badFile = setup.resumesDirectory.appendingPathComponent(badID.uuidString + ".json")
        try Data("{ this is not json".utf8).write(to: badFile)
        let emptyID = UUID()
        let emptyFile = setup.resumesDirectory.appendingPathComponent(emptyID.uuidString + ".json")
        try Data().write(to: emptyFile)

        let store = DocumentStore(directory: folder)
        XCTAssertEqual(store.resumes.count, 1)
        XCTAssertEqual(store.resumes.first?.title, "Good one")
        XCTAssertFalse(FileManager.default.fileExists(atPath: badFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: emptyFile.path))
        let quarantined = (try? FileManager.default.contentsOfDirectory(at: store.quarantineDirectory, includingPropertiesForKeys: nil)) ?? []
        XCTAssertEqual(quarantined.count, 2)
    }

    func testCorruptMainFileRecoversFromBackup() throws {
        let store = DocumentStore(directory: folder)
        var resume = sampleResume("Version A")
        store.upsert(resume)
        store.flushNow()
        resume.title = "Version B"
        store.upsert(resume)
        store.flushNow()
        try Data("garbage".utf8).write(to: resumeFile(store, resume.id))

        let reloaded = DocumentStore(directory: folder)
        XCTAssertEqual(reloaded.resumes.count, 1)
        XCTAssertEqual(reloaded.resumes.first?.title, "Version A")
        let quarantined = (try? FileManager.default.contentsOfDirectory(at: reloaded.quarantineDirectory, includingPropertiesForKeys: nil)) ?? []
        XCTAssertEqual(quarantined.count, 1)
    }

    func testSecondSaveKeepsPreviousVersionAsBackup() throws {
        let store = DocumentStore(directory: folder)
        var resume = sampleResume("First")
        store.upsert(resume)
        store.flushNow()
        resume.title = "Second"
        store.upsert(resume)
        store.flushNow()
        let backup = resumeFile(store, resume.id).appendingPathExtension("bak")
        let data = try Data(contentsOf: backup)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let old = try decoder.decode(Resume.self, from: data)
        XCTAssertEqual(old.title, "First")
    }

    func testDebouncedSaveWritesAfterTheDelay() async throws {
        let store = DocumentStore(directory: folder)
        let resume = sampleResume()
        store.upsert(resume)
        XCTAssertEqual(store.saveState, .saving)
        XCTAssertFalse(FileManager.default.fileExists(atPath: resumeFile(store, resume.id).path))

        try await Task.sleep(nanoseconds: 1_300_000_000)
        XCTAssertTrue(FileManager.default.fileExists(atPath: resumeFile(store, resume.id).path))
        if case .saved = store.saveState {
            // expected
        } else {
            XCTFail("save state should be saved, was \(store.saveState)")
        }
    }

    func testRapidEditsAreCoalescedIntoOneWrite() async throws {
        let store = DocumentStore(directory: folder, debounceInterval: 0.3)
        var resume = sampleResume("Typing")
        for i in 0..<10 {
            resume.title = "Typing \(i)"
            store.upsert(resume)
        }
        try await Task.sleep(nanoseconds: 800_000_000)
        let reloaded = DocumentStore(directory: folder)
        XCTAssertEqual(reloaded.resume(id: resume.id)?.title, "Typing 9")
    }

    func testFlushNowIsSynchronous() {
        let store = DocumentStore(directory: folder)
        let resume = sampleResume()
        store.upsert(resume)
        store.flushNow()
        XCTAssertTrue(FileManager.default.fileExists(atPath: resumeFile(store, resume.id).path))
        if case .saved = store.saveState {
            // expected
        } else {
            XCTFail("save state should be saved")
        }
    }

    func testArchiveFlagPersists() {
        let store = DocumentStore(directory: folder)
        let resume = sampleResume()
        store.upsert(resume)
        store.setArchived(true, resumeID: resume.id)
        store.flushNow()
        XCTAssertEqual(DocumentStore(directory: folder).resume(id: resume.id)?.isArchived, true)
        store.setArchived(false, resumeID: resume.id)
        XCTAssertEqual(store.resume(id: resume.id)?.isArchived, false)
    }

    func testDeleteAllDataEmptiesEverything() throws {
        let store = DocumentStore(directory: folder)
        store.upsert(sampleResume())
        store.upsert(EngineFixtures.letter())
        store.flushNow()
        try store.deleteAllData()
        XCTAssertTrue(store.resumes.isEmpty)
        XCTAssertTrue(store.coverLetters.isEmpty)
        XCTAssertEqual(store.saveState, .idle)
        let reloaded = DocumentStore(directory: folder)
        XCTAssertTrue(reloaded.resumes.isEmpty)
        XCTAssertTrue(reloaded.coverLetters.isEmpty)
    }

    func testBackupFileContainsEveryDocument() throws {
        let store = DocumentStore(directory: folder)
        store.upsert(sampleResume("One"))
        store.upsert(sampleResume("Two"))
        store.upsert(EngineFixtures.letter())
        let url = try store.makeBackupFile()
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.pathExtension, "json")

        let data = try Data(contentsOf: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("backup is not a JSON object")
            return
        }
        XCTAssertEqual((object["resumes"] as? [Any])?.count, 2)
        XCTAssertEqual((object["coverLetters"] as? [Any])?.count, 1)
        XCTAssertEqual(object["schemaVersion"] as? Int, DocumentStore.currentSchemaVersion)
    }

    func testPhotoDataSurvivesTheRoundTrip() {
        let store = DocumentStore(directory: folder)
        var resume = sampleResume()
        let photo = EngineFixtures.photoData()
        resume.personal.photoData = photo
        store.upsert(resume)
        store.flushNow()
        XCTAssertEqual(DocumentStore(directory: folder).resume(id: resume.id)?.personal.photoData, photo)
    }
}
