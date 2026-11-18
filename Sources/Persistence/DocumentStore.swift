import Foundation
import Combine

/// Keeps resumes and cover letters on the device as one JSON file per document.
///
/// Layout inside the root folder (Application Support/CareerKit unless a directory is injected):
///   Documents/Resumes/<uuid>.json      (plus <uuid>.json.bak, the previous version)
///   Documents/CoverLetters/<uuid>.json
///   Quarantine/                        files that could not be read
///
/// A file whose `schemaVersion` is newer than this build is never decoded, rewritten or quarantined.
/// It stays where it is and is counted in `newerVersionFileCount` so Profile can explain it.
@MainActor
final class DocumentStore: ObservableObject {
    enum SaveState: Equatable {
        case idle
        case saving
        case saved(Date)
        case failed(String)
    }

    /// Version written into new documents. Older versions pass through `CKSchemaMigration` when loaded.
    static let currentSchemaVersion: Int = CKSchema.current

    @Published private(set) var resumes: [Resume] = []
    @Published private(set) var coverLetters: [CoverLetter] = []
    @Published private(set) var saveState: SaveState = .idle
    /// Files in Quarantine (could not be read). Profile offers to export or delete them.
    @Published private(set) var quarantinedFiles: [URL] = []
    /// Documents written by a newer CareerKit. Kept untouched on disk.
    @Published private(set) var newerVersionFileCount: Int = 0
    /// Ids of the newer-version files, so a restore never reuses them.
    private var newerVersionIDs: Set<UUID> = []

    let rootDirectory: URL
    let resumesDirectory: URL
    let lettersDirectory: URL
    let quarantineDirectory: URL

    private let fileManager: FileManager = FileManager.default
    private let debounceNanoseconds: UInt64
    /// First wait before a failed write is tried again. It doubles after each failure, up to a minute.
    private let retryBaseNanoseconds: UInt64
    /// Failed write rounds in a row. Reset by a round that wrote everything.
    private var failedFlushStreak: Int = 0
    /// Automatic retries stop after this many failed rounds in a row. Any edit, and every move to the background,
    /// still tries again.
    static let maxAutomaticRetries: Int = 8
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var dirtyResumeIDs: Set<UUID> = []
    private var dirtyLetterIDs: Set<UUID> = []
    private var saveTask: Task<Void, Never>?

    /// - Parameters:
    ///   - directory: root folder. nil uses Application Support/CareerKit. Tests pass a temporary folder.
    ///   - debounceInterval: delay before an edit is written to disk.
    ///   - retryInterval: first wait before a failed write is tried again (doubles each time, at most one minute).
    init(directory: URL? = nil, debounceInterval: TimeInterval = 0.6, retryInterval: TimeInterval = 5) {
        let root: URL
        if let directory = directory {
            root = directory
        } else {
            let base: URL = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                          in: .userDomainMask,
                                                          appropriateFor: nil,
                                                          create: true)) ?? FileManager.default.temporaryDirectory
            root = base.appendingPathComponent("CareerKit", isDirectory: true)
        }
        self.rootDirectory = root
        let documents: URL = root.appendingPathComponent("Documents", isDirectory: true)
        self.resumesDirectory = documents.appendingPathComponent("Resumes", isDirectory: true)
        self.lettersDirectory = documents.appendingPathComponent("CoverLetters", isDirectory: true)
        self.quarantineDirectory = root.appendingPathComponent("Quarantine", isDirectory: true)
        self.debounceNanoseconds = UInt64(max(0, debounceInterval) * 1_000_000_000)
        self.retryBaseNanoseconds = UInt64(max(0.01, retryInterval) * 1_000_000_000)

        self.encoder = CKJSON.encoder()
        self.decoder = CKJSON.decoder()

        createDirectories()
        loadAll()
    }

    // MARK: Lookup

    func resume(id: UUID) -> Resume? {
        return resumes.first(where: { $0.id == id })
    }

    func coverLetter(id: UUID) -> CoverLetter? {
        return coverLetters.first(where: { $0.id == id })
    }

    // MARK: Changes

    /// Inserts or replaces a resume, stamps `updatedAt` and schedules a save.
    func upsert(_ resume: Resume) {
        var copy = resume
        copy.updatedAt = Date()
        if let index = resumes.firstIndex(where: { $0.id == copy.id }) {
            resumes[index] = copy
        } else {
            resumes.append(copy)
        }
        resumes.sort(by: { $0.updatedAt > $1.updatedAt })
        dirtyResumeIDs.insert(copy.id)
        scheduleSave()
    }

    func upsert(_ letter: CoverLetter) {
        var copy = letter
        copy.updatedAt = Date()
        if let index = coverLetters.firstIndex(where: { $0.id == copy.id }) {
            coverLetters[index] = copy
        } else {
            coverLetters.append(copy)
        }
        coverLetters.sort(by: { $0.updatedAt > $1.updatedAt })
        dirtyLetterIDs.insert(copy.id)
        scheduleSave()
    }

    func delete(resumeID: UUID) {
        resumes.removeAll(where: { $0.id == resumeID })
        dirtyResumeIDs.remove(resumeID)
        removeFiles(for: fileURL(resumeID, in: resumesDirectory))
    }

    func delete(coverLetterID: UUID) {
        coverLetters.removeAll(where: { $0.id == coverLetterID })
        dirtyLetterIDs.remove(coverLetterID)
        removeFiles(for: fileURL(coverLetterID, in: lettersDirectory))
    }

    @discardableResult
    func duplicate(resumeID: UUID) -> Resume? {
        guard let original = resume(id: resumeID) else { return nil }
        var copy = original
        copy.id = UUID()
        copy.title = CKDocumentNaming.copyTitle(for: original.title, existingTitles: resumes.map { $0.title })
        copy.createdAt = Date()
        copy.isArchived = false
        copy.linkedCoverLetterID = nil
        upsert(copy)
        flushNow()
        return resume(id: copy.id)
    }

    @discardableResult
    func duplicate(coverLetterID: UUID) -> CoverLetter? {
        guard let original = coverLetter(id: coverLetterID) else { return nil }
        var copy = original
        copy.id = UUID()
        copy.title = CKDocumentNaming.copyTitle(for: original.title, existingTitles: coverLetters.map { $0.title })
        copy.createdAt = Date()
        upsert(copy)
        flushNow()
        return coverLetter(id: copy.id)
    }

    func setArchived(_ archived: Bool, resumeID: UUID) {
        guard var current = resume(id: resumeID) else { return }
        current.isArchived = archived
        upsert(current)
    }

    // MARK: Saving

    private func scheduleSave() {
        saveState = .saving
        saveTask?.cancel()
        let nanos: UInt64 = debounceNanoseconds
        saveTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: nanos)
            } catch {
                return
            }
            guard let self = self, !Task.isCancelled else { return }
            self.flushNow()
        }
    }

    /// Writes every pending change right now. Call when the app moves to the background.
    func flushNow() {
        saveTask?.cancel()
        saveTask = nil
        guard !dirtyResumeIDs.isEmpty || !dirtyLetterIDs.isEmpty else {
            if saveState == .saving {
                saveState = .saved(Date())
            }
            return
        }
        var firstError: String? = nil

        for id in Array(dirtyResumeIDs) {
            guard let value = resume(id: id) else {
                dirtyResumeIDs.remove(id)
                continue
            }
            do {
                try write(value, to: fileURL(id, in: resumesDirectory))
                dirtyResumeIDs.remove(id)
            } catch {
                if firstError == nil { firstError = error.localizedDescription }
            }
        }
        for id in Array(dirtyLetterIDs) {
            guard let value = coverLetter(id: id) else {
                dirtyLetterIDs.remove(id)
                continue
            }
            do {
                try write(value, to: fileURL(id, in: lettersDirectory))
                dirtyLetterIDs.remove(id)
            } catch {
                if firstError == nil { firstError = error.localizedDescription }
            }
        }

        if let message = firstError {
            saveState = .failed(message)
            scheduleRetryAfterFailure()
        } else {
            failedFlushStreak = 0
            saveState = .saved(Date())
        }
    }

    /// A write failed (for example the disk was full for a moment): the changes stay marked as unsaved, so try again
    /// after a growing wait instead of leaving them only in memory until the next edit.
    private func scheduleRetryAfterFailure() {
        failedFlushStreak += 1
        guard failedFlushStreak <= Self.maxAutomaticRetries else { return }
        let step: UInt64 = retryBaseNanoseconds << UInt64(min(failedFlushStreak - 1, 6))
        let nanos: UInt64 = min(step, 60 * 1_000_000_000)
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: nanos)
            } catch {
                return
            }
            guard let self = self, !Task.isCancelled else { return }
            self.flushNow()
        }
    }


    // MARK: Delete everything

    /// Removes every document, every `.bak` copy, quarantined files and newer-version files.
    /// Temporary share files, export grants, caches and navigation are reset by `CKLocalDataReset`.
    func deleteAllData() throws {
        saveTask?.cancel()
        saveTask = nil
        dirtyResumeIDs.removeAll()
        dirtyLetterIDs.removeAll()
        var firstError: Error? = nil
        for folder in [resumesDirectory, lettersDirectory, quarantineDirectory] {
            let contents: [URL] = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for url in contents {
                do {
                    try fileManager.removeItem(at: url)
                } catch {
                    if firstError == nil { firstError = error }
                }
            }
        }
        resumes = []
        coverLetters = []
        saveState = .idle
        newerVersionIDs = []
        newerVersionFileCount = 0
        refreshQuarantine()
        if let error = firstError {
            throw error
        }
    }

    // MARK: Backup and restore

    /// One JSON file holding every document, written to a temporary location for the share sheet.
    /// The caller removes it when the share sheet closes; stale ones are cleaned at launch.
    func makeBackupFile() throws -> URL {
        return try Self.writeBackup(snapshotForBackup())
    }

    /// Same file as `makeBackupFile`, but the encoding and the write run off the main thread, so a large library
    /// (up to 150 MB) never freezes the screen. The snapshot of the documents is taken on the main actor first.
    func makeBackupFileInBackground() async throws -> URL {
        let box = BackupSnapshot(payload: snapshotForBackup())
        return try await Task.detached(priority: .userInitiated) {
            try DocumentStore.writeBackup(box.payload)
        }.value
    }

    private func snapshotForBackup() -> CKBackupPayload {
        flushNow()
        return CKBackupPayload(schemaVersion: DocumentStore.currentSchemaVersion,
                               createdAt: Date(),
                               resumes: resumes,
                               coverLetters: coverLetters)
    }

    private struct BackupSnapshot: @unchecked Sendable {
        let payload: CKBackupPayload
    }

    /// Encodes and writes the backup file. Touches no store state, so it can run on any thread.
    nonisolated private static func writeBackup(_ payload: CKBackupPayload) throws -> URL {
        let data: Data = try CKJSON.encoder().encode(payload)
        let stamp = DateFormatter()
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.dateFormat = "yyyy-MM-dd"
        let name: String = "CareerKit-Backup-" + stamp.string(from: Date()) + ".json"
        let url: URL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: [.atomic])
        return url
    }

    /// Validates a backup file's contents and merges it into the library by id.
    /// Never overwrites a document that is newer on this device (see `CKBackupMerge`).
    func restoreBackup(from data: Data) throws -> CKRestoreSummary {
        let payload: CKBackupPayload = try CKBackupParser.parse(data, currentSchemaVersion: DocumentStore.currentSchemaVersion)
        return try restoreBackup(payload: payload)
    }

    /// Merges an already decoded backup. The app decodes the file off the main thread (`CKBackupParser.parse`) and
    /// calls this on the main actor for the merge only.
    func restoreBackup(payload: CKBackupPayload) throws -> CKRestoreSummary {
        flushNow()

        let incomingResumes: [Resume] = payload.resumes.map { CKSchemaMigration.migrate($0) }
        let incomingLetters: [CoverLetter] = payload.coverLetters.map { CKSchemaMigration.migrate($0) }
        let resumeMerge = CKBackupMerge.merge(incoming: incomingResumes,
                                              existing: resumes,
                                              reservedIDs: newerVersionIDs,
                                              currentSchemaVersion: DocumentStore.currentSchemaVersion)
        let letterMerge = CKBackupMerge.merge(incoming: incomingLetters,
                                              existing: coverLetters,
                                              reservedIDs: newerVersionIDs,
                                              currentSchemaVersion: DocumentStore.currentSchemaVersion)

        // Restored documents keep their own dates, so `upsert` (which stamps updatedAt) is not used.
        for resume in resumeMerge.inserts + resumeMerge.replacements {
            if let index = resumes.firstIndex(where: { $0.id == resume.id }) {
                resumes[index] = resume
            } else {
                resumes.append(resume)
            }
            dirtyResumeIDs.insert(resume.id)
        }
        for letter in letterMerge.inserts + letterMerge.replacements {
            if let index = coverLetters.firstIndex(where: { $0.id == letter.id }) {
                coverLetters[index] = letter
            } else {
                coverLetters.append(letter)
            }
            dirtyLetterIDs.insert(letter.id)
        }
        resumes.sort(by: { $0.updatedAt > $1.updatedAt })
        coverLetters.sort(by: { $0.updatedAt > $1.updatedAt })
        saveState = .saving
        flushNow()

        return CKRestoreSummary(restored: resumeMerge.restoredCount + letterMerge.restoredCount,
                                skipped: resumeMerge.skippedCount + letterMerge.skippedCount,
                                keptBoth: resumeMerge.keptBoth + letterMerge.keptBoth,
                                unreadable: payload.unreadableItems,
                                replacedExisting: resumeMerge.replacements.count + letterMerge.replacements.count)
    }

    // MARK: Quarantine

    /// Re-reads the Quarantine folder.
    func refreshQuarantine() {
        let contents: [URL] = (try? fileManager.contentsOfDirectory(at: quarantineDirectory, includingPropertiesForKeys: nil)) ?? []
        quarantinedFiles = contents
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
    }

    /// Permanently removes every quarantined file.
    func deleteQuarantinedFiles() throws {
        var firstError: Error? = nil
        for url in quarantinedFiles {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        refreshQuarantine()
        if let error = firstError {
            throw error
        }
    }

    // MARK: Files

    private func createDirectories() {
        for folder in [resumesDirectory, lettersDirectory, quarantineDirectory] {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
        }
    }

    private func fileURL(_ id: UUID, in folder: URL) -> URL {
        return folder.appendingPathComponent(id.uuidString + ".json", isDirectory: false)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        let data: Data = try encoder.encode(value)
        if fileManager.fileExists(atPath: url.path) {
            let backup: URL = url.appendingPathExtension("bak")
            try? fileManager.removeItem(at: backup)
            try? fileManager.copyItem(at: url, to: backup)
        }
        try data.write(to: url, options: [.atomic])
    }

    private func removeFiles(for url: URL) {
        try? fileManager.removeItem(at: url)
        try? fileManager.removeItem(at: url.appendingPathExtension("bak"))
    }

    // MARK: Loading

    private func loadAll() {
        var newerIDs: Set<UUID> = []
        var newerCount: Int = 0

        let loadedResumes: [Resume] = loadDocuments(in: resumesDirectory, as: Resume.self, newerIDs: &newerIDs, newerCount: &newerCount)
        resumes = loadedResumes.map { CKSchemaMigration.migrate($0) }.sorted(by: { $0.updatedAt > $1.updatedAt })
        let loadedLetters: [CoverLetter] = loadDocuments(in: lettersDirectory, as: CoverLetter.self, newerIDs: &newerIDs, newerCount: &newerCount)
        coverLetters = loadedLetters.map { CKSchemaMigration.migrate($0) }.sorted(by: { $0.updatedAt > $1.updatedAt })

        newerVersionIDs = newerIDs
        newerVersionFileCount = newerCount
        refreshQuarantine()
    }

    private enum FileRead<T> {
        case document(T)
        case newerVersion
        case unreadable
    }

    private func loadDocuments<T: Decodable & CKPersistedDocument>(in folder: URL,
                                                                     as type: T.Type,
                                                                     newerIDs: inout Set<UUID>,
                                                                     newerCount: inout Int) -> [T] {
        let contents: [URL] = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        var out: [T] = []
        for url in contents where url.pathExtension.lowercased() == "json" {
            let fileID: UUID? = UUID(uuidString: url.deletingPathExtension().lastPathComponent)
            switch readFile(url, as: type) {
            case .document(let value):
                out.append(withFileID(value, fileID))
                continue
            case .newerVersion:
                // Made by a newer CareerKit: leave the file and its .bak exactly as they are.
                newerCount += 1
                if let fileID = fileID { newerIDs.insert(fileID) }
                continue
            case .unreadable:
                break
            }
            // The main file is unreadable. Move it aside, then try the previous version.
            let backup: URL = url.appendingPathExtension("bak")
            quarantine(url)
            switch readFile(backup, as: type) {
            case .document(let recovered):
                try? fileManager.copyItem(at: backup, to: url)
                out.append(withFileID(recovered, fileID))
            case .newerVersion:
                // Unusual, but never touch a newer file.
                newerCount += 1
                if let fileID = fileID { newerIDs.insert(fileID) }
            case .unreadable:
                if fileManager.fileExists(atPath: backup.path) {
                    quarantine(backup)
                }
            }
        }
        return out
    }

    private func readFile<T: Decodable>(_ url: URL, as type: T.Type) -> FileRead<T> {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return .unreadable }
        if let version = CKSchemaPeek.version(of: data), CKSchemaMigration.isFromNewerApp(version, current: DocumentStore.currentSchemaVersion) {
            return .newerVersion
        }
        guard let value = try? decoder.decode(type, from: data) else { return .unreadable }
        return .document(value)
    }

    /// Files are named after their id. If the id inside is missing or different, the file name wins,
    /// so the next save replaces this file instead of creating a second one.
    private func withFileID<T: CKPersistedDocument>(_ value: T, _ fileID: UUID?) -> T {
        guard let fileID = fileID, value.id != fileID else { return value }
        var copy = value
        copy.id = fileID
        return copy
    }

    /// Moves a file that cannot be read into Quarantine so it is never loaded again and nothing is lost.
    /// If the move fails the file stays where it is; it is never deleted here.
    private func quarantine(_ url: URL) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.createDirectory(at: quarantineDirectory, withIntermediateDirectories: true, attributes: nil)
        let stamp: Int = Int(Date().timeIntervalSince1970)
        let name: String = url.lastPathComponent + "." + String(stamp) + "." + String(UUID().uuidString.prefix(6)) + ".corrupt"
        let destination: URL = quarantineDirectory.appendingPathComponent(name)
        try? fileManager.moveItem(at: url, to: destination)
    }
}
