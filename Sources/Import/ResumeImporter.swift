import Foundation
import PDFKit

// Turns the text of an existing resume (a PDF with selectable text, or pasted text) into a draft `Resume`.
// Everything runs on the device. Nothing is invented: every line of the source ends up somewhere the user can
// edit, and lines that cannot be placed with confidence go into a final "Imported text" section.

// MARK: - Errors

enum ResumeImportError: Error, Equatable {
    case tooLarge
    case tooManyPages(Int)
    case locked
    case unreadable
    case noText
    case emptyText

    var title: String {
        switch self {
        case .tooLarge: return String(localized: "This file is too large")
        case .tooManyPages: return String(localized: "This PDF has too many pages")
        case .locked: return String(localized: "This PDF is password protected")
        case .unreadable: return String(localized: "This file could not be opened")
        case .noText: return String(localized: "No text found in this PDF")
        case .emptyText: return String(localized: "There is no text to import")
        }
    }

    var message: String {
        switch self {
        case .tooLarge:
            return String(localized: "CareerKit imports PDFs up to 10 MB. Export a smaller copy, or paste the text instead.")
        case .tooManyPages(let pages):
            return String(localized: "This PDF has \(pages) pages. CareerKit imports resumes of up to 10 pages. Paste the text of the pages you need instead.",
                          comment: "Import error. The number is always more than 10.")
        case .locked:
            return String(localized: "Remove the password in the app that made the PDF, then import it again. You can also paste the text instead.")
        case .unreadable:
            return String(localized: "The file may be damaged or not a PDF. Try exporting it again, or paste the text instead.")
        case .noText:
            return String(localized: "This looks like a scan or a photo of a resume. It contains pictures of text, not text, so it cannot be read. Paste the text instead, or start from a template.")
        case .emptyText:
            return String(localized: "Paste the text of your resume, then try again.")
        }
    }
}

// MARK: - Draft

/// One section found in the source, before it is added to a resume.
struct ImportedSection: Identifiable, Equatable {
    var id = UUID()
    var section: ResumeSection
    /// The heading as written in the source. Empty for the fallback section and for summaries found above any heading.
    var detectedHeading: String = ""
    /// True for the "Imported text" section that holds lines that could not be placed.
    var isFallback: Bool = false
    /// Removed sections are not added to the new resume.
    var isIncluded: Bool = true

    /// A few short lines describing what was found, for the review screen.
    var previewLines: [String] {
        var out: [String] = []
        let s = section
        let text: String = s.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            out.append(ResumeImporter.abbreviate(text, to: 140))
        }
        for entry in s.entries.prefix(4) {
            var parts: [String] = []
            if !entry.heading.isEmpty { parts.append(entry.heading) }
            if !entry.subheading.isEmpty { parts.append(entry.subheading) }
            let dates: String = entry.dateRange()
            if !dates.isEmpty { parts.append(dates) }
            var line: String = parts.joined(separator: ", ")
            if line.isEmpty { line = ResumeImporter.abbreviate(entry.detail, to: 120) }
            if !entry.bullets.isEmpty {
                let count: Int = entry.bullets.count
                let noun: String = String(localized: "\(count) bullets",
                                          comment: "Import review: how many bullet points an entry has. Plural.")
                line = line.isEmpty ? noun : "\(line) (\(noun))"
            }
            if !line.isEmpty { out.append(line) }
        }
        if s.entries.count > 4 {
            let count: Int = s.entries.count - 4
            out.append(String(localized: "and \(count) more",
                              comment: "Import review: more entries than the preview shows."))
        }
        for group in s.skillGroups.prefix(3) {
            let items: String = group.items.prefix(8).joined(separator: ", ")
            let suffix: String = group.items.count > 8 ? ", ..." : ""
            out.append(group.name.isEmpty ? items + suffix : "\(group.name): \(items)\(suffix)")
        }
        return out
    }
}

struct ResumeImportDraft: Equatable {
    var personal = PersonalInfo()
    var sections: [ImportedSection] = []
    /// True when the source was longer than `ResumeImporter.maxTextLength` and only the start was read.
    var wasTruncated = false

    static let empty = ResumeImportDraft()

    var hasContent: Bool {
        if !personal.fullName.isEmpty || !personal.email.isEmpty || !personal.phone.isEmpty { return true }
        return sections.contains(where: { $0.section.hasContent })
    }

    var fallbackSection: ImportedSection? {
        return sections.first(where: { $0.isFallback })
    }

    var suggestedTitle: String {
        let name: String = personal.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty
            ? String(localized: "Imported resume")
            : String(localized: "\(name) Resume", comment: "Title of an imported resume. The placeholder is the person's name.")
    }

    /// Builds the resume. Required sections the source did not have are added empty, after the imported ones,
    /// so the editor can guide the user through them.
    func makeResume(title: String, templateID: String, pageSize: PageSize) -> Resume {
        var sections: [ResumeSection] = self.sections.filter { $0.isIncluded }.map { $0.section }
        for kind in ResumeFactory.requiredKinds where !sections.contains(where: { $0.kind == kind }) {
            sections.append(ResumeSection(kind: kind))
        }
        var resume = Resume(title: title, templateID: templateID, pageSize: pageSize, sections: sections)
        resume.personal = personal
        return resume
    }

    /// Every piece of text in the draft, one per line. Used by tests to check nothing was dropped.
    var allText: String {
        var lines: [String] = [personal.fullName, personal.professionalTitle, personal.email, personal.phone,
                               personal.city, personal.country, personal.linkedIn, personal.portfolio, personal.website]
        for item in sections {
            lines.append(item.section.title)
            lines.append(item.section.text)
            for entry in item.section.entries {
                lines.append(contentsOf: [entry.heading, entry.subheading, entry.location, entry.detail, entry.extra])
                lines.append(contentsOf: entry.bullets)
            }
            for group in item.section.skillGroups {
                lines.append(group.name)
                lines.append(contentsOf: group.items)
            }
        }
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

// MARK: - Importer

enum ResumeImporter {
    static let maxFileBytes: Int = 10 * 1024 * 1024
    static let maxPages: Int = 10
    /// Longer text is cut to this many characters before parsing.
    static let maxTextLength: Int = 100_000
    /// Fewer letters than this in a PDF means it is a scan or a picture.
    static let minimumLetters: Int = 20

    // MARK: Reading

    /// Reads a PDF picked in the document browser, with security-scoped access and size and page checks.
    static func readPDF(at url: URL) throws -> String {
        let scoped: Bool = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }
        if let values = try? url.resourceValues(forKeys: [.fileSizeKey]), let size = values.fileSize, size > maxFileBytes {
            throw ResumeImportError.tooLarge
        }
        let data: Data
        do {
            // Not memory mapped: access to the file ends when this function returns.
            data = try Data(contentsOf: url)
        } catch {
            throw ResumeImportError.unreadable
        }
        return try text(fromPDFData: data)
    }

    /// Extracts the text of a PDF, page by page.
    static func text(fromPDFData data: Data) throws -> String {
        if data.count > maxFileBytes { throw ResumeImportError.tooLarge }
        guard !data.isEmpty, let document = PDFDocument(data: data) else { throw ResumeImportError.unreadable }
        if document.isLocked { throw ResumeImportError.locked }
        let pages: Int = document.pageCount
        if pages == 0 { throw ResumeImportError.unreadable }
        if pages > maxPages { throw ResumeImportError.tooManyPages(pages) }
        var parts: [String] = []
        for index in 0..<pages {
            guard let page = document.page(at: index) else { continue }
            let pageText: String = page.string ?? ""
            if !pageText.isEmpty { parts.append(pageText) }
        }
        let text: String = parts.joined(separator: "\n\n")
        let letters: Int = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        if letters < minimumLetters { throw ResumeImportError.noText }
        return text
    }

    /// Parses pasted text. Throws `.emptyText` when there is nothing to read.
    static func draft(fromPastedText text: String) throws -> ResumeImportDraft {
        guard text.contains(where: { $0.isLetter || $0.isNumber }) else { throw ResumeImportError.emptyText }
        return parse(text)
    }

    // MARK: Parsing

    private enum Heading: Equatable {
        case section(SectionKind)
        case contact
    }

    private struct Block {
        var heading: Heading
        var title: String
        var lines: [String]
    }

    static func parse(_ raw: String) -> ResumeImportDraft {
        var draft = ResumeImportDraft()
        var source: String = raw
        if source.count > maxTextLength {
            source = String(source.prefix(maxTextLength))
            draft.wasTruncated = true
        }
        var lines: [String] = normalisedLines(source)
        guard lines.contains(where: { !$0.isEmpty }) else { return draft }

        // Two-column PDFs often read the sidebar first, so the text starts with a heading such as "Contact"
        // and the name sits further down. Bring an upper case name (and the title under it) to the top.
        var promoted: [String] = []
        if let firstIndex = lines.firstIndex(where: { !$0.isEmpty }), heading(for: lines[firstIndex]) != nil {
            let limit: Int = min(lines.count, 80)
            var nameIndex: Int? = nil
            for i in 0..<limit where !lines[i].isEmpty && heading(for: lines[i]) == nil && looksLikeUppercaseName(lines[i]) {
                nameIndex = i
                break
            }
            if let nameIndex {
                promoted.append(lines[nameIndex])
                let next: Int = nameIndex + 1
                if next < lines.count, !lines[next].isEmpty, heading(for: lines[next]) == nil,
                   looksLikeTitle(lines[next]), !lines[next].contains("@") {
                    promoted.append(lines[next])
                    lines.remove(at: next)
                }
                lines.remove(at: nameIndex)
            }
        }

        // Split into a header (before the first heading) and blocks (one per heading).
        var headerLines: [String] = promoted
        var blocks: [Block] = []
        for line in lines {
            if let found = heading(for: line) {
                // Inside a skills list, "Languages: English, Spanish" is a named group, not a new section.
                let skillShaped: Bool = found.heading == .section(.skills) || found.heading == .section(.languages)
                if skillShaped, !found.remainder.isEmpty, let last = blocks.last,
                   last.heading == .section(.skills) || last.heading == .section(.languages) {
                    blocks[blocks.count - 1].lines.append(line)
                    continue
                }
                var block = Block(heading: found.heading, title: found.title, lines: [])
                if !found.remainder.isEmpty { block.lines.append(found.remainder) }
                blocks.append(block)
            } else if blocks.isEmpty {
                headerLines.append(line)
            } else {
                blocks[blocks.count - 1].lines.append(line)
            }
        }

        var personal = PersonalInfo()
        var fallback: [String] = []
        var sections: [ImportedSection] = []

        // Header: name, title, contact details. With no headings at all only the first lines count as the header.
        let header = parseHeader(headerLines, hasHeadings: !blocks.isEmpty, personal: &personal)
        if !header.summary.isEmpty {
            var summary = ResumeSection(kind: .summary)
            summary.text = textSection(header.summary)
            sections.append(ImportedSection(section: summary, detectedHeading: ""))
        }
        fallback.append(contentsOf: header.leftover)

        for block in blocks {
            switch block.heading {
            case .contact:
                for line in block.lines where !line.isEmpty {
                    let rest: String = extractContacts(from: line, into: &personal, allowLooseLocation: true)
                    if hasText(rest) { fallback.append(rest) }
                }
            case .section(let kind):
                let body: [String] = block.lines
                guard body.contains(where: { !$0.isEmpty }) else { continue }
                let built: ResumeSection = buildSection(kind: kind, title: block.title, lines: body)
                guard built.hasContent else {
                    fallback.append(contentsOf: body.filter { !$0.isEmpty })
                    continue
                }
                // Two-column PDFs can repeat a heading; keep one section per kind and add to it.
                if kind != .custom, let index = sections.firstIndex(where: { $0.section.kind == kind && !$0.isFallback }) {
                    sections[index].section.text = [sections[index].section.text, built.text]
                        .filter { !$0.isEmpty }.joined(separator: "\n")
                    sections[index].section.entries.append(contentsOf: built.entries)
                    sections[index].section.skillGroups.append(contentsOf: built.skillGroups)
                } else {
                    sections.append(ImportedSection(section: built, detectedHeading: block.title))
                }
            }
        }

        // Contact details sometimes sit at the bottom or in a sidebar without a heading.
        if personal.email.isEmpty, let email = firstMatch(emailRegex, in: source) {
            personal.email = email
        }

        let unplaced: [String] = fallback.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if !unplaced.isEmpty {
            var custom = ResumeSection(kind: .custom, title: String(localized: "Imported text"))
            var entry = ResumeEntry()
            entry.detail = unplaced.joined(separator: "\n")
            custom.entries = [entry]
            sections.append(ImportedSection(section: custom, detectedHeading: "", isFallback: true))
        }

        draft.personal = personal
        draft.sections = sections
        return draft
    }

    // MARK: Lines

    /// Unifies line breaks, spaces, ligatures and invisible characters. Blank lines are kept as "".
    static func normalisedLines(_ text: String) -> [String] {
        var value: String = CJKText.foldingRadicals(text)
        value = value.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        value = value.replacingOccurrences(of: "\u{2028}", with: "\n").replacingOccurrences(of: "\u{2029}", with: "\n")
        value = value.replacingOccurrences(of: "\u{000C}", with: "\n")
        var cleaned = String.UnicodeScalarView()
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x00AD, 0x200B, 0x200C, 0x200D, 0x2060, 0xFEFF:
                continue
            case 0x0009, 0x00A0, 0x2000...0x200A, 0x202F, 0x205F, 0x3000:
                cleaned.append(" ")
            default:
                if scalar.value < 0x20 && scalar.value != 0x0A { continue }
                cleaned.append(scalar)
            }
        }
        return String(cleaned).components(separatedBy: "\n").map { line in
            line.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        }
    }

    static func wordCount(_ text: String) -> Int {
        return text.split(whereSeparator: { $0.isWhitespace }).count
    }

    static func hasLetters(_ text: String) -> Bool {
        return text.contains(where: { $0.isLetter })
    }

    static func abbreviate(_ text: String, to length: Int) -> String {
        let flat: String = text.replacingOccurrences(of: "\n", with: " ")
        if flat.count <= length { return flat }
        return String(flat.prefix(max(0, length - 3))) + "..."
    }

    // MARK: Headings

    private static let headingNames: [SectionKind: [String]] = [
        .summary: ["summary", "professional summary", "career summary", "executive summary", "profile", "professional profile",
                   "personal profile", "about me", "about", "objective", "career objective", "personal statement",
                   "perfil", "perfil profesional", "resumen", "resumen profesional", "sobre mi", "acerca de mi",
                   "resumo", "perfil profissional", "sobre mim", "objetivo", "objetivo profissional",
                   "profil", "kurzprofil", "uber mich", "zusammenfassung", "a propos", "a propos de moi", "objectif"],
        .experience: ["experience", "work experience", "professional experience", "relevant experience", "employment",
                      "employment history", "work history", "career history", "professional background", "career",
                      "experiencia", "experiencia laboral", "experiencia profesional", "historial laboral",
                      "experiencia profissional", "historico profissional",
                      "berufserfahrung", "berufliche erfahrung", "beruflicher werdegang", "werdegang",
                      "experiences", "experience professionnelle", "experiences professionnelles", "parcours professionnel"],
        .education: ["education", "education and training", "academic background", "academic history", "academics",
                     "educational background", "qualifications and education", "education and qualifications",
                     "educacion", "formacion", "formacion academica", "estudios",
                     "educacao", "formacao", "formacao academica",
                     "ausbildung", "bildung", "bildungsweg", "studium", "formation", "formations", "etudes", "diplomes"],
        .skills: ["skills", "technical skills", "key skills", "core skills", "skills and abilities", "skills and expertise",
                  "core competencies", "competencies", "expertise", "areas of expertise", "technologies", "tools",
                  "tools and technologies", "technical proficiencies", "skill set", "skillset",
                  "habilidades", "competencias", "aptitudes", "conocimientos", "competencias tecnicas",
                  "kenntnisse", "fahigkeiten", "kompetenzen", "faehigkeiten", "competences", "competences techniques"],
        .projects: ["projects", "key projects", "selected projects", "personal projects", "academic projects",
                    "proyectos", "projetos", "projekte", "projets"],
        .certifications: ["certifications", "certificates", "certification", "licenses", "licences",
                          "licenses and certifications", "licences and certifications", "certifications and licenses",
                          "certificaciones", "certificados", "certificacoes", "zertifikate", "zertifizierungen"],
        .languages: ["languages", "language skills", "idiomas", "linguas", "sprachen", "sprachkenntnisse", "langues"],
        .awards: ["awards", "honors", "honours", "awards and honors", "awards and honours", "honors and awards",
                  "achievements", "accomplishments", "premios", "reconocimientos", "premios e reconhecimentos",
                  "auszeichnungen", "prix", "distinctions"],
        .volunteer: ["volunteer", "volunteering", "volunteer experience", "volunteer work", "community involvement",
                     "voluntariado", "trabajo voluntario", "ehrenamt", "ehrenamtliches engagement", "benevolat"],
        .references: ["references", "referees", "referencias", "referencias profissionais", "referenzen", "references professionnelles"],
        .publications: ["publications", "publicaciones", "publicacoes", "publikationen"],
        .courses: ["courses", "training", "trainings", "professional development", "continuing education",
                   "cursos", "weiterbildung", "fortbildung", "formation continue"],
        .interests: ["interests", "hobbies", "hobbies and interests", "interests and hobbies", "intereses", "interesses",
                     "hobbys", "interessen", "centres d interet", "loisirs"],
        .internships: ["internships", "internship", "internship experience", "practicas", "estagios", "praktika", "stages"],
        .memberships: ["memberships", "professional memberships", "affiliations", "professional affiliations",
                       "membresias", "mitgliedschaften"]
    ]

    /// More headings in Spanish, French, German and Chinese. Kept apart from `headingNames` to keep both readable.
    private static let moreHeadingNames: [SectionKind: [String]] = [
        .summary: ["perfil personal", "objetivo profesional", "extracto", "presentacion", "resumen de perfil",
                   "profil professionnel", "presentation", "objectif professionnel", "synthese", "en bref",
                   "personliches profil", "profil und ziele", "kurzvorstellung", "berufliches profil", "uber mich",
                   "自我评价", "个人简介", "个人总结", "个人优势", "职业目标", "求职意向", "个人评价", "自我介绍",
                   "个人概述", "职业概述", "自己pr", "職務要約"],
        .experience: ["trayectoria profesional", "experiencia laboral relevante", "historial profesional",
                      "experiencia professional", "parcours", "experience", "experiences professionnelles",
                      "emplois", "berufliche laufbahn", "praxiserfahrung", "berufspraxis", "beruflicher hintergrund",
                      "工作经历", "工作经验", "职业经历", "工作履历", "工作背景", "从业经历", "職務経歴", "職歴"],
        .education: ["educacion y formacion", "formacion academica y profesional", "titulacion", "estudios realizados",
                     "formation academique", "diplomes et formations", "parcours academique", "cursus",
                     "schulbildung", "akademische ausbildung", "studium und ausbildung", "ausbildung und studium",
                     "hochschulbildung", "教育背景", "教育经历", "学历", "教育", "学习经历", "学历背景", "学歴"],
        .skills: ["habilidades tecnicas", "conocimientos informaticos", "competencias profesionales",
                  "habilidades y competencias", "herramientas", "competences cles", "competences professionnelles",
                  "savoir faire", "outils", "it kenntnisse", "edv kenntnisse", "fachkenntnisse", "fachliche kompetenzen",
                  "qualifikationen", "kenntnisse und fahigkeiten", "技能", "专业技能", "技能特长", "个人技能",
                  "技术能力", "技能专长", "专业能力", "技术栈", "スキル", "保有スキル"],
        .projects: ["proyectos destacados", "projets personnels", "projets professionnels", "projets realises",
                    "ausgewahlte projekte", "projekterfahrung", "项目经历", "项目经验", "项目", "主要项目",
                    "プロジェクト"],
        .certifications: ["certificaciones y licencias", "certificats", "certifications professionnelles",
                          "zertifikate und lizenzen", "zertifizierungen und lizenzen", "证书", "资格证书", "获得证书",
                          "证书与资质", "资质证书", "认证", "資格", "免許 資格"],
        .languages: ["idiomas y niveles", "competences linguistiques", "langues etrangeres", "fremdsprachen",
                     "sprachkenntnisse und niveau", "语言能力", "语言", "外语能力", "语言技能", "語学"],
        .awards: ["logros", "premios y reconocimientos", "honores", "realisations", "prix and distinctions",
                  "ehrungen", "erfolge", "获奖情况", "荣誉奖项", "获奖经历", "荣誉", "奖项", "所获荣誉", "受賞歴"],
        .volunteer: ["voluntariado y actividades", "engagement associatif", "benevolat et engagement",
                     "soziales engagement", "志愿者经历", "志愿服务", "社会实践", "ボランティア"],
        .references: ["referencias laborales", "referees", "referenzen und empfehlungen", "推荐人", "证明人"],
        .publications: ["articulos", "veroffentlichungen", "发表论文", "论文发表", "出版物", "論文"],
        .courses: ["formacion complementaria", "cursos y seminarios", "formation complementaire",
                   "weiterbildungen", "kurse", "seminare", "培训经历", "培训", "进修经历", "研修"],
        .interests: ["aficiones", "intereses personales", "centres d interet", "passions", "freizeit",
                     "hobbys and interessen", "freizeitaktivitaten", "兴趣爱好", "爱好", "个人爱好", "興味", "趣味"],
        .internships: ["practicas profesionales", "stage", "experience de stage", "praktikum", "实习经历",
                       "实习经验", "实习", "インターン"],
        .memberships: ["asociaciones", "associations", "verbande", "mitgliedschaften in verbanden", "社团经历",
                       "社团活动", "学生工作", "所属団体"]
    ]

    private static let contactNames: [String] = [
        "contact", "contact details", "contact information", "contact info", "personal details", "personal information",
        "personal info", "contacto", "datos de contacto", "datos personales", "contato", "dados pessoais",
        "kontakt", "kontaktdaten", "personliche daten", "persoenliche daten", "coordonnees", "informations personnelles",
        "informacion de contacto", "informacion personal", "etat civil", "persoenliche angaben", "personliche angaben",
        "联系方式", "个人信息", "基本信息", "联系信息", "个人资料", "連絡先", "基本情報"
    ]

    /// The kind of section a heading names, in English, Spanish, Portuguese, French, German, Chinese or Japanese.
    /// nil for contact headings and for anything unknown.
    static func sectionKind(forHeading text: String) -> SectionKind? {
        let key: String = headingKey(text)
        guard !key.isEmpty, case .section(let kind)? = headingTable[key] else { return nil }
        return kind
    }

    private static let headingTable: [String: Heading] = {
        var table: [String: Heading] = [:]
        for list in [headingNames, moreHeadingNames] {
            for (kind, names) in list {
                for name in names {
                    let key: String = headingKey(name)
                    // The first list wins when a name appears twice.
                    if table[key] == nil { table[key] = .section(kind) }
                    let compact: String = key.replacingOccurrences(of: " ", with: "")
                    if table[compact] == nil { table[compact] = .section(kind) }
                }
            }
        }
        for name in contactNames {
            let key: String = headingKey(name)
            table[key] = .contact
            table[key.replacingOccurrences(of: " ", with: "")] = .contact
        }
        return table
    }()

    /// Lowercase, no accents, "&" read as "and", punctuation dropped, single spaces.
    static func headingKey(_ text: String) -> String {
        var value: String = text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil).lowercased()
        value = value.replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "+", with: " and ")
            .replacingOccurrences(of: "/", with: " and ")
            .replacingOccurrences(of: " und ", with: " and ")
            .replacingOccurrences(of: " y ", with: " and ")
            .replacingOccurrences(of: " e ", with: " and ")
            .replacingOccurrences(of: " et ", with: " and ")
        var kept: String = ""
        for ch in value {
            if ch.isLetter { kept.append(ch) } else { kept.append(" ") }
        }
        return kept.split(separator: " ").joined(separator: " ")
    }

    private struct FoundHeading {
        let heading: Heading
        let title: String
        let remainder: String
    }

    /// A known section heading, alone on its line or followed by a colon and content ("Skills: Swift, SQL").
    private static func heading(for line: String) -> FoundHeading? {
        let trimmed: String = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count <= 70 else { return nil }
        if isBulletLine(trimmed) { return nil }
        var head: String = trimmed
        var rest: String = ""
        if let colon = trimmed.firstIndex(of: ":") {
            head = String(trimmed[..<colon])
            rest = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        } else if trimmed.count > 45 {
            return nil
        }
        let key: String = headingKey(head)
        guard !key.isEmpty else { return nil }
        let words: [Substring] = key.split(separator: " ")
        if let found = headingTable[key], words.count <= 6 {
            // "Skills: Swift, SQL" is a heading with content. "Training: ran onboarding for new staff" inside a job is not.
            if !rest.isEmpty && !headingAllowsInlineContent(found) { return nil }
            return FoundHeading(heading: found, title: cleanHeadingTitle(head), remainder: rest)
        }
        // Letter-spaced headings come out of some PDFs as "S K I L L S" or "工 作 经 历".
        if words.count >= 2 && words.allSatisfy({ $0.count == 1 }) && (words.count >= 4 || CJKText.containsCJK(key)) {
            let compact: String = words.joined()
            if let found = headingTable[compact] {
                return FoundHeading(heading: found, title: cleanHeadingTitle(compact), remainder: rest)
            }
        }
        // Bilingual headings such as "工作经历 Work Experience": either half is enough.
        if CJKText.containsCJK(key) && rest.isEmpty && words.count <= 6 {
            let cjkPart: String = words.filter { CJKText.containsCJK(String($0)) }.joined()
            let latinPart: String = words.filter { !CJKText.containsCJK(String($0)) }.joined(separator: " ")
            for candidate in [cjkPart, latinPart] where !candidate.isEmpty {
                if let found = headingTable[candidate] {
                    return FoundHeading(heading: found, title: cleanHeadingTitle(head), remainder: rest)
                }
            }
        }
        return nil
    }

    private static func headingAllowsInlineContent(_ heading: Heading) -> Bool {
        switch heading {
        case .contact:
            return true
        case .section(let kind):
            return kind == .summary || kind == .skills || kind == .languages || kind == .interests
        }
    }

    /// Lines that name the document rather than the person.
    private static let documentTitles: Set<String> = [
        "resume", "cv", "curriculum vitae", "curriculum", "resume cv", "lebenslauf", "curriculo", "hoja de vida",
        "my resume", "c v", "mi curriculum", "mon cv", "tabellarischer lebenslauf", "简历", "个人简历", "求职简历",
        "履历", "简 历", "履歴書", "職務経歴書"
    ]

    /// "姓名：张伟", "Name: Jane Doe", "Nombre: Ana López": the value after a name label, or nil.
    static func labelledName(_ line: String) -> String? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let label: String = headingKey(String(line[..<colon]))
        let labels: Set<String> = ["name", "full name", "nombre", "nombre completo", "nom", "nom complet",
                                   "vorname and nachname", "姓名", "名字", "氏名"]
        guard labels.contains(label) else { return nil }
        let value: String = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    /// "WORK EXPERIENCE" becomes "Work Experience"; mixed case is kept as written.
    private static func cleanHeadingTitle(_ text: String) -> String {
        let trimmed: String = text.trimmingCharacters(in: CharacterSet(charactersIn: " :-|\u{2013}\u{2014}"))
        if trimmed == trimmed.uppercased() || trimmed == trimmed.lowercased() {
            return trimmed.capitalized
        }
        return trimmed
    }

    // MARK: Header

    private struct HeaderResult {
        var summary: [String] = []
        var leftover: [String] = []
    }

    private static func parseHeader(_ lines: [String], hasHeadings: Bool, personal: inout PersonalInfo) -> HeaderResult {
        var result = HeaderResult()
        let nonEmpty: [String] = lines.filter { !$0.isEmpty }
        // Without headings, only the top of the text is treated as the header; the rest is kept as imported text.
        let headerLimit: Int = hasHeadings ? nonEmpty.count : min(nonEmpty.count, 8)
        var index: Int = 0
        var nameFound: Bool = false
        var titleChecked: Bool = false
        var prose: [String] = []

        while index < headerLimit {
            let line: String = nonEmpty[index]
            index += 1

            // A document title such as "Resume" or "Curriculum Vitae" is not a name. It is kept, not dropped.
            if !nameFound && documentTitles.contains(headingKey(line)) {
                result.leftover.append(line)
                continue
            }

            if !nameFound, let labelled = labelledName(line) {
                let parts: [String] = splitParts(labelled)
                if let first = parts.first, looksLikeName(first) {
                    personal.fullName = normaliseName(first)
                    nameFound = true
                    let rest: String = parts.dropFirst().joined(separator: " | ")
                    if !rest.isEmpty {
                        let left: String = extractContacts(from: rest, into: &personal, allowLooseLocation: true)
                        if hasText(left) { result.leftover.append(left) }
                    }
                    continue
                }
            }

            if !nameFound {
                let parts: [String] = splitParts(line)
                if let first = parts.first, looksLikeName(first) {
                    personal.fullName = normaliseName(first)
                    nameFound = true
                    let rest: String = parts.dropFirst().joined(separator: " | ")
                    if !rest.isEmpty {
                        let left: String = extractContacts(from: rest, into: &personal, allowLooseLocation: true)
                        if hasText(left) { result.leftover.append(left) }
                    }
                    continue
                }
                // An email or phone line above the name: read it and keep looking, for at most three lines.
                if index <= 3 {
                    let left: String = extractContacts(from: line, into: &personal, allowLooseLocation: false)
                    if hasText(left) {
                        if index == 3 || wordCount(left) > 6 {
                            nameFound = true
                            prose.append(left)
                        } else {
                            result.leftover.append(left)
                        }
                    }
                    continue
                }
                nameFound = true
            }

            let left: String = extractContacts(from: line, into: &personal, allowLooseLocation: false)
            let untouched: Bool = left == line.trimmingCharacters(in: .whitespaces)
            if !titleChecked {
                titleChecked = true
                if untouched && looksLikeTitle(left) {
                    personal.professionalTitle = left
                    continue
                }
            }
            if !hasText(left) { continue }
            prose.append(left)
        }
        // A paragraph above the first heading is a summary; short scraps are kept as imported text.
        let proseWords: Int = prose.reduce(0) { $0 + wordCount($1) }
        if hasHeadings && proseWords >= 12 {
            result.summary = prose
        } else {
            result.leftover.append(contentsOf: prose)
        }
        if headerLimit < nonEmpty.count {
            result.leftover.append(contentsOf: nonEmpty[headerLimit...])
        }
        return result
    }

    private static func looksLikeName(_ text: String) -> Bool {
        let value: String = text.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty, value.count <= 60 else { return false }
        if value.contains("@") || value.lowercased().contains("www.") || value.lowercased().contains("http") { return false }
        if value.contains(where: { $0.isNumber }) { return false }
        let words: Int = wordCount(value)
        guard (1...6).contains(words) else { return false }
        let letters: Int = value.filter { $0.isLetter }.count
        guard letters >= 2 else { return false }
        let ratio: Double = Double(letters) / Double(value.filter { !$0.isWhitespace }.count)
        guard ratio >= 0.75 else { return false }
        if heading(for: value) != nil { return false }
        if value.hasSuffix(".") && words > 3 { return false }
        if CJKText.containsCJK(value) { return looksLikeCJKName(value) }
        return true
    }

    /// Chinese and Japanese names: two to four characters with no spaces ("张伟", "欧阳娜娜"), or a
    /// Japanese family and given name with one space ("山田 太郎"). A middle dot joins transliterated names.
    static func looksLikeCJKName(_ text: String) -> Bool {
        let value: String = text.trimmingCharacters(in: .whitespaces)
        let parts: [Substring] = value.split(separator: " ")
        guard parts.count <= 2 else { return false }
        let compact: String = parts.joined()
        guard compact.unicodeScalars.allSatisfy({ CJKText.isCJK($0) || $0 == "\u{00B7}" || $0 == "\u{30FB}" }) else {
            return false
        }
        let count: Int = compact.filter { $0 != "\u{00B7}" && $0 != "\u{30FB}" }.count
        if compact.contains("\u{00B7}") || compact.contains("\u{30FB}") { return (3...10).contains(count) }
        return (2...4).contains(count)
    }

    private static func looksLikeUppercaseName(_ text: String) -> Bool {
        guard looksLikeName(text), (2...4).contains(wordCount(text)) else { return false }
        return text == text.uppercased() && text != text.lowercased()
    }

    /// "JANE DOE" becomes "Jane Doe". Mixed case is kept.
    private static func normaliseName(_ text: String) -> String {
        let value: String = text.trimmingCharacters(in: .whitespaces)
        if value == value.uppercased() && value != value.lowercased() {
            return value.capitalized
        }
        return value
    }

    private static func looksLikeTitle(_ text: String) -> Bool {
        let words: Int = wordCount(text)
        guard (1...10).contains(words), hasLetters(text), text.count <= 90 else { return false }
        if text.hasSuffix(".") && words > 5 { return false }
        let digits: Int = text.filter { $0.isNumber }.count
        return digits <= 2
    }

    // MARK: Contact details

    static let emailRegex: NSRegularExpression = makeRegex("[A-Z0-9._%+\\-]+@[A-Z0-9.\\-]+\\.[A-Z]{2,}")
    private static let phoneFallbackRegex: NSRegularExpression = makeRegex("(?:\\+|\\()?\\d[\\d\\s().\\-]{5,}\\d")
    private static let yearRangeRegex: NSRegularExpression = makeRegex("^\\s*(?:19|20)\\d{2}\\s*[\\-\u{2013}\u{2014}/]?\\s*(?:(?:19|20)\\d{2})?\\s*$")
    private static let locationRegex: NSRegularExpression = makeRegex("^[\\p{L}][\\p{L} .'\\-]{0,40},\\s*[\\p{L}][\\p{L} .'\\-]{0,40}$")
    private static let regionCodeRegex: NSRegularExpression = makeRegex(",\\s*[A-Z]{2,3}$", caseInsensitive: false)

    private static let linkDetector: NSDataDetector? = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    private static let phoneDetector: NSDataDetector? = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)

    static func makeRegex(_ pattern: String, caseInsensitive: Bool = true) -> NSRegularExpression {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        if let regex = try? NSRegularExpression(pattern: pattern, options: options) { return regex }
        // Patterns are constants; this only guards against a typo. It matches nothing.
        // swiftlint:disable:next force_try
        return try! NSRegularExpression(pattern: "(?!x)x", options: [])
    }

    static func firstMatch(_ regex: NSRegularExpression, in text: String) -> String? {
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: match.range)
    }

    private static let contactLabels: [String] = [
        "e-mail", "email", "mail", "phone", "telephone", "tel", "mobile", "cell", "linkedin", "website", "web",
        "portfolio", "github", "address", "location", "telefono", "movil", "correo", "telefone", "celular",
        "telefon", "handy", "adresse", "courriel", "portable",
        "direccion", "ubicacion", "correo electronico", "teléfono", "móvil", "dirección", "ubicación", "téléphone",
        "mobil", "wohnort", "anschrift", "电话", "手机", "邮箱", "电子邮箱", "电子邮件", "地址", "现居", "所在地",
        "现居地", "居住地", "联系电话", "微信", "電話", "メール", "住所"
    ]

    private static let locationLabels: Set<String> = [
        "location", "address", "adresse", "direccion", "dirección", "ubicacion", "ubicación", "wohnort", "anschrift",
        "地址", "现居", "所在地", "现居地", "居住地", "住所"
    ]

    /// Takes email, phone, links and (when it is clear) a location out of `line`, fills empty fields of
    /// `personal`, and returns what is left.
    static func extractContacts(from line: String, into personal: inout PersonalInfo, allowLooseLocation: Bool) -> String {
        var rest: String = line
        var foundSomething: Bool = false

        // Email.
        while let email = firstMatch(emailRegex, in: rest) {
            if personal.email.isEmpty { personal.email = email }
            rest = rest.replacingOccurrences(of: email, with: " ")
            foundSomething = true
        }

        // Links.
        if let detector = linkDetector {
            let ns = rest as NSString
            let matches = detector.matches(in: rest, options: [], range: NSRange(location: 0, length: ns.length))
            var found: [String] = []
            for match in matches {
                if let url = match.url, url.scheme?.lowercased() == "mailto" { continue }
                found.append(ns.substring(with: match.range))
            }
            for link in found {
                let trimmedLink: String = link.trimmingCharacters(in: CharacterSet(charactersIn: ".,;)"))
                // "Node.js" is detected as a link; only clear web addresses are taken.
                guard looksLikeWebAddress(trimmedLink) else { continue }
                assignLink(trimmedLink, to: &personal)
                rest = rest.replacingOccurrences(of: link, with: " ")
                foundSomething = true
            }
        }

        // Phone.
        var phones: [String] = []
        if let detector = phoneDetector {
            let ns = rest as NSString
            for match in detector.matches(in: rest, options: [], range: NSRange(location: 0, length: ns.length)) {
                phones.append(ns.substring(with: match.range))
            }
        }
        if phones.isEmpty, let loose = firstMatch(phoneFallbackRegex, in: rest) {
            phones.append(loose)
        }
        for phone in phones {
            let digits: Int = phone.filter { $0.isNumber }.count
            guard (7...15).contains(digits) else { continue }
            if firstMatch(yearRangeRegex, in: phone) != nil { continue }
            if ImportDateParser.find(in: phone, allowSingle: false) != nil { continue }
            if personal.phone.isEmpty { personal.phone = phone.trimmingCharacters(in: .whitespaces) }
            rest = rest.replacingOccurrences(of: phone, with: " ")
            foundSomething = true
        }

        // Labels such as "Email:" that are now empty.
        var parts: [String] = []
        for part in splitParts(rest) {
            var value: String = part
            let lower: String = value.lowercased()
            var drop: Bool = false
            for label in contactLabels {
                if lower == label || lower == label + ":" {
                    drop = true
                    break
                }
                if lower.hasPrefix(label + ":") {
                    value = String(value.dropFirst(label.count + 1)).trimmingCharacters(in: .whitespaces)
                    if locationLabels.contains(label) && personal.city.isEmpty && !value.isEmpty {
                        assignLocation(value, to: &personal)
                        drop = true
                    }
                    break
                }
            }
            if drop { continue }
            let trimmed: String = value.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:|-"))
            if !trimmed.isEmpty { parts.append(trimmed) }
        }

        // Location: "Austin, TX" next to other contact details, or anywhere in a contact block.
        if personal.city.isEmpty {
            if let index = parts.firstIndex(where: { isLocation($0, loose: allowLooseLocation || foundSomething) }) {
                assignLocation(parts[index], to: &personal)
                parts.remove(at: index)
            }
        }
        return parts.joined(separator: " | ").trimmingCharacters(in: .whitespaces)
    }

    private static let webSuffixRegex: NSRegularExpression = makeRegex("\\.(?:com|net|org|io|dev|me|co|app|design|info|page|site|ai|uk|de|es|fr|br|pt|ca|au|in|eu|nl|it|mx|ar)(?:/|$)")

    private static func looksLikeWebAddress(_ text: String) -> Bool {
        let lower: String = text.lowercased()
        guard lower.contains("."), !lower.contains(" ") else { return false }
        if lower.hasPrefix("http") || lower.hasPrefix("www.") || lower.contains("/") { return true }
        return firstMatch(webSuffixRegex, in: lower) != nil
    }

    /// True when something other than spaces and separators is left.
    static func hasText(_ text: String) -> Bool {
        return !text.trimmingCharacters(in: CharacterSet(charactersIn: " |,;:-\u{2013}\u{2014}\u{00B7}\u{2022}/")).isEmpty
    }

    private static func isLocation(_ text: String, loose: Bool) -> Bool {
        guard !text.contains(where: { $0.isNumber }), wordCount(text) <= 6 else { return false }
        guard firstMatch(locationRegex, in: text) != nil else { return false }
        return loose || firstMatch(regionCodeRegex, in: text) != nil
    }

    private static func assignLocation(_ text: String, to personal: inout PersonalInfo) {
        let parts: [String] = text.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count == 2 {
            personal.city = parts[0]
            personal.country = parts[1]
        } else {
            personal.city = text.trimmingCharacters(in: .whitespaces)
        }
    }

    private static func assignLink(_ link: String, to personal: inout PersonalInfo) {
        let lower: String = link.lowercased()
        if lower.contains("linkedin.") {
            if personal.linkedIn.isEmpty { personal.linkedIn = link }
        } else if ["github.", "behance.", "dribbble.", "gitlab.", "portfolio"].contains(where: { lower.contains($0) }) {
            if personal.portfolio.isEmpty { personal.portfolio = link } else if personal.website.isEmpty { personal.website = link }
        } else if personal.website.isEmpty {
            personal.website = link
        } else if personal.portfolio.isEmpty {
            personal.portfolio = link
        }
    }

    /// Splits "Jane Doe | jane@example.com · +1 555 0100" into its parts.
    static func splitParts(_ text: String) -> [String] {
        var value: String = text
        for separator in [" \u{2013} ", " \u{2014} ", " - ", "  "] {
            value = value.replacingOccurrences(of: separator, with: "|")
        }
        let marks: Set<Character> = ["|", "\u{2022}", "\u{00B7}", "\u{25AA}", "\u{25CF}", "\u{25E6}", "\u{2219}", "\u{22C5}", "\u{2027}", "\u{2756}", "\u{25C6}"]
        return value.split(whereSeparator: { marks.contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: Bullets

    private static let bulletGlyphs: Set<Character> = [
        "\u{2022}", "\u{25AA}", "\u{25CF}", "\u{25E6}", "\u{2023}", "\u{2219}", "\u{00B7}", "\u{25A0}", "\u{25A1}",
        "\u{25CB}", "\u{27A2}", "\u{25BA}", "\u{25B8}", "\u{2713}", "\u{2714}", "\u{2192}", "\u{2043}", "\u{25C6}",
        "\u{2756}", "\u{F0B7}", "\u{F0A7}", "\u{F076}", "\u{F0D8}"
    ]
    private static let dashBullets: Set<Character> = ["-", "*", "\u{2013}", "\u{2014}", "+", ">"]

    static func isBulletLine(_ line: String) -> Bool {
        guard let first = line.first else { return false }
        if bulletGlyphs.contains(first) { return true }
        if dashBullets.contains(first) {
            let rest = line.dropFirst()
            return rest.first?.isWhitespace == true
        }
        return false
    }

    static func stripBullet(_ line: String) -> String {
        guard isBulletLine(line) else { return line.trimmingCharacters(in: .whitespaces) }
        return String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
    }

    // MARK: Sections

    private static let listKinds: Set<SectionKind> = [.certifications, .awards, .courses, .memberships, .publications, .references]

    private static func buildSection(kind: SectionKind, title: String, lines: [String]) -> ResumeSection {
        var section = ResumeSection(kind: kind)
        if !title.isEmpty && headingKey(title) != headingKey(kind.defaultTitle) {
            section.title = title
        }
        switch kind.shape {
        case .text:
            section.text = textSection(lines)
        case .skillGroups:
            section.skillGroups = skillGroups(lines)
        case .entries:
            section.entries = listKinds.contains(kind) ? listEntries(lines) : entries(lines)
        }
        return section
    }

    /// Paragraph text: wrapped lines are joined, blank lines and bullets start a new line.
    static func textSection(_ lines: [String]) -> String {
        var paragraphs: [String] = []
        var current: String = ""
        for line in lines {
            if line.isEmpty {
                if !current.isEmpty { paragraphs.append(current) }
                current = ""
                continue
            }
            if isBulletLine(line) {
                if !current.isEmpty { paragraphs.append(current) }
                current = stripBullet(line)
                continue
            }
            current = current.isEmpty ? line : current + " " + line
        }
        if !current.isEmpty { paragraphs.append(current) }
        return paragraphs.joined(separator: "\n")
    }

    /// "Languages: Swift, Kotlin" becomes a named group; other lines become items of one unnamed group.
    static func skillGroups(_ lines: [String]) -> [SkillGroup] {
        var named: [SkillGroup] = []
        var loose = SkillGroup()
        // "、" is the Chinese and Japanese list comma.
        let separators: Set<Character> = [",", ";", "|", "\u{2022}", "\u{00B7}", "\u{25AA}", "\u{25CF}", "\u{3001}"]
        for raw in lines where !raw.isEmpty {
            let line: String = stripBullet(raw)
            var name: String = ""
            var body: String = line
            if let colon = line.firstIndex(of: ":") {
                let head: String = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
                if !head.isEmpty && wordCount(head) <= 4 {
                    name = head
                    body = String(line[line.index(after: colon)...])
                }
            }
            let items: [String] = body.split(whereSeparator: { separators.contains($0) })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if name.isEmpty {
                loose.items.append(contentsOf: items)
            } else if items.isEmpty {
                loose.items.append(name)
            } else {
                var group = SkillGroup()
                group.name = name
                group.items = items
                named.append(group)
            }
        }
        if !loose.items.isEmpty { named.insert(loose, at: 0) }
        return named
    }

    /// One entry per line, for certifications, awards and similar lists.
    static func listEntries(_ lines: [String]) -> [ResumeEntry] {
        var out: [ResumeEntry] = []
        for raw in lines where !raw.isEmpty {
            let isBullet: Bool = isBulletLine(raw)
            let line: String = stripBullet(raw)
            // A wrapped line continues the previous item.
            if !isBullet, let last = out.last, let first = line.first, first.isLowercase {
                var copy = last
                copy.heading = copy.heading + " " + line
                out[out.count - 1] = copy
                continue
            }
            var entry = ResumeEntry()
            var text: String = line
            if let found = ImportDateParser.find(in: text, allowSingle: true) {
                found.apply(to: &entry)
                text = found.remainder
            }
            let parts: [String] = splitParts(text)
            entry.heading = parts.first ?? text
            if parts.count > 1 { entry.subheading = parts[1] }
            if parts.count > 2 { entry.extra = parts[2...].joined(separator: " | ") }
            if entry.heading.isEmpty && entry.start == nil && entry.end == nil { continue }
            out.append(entry)
        }
        return out
    }

    /// Jobs, degrees and projects. Entries are split at blank lines and at lines with a date range.
    static func entries(_ lines: [String]) -> [ResumeEntry] {
        var groups: [[String]] = []
        var current: [String] = []
        var anchor: Int = -1   // index in `current` of the last bullet or date line

        func hasDate(_ line: String) -> Bool {
            if isBulletLine(line) { return false }
            return ImportDateParser.find(in: line, allowSingle: wordCount(line) <= 10) != nil
        }

        for line in lines {
            if line.isEmpty {
                if anchor >= 0 {
                    groups.append(current)
                    current = []
                    anchor = -1
                }
                continue
            }
            let bullet: Bool = isBulletLine(line)
            let dated: Bool = hasDate(line)
            if dated && anchor >= 0 {
                // The lines after the last bullet are usually the title of the next entry ("Designer" above "Acme, 2019 - 2021").
                var carried: [String] = []
                while current.count - 1 > anchor, carried.count < 2,
                      let last = current.last, wordCount(last) <= 12, !last.hasSuffix(".") {
                    carried.insert(current.removeLast(), at: 0)
                }
                if !current.isEmpty { groups.append(current) }
                current = carried
                anchor = -1
            }
            current.append(line)
            if bullet || dated { anchor = current.count - 1 }
        }
        if !current.isEmpty { groups.append(current) }
        return groups.map { makeEntry($0) }.filter { RenderContent.entryIsRenderable($0) || $0.start != nil }
    }

    private static func makeEntry(_ lines: [String]) -> ResumeEntry {
        var entry = ResumeEntry()
        var titleLines: [String] = []
        var details: [String] = []
        var lastWasBullet: Bool = false
        var hasDates: Bool = false

        for line in lines {
            if isBulletLine(line) {
                let text: String = stripBullet(line)
                if !text.isEmpty { entry.bullets.append(text) }
                lastWasBullet = !text.isEmpty
                continue
            }
            var text: String = line
            if !hasDates, let found = ImportDateParser.find(in: text, allowSingle: wordCount(text) <= 10) {
                found.apply(to: &entry)
                hasDates = true
                text = found.remainder
                if text.isEmpty { continue }
            }
            if lastWasBullet, let previous = entry.bullets.last, isContinuation(text, of: previous) {
                entry.bullets[entry.bullets.count - 1] = previous + " " + text
                continue
            }
            lastWasBullet = false
            if titleLines.count < 2 && details.isEmpty && entry.bullets.isEmpty && wordCount(text) <= 14 {
                titleLines.append(text)
            } else {
                details.append(text)
            }
        }

        // First title line: "Senior Designer | Acme Corp | Austin, TX" or "Senior Designer at Acme".
        if let first = titleLines.first {
            var parts: [String] = splitParts(first)
            if parts.count == 1, let range = first.range(of: " at ") {
                parts = [String(first[..<range.lowerBound]), String(first[range.upperBound...])]
            }
            assignTitleParts(parts, to: &entry)
        }
        if titleLines.count > 1 {
            let parts: [String] = splitParts(titleLines[1])
            assignTitleParts(parts, to: &entry)
        }
        entry.detail = details.joined(separator: "\n")
        return entry
    }

    private static func assignTitleParts(_ parts: [String], to entry: inout ResumeEntry) {
        for part in parts {
            let value: String = part.trimmingCharacters(in: CharacterSet(charactersIn: " ,;"))
            if value.isEmpty { continue }
            if entry.heading.isEmpty {
                entry.heading = value
            } else if entry.location.isEmpty && isLocation(value, loose: true) {
                entry.location = value
            } else if entry.subheading.isEmpty {
                // "Acme Corp, Austin, TX": the place goes to location.
                if let comma = value.firstIndex(of: ","), entry.location.isEmpty {
                    let tail: String = String(value[value.index(after: comma)...]).trimmingCharacters(in: .whitespaces)
                    if isLocation(tail, loose: true) {
                        entry.subheading = String(value[..<comma]).trimmingCharacters(in: .whitespaces)
                        entry.location = tail
                        continue
                    }
                }
                entry.subheading = value
            } else {
                entry.extra = entry.extra.isEmpty ? value : entry.extra + " | " + value
            }
        }
    }

    /// A wrapped bullet: starts in lower case, or the previous bullet did not end a sentence.
    private static func isContinuation(_ line: String, of previous: String) -> Bool {
        guard let first = line.first else { return false }
        if first.isLowercase { return true }
        if let last = previous.last, ".!?;:".contains(last) { return false }
        // A short line in title case is more likely the next entry's title.
        let words: [Substring] = line.split(separator: " ")
        if words.count <= 6 && words.allSatisfy({ $0.first?.isUppercase == true || $0.first?.isNumber == true }) {
            return false
        }
        return true
    }
}

// MARK: - Dates

/// A date or date range found in a line, such as "Jan 2020 - Present", "03/2018 - 06/2021" or "2014".
struct ImportFoundDate {
    var start: MonthYear?
    var end: MonthYear?
    var isCurrent: Bool
    /// The line without the date text.
    var remainder: String

    func apply(to entry: inout ResumeEntry) {
        entry.start = start
        entry.end = end
        entry.isCurrent = isCurrent
    }
}

enum ImportDateParser {
    /// Month names and short forms in English, Spanish, Portuguese, German and French, folded (no accents).
    static let months: [String: Int] = {
        let table: [(Int, [String])] = [
            (1, ["jan", "january", "ene", "enero", "janeiro", "januar", "janv", "janvier"]),
            (2, ["feb", "february", "febrero", "fev", "fevereiro", "februar", "fevr", "fevrier"]),
            (3, ["mar", "march", "marzo", "marco", "marz", "mrz", "mars"]),
            (4, ["apr", "april", "abr", "abril", "avr", "avril"]),
            (5, ["may", "mayo", "mai", "maio"]),
            (6, ["jun", "june", "junio", "junho", "juni", "juin"]),
            (7, ["jul", "july", "julio", "julho", "juli", "juil", "juillet"]),
            (8, ["aug", "august", "ago", "agosto", "aout"]),
            (9, ["sep", "sept", "september", "septiembre", "setiembre", "set", "setembro", "septembre"]),
            (10, ["oct", "october", "octubre", "out", "outubro", "okt", "oktober", "octobre"]),
            (11, ["nov", "november", "noviembre", "novembro", "novembre"]),
            (12, ["dec", "december", "dic", "diciembre", "dez", "dezembro", "dezember", "decembre"])
        ]
        var out: [String: Int] = [:]
        for (number, names) in table {
            for name in names { out[name] = number }
        }
        return out
    }()

    private static let presentWords: [String] = [
        "present", "current", "now", "today", "ongoing", "actual", "actualidad", "actualmente", "presente", "atual",
        "atualmente", "heute", "jetzt", "aujourd'hui", "aujourd\u{2019}hui", "en cours", "présent", "present day",
        "la actualidad", "hoy", "la fecha", "maintenant", "ce jour", "derzeit", "laufend", "aktuell", "gegenwart",
        "至今", "今", "现在", "目前", "当前", "现今", "現在"
    ]

    /// Month spellings as typed, with accents, longest first so "mars" wins over "mar".
    private static let monthPattern: String = {
        var names: [String] = Array(months.keys)
        names.append(contentsOf: ["março", "märz", "févr", "février", "août", "décembre", "déc", "fév"])
        names.sort { $0.count > $1.count }
        return names.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
    }()

    /// "Jan 2020", "enero de 2020", "03/2018", "2020年1月", "2020.01", "2020/01", "2020年" or "2014".
    private static var datePattern: String {
        return "(?:(?:\(monthPattern))\\.?,?\\s+(?:de\\s+)?(?:19|20)\\d{2}"
            + "|(?:0?[1-9]|1[0-2])\\s*[/.\\-]\\s*(?:19|20)\\d{2}"
            + "|(?:19|20)\\d{2}\\s*\u{5E74}\\s*(?:0?[1-9]|1[0-2])\\s*\u{6708}?"
            + "|(?:19|20)\\d{2}\\s*[./]\\s*(?:0[1-9]|1[0-2])(?!\\d)"
            + "|(?:19|20)\\d{2}\\s*\u{5E74}"
            + "|(?:19|20)\\d{2})"
    }

    /// Letters next to a date that mean it is part of a word. Chinese and Japanese characters are excluded,
    /// because those languages write dates directly next to other words ("2020年1月至今负责").
    private static let wordLetter: String = "[\\p{Latin}\\p{Greek}\\p{Cyrillic}\\p{Arabic}\\p{Hebrew}\\d]"

    private static var presentPattern: String {
        return presentWords.sorted { $0.count > $1.count }
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
    }

    private static let rangeRegex: NSRegularExpression = ResumeImporter.makeRegex(
        "(?<!\(wordLetter))(\(datePattern))\\s*(?:-|\u{2013}|\u{2014}|\u{2212}|~|\u{FF5E}|\u{81F3}|\u{5230}|to|until|till|bis|hasta|ate|até|au|à|a)\\s*(\(datePattern)|\(presentPattern))(?!\(wordLetter))"
    )
    private static let singleRegex: NSRegularExpression = ResumeImporter.makeRegex(
        "(?<![\\p{Latin}\\p{Greek}\\p{Cyrillic}\\p{Arabic}\\p{Hebrew}\\d/.])(\(datePattern))(?![\\p{Latin}\\p{Greek}\\p{Cyrillic}\\p{Arabic}\\p{Hebrew}\\d/])"
    )
    /// "seit 2019", "depuis mars 2020", "desde 2018", "since 2021": a role that is still current.
    private static let sinceRegex: NSRegularExpression = ResumeImporter.makeRegex(
        "(?<!\(wordLetter))(?:since|seit|depuis|desde)\\s+(\(datePattern))(?!\(wordLetter))"
    )
    private static let yearRegex: NSRegularExpression = ResumeImporter.makeRegex("(?:19|20)\\d{2}")
    private static let numericRegex: NSRegularExpression = ResumeImporter.makeRegex("^(\\d{1,2})\\s*[/.\\-]\\s*((?:19|20)\\d{2})$")
    /// Year first: "2020年1月", "2020.01", "2020/1", "2020-01".
    private static let yearFirstRegex: NSRegularExpression = ResumeImporter.makeRegex("^((?:19|20)\\d{2})\\s*[./\\-\u{5E74}]\\s*(\\d{1,2})\\s*\u{6708}?$")

    /// The first date range in `line`, or a single date when `allowSingle` is true.
    static func find(in line: String, allowSingle: Bool) -> ImportFoundDate? {
        let ns = line as NSString
        let full = NSRange(location: 0, length: ns.length)
        if let match = rangeRegex.firstMatch(in: line, options: [], range: full), match.numberOfRanges >= 3 {
            let startText: String = ns.substring(with: match.range(at: 1))
            let endText: String = ns.substring(with: match.range(at: 2))
            guard let start = parseDate(startText) else { return nil }
            let current: Bool = isPresent(endText)
            let end: MonthYear? = current ? nil : parseDate(endText)
            if !current && end == nil { return nil }
            return ImportFoundDate(start: start, end: end, isCurrent: current,
                                   remainder: remainder(of: ns, removing: match.range))
        }
        guard allowSingle else { return nil }
        if let match = sinceRegex.firstMatch(in: line, options: [], range: full), match.numberOfRanges >= 2 {
            let text: String = ns.substring(with: match.range(at: 1))
            if let date = parseDate(text) {
                return ImportFoundDate(start: date, end: nil, isCurrent: true,
                                       remainder: remainder(of: ns, removing: match.range))
            }
        }
        if let match = singleRegex.firstMatch(in: line, options: [], range: full) {
            let text: String = ns.substring(with: match.range)
            guard let date = parseDate(text) else { return nil }
            return ImportFoundDate(start: nil, end: date, isCurrent: false,
                                   remainder: remainder(of: ns, removing: match.range))
        }
        return nil
    }

    private static func isPresent(_ text: String) -> Bool {
        let folded: String = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        return presentWords.contains(where: {
            $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased() == folded
        })
    }

    static func parseDate(_ text: String) -> MonthYear? {
        let trimmed: String = text.trimmingCharacters(in: .whitespaces)
        let ns = trimmed as NSString
        let full = NSRange(location: 0, length: ns.length)
        if let numeric = numericRegex.firstMatch(in: trimmed, options: [], range: full), numeric.numberOfRanges >= 3 {
            let month: Int = Int(ns.substring(with: numeric.range(at: 1))) ?? 0
            let year: Int = Int(ns.substring(with: numeric.range(at: 2))) ?? 0
            guard (1950...2100).contains(year) else { return nil }
            return MonthYear(year: year, month: (1...12).contains(month) ? month : nil)
        }
        if let yearFirst = yearFirstRegex.firstMatch(in: trimmed, options: [], range: full), yearFirst.numberOfRanges >= 3 {
            let year: Int = Int(ns.substring(with: yearFirst.range(at: 1))) ?? 0
            let month: Int = Int(ns.substring(with: yearFirst.range(at: 2))) ?? 0
            guard (1950...2100).contains(year) else { return nil }
            return MonthYear(year: year, month: (1...12).contains(month) ? month : nil)
        }
        guard let yearMatch = yearRegex.firstMatch(in: trimmed, options: [], range: full) else { return nil }
        let year: Int = Int(ns.substring(with: yearMatch.range)) ?? 0
        guard (1950...2100).contains(year) else { return nil }
        var month: Int? = nil
        let before: String = ns.substring(to: yearMatch.range.location)
        var word: String = before
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: " .,"))
        // "enero de 2020"
        if word.hasSuffix(" de") {
            word = String(word.dropLast(3)).trimmingCharacters(in: CharacterSet(charactersIn: " .,"))
        }
        if !word.isEmpty { month = months[word] }
        return MonthYear(year: year, month: month)
    }

    private static func remainder(of ns: NSString, removing range: NSRange) -> String {
        let removed: String = ns.replacingCharacters(in: range, with: " ")
        var value: String = removed.replacingOccurrences(of: "()", with: " ").replacingOccurrences(of: "( )", with: " ")
        value = value.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        return value.trimmingCharacters(in: CharacterSet(charactersIn: " ,;|-\u{2013}\u{2014}()\u{00B7}\u{2022}"))
    }
}
