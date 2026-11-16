import Foundation

// MARK: - Backup file

/// The single JSON file written by "Export backup" and read by "Restore from backup".
/// Keys: format, schemaVersion, createdAt, resumes, coverLetters. Do not rename them.
struct CKBackupPayload: Codable {
    static let formatName = "careerkit-backup"

    var format: String
    var schemaVersion: Int
    var createdAt: Date
    var resumes: [Resume]
    var coverLetters: [CoverLetter]
    /// Items in the file that could not be read at all. Not written to disk.
    var unreadableItems: Int = 0

    init(format: String = CKBackupPayload.formatName,
         schemaVersion: Int,
         createdAt: Date,
         resumes: [Resume],
         coverLetters: [CoverLetter]) {
        self.format = format
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.resumes = resumes
        self.coverLetters = coverLetters
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CKCodingKey.self)
        format = c.ck("format", "")
        schemaVersion = c.ck("schemaVersion", 1)
        createdAt = c.ck("createdAt", Date(timeIntervalSince1970: 0))
        let resumeResult = c.ckLossyArray("resumes", of: Resume.self)
        let letterResult = c.ckLossyArray("coverLetters", of: CoverLetter.self)
        resumes = resumeResult.values
        coverLetters = letterResult.values
        unreadableItems = resumeResult.failures + letterResult.failures
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CKCodingKey.self)
        try c.encode(format, forKey: CKCodingKey("format"))
        try c.encode(schemaVersion, forKey: CKCodingKey("schemaVersion"))
        try c.encode(createdAt, forKey: CKCodingKey("createdAt"))
        try c.encode(resumes, forKey: CKCodingKey("resumes"))
        try c.encode(coverLetters, forKey: CKCodingKey("coverLetters"))
    }
}

enum CKBackupError: Error, Equatable {
    case empty
    case tooLarge
    case unreadable
    case notABackup
    case newerVersion
    case cannotOpenFile

    /// Plain message for an alert.
    var message: String {
        switch self {
        case .empty, .unreadable:
            return String(localized: "This file could not be read as a CareerKit backup.")
        case .tooLarge:
            return String(localized: "This file is too large to be a CareerKit backup.")
        case .notABackup:
            return String(localized: "This file is not a CareerKit backup. Choose a file whose name starts with CareerKit-Backup.")
        case .newerVersion:
            return String(localized: "This backup was made with a newer version of CareerKit. Update the app, then try again.")
        case .cannotOpenFile:
            return String(localized: "CareerKit could not open this file. Save it to the Files app first, then try again.")
        }
    }
}

enum CKBackupParser {
    /// Far above any real backup (photos are stored downscaled), low enough to refuse obvious mistakes.
    static let maxBytes: Int = 150 * 1024 * 1024

    /// Checks size, format and version, then decodes tolerantly. Pure.
    static func parse(_ data: Data, currentSchemaVersion: Int = CKSchema.current) throws -> CKBackupPayload {
        guard !data.isEmpty else { throw CKBackupError.empty }
        guard data.count <= maxBytes else { throw CKBackupError.tooLarge }
        let payload: CKBackupPayload
        do {
            payload = try CKJSON.decoder().decode(CKBackupPayload.self, from: data)
        } catch {
            throw CKBackupError.unreadable
        }
        guard payload.format == CKBackupPayload.formatName else { throw CKBackupError.notABackup }
        guard !CKSchemaMigration.isFromNewerApp(payload.schemaVersion, current: currentSchemaVersion) else {
            throw CKBackupError.newerVersion
        }
        return payload
    }

    /// Reads a file picked in the document browser, with security-scoped access and a size check first.
    static func readFile(at url: URL) throws -> Data {
        let scoped: Bool = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }
        if let values = try? url.resourceValues(forKeys: [.fileSizeKey]), let size = values.fileSize, size > maxBytes {
            throw CKBackupError.tooLarge
        }
        do {
            // Not memory mapped: access to the file ends when this function returns.
            return try Data(contentsOf: url)
        } catch {
            throw CKBackupError.cannotOpenFile
        }
    }
}

// MARK: - Merge

/// What to write for one document type after comparing a backup with the device.
struct CKMergeResult<Doc: CKPersistedDocument> {
    /// Documents that are new to this device, including copies kept beside a newer local version.
    var inserts: [Doc] = []
    /// Backup versions that are newer than the device version with the same id.
    var replacements: [Doc] = []
    /// Of `inserts`, how many are copies made because the device had newer or different changes.
    var keptBoth: Int = 0
    /// Already on this device with the same content, or repeated inside the backup.
    var skippedSame: Int = 0
    /// Written by a newer CareerKit; left out so nothing is downgraded.
    var skippedNewerSchema: Int = 0

    var restoredCount: Int { inserts.count + replacements.count }
    var skippedCount: Int { skippedSame + skippedNewerSchema }
}

enum CKBackupMerge {
    /// Merges by id. Pure.
    /// - Same id, same content: skipped.
    /// - Same id, backup newer (whole seconds): the backup version replaces the device version.
    /// - Same id, device newer or same time with different content: both are kept. The backup copy gets a
    ///   new id and the title "<title> (restored)", so a newer local document is never overwritten.
    /// - `reservedIDs` (files from a newer app version) are never reused: the backup copy gets a new id.
    static func merge<Doc: CKPersistedDocument>(
        incoming: [Doc],
        existing: [Doc],
        reservedIDs: Set<UUID> = [],
        currentSchemaVersion: Int = CKSchema.current,
        makeID: () -> UUID = { UUID() }
    ) -> CKMergeResult<Doc> {
        var result = CKMergeResult<Doc>()
        var existingByID: [UUID: Doc] = [:]
        for doc in existing where existingByID[doc.id] == nil {
            existingByID[doc.id] = doc
        }
        var titles: Set<String> = Set(existing.map { $0.title })
        var seen: Set<UUID> = []

        // Newest first, so a backup that repeats an id keeps its newest version.
        let ordered: [Doc] = incoming.sorted { $0.updatedAt > $1.updatedAt }
        for doc in ordered {
            if CKSchemaMigration.isFromNewerApp(doc.schemaVersion, current: currentSchemaVersion) {
                result.skippedNewerSchema += 1
                continue
            }
            if seen.contains(doc.id) {
                result.skippedSame += 1
                continue
            }
            seen.insert(doc.id)

            guard !reservedIDs.contains(doc.id), let local = existingByID[doc.id] else {
                if reservedIDs.contains(doc.id) {
                    result.inserts.append(keptCopy(of: doc, titles: &titles, makeID: makeID))
                    result.keptBoth += 1
                } else {
                    result.inserts.append(doc)
                    titles.insert(doc.title)
                }
                continue
            }

            if local.comparableContent() == doc.comparableContent() {
                result.skippedSame += 1
                continue
            }
            if doc.updatedAt.ckWholeSeconds > local.updatedAt.ckWholeSeconds {
                result.replacements.append(doc)
                titles.insert(doc.title)
                continue
            }
            result.inserts.append(keptCopy(of: doc, titles: &titles, makeID: makeID))
            result.keptBoth += 1
        }
        return result
    }

    private static func keptCopy<Doc: CKPersistedDocument>(of doc: Doc, titles: inout Set<String>, makeID: () -> UUID) -> Doc {
        var copy = doc
        copy.id = makeID()
        copy.title = CKDocumentNaming.restoredTitle(for: doc.title, existingTitles: titles)
        titles.insert(copy.title)
        return copy
    }
}

/// Totals shown after a restore.
struct CKRestoreSummary: Equatable {
    var restored: Int = 0
    var skipped: Int = 0
    var keptBoth: Int = 0
    var unreadable: Int = 0
    var replacedExisting: Int = 0

    /// "Restored 3 documents, skipped 1." plus a note when copies were kept or items could not be read.
    var message: String {
        var parts: [String] = []
        parts.append(String(localized: "Restored \(CKDocumentNaming.documentCount(restored)), skipped \(skipped)."))
        if keptBoth > 0 {
            let copies: String = keptBoth == 1
                ? String(localized: "1 was added as a separate copy marked restored, because this device has newer changes.")
                : String(localized: "\(keptBoth) were added as separate copies marked restored, because this device has newer changes.")
            parts.append(copies)
        }
        if unreadable > 0 {
            parts.append(String(localized: "\(CKDocumentNaming.documentCount(unreadable)) in the file could not be read."))
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Names

enum CKDocumentNaming {
    private static let copyWord = " copy"
    private static let restoredWord = " (restored"

    /// "1 document", "3 documents".
    static func documentCount(_ count: Int) -> String {
        return count == 1 ? String(localized: "1 document") : String(localized: "\(count) documents")
    }

    /// "CV" -> "CV copy"; "CV copy" -> "CV copy 2"; "CV copy 2" -> "CV copy 3" (the first free number).
    static func copyTitle(for title: String, existingTitles: [String]) -> String {
        let taken: Set<String> = Set(existingTitles)
        let base: String = baseTitle(removingCopySuffixFrom: title)
        let first: String = base + copyWord
        if !taken.contains(first) { return first }
        var number: Int = 2
        while number < 10_000 && taken.contains(base + copyWord + " " + String(number)) {
            number += 1
        }
        return base + copyWord + " " + String(number)
    }

    /// Strips any trailing " copy" or " copy N" (repeated ones too) so copies do not pile up words.
    static func baseTitle(removingCopySuffixFrom title: String) -> String {
        var current: String = title.trimmingCharacters(in: .whitespaces)
        var changed: Bool = true
        while changed {
            changed = false
            if current.hasSuffix(copyWord) {
                current = String(current.dropLast(copyWord.count))
                changed = true
            } else if let range = current.range(of: copyWord + " ", options: .backwards) {
                let tail: Substring = current[range.upperBound...]
                if !tail.isEmpty && tail.allSatisfy({ $0.isASCII && $0.isNumber }) {
                    current = String(current[..<range.lowerBound])
                    changed = true
                }
            }
        }
        let trimmed: String = current.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? String(localized: "Untitled") : trimmed
    }

    /// "CV" -> "CV (restored)", then "CV (restored 2)" when that name is taken.
    static func restoredTitle(for title: String, existingTitles: Set<String>) -> String {
        let trimmed: String = title.trimmingCharacters(in: .whitespaces)
        let base: String = trimmed.isEmpty ? String(localized: "Untitled") : trimmed
        let first: String = base + restoredWord + ")"
        if !existingTitles.contains(first) { return first }
        var number: Int = 2
        while number < 10_000 && existingTitles.contains(base + restoredWord + " " + String(number) + ")") {
            number += 1
        }
        return base + restoredWord + " " + String(number) + ")"
    }
}
