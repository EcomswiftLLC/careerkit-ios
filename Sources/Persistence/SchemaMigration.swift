import Foundation

/// The schema version this build writes. Not actor isolated, so pure code and background tasks can read it.
/// `DocumentStore.currentSchemaVersion` returns the same value.
enum CKSchema {
    static let current: Int = 1
}

/// JSON settings shared by document files and backups. Dates are ISO 8601 (whole seconds).
enum CKJSON {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

/// Reads only `schemaVersion` from a document or backup, without decoding the rest.
struct CKSchemaPeek: Decodable {
    let schemaVersion: Int?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CKCodingKey.self)
        schemaVersion = c.ckOptional("schemaVersion", as: Int.self)
    }

    /// nil when the data is not a JSON object. A document without the key counts as version 1.
    static func version(of data: Data) -> Int? {
        guard let peek = try? JSONDecoder().decode(CKSchemaPeek.self, from: data) else { return nil }
        return peek.schemaVersion ?? 1
    }
}

/// Upgrades documents saved by older versions. Pure, so every step can be unit tested.
///
/// To add version 2: bump `CKSchema.current`, then add a `case 1:` step below that changes the copy.
/// Steps run in order from the saved version up to the current one. Never remove a step.
enum CKSchemaMigration {
    /// True when the document was written by a newer CareerKit. Such files are left untouched.
    static func isFromNewerApp(_ version: Int, current: Int = CKSchema.current) -> Bool {
        return version > current
    }

    static func migrate(_ resume: Resume, to current: Int = CKSchema.current) -> Resume {
        var copy = resume
        guard copy.schemaVersion < current else { return copy }
        var version: Int = max(0, copy.schemaVersion)
        while version < current {
            switch version {
            case 0:
                // Files written before schemaVersion existed already have the version 1 shape.
                break
            default:
                break
            }
            version += 1
        }
        copy.schemaVersion = current
        return copy
    }

    static func migrate(_ letter: CoverLetter, to current: Int = CKSchema.current) -> CoverLetter {
        var copy = letter
        guard copy.schemaVersion < current else { return copy }
        var version: Int = max(0, copy.schemaVersion)
        while version < current {
            switch version {
            case 0:
                break
            default:
                break
            }
            version += 1
        }
        copy.schemaVersion = current
        return copy
    }
}
