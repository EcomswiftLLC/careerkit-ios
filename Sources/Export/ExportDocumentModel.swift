import Foundation

/// What is being exported: the same models and templates the PDF renderer takes.
enum ExportSource {
    case resume(Resume, TemplateSpec)
    case coverLetter(CoverLetter, CoverLetterTemplateSpec)
}

/// A piece of text with simple formatting. `url` turns it into a link in formats that support links.
struct ExportRun: Equatable {
    var text: String
    var bold: Bool = false
    var italic: Bool = false
    var muted: Bool = false
    var url: String? = nil

    init(_ text: String, bold: Bool = false, italic: Bool = false, muted: Bool = false, url: String? = nil) {
        self.text = text
        self.bold = bold
        self.italic = italic
        self.muted = muted
        self.url = url
    }
}

/// One paragraph of the exported document. Every format maps these kinds to its own styles,
/// so all text formats share one reading order and one definition of what is included.
struct ExportBlock: Equatable {
    enum Kind: Equatable {
        /// The person's name at the top.
        case name
        /// Professional title under the name.
        case subtitle
        /// Email, phone, location and links on one line.
        case contact
        /// A section heading such as "Work Experience".
        case heading
        /// Job title, degree or project name.
        case entryTitle
        /// Company, location and dates under an entry title.
        case entryMeta
        /// Extra line such as a grade or URL.
        case entryNote
        /// Body paragraph with normal spacing after it.
        case paragraph
        /// A line that belongs to a tight block (address lines) with no spacing after it.
        case line
        /// A list item.
        case bullet
        /// Empty space, for example between the sign-off and the signature.
        case gap
        /// The name under a cover letter.
        case signature
    }

    var kind: Kind
    var runs: [ExportRun]

    init(_ kind: Kind, _ runs: [ExportRun]) {
        self.kind = kind
        self.runs = runs
    }

    init(_ kind: Kind, text: String) {
        self.kind = kind
        self.runs = text.isEmpty ? [] : [ExportRun(text)]
    }

    var plainText: String {
        return runs.map { $0.text }.joined()
    }

    /// True when the paragraph starts with right to left text (Arabic, Hebrew, ...).
    var isRightToLeft: Bool {
        return RenderTextDirection.isRightToLeft(plainText)
    }
}

/// The document as a list of blocks plus the style values every format needs.
struct ExportDocument {
    enum DocumentKind { case resume, coverLetter }

    var kind: DocumentKind
    /// Title for file metadata.
    var title: String
    var author: String
    var pageSize: PageSize
    /// Margins in points.
    var marginTop: Double
    var marginSide: Double
    var marginBottom: Double
    /// "#RRGGBB"
    var accentHex: String
    var inkHex: String
    var mutedHex: String
    var headingFont: FontChoice
    var bodyFont: FontChoice
    /// Sizes in points.
    var bodySize: Double
    var headingSize: Double
    var nameSize: Double
    /// Line height multiplier, 1.0 is single spacing.
    var lineSpacing: Double
    var uppercaseHeadings: Bool
    var blocks: [ExportBlock]

    /// True when most of the visible text is right to left. Used for the document direction of HTML.
    var isMostlyRightToLeft: Bool {
        var rtl: Int = 0
        var total: Int = 0
        for block in blocks where !block.plainText.isEmpty {
            total += 1
            if block.isRightToLeft { rtl += 1 }
        }
        return total > 0 && rtl * 2 > total
    }
}

// MARK: - Fonts

/// Maps the app's iOS fonts to fonts that exist on Windows, macOS and in Google Docs.
enum ExportFonts {
    /// A font name Word can be expected to have.
    static func wordFont(_ choice: FontChoice) -> String {
        switch choice {
        case .sfPro: return "Calibri"
        case .newYork: return "Georgia"
        case .helveticaNeue: return "Arial"
        case .avenirNext: return "Calibri"
        case .georgia: return "Georgia"
        case .palatino: return "Palatino Linotype"
        case .baskerville: return "Garamond"
        case .hoeflerText: return "Garamond"
        case .charter: return "Cambria"
        case .iowanOldStyle: return "Cambria"
        case .gillSans: return "Calibri"
        case .optima: return "Calibri"
        case .cochin: return "Georgia"
        case .didot: return "Georgia"
        case .futura: return "Century Gothic"
        case .menlo: return "Consolas"
        }
    }

    /// Font used for right to left and other complex scripts. Arial covers Arabic and Hebrew everywhere.
    static let complexScriptFont = "Arial"

    static func isSerif(_ choice: FontChoice) -> Bool {
        if choice == .menlo { return false }
        return choice.isSerif
    }

    /// CSS font stack: the original iOS family first, then the Word-safe font, then a generic family.
    static func cssStack(_ choice: FontChoice) -> String {
        var names: [String] = []
        switch choice {
        case .sfPro:
            names.append("-apple-system")
            names.append("BlinkMacSystemFont")
            names.append("'Segoe UI'")
        case .newYork:
            names.append("ui-serif")
            names.append("'New York'")
        default:
            if let family = choice.familyName {
                names.append("'" + family + "'")
            }
        }
        let word: String = wordFont(choice)
        let quotedWord: String = "'" + word + "'"
        if !names.contains(quotedWord) {
            names.append(quotedWord)
        }
        if choice == .menlo {
            names.append("monospace")
        } else {
            names.append(isSerif(choice) ? "serif" : "sans-serif")
        }
        return names.joined(separator: ", ")
    }
}

// MARK: - Text cleaning

enum ExportText {
    /// Removes characters that are not allowed in XML 1.0 (most control characters, U+FFFE, U+FFFF).
    /// Tab, line feed and carriage return are kept.
    static func xmlSafe(_ text: String) -> String {
        var out = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if isXMLAllowed(scalar.value) {
                out.append(scalar)
            }
        }
        return String(out)
    }

    static func isXMLAllowed(_ v: UInt32) -> Bool {
        if v == 0x9 || v == 0xA || v == 0xD { return true }
        if v >= 0x20 && v <= 0xD7FF { return true }
        if v >= 0xE000 && v <= 0xFFFD { return true }
        if v >= 0x10000 && v <= 0x10FFFF { return true }
        return false
    }

    /// Escapes text for XML element content and attribute values. Invalid characters are dropped.
    static func xmlEscape(_ text: String) -> String {
        let safe: String = xmlSafe(text)
        var out: String = ""
        out.reserveCapacity(safe.utf8.count)
        for scalar in safe.unicodeScalars {
            switch scalar {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&apos;"
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    /// Same as `xmlEscape` but uses `&#39;` for the apostrophe, which every HTML parser accepts.
    static func htmlEscape(_ text: String) -> String {
        let safe: String = xmlSafe(text)
        var out: String = ""
        out.reserveCapacity(safe.utf8.count)
        for scalar in safe.unicodeScalars {
            switch scalar {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&#39;"
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    /// Only web, mail and phone links are kept. Anything else (for example javascript:) becomes plain text.
    static func safeLink(_ raw: String?) -> String? {
        guard let raw = raw else { return nil }
        let trimmed: String = raw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lower: String = trimmed.lowercased()
        let allowed: [String] = ["https://", "http://", "mailto:", "tel:"]
        guard allowed.contains(where: { lower.hasPrefix($0) }) else { return nil }
        guard !trimmed.contains(" "), !trimmed.contains("\n") else { return nil }
        return trimmed
    }

    /// "#1f4d3a" or "1F4D3A" becomes "1F4D3A". Invalid input gives the fallback.
    static func hexDigits(_ hex: String, fallback: String = "1F2421") -> String {
        if let normalized = TemplateSpec.normalizedHex(hex) {
            return String(normalized.dropFirst())
        }
        return fallback
    }

    /// Red, green and blue components 0...255 of "#RRGGBB".
    static func rgb(_ hex: String) -> (Int, Int, Int) {
        let digits: String = hexDigits(hex)
        let value: Int = Int(digits, radix: 16) ?? 0
        return ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)
    }
}

// MARK: - Builder

/// Turns a resume or cover letter into an `ExportDocument`. Pure, safe on any thread.
enum ExportDocumentBuilder {
    static func build(_ source: ExportSource) -> ExportDocument {
        switch source {
        case .resume(let resume, let template):
            return build(resume: resume, template: template)
        case .coverLetter(let letter, let template):
            return build(letter: letter, template: template)
        }
    }

    private static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        guard value.isFinite else { return low }
        return min(max(value, low), high)
    }

    private static func margins(top: Double, side: Double, bottom: Double, custom: Double?, customMax: Double, pageWidth: Double) -> (Double, Double, Double) {
        var t: Double = top
        var s: Double = side
        var b: Double = bottom
        if let value = custom, value.isFinite {
            let c: Double = clamp(value, 14, customMax)
            t = c
            s = c
            b = c
        }
        s = min(max(s, 14), (pageWidth - 240) / 2)
        t = max(t, 18)
        b = max(b, 18)
        return (t, s, b)
    }

    // MARK: Resume

    static func build(resume: Resume, template: TemplateSpec) -> ExportDocument {
        let effective: TemplateSpec = template.applying(resume.style)
        let o: StyleOverrides = resume.style
        let scale: Double = clamp(o.fontScale, 0.7, 1.4)
        let pageWidth: Double = Double(resume.pageSize.size.width)
        let m = margins(top: effective.marginTop, side: effective.marginSide, bottom: effective.marginBottom,
                        custom: o.marginPoints, customMax: 80, pageWidth: pageWidth)
        let accent: String = TemplateSpec.normalizedHex(o.accentHex) ?? TemplateSpec.normalizedHex(effective.accentHex) ?? "#1F4D3A"
        let ink: String = TemplateSpec.normalizedHex(effective.textHex) ?? "#1F2421"
        let muted: String = TemplateSpec.normalizedHex(effective.mutedHex) ?? "#5B605C"
        let leading: Double = clamp(effective.lineSpacing, 0.9, 1.6) * clamp(o.lineSpacing, 0.8, 1.6)

        var blocks: [ExportBlock] = []
        let p: PersonalInfo = resume.personal
        let name: String = RenderContent.trimmed(p.fullName)
        if !name.isEmpty { blocks.append(ExportBlock(.name, text: name)) }
        let title: String = RenderContent.trimmed(p.professionalTitle)
        if !title.isEmpty { blocks.append(ExportBlock(.subtitle, text: title)) }
        let contact: [ExportRun] = contactRuns(RenderContact.items(for: p))
        if !contact.isEmpty { blocks.append(ExportBlock(.contact, contact)) }

        let dateFormat: ResumeDateFormat? = o.dateFormat
        for section in RenderContent.visibleSections(resume) {
            blocks.append(ExportBlock(.heading, text: RenderContent.label(for: section)))
            for paragraph in RenderContent.paragraphs(section.text) {
                blocks.append(ExportBlock(.paragraph, text: paragraph))
            }
            for entry in RenderContent.renderableEntries(section) {
                blocks.append(contentsOf: entryBlocks(entry, dateFormat: dateFormat))
            }
            for group in RenderContent.renderableSkillGroups(section) {
                var runs: [ExportRun] = []
                if !group.name.isEmpty {
                    runs.append(ExportRun(group.name + ": ", bold: true))
                }
                runs.append(ExportRun(group.items.joined(separator: ", ")))
                blocks.append(ExportBlock(.paragraph, runs))
            }
        }

        let docTitle: String = RenderContent.trimmed(resume.title).isEmpty ? name : RenderContent.trimmed(resume.title)
        let uppercase: Bool = o.uppercaseHeadings ?? effective.uppercaseHeadings
        return ExportDocument(kind: .resume,
                              title: docTitle,
                              author: name,
                              pageSize: resume.pageSize,
                              marginTop: m.0,
                              marginSide: m.1,
                              marginBottom: m.2,
                              accentHex: accent,
                              inkHex: ink,
                              mutedHex: muted,
                              headingFont: o.headingFont ?? effective.headingFont,
                              bodyFont: o.bodyFont ?? effective.bodyFont,
                              bodySize: max(8, effective.baseSize * scale),
                              headingSize: max(9, effective.headingSize * scale),
                              nameSize: clamp(effective.nameSize * scale, 16, 36),
                              lineSpacing: clamp(leading, 1.0, 1.5),
                              uppercaseHeadings: uppercase,
                              blocks: blocks)
    }

    static func entryBlocks(_ entry: ResumeEntry, dateFormat: ResumeDateFormat?) -> [ExportBlock] {
        var out: [ExportBlock] = []
        let heading: String = RenderContent.trimmed(entry.heading)
        let sub: String = RenderContent.trimmed(entry.subheading)
        let location: String = RenderContent.trimmed(entry.location)
        let extra: String = RenderContent.trimmed(entry.extra)
        let dates: String = entry.dateRange(format: dateFormat, locale: Locale.current)
        let primary: String = heading.isEmpty ? sub : heading
        let secondary: String = heading.isEmpty ? "" : sub

        if !primary.isEmpty {
            out.append(ExportBlock(.entryTitle, text: primary))
        }
        var meta: [ExportRun] = []
        for (value, isMuted) in [(secondary, false), (location, true), (dates, true)] where !value.isEmpty {
            if !meta.isEmpty { meta.append(ExportRun(" | ", muted: true)) }
            meta.append(ExportRun(value, muted: isMuted))
        }
        if !meta.isEmpty {
            out.append(ExportBlock(.entryMeta, meta))
        }
        if !extra.isEmpty {
            out.append(ExportBlock(.entryNote, [ExportRun(extra, italic: true, muted: true)]))
        }
        for paragraph in RenderContent.paragraphs(entry.detail) {
            out.append(ExportBlock(.paragraph, text: paragraph))
        }
        for bullet in RenderContent.renderableBullets(entry) {
            out.append(ExportBlock(.bullet, text: flattenLines(bullet)))
        }
        return out
    }

    /// Contact items joined by " | ", each one a link when it has a safe URL.
    static func contactRuns(_ items: [RenderContactItem]) -> [ExportRun] {
        var runs: [ExportRun] = []
        for item in items {
            let text: String = RenderContent.trimmed(item.text)
            if text.isEmpty { continue }
            if !runs.isEmpty { runs.append(ExportRun(" | ", muted: true)) }
            runs.append(ExportRun(text, url: ExportText.safeLink(item.url?.absoluteString)))
        }
        return runs
    }

    /// A bullet is one list item, so line breaks inside it become spaces.
    static func flattenLines(_ text: String) -> String {
        let parts: [String] = text.components(separatedBy: CharacterSet.newlines)
            .map { RenderContent.trimmed($0) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: " ")
    }

    // MARK: Cover letter

    static func build(letter: CoverLetter, template: CoverLetterTemplateSpec) -> ExportDocument {
        let o: StyleOverrides = letter.style
        let scale: Double = clamp(o.fontScale, 0.7, 1.4)
        let pageWidth: Double = Double(letter.pageSize.size.width)
        let m = margins(top: template.marginTop, side: template.marginSide, bottom: template.marginBottom,
                        custom: o.marginPoints, customMax: 90, pageWidth: pageWidth)
        let accent: String = TemplateSpec.normalizedHex(o.accentHex) ?? TemplateSpec.normalizedHex(template.accentHex) ?? "#1F4D3A"
        let ink: String = TemplateSpec.normalizedHex(o.textHex) ?? TemplateSpec.normalizedHex(template.textHex) ?? "#1F2421"
        let muted: String = TemplateSpec.normalizedHex(template.mutedHex) ?? "#5B605C"
        let leading: Double = clamp(template.lineSpacing, 0.9, 1.6) * clamp(o.lineSpacing, 0.8, 1.6)
        let nameFactor: Double = clamp(o.nameScale, StyleOverrides.nameScaleRange.lowerBound, StyleOverrides.nameScaleRange.upperBound)

        var blocks: [ExportBlock] = []
        let name: String = RenderContent.trimmed(letter.senderName)
        if !name.isEmpty { blocks.append(ExportBlock(.name, text: name)) }
        let title: String = RenderContent.trimmed(letter.senderTitle)
        if !title.isEmpty { blocks.append(ExportBlock(.subtitle, text: title)) }
        let contact: [ExportRun] = contactRuns(RenderContact.items(email: letter.senderEmail,
                                                                    phone: letter.senderPhone,
                                                                    location: letter.senderLocation))
        if !contact.isEmpty { blocks.append(ExportBlock(.contact, contact)) }
        if !blocks.isEmpty { blocks.append(ExportBlock(.gap, runs: [])) }

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        let dateText: String = formatter.string(from: letter.date)
        if !dateText.isEmpty { blocks.append(ExportBlock(.paragraph, [ExportRun(dateText, muted: true)])) }

        var recipient: [String] = []
        for value in [letter.recipientName, letter.recipientTitle, letter.companyName] {
            let t: String = RenderContent.trimmed(value)
            if !t.isEmpty { recipient.append(t) }
        }
        recipient.append(contentsOf: RenderContent.paragraphs(letter.companyAddress))
        for (i, line) in recipient.enumerated() {
            blocks.append(ExportBlock(i == recipient.count - 1 ? .paragraph : .line, text: line))
        }

        let greeting: String = RenderContent.trimmed(letter.effectiveGreeting)
        if !greeting.isEmpty { blocks.append(ExportBlock(.paragraph, text: greeting)) }
        for paragraph in letter.bodyParagraphs {
            for part in RenderContent.paragraphs(paragraph) {
                blocks.append(ExportBlock(.paragraph, text: part))
            }
        }
        let signOff: String = RenderContent.trimmed(letter.signOff)
        if !signOff.isEmpty { blocks.append(ExportBlock(.line, text: signOff)) }
        if !name.isEmpty {
            blocks.append(ExportBlock(.gap, runs: []))
            blocks.append(ExportBlock(.signature, [ExportRun(name, bold: true)]))
        }

        let docTitle: String = RenderContent.trimmed(letter.title).isEmpty ? name : RenderContent.trimmed(letter.title)
        return ExportDocument(kind: .coverLetter,
                              title: docTitle,
                              author: name,
                              pageSize: letter.pageSize,
                              marginTop: m.0,
                              marginSide: m.1,
                              marginBottom: m.2,
                              accentHex: accent,
                              inkHex: ink,
                              mutedHex: muted,
                              headingFont: o.headingFont ?? template.headingFont,
                              bodyFont: o.bodyFont ?? template.bodyFont,
                              bodySize: max(8, template.baseSize * scale),
                              headingSize: max(9, template.baseSize * scale),
                              nameSize: clamp(template.nameSize * scale * nameFactor, 16, 36),
                              lineSpacing: clamp(leading, 1.0, 1.5),
                              uppercaseHeadings: false,
                              blocks: blocks)
    }
}

extension ExportBlock {
    init(_ kind: Kind, runs: [ExportRun]) {
        self.kind = kind
        self.runs = runs
    }
}
