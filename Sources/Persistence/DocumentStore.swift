import Foundation
import Combine

/// Keeps resumes and cover letters on the device as one JSON file per document.
///
/// Layout inside the root folder (Application Support/CareerKit unless a directory is injected):
///   Documents/Resumes/<uuid>.json      (plus <uuid>.json.bak, the previous version)
///   Documents/CoverLetters/<uuid>.json
///   Quarantine/                        files that could not be read
@MainActor
final class DocumentStore: ObservableObject {
    enum SaveState: Equatable {
        case idle
        case saving
        case saved(Date)
        case failed(String)
    }

    /// Version written into new documents. Older versions pass through `migrated(_:)` when loaded.
    static let currentSchemaVersion: Int = 1

    @Published private(set) var resumes: [Resume] = []
    @Published private(set) var coverLetters: [CoverLetter] = []
    @Published private(set) var saveState: SaveState = .idle

    let rootDirectory: URL
    let resumesDirectory: URL
    let lettersDirectory: URL
    let quarantineDirectory: URL

    private let fileManager: FileManager = FileManager.default
    private let debounceNanoseconds: UInt64
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var dirtyResumeIDs: Set<UUID> = []
    private var dirtyLetterIDs: Set<UUID> = []
    private var saveTask: Task<Void, Never>?

    /// - Parameters:
    ///   - directory: root folder. nil uses Application Support/CareerKit. Tests pass a temporary folder.
    ///   - debounceInterval: delay before an edit is written to disk.
    init(directory: URL? = nil, debounceInterval: TimeInterval = 0.6) {
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

        let newEncoder = JSONEncoder()
        newEncoder.dateEncodingStrategy = .iso8601
        newEncoder.outputFormatting = [.sortedKeys]
        self.encoder = newEncoder
        let newDecoder = JSONDecoder()
        newDecoder.dateDecodingStrategy = .iso8601
        self.decoder = newDecoder

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
        copy.title = original.title + " copy"
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
        copy.title = original.title + " copy"
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
        } else {
            saveState = .saved(Date())
        }
    }

    // MARK: Delete everything and backup

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
        if let error = firstError {
            throw error
        }
    }

    private struct BackupPayload: Codable {
        var format: String
        var schemaVersion: Int
        var createdAt: Date
        var resumes: [Resume]
        var coverLetters: [CoverLetter]
    }

    /// One JSON file holding every document, written to a temporary location for the share sheet.
    func makeBackupFile() throws -> URL {
        flushNow()
        let payload = BackupPayload(format: "careerkit-backup",
                                    schemaVersion: DocumentStore.currentSchemaVersion,
                                    createdAt: Date(),
                                    resumes: resumes,
                                    coverLetters: coverLetters)
        let data: Data = try encoder.encode(payload)
        let stamp = DateFormatter()
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.dateFormat = "yyyy-MM-dd"
        let name: String = "CareerKit-Backup-" + stamp.string(from: Date()) + ".json"
        let url: URL = fileManager.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: [.atomic])
        return url
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
        let loadedResumes: [Resume] = loadDocuments(in: resumesDirectory, as: Resume.self)
        resumes = loadedResumes.map { migrated($0) }.sorted(by: { $0.updatedAt > $1.updatedAt })
        let loadedLetters: [CoverLetter] = loadDocuments(in: lettersDirectory, as: CoverLetter.self)
        coverLetters = loadedLetters.map { migrated($0) }.sorted(by: { $0.updatedAt > $1.updatedAt })
    }

    private func loadDocuments<T: Decodable>(in folder: URL, as type: T.Type) -> [T] {
        let contents: [URL] = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        var out: [T] = []
        for url in contents where url.pathExtension.lowercased() == "json" {
            if let value = decodeFile(url, as: type) {
                out.append(value)
                continue
            }
            // The main file is unreadable. Move it aside, then try the previous version.
            let backup: URL = url.appendingPathExtension("bak")
            quarantine(url)
            if let recovered = decodeFile(backup, as: type) {
                try? fileManager.copyItem(at: backup, to: url)
                out.append(recovered)
            } else if fileManager.fileExists(atPath: backup.path) {
                quarantine(backup)
            }
        }
        return out
    }

    private func decodeFile<T: Decodable>(_ url: URL, as type: T.Type) -> T? {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        return try? decoder.decode(type, from: data)
    }

    /// Moves a file that cannot be read into Quarantine so it is never loaded again and nothing is lost.
    private func quarantine(_ url: URL) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.createDirectory(at: quarantineDirectory, withIntermediateDirectories: true, attributes: nil)
        let stamp: Int = Int(Date().timeIntervalSince1970)
        let name: String = url.lastPathComponent + "." + String(stamp) + "." + String(UUID().uuidString.prefix(6)) + ".corrupt"
        let destination: URL = quarantineDirectory.appendingPathComponent(name)
        do {
            try fileManager.moveItem(at: url, to: destination)
        } catch {
            try? fileManager.removeItem(at: url)
        }
    }

    // MARK: Migration

    /// Upgrade hook. Version 1 is the first schema, so nothing needs to change yet.
    private func migrated(_ resume: Resume) -> Resume {
        var copy = resume
        if copy.schemaVersion < DocumentStore.currentSchemaVersion {
            copy.schemaVersion = DocumentStore.currentSchemaVersion
        }
        return copy
    }

    private func migrated(_ letter: CoverLetter) -> CoverLetter {
        var copy = letter
        if copy.schemaVersion < DocumentStore.currentSchemaVersion {
            copy.schemaVersion = DocumentStore.currentSchemaVersion
        }
        return copy
    }
}
