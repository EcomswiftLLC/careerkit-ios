import Foundation

// Tolerant decoding for every model that is saved to disk or written into a backup.
//
// Rules:
// - Every field is optional on the way in. A missing key, a null, or a value of the wrong type
//   falls back to the same default a brand new document would get.
// - Unknown keys are ignored. Unknown enum values fall back to a safe case (see each type).
// - Arrays are decoded item by item, so one unreadable item never loses its neighbours.
// - Encoding is unchanged: these types keep the compiler-generated `encode(to:)` and `CodingKeys`,
//   so files written by this version are byte-for-byte the same shape as before.
//
// The decoders live in extensions so the memberwise initialisers stay available.

/// String coding key used by the tolerant decoders. Key names must match the property names.
struct CKCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ string: String) {
        self.stringValue = string
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

/// Decodes any JSON value and throws nothing. Used to step over an unreadable array item.
struct CKSkippedValue: Decodable {
    init(from decoder: Decoder) throws {}
}

extension KeyedDecodingContainer where K == CKCodingKey {
    /// The value for `key`, or `fallback` when it is missing, null or the wrong type.
    func ck<T: Decodable>(_ key: String, _ fallback: T) -> T {
        if let value = try? decodeIfPresent(T.self, forKey: CKCodingKey(key)) {
            return value
        }
        return fallback
    }

    /// The value for `key`, or nil when it is missing, null or the wrong type.
    func ckOptional<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        guard let value = try? decodeIfPresent(type, forKey: CKCodingKey(key)) else { return nil }
        return value
    }

    /// Decodes an array item by item. Items that cannot be read are skipped and counted.
    func ckLossyArray<T: Decodable>(_ key: String, of type: T.Type) -> (values: [T], failures: Int) {
        guard var items = try? nestedUnkeyedContainer(forKey: CKCodingKey(key)) else {
            return ([], 0)
        }
        var values: [T] = []
        var failures: Int = 0
        while !items.isAtEnd {
            let before: Int = items.currentIndex
            if let value = try? items.decode(type) {
                values.append(value)
            } else {
                failures += 1
                let wasNull: Bool = (try? items.decodeNil()) ?? false
                if !wasNull {
                    _ = try? items.decode(CKSkippedValue.self)
                }
            }
            // Never loop forever on a decoder that refuses to move on.
            if items.currentIndex == before { break }
        }
        return (values, failures)
    }

    /// Same as `ckLossyArray` without the failure count.
    func ckArray<T: Decodable>(_ key: String, of type: T.Type) -> [T] {
        return ckLossyArray(key, of: type).values
    }
}

// MARK: - Enums with a safe fallback

extension SectionKind {
    /// A section kind added by a newer version opens as a custom section, keeping its title and content.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw: String = (try? container.decode(String.self)) ?? ""
        self = SectionKind(rawValue: raw) ?? .custom
    }
}

// `PageSize`, `ResumeDateFormat`, `SidebarPosition` and `PhotoShape` keep their raw-value decoding.
// Every place that reads them uses `ck(_:_:)` or `ckOptional`, so an unknown value becomes the default.

// MARK: - Dates

extension MonthYear {
    /// `year` is required (a date without a year is meaningless, so the containing field becomes nil).
    /// A `month` of the wrong type is dropped and the date becomes year-only. Out-of-range months are kept
    /// as saved; `formatted` already shows those as year-only.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CKCodingKey.self)
        guard let year = c.ckOptional("year", as: Int.self) else {
            throw DecodingError.keyNotFound(CKCodingKey("year"),
                                            DecodingError.Context(codingPath: decoder.codingPath,
                                                                  debugDescription: "MonthYear needs a year"))
        }
        self.year = year
        self.month = c.ckOptional("month", as: Int.self)
    }
}

// MARK: - Resume parts

extension PersonalInfo {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CKCodingKey.self)
        fullName = c.ck("fullName", "")
        professionalTitle = c.ck("professionalTitle", "")
        email = c.ck("email", "")
        phone = c.ck("phone", "")
        city = c.ck("city", "")
        country = c.ck("country", "")
        linkedIn = c.ck("linkedIn", "")
        portfolio = c.ck("portfolio", "")
        website = c.ck("website", "")
        photoData = c.ckOptional("photoData", as: Data.self)
    }
}

extension ResumeEntry {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CKCodingKey.self)
        id = c.ck("id", UUID())
        heading = c.ck("heading", "")
        subheading = c.ck("subheading", "")
        location = c.ck("location", "")
        start = c.ckOptional("start", as: MonthYear.self)
        end = c.ckOptional("end", as: MonthYear.self)
        isCurrent = c.ck("isCurrent", false)
        detail = c.ck("detail", "")
        bullets = c.ckArray("bullets", of: String.self)
        extra = c.ck("extra", "")
    }
}

extension SkillGroup {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CKCodingKey.self)
        id = c.ck("id", UUID())
        name = c.ck("name", "")
        items = c.ckArray("items", of: String.self)
    }
}

extension ResumeSection {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CKCodingKey.self)
        let kind: SectionKind = c.ck("kind", SectionKind.custom)
        let title: String = c.ck("title", kind.defaultTitle)
        self.init(kind: kind, title: title)
        id = c.ck("id", UUID())
        isVisible = c.ck("isVisible", true)
        text = c.ck("text", "")
        entries = c.ckArray("entries", of: ResumeEntry.self)
        skillGroups = c.ckArray("skillGroups", of: SkillGroup.self)
    }
}

// MARK: - Documents

extension Resume {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CKCodingKey.self)
        let decodedTitle: String = c.ck("title", String(localized: "Untitled resume"))
        let decodedTemplate: String = c.ck("templateID", TemplateLibrary.defaultTemplateID)
        let decodedSections: [ResumeSection] = c.ckArray("sections", of: ResumeSection.self)
        self.init(title: decodedTitle, templateID: decodedTemplate, sections: decodedSections)

        id = c.ck("id", UUID())
        let created: Date = c.ck("createdAt", Date())
        createdAt = created
        updatedAt = c.ck("updatedAt", created)
        isArchived = c.ck("isArchived", false)
        pageSize = c.ck("pageSize", PageSize.a4)
        personal = c.ck("personal", PersonalInfo())
        style = c.ck("style", StyleOverrides())
        linkedCoverLetterID = c.ckOptional("linkedCoverLetterID", as: UUID.self)
        isBlank = c.ck("isBlank", false)
        schemaVersion = c.ck("schemaVersion", 1)
    }
}

extension CoverLetter {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CKCodingKey.self)
        let decodedTitle: String = c.ck("title", String(localized: "Untitled cover letter"))
        let fallbackTemplate: String = CoverLetterTemplateLibrary.all.first?.id ?? ""
        let decodedTemplate: String = c.ck("templateID", fallbackTemplate)
        self.init(title: decodedTitle, templateID: decodedTemplate)

        id = c.ck("id", UUID())
        let created: Date = c.ck("createdAt", Date())
        createdAt = created
        updatedAt = c.ck("updatedAt", created)
        pageSize = c.ck("pageSize", PageSize.a4)
        linkedResumeID = c.ckOptional("linkedResumeID", as: UUID.self)

        senderName = c.ck("senderName", "")
        senderTitle = c.ck("senderTitle", "")
        senderEmail = c.ck("senderEmail", "")
        senderPhone = c.ck("senderPhone", "")
        senderLocation = c.ck("senderLocation", "")

        recipientName = c.ck("recipientName", "")
        recipientTitle = c.ck("recipientTitle", "")
        companyName = c.ck("companyName", "")
        companyAddress = c.ck("companyAddress", "")
        jobTitle = c.ck("jobTitle", "")
        jobDescription = c.ck("jobDescription", "")

        date = c.ck("date", created)
        greeting = c.ck("greeting", "")
        introduction = c.ck("introduction", "")
        experienceParagraph = c.ck("experienceParagraph", "")
        interestParagraph = c.ck("interestParagraph", "")
        closing = c.ck("closing", "")
        signOff = c.ck("signOff", "Sincerely,")

        style = c.ck("style", StyleOverrides())
        schemaVersion = c.ck("schemaVersion", 1)
    }
}

// MARK: - Shared shape used by migration, restore and naming

/// What persistence needs to know about a resume or a cover letter.
protocol CKPersistedDocument: Equatable {
    var id: UUID { get set }
    var title: String { get set }
    var createdAt: Date { get set }
    var updatedAt: Date { get set }
    var schemaVersion: Int { get set }
    /// A copy with every date reduced to whole seconds and the timestamps cleared, so two copies of the
    /// same content compare equal even after one of them went through JSON (which keeps whole seconds).
    func comparableContent() -> Self
}

extension Date {
    /// Whole seconds since 1970. JSON backups keep this precision.
    var ckWholeSeconds: Int64 {
        Int64(floor(timeIntervalSince1970))
    }
}

extension Resume: CKPersistedDocument {
    func comparableContent() -> Resume {
        var copy = self
        copy.createdAt = Date(timeIntervalSince1970: 0)
        copy.updatedAt = Date(timeIntervalSince1970: 0)
        return copy
    }
}

extension CoverLetter: CKPersistedDocument {
    func comparableContent() -> CoverLetter {
        var copy = self
        copy.createdAt = Date(timeIntervalSince1970: 0)
        copy.updatedAt = Date(timeIntervalSince1970: 0)
        copy.date = Date(timeIntervalSince1970: TimeInterval(date.ckWholeSeconds))
        return copy
    }
}
