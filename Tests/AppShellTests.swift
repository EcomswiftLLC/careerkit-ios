import XCTest
@testable import CareerKit

/// Pure logic behind the app shell: sorting, search, default paper size, temp cleanup, navigation reset.
final class AppShellSortingTests: XCTestCase {
    private func resume(_ title: String, created: TimeInterval, updated: TimeInterval, name: String = "") -> Resume {
        var value = Resume(title: title, templateID: TemplateLibrary.defaultTemplateID, sections: [])
        value.createdAt = Date(timeIntervalSince1970: created)
        value.updatedAt = Date(timeIntervalSince1970: updated)
        value.personal.fullName = name
        return value
    }

    private var sample: [Resume] {
        [
            resume("banana", created: 300, updated: 100),
            resume("Apple", created: 100, updated: 300),
            resume("cherry", created: 200, updated: 200)
        ]
    }

    func testLastEditedIsNewestFirst() {
        XCTAssertEqual(CKResumeSort.lastEdited.sorted(sample).map { $0.title }, ["Apple", "cherry", "banana"])
    }

    func testCreatedIsNewestFirst() {
        XCTAssertEqual(CKResumeSort.created.sorted(sample).map { $0.title }, ["banana", "cherry", "Apple"])
    }

    func testTitleIsCaseInsensitiveAToZ() {
        XCTAssertEqual(CKResumeSort.title.sorted(sample).map { $0.title }, ["Apple", "banana", "cherry"])
    }

    func testCompletionPutsFullerResumesFirst() {
        var full = resume("Full", created: 1, updated: 1)
        full.personal.fullName = "Sample Person"
        full.personal.email = "sample@example.com"
        full.personal.phone = "555"
        let empty = resume("Empty", created: 2, updated: 2)
        XCTAssertEqual(CKResumeSort.completion.sorted([empty, full]).map { $0.title }, ["Full", "Empty"])
    }

    func testSearchNeedsEveryWord() {
        let target = resume("Finance CV", created: 1, updated: 1, name: "Jordan Lee")
        XCTAssertTrue(CKResumeSearch.matches(target, query: ""))
        XCTAssertTrue(CKResumeSearch.matches(target, query: "finance"))
        XCTAssertTrue(CKResumeSearch.matches(target, query: "jordan cv"))
        XCTAssertFalse(CKResumeSearch.matches(target, query: "jordan designer"))
    }

    func testEverySortHasATitle() {
        for sort in CKResumeSort.allCases {
            XCTAssertFalse(sort.title.isEmpty)
        }
    }
}

final class AppShellPageSizeTests: XCTestCase {
    func testLetterRegions() {
        XCTAssertEqual(AppState.suggestedPageSize(regionCode: "US"), .usLetter)
        XCTAssertEqual(AppState.suggestedPageSize(regionCode: "ca"), .usLetter)
        XCTAssertEqual(AppState.suggestedPageSize(regionCode: "MX"), .usLetter)
    }

    func testEverywhereElseIsA4() {
        XCTAssertEqual(AppState.suggestedPageSize(regionCode: "GB"), .a4)
        XCTAssertEqual(AppState.suggestedPageSize(regionCode: "DE"), .a4)
        XCTAssertEqual(AppState.suggestedPageSize(regionCode: nil), .a4)
    }
}

final class AppShellTempCleanupTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testOnlyOldCareerKitItemsAreSelected() {
        let entries: [CKTempFiles.Entry] = [
            CKTempFiles.Entry(name: "CareerKitExport-ABC", modified: now.addingTimeInterval(-7200)),
            CKTempFiles.Entry(name: "CareerKitExport-NEW", modified: now.addingTimeInterval(-60)),
            CKTempFiles.Entry(name: "CareerKit-Backup-2026-01-01.json", modified: now.addingTimeInterval(-3601)),
            CKTempFiles.Entry(name: "CareerKit-Backup-2026-01-02.json", modified: nil),
            CKTempFiles.Entry(name: "SomeOtherApp-file", modified: now.addingTimeInterval(-99_999)),
            CKTempFiles.Entry(name: "CareerKitStoreTests-1", modified: now.addingTimeInterval(-99_999))
        ]
        let stale: [String] = CKTempFiles.staleNames(entries, now: now)
        XCTAssertEqual(Set(stale), ["CareerKitExport-ABC", "CareerKit-Backup-2026-01-01.json", "CareerKit-Backup-2026-01-02.json"])
    }

    func testRemoveStaleDeletesOnlyOldItemsOnDisk() throws {
        let directory: URL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CKTempCleanupTests-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let oldFolder: URL = directory.appendingPathComponent("CareerKitExport-old", isDirectory: true)
        try FileManager.default.createDirectory(at: oldFolder, withIntermediateDirectories: true)
        let freshBackup: URL = directory.appendingPathComponent("CareerKit-Backup-today.json")
        try Data("{}".utf8).write(to: freshBackup)
        let unrelated: URL = directory.appendingPathComponent("keep-me.txt")
        try Data("x".utf8).write(to: unrelated)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-7200)], ofItemAtPath: oldFolder.path)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-7200)], ofItemAtPath: unrelated.path)

        let removed: Int = CKTempFiles.removeStale(in: directory, now: Date())
        XCTAssertEqual(removed, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldFolder.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: freshBackup.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))

        XCTAssertEqual(CKTempFiles.removeAll(in: directory), 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: freshBackup.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
    }
}

@MainActor
final class AppShellStateTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name: String = "CareerKitAppShellTests-" + UUID().uuidString
        let defaults: UserDefaults = UserDefaults(suiteName: name) ?? .standard
        addTeardownBlock {
            UserDefaults().removePersistentDomain(forName: name)
        }
        return defaults
    }

    func testResetNavigationBumpsTheGeneration() {
        let state = AppState(defaults: freshDefaults())
        let before: Int = state.dataResetGeneration
        state.resetNavigation()
        XCTAssertEqual(state.dataResetGeneration, before + 1)
    }

    func testEraseEverythingClearsDocumentsGrantsAndName() throws {
        let folder: URL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CareerKitEraseTests-" + UUID().uuidString, isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: folder)
        }
        let defaults: UserDefaults = freshDefaults()
        let store = DocumentStore(directory: folder)
        let state = AppState(defaults: defaults)
        let gate = ExportGate(defaults: defaults, storageKey: "test.grants")
        let resume = Resume(title: "CV", templateID: TemplateLibrary.defaultTemplateID, sections: [])
        store.upsert(resume)
        store.flushNow()
        gate.grant(for: resume.id)
        gate.grant(for: UUID())
        state.displayName = "Sam"
        let generation: Int = state.dataResetGeneration

        try CKLocalDataReset.eraseEverything(store: store, exportGate: gate, appState: state)

        XCTAssertTrue(store.resumes.isEmpty)
        XCTAssertTrue(gate.logic.grants.isEmpty)
        XCTAssertEqual(state.displayName, "")
        XCTAssertEqual(state.dataResetGeneration, generation + 1)
    }
}
