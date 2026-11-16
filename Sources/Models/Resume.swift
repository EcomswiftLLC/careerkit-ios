import Foundation

// MARK: - Page size

enum PageSize: String, Codable, CaseIterable, Identifiable {
    case a4
    case usLetter

    var id: String { rawValue }

    /// Size in PDF points (1 pt = 1/72 inch).
    var size: CGSize {
        switch self {
        case .a4: return CGSize(width: 595.28, height: 841.89)
        case .usLetter: return CGSize(width: 612, height: 792)
        }
    }

    var displayName: String {
        switch self {
        case .a4: return "A4"
        case .usLetter: return "US Letter"
        }
    }
}

// MARK: - Dates

/// Month-precision date. `month == nil` means year only.
struct MonthYear: Codable, Equatable, Hashable {
    var year: Int
    var month: Int?

    func formatted(locale: Locale = .current) -> String {
        guard let month, (1...12).contains(month) else { return String(year) }
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let date = Calendar(identifier: .gregorian).date(from: comps) else { return String(year) }
        let f = DateFormatter()
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate("MMM yyyy")
        return f.string(from: date)
    }
}

// MARK: - Personal info

struct PersonalInfo: Codable, Equatable {
    var fullName = ""
    var professionalTitle = ""
    var email = ""
    var phone = ""
    var city = ""
    var country = ""
    var linkedIn = ""
    var portfolio = ""
    var website = ""
    /// Optional JPEG data, already downscaled by the editor (max 600 px).
    var photoData: Data?

    var locationLine: String {
        [city, country].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

// MARK: - Sections

enum SectionKind: String, Codable, CaseIterable, Identifiable {
    case summary
    case experience
    case education
    case skills
    case certifications
    case projects
    case awards
    case languages
    case publications
    case volunteer
    case internships
    case memberships
    case references
    case courses
    case interests
    case custom

    var id: String { rawValue }

    var defaultTitle: String {
        switch self {
        case .summary: return "Professional Summary"
        case .experience: return "Work Experience"
        case .education: return "Education"
        case .skills: return "Skills"
        case .certifications: return "Certifications"
        case .projects: return "Projects"
        case .awards: return "Awards"
        case .languages: return "Languages"
        case .publications: return "Publications"
        case .volunteer: return "Volunteer Experience"
        case .internships: return "Internships"
        case .memberships: return "Professional Memberships"
        case .references: return "References"
        case .courses: return "Courses"
        case .interests: return "Interests"
        case .custom: return "Custom Section"
        }
    }

    /// Which editor the section uses.
    enum Shape { case text, entries, skillGroups }

    var shape: Shape {
        switch self {
        case .summary, .interests: return .text
        case .skills, .languages: return .skillGroups
        default: return .entries
        }
    }

    var systemImage: String {
        switch self {
        case .summary: return "text.alignleft"
        case .experience: return "briefcase"
        case .education: return "graduationcap"
        case .skills: return "square.grid.2x2"
        case .certifications: return "checkmark.seal"
        case .projects: return "hammer"
        case .awards: return "rosette"
        case .languages: return "character.bubble"
        case .publications: return "books.vertical"
        case .volunteer: return "heart"
        case .internships: return "person.badge.clock"
        case .memberships: return "person.2"
        case .references: return "quote.bubble"
        case .courses: return "book"
        case .interests: return "sparkles"
        case .custom: return "plus.square.dashed"
        }
    }
}

/// One item in an entries-type section (job, degree, project, award, ...).
struct ResumeEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    /// Job title, degree, certification name, project name, award name...
    var heading = ""
    /// Company, institution, issuer, publisher...
    var subheading = ""
    var location = ""
    var start: MonthYear?
    var end: MonthYear?
    var isCurrent = false
    /// Free text paragraph (optional).
    var detail = ""
    /// Achievement / responsibility bullets, one per string.
    var bullets: [String] = []
    /// Optional extra line such as GPA or a URL.
    var extra = ""

    var isEmpty: Bool {
        heading.isEmpty && subheading.isEmpty && detail.isEmpty && bullets.allSatisfy { $0.isEmpty }
    }

    /// "Jan 2020 – Present", "2018 – 2022", or "" when no dates.
    func dateRange(locale: Locale = .current) -> String {
        let startText = start?.formatted(locale: locale) ?? ""
        let endText = isCurrent ? "Present" : (end?.formatted(locale: locale) ?? "")
        switch (startText.isEmpty, endText.isEmpty) {
        case (true, true): return ""
        case (false, true): return startText
        case (true, false): return endText
        case (false, false): return "\(startText) – \(endText)"
        }
    }
}

struct SkillGroup: Codable, Identifiable, Equatable {
    var id = UUID()
    /// "Technical", "Languages", "Tools"... may be empty for a flat list.
    var name = ""
    var items: [String] = []
}

struct ResumeSection: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: SectionKind
    var title: String
    var isVisible = true
    /// Used by .text sections (summary, interests, custom text).
    var text = ""
    var entries: [ResumeEntry] = []
    var skillGroups: [SkillGroup] = []

    init(kind: SectionKind, title: String? = nil) {
        self.kind = kind
        self.title = title ?? kind.defaultTitle
    }

    var hasContent: Bool {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if entries.contains(where: { !$0.isEmpty }) { return true }
        if skillGroups.contains(where: { !$0.items.isEmpty }) { return true }
        return false
    }
}

// MARK: - Style overrides chosen by the user

struct StyleOverrides: Codable, Equatable {
    /// "#RRGGBB". nil keeps the template accent.
    var accentHex: String?
    /// nil keeps the template fonts.
    var bodyFont: FontChoice?
    var headingFont: FontChoice?
    /// Multiplier on every text size, 0.85...1.2.
    var fontScale: Double = 1.0
    /// Multiplier on line spacing, 0.9...1.4.
    var lineSpacing: Double = 1.0
    /// Page margin in points. nil keeps the template margin.
    var marginPoints: Double?
    /// Hide the photo even if the template supports it.
    var showPhoto = true
}

// MARK: - Resume

struct Resume: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var templateID: String
    var createdAt = Date()
    var updatedAt = Date()
    var isArchived = false
    var pageSize: PageSize = .a4
    var personal = PersonalInfo()
    var sections: [ResumeSection]
    var style = StyleOverrides()
    var linkedCoverLetterID: UUID?
    /// Set when the user started from the Blank Resume option.
    var isBlank = false
    var schemaVersion = 1

    /// Fraction 0...1 describing how complete the resume is. Used for progress rings.
    var completion: Double {
        var score = 0.0
        var total = 0.0
        func add(_ ok: Bool, _ weight: Double) { total += weight; if ok { score += weight } }
        add(!personal.fullName.isEmpty, 2)
        add(!personal.professionalTitle.isEmpty, 1)
        add(!personal.email.isEmpty, 1.5)
        add(!personal.phone.isEmpty, 1)
        add(!personal.city.isEmpty, 0.5)
        for kind in [SectionKind.summary, .experience, .education, .skills] {
            add(sections.first(where: { $0.kind == kind })?.hasContent == true, 2)
        }
        return total == 0 ? 0 : score / total
    }
}
