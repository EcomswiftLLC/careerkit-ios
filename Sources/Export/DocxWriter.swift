import Foundation

/// Writes a minimal, valid Word (.docx) package: real Heading 1 / Heading 2 paragraphs, real bulleted list
/// paragraphs (numbering.xml), hyperlinks through relationships, the page size and margins of the document,
/// and right to left paragraphs for Arabic and Hebrew. Element order follows the OOXML schema so Word,
/// Pages, Google Docs and LibreOffice open it without repairs.
enum DocxWriter {
    static let wordNamespace = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    static let relNamespace = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    static let hyperlinkType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink"

    /// Part names in the order they are written. [Content_Types].xml is first, as Office does it.
    static let partNames: [String] = [
        "[Content_Types].xml",
        "_rels/.rels",
        "docProps/core.xml",
        "docProps/app.xml",
        "word/document.xml",
        "word/styles.xml",
        "word/numbering.xml",
        "word/settings.xml",
        "word/_rels/document.xml.rels"
    ]

    static func data(_ document: ExportDocument, date: Date = Date()) -> Data {
        var links: [String] = []
        let documentXML: String = documentPart(document, links: &links)
        var zip = StoredZipWriter(date: date)
        zip.add("[Content_Types].xml", text: contentTypes())
        zip.add("_rels/.rels", text: packageRels())
        zip.add("docProps/core.xml", text: coreProperties(document, date: date))
        zip.add("docProps/app.xml", text: appProperties())
        zip.add("word/document.xml", text: documentXML)
        zip.add("word/styles.xml", text: styles(document))
        zip.add("word/numbering.xml", text: numbering(document))
        zip.add("word/settings.xml", text: settings())
        zip.add("word/_rels/document.xml.rels", text: documentRels(links))
        return zip.archive()
    }

    private static let header = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"

    private static func esc(_ text: String) -> String {
        return ExportText.xmlEscape(text)
    }

    // MARK: Package parts

    static func contentTypes() -> String {
        var x: String = header
        x += "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">"
        x += "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
        x += "<Default Extension=\"xml\" ContentType=\"application/xml\"/>"
        x += "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>"
        x += "<Override PartName=\"/word/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml\"/>"
        x += "<Override PartName=\"/word/numbering.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml\"/>"
        x += "<Override PartName=\"/word/settings.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml\"/>"
        x += "<Override PartName=\"/docProps/core.xml\" ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/>"
        x += "<Override PartName=\"/docProps/app.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.extended-properties+xml\"/>"
        x += "</Types>"
        return x
    }

    static func packageRels() -> String {
        var x: String = header
        x += "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
        x += "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/>"
        x += "<Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties\" Target=\"docProps/core.xml\"/>"
        x += "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties\" Target=\"docProps/app.xml\"/>"
        x += "</Relationships>"
        return x
    }

    static func documentRels(_ links: [String]) -> String {
        var x: String = header
        x += "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
        x += "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>"
        x += "<Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering\" Target=\"numbering.xml\"/>"
        x += "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings\" Target=\"settings.xml\"/>"
        for (i, link) in links.enumerated() {
            x += "<Relationship Id=\"" + linkID(i) + "\" Type=\"" + hyperlinkType + "\" Target=\"" + esc(link) + "\" TargetMode=\"External\"/>"
        }
        x += "</Relationships>"
        return x
    }

    static func linkID(_ index: Int) -> String {
        return "rIdLink\(index + 1)"
    }

    static func coreProperties(_ document: ExportDocument, date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: "UTC")
        let stamp: String = formatter.string(from: date)
        var x: String = header
        x += "<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:dcterms=\"http://purl.org/dc/terms/\" xmlns:dcmitype=\"http://purl.org/dc/dcmitype/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">"
        if !document.title.isEmpty {
            x += "<dc:title>" + esc(document.title) + "</dc:title>"
        }
        if !document.author.isEmpty {
            x += "<dc:creator>" + esc(document.author) + "</dc:creator>"
            x += "<cp:lastModifiedBy>" + esc(document.author) + "</cp:lastModifiedBy>"
        }
        x += "<dcterms:created xsi:type=\"dcterms:W3CDTF\">" + stamp + "</dcterms:created>"
        x += "<dcterms:modified xsi:type=\"dcterms:W3CDTF\">" + stamp + "</dcterms:modified>"
        x += "</cp:coreProperties>"
        return x
    }

    static func appProperties() -> String {
        var x: String = header
        x += "<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\" xmlns:vt=\"http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes\">"
        x += "<Application>CareerKit</Application>"
        x += "</Properties>"
        return x
    }

    static func settings() -> String {
        var x: String = header
        x += "<w:settings xmlns:w=\"" + wordNamespace + "\">"
        x += "<w:defaultTabStop w:val=\"720\"/>"
        x += "<w:characterSpacingControl w:val=\"doNotCompress\"/>"
        x += "<w:compat><w:compatSetting w:name=\"compatibilityMode\" w:uri=\"http://schemas.microsoft.com/office/word\" w:val=\"15\"/></w:compat>"
        x += "</w:settings>"
        return x
    }

    // MARK: Styles

    private static func halfPoints(_ points: Double) -> Int {
        return max(12, Int((points * 2).rounded()))
    }

    private static func twips(_ points: Double) -> Int {
        return Int((points * 20).rounded())
    }

    private static func fonts(_ name: String) -> String {
        let n: String = esc(name)
        let cs: String = esc(ExportFonts.complexScriptFont)
        return "<w:rFonts w:ascii=\"" + n + "\" w:hAnsi=\"" + n + "\" w:eastAsia=\"" + n + "\" w:cs=\"" + cs + "\"/>"
    }

    static func styles(_ document: ExportDocument) -> String {
        let bodyFont: String = ExportFonts.wordFont(document.bodyFont)
        let headingFont: String = ExportFonts.wordFont(document.headingFont)
        let accent: String = ExportText.hexDigits(document.accentHex, fallback: "1F4D3A")
        let ink: String = ExportText.hexDigits(document.inkHex, fallback: "1F2421")
        let muted: String = ExportText.hexDigits(document.mutedHex, fallback: "5B605C")
        let body: Int = halfPoints(document.bodySize)
        let small: Int = halfPoints(document.bodySize * 0.92)
        let heading: Int = halfPoints(document.headingSize * 1.05)
        let name: Int = halfPoints(document.nameSize)
        let line: Int = Int((240.0 * document.lineSpacing).rounded())
        let caps: String = document.uppercaseHeadings ? "<w:caps/>" : ""

        var x: String = header
        x += "<w:styles xmlns:w=\"" + wordNamespace + "\">"
        x += "<w:docDefaults>"
        x += "<w:rPrDefault><w:rPr>" + fonts(bodyFont) + "<w:color w:val=\"" + ink + "\"/><w:sz w:val=\"\(body)\"/><w:szCs w:val=\"\(body)\"/><w:lang w:val=\"en-US\" w:bidi=\"ar-SA\"/></w:rPr></w:rPrDefault>"
        x += "<w:pPrDefault><w:pPr><w:spacing w:after=\"80\" w:line=\"\(line)\" w:lineRule=\"auto\"/></w:pPr></w:pPrDefault>"
        x += "</w:docDefaults>"

        // Normal
        x += "<w:style w:type=\"paragraph\" w:default=\"1\" w:styleId=\"Normal\"><w:name w:val=\"Normal\"/><w:qFormat/>"
        x += "<w:pPr><w:widowControl/><w:spacing w:after=\"80\" w:line=\"\(line)\" w:lineRule=\"auto\"/></w:pPr>"
        x += "<w:rPr>" + fonts(bodyFont) + "<w:color w:val=\"" + ink + "\"/><w:sz w:val=\"\(body)\"/><w:szCs w:val=\"\(body)\"/></w:rPr></w:style>"

        // Default character style, needed by Hyperlink.
        x += "<w:style w:type=\"character\" w:default=\"1\" w:styleId=\"DefaultParagraphFont\"><w:name w:val=\"Default Paragraph Font\"/><w:uiPriority w:val=\"1\"/><w:semiHidden/><w:unhideWhenUsed/></w:style>"

        // Title: the person's name.
        x += "<w:style w:type=\"paragraph\" w:styleId=\"Title\"><w:name w:val=\"Title\"/><w:basedOn w:val=\"Normal\"/><w:next w:val=\"Normal\"/><w:uiPriority w:val=\"10\"/><w:qFormat/>"
        x += "<w:pPr><w:keepNext/><w:spacing w:after=\"40\" w:line=\"240\" w:lineRule=\"auto\"/></w:pPr>"
        x += "<w:rPr>" + fonts(headingFont) + "<w:b/><w:bCs/><w:color w:val=\"" + ink + "\"/><w:sz w:val=\"\(name)\"/><w:szCs w:val=\"\(name)\"/></w:rPr></w:style>"

        // Subtitle: professional title.
        x += "<w:style w:type=\"paragraph\" w:styleId=\"Subtitle\"><w:name w:val=\"Subtitle\"/><w:basedOn w:val=\"Normal\"/><w:next w:val=\"Normal\"/><w:uiPriority w:val=\"11\"/><w:qFormat/>"
        x += "<w:pPr><w:keepNext/><w:spacing w:after=\"60\"/></w:pPr>"
        x += "<w:rPr><w:color w:val=\"" + accent + "\"/><w:sz w:val=\"\(halfPoints(document.bodySize * 1.1))\"/><w:szCs w:val=\"\(halfPoints(document.bodySize * 1.1))\"/></w:rPr></w:style>"

        // Contact line.
        x += "<w:style w:type=\"paragraph\" w:customStyle=\"1\" w:styleId=\"Contact\"><w:name w:val=\"Contact\"/><w:basedOn w:val=\"Normal\"/><w:next w:val=\"Normal\"/><w:qFormat/>"
        x += "<w:pPr><w:spacing w:after=\"200\"/></w:pPr>"
        x += "<w:rPr><w:color w:val=\"" + muted + "\"/><w:sz w:val=\"\(small)\"/><w:szCs w:val=\"\(small)\"/></w:rPr></w:style>"

        // Heading 1: section headings, accent colour with a rule under them.
        x += "<w:style w:type=\"paragraph\" w:styleId=\"Heading1\"><w:name w:val=\"heading 1\"/><w:basedOn w:val=\"Normal\"/><w:next w:val=\"Normal\"/><w:uiPriority w:val=\"9\"/><w:qFormat/>"
        x += "<w:pPr><w:keepNext/><w:keepLines/><w:pBdr><w:bottom w:val=\"single\" w:sz=\"6\" w:space=\"1\" w:color=\"" + accent + "\"/></w:pBdr>"
        x += "<w:spacing w:before=\"280\" w:after=\"100\" w:line=\"240\" w:lineRule=\"auto\"/><w:outlineLvl w:val=\"0\"/></w:pPr>"
        x += "<w:rPr>" + fonts(headingFont) + "<w:b/><w:bCs/>" + caps + "<w:color w:val=\"" + accent + "\"/><w:sz w:val=\"\(heading)\"/><w:szCs w:val=\"\(heading)\"/></w:rPr></w:style>"

        // Heading 2: job titles, degrees, project names.
        x += "<w:style w:type=\"paragraph\" w:styleId=\"Heading2\"><w:name w:val=\"heading 2\"/><w:basedOn w:val=\"Normal\"/><w:next w:val=\"Normal\"/><w:uiPriority w:val=\"9\"/><w:unhideWhenUsed/><w:qFormat/>"
        x += "<w:pPr><w:keepNext/><w:keepLines/><w:spacing w:before=\"160\" w:after=\"0\"/><w:outlineLvl w:val=\"1\"/></w:pPr>"
        x += "<w:rPr>" + fonts(bodyFont) + "<w:b/><w:bCs/><w:color w:val=\"" + ink + "\"/><w:sz w:val=\"\(body)\"/><w:szCs w:val=\"\(body)\"/></w:rPr></w:style>"

        // Entry details line.
        x += "<w:style w:type=\"paragraph\" w:customStyle=\"1\" w:styleId=\"EntryDetails\"><w:name w:val=\"Entry Details\"/><w:basedOn w:val=\"Normal\"/><w:next w:val=\"Normal\"/><w:qFormat/>"
        x += "<w:pPr><w:keepNext/><w:spacing w:after=\"40\"/></w:pPr></w:style>"

        // Entry note: grade, URL.
        x += "<w:style w:type=\"paragraph\" w:customStyle=\"1\" w:styleId=\"EntryNote\"><w:name w:val=\"Entry Note\"/><w:basedOn w:val=\"Normal\"/><w:next w:val=\"Normal\"/><w:qFormat/>"
        x += "<w:pPr><w:spacing w:after=\"40\"/></w:pPr>"
        x += "<w:rPr><w:i/><w:iCs/><w:color w:val=\"" + muted + "\"/><w:sz w:val=\"\(small)\"/><w:szCs w:val=\"\(small)\"/></w:rPr></w:style>"

        // List Bullet: real list paragraphs through numbering.xml.
        x += "<w:style w:type=\"paragraph\" w:styleId=\"ListBullet\"><w:name w:val=\"List Bullet\"/><w:basedOn w:val=\"Normal\"/><w:uiPriority w:val=\"99\"/><w:unhideWhenUsed/><w:qFormat/>"
        x += "<w:pPr><w:numPr><w:numId w:val=\"1\"/></w:numPr><w:spacing w:after=\"40\"/><w:ind w:left=\"360\" w:hanging=\"240\"/><w:contextualSpacing/></w:pPr></w:style>"

        // Hyperlink character style.
        x += "<w:style w:type=\"character\" w:styleId=\"Hyperlink\"><w:name w:val=\"Hyperlink\"/><w:basedOn w:val=\"DefaultParagraphFont\"/><w:uiPriority w:val=\"99\"/><w:unhideWhenUsed/>"
        x += "<w:rPr><w:color w:val=\"" + accent + "\"/><w:u w:val=\"single\"/></w:rPr></w:style>"

        x += "</w:styles>"
        return x
    }

    static func numbering(_ document: ExportDocument) -> String {
        let accent: String = ExportText.hexDigits(document.accentHex, fallback: "1F4D3A")
        var x: String = header
        x += "<w:numbering xmlns:w=\"" + wordNamespace + "\">"
        x += "<w:abstractNum w:abstractNumId=\"0\">"
        x += "<w:multiLevelType w:val=\"singleLevel\"/>"
        x += "<w:lvl w:ilvl=\"0\">"
        x += "<w:start w:val=\"1\"/><w:numFmt w:val=\"bullet\"/><w:lvlText w:val=\"\u{2022}\"/><w:lvlJc w:val=\"left\"/>"
        x += "<w:pPr><w:ind w:left=\"360\" w:hanging=\"240\"/></w:pPr>"
        x += "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\" w:cs=\"Arial\" w:hint=\"default\"/><w:color w:val=\"" + accent + "\"/></w:rPr>"
        x += "</w:lvl>"
        x += "</w:abstractNum>"
        x += "<w:num w:numId=\"1\"><w:abstractNumId w:val=\"0\"/></w:num>"
        x += "</w:numbering>"
        return x
    }

    // MARK: Document

    static func documentPart(_ document: ExportDocument, links: inout [String]) -> String {
        let size = document.pageSize.size
        let pageW: Int = twips(Double(size.width))
        let pageH: Int = twips(Double(size.height))
        let side: Int = twips(document.marginSide)
        let top: Int = twips(document.marginTop)
        let bottom: Int = twips(document.marginBottom)

        var x: String = header
        x += "<w:document xmlns:w=\"" + wordNamespace + "\" xmlns:r=\"" + relNamespace + "\">"
        x += "<w:body>"
        let muted: String = ExportText.hexDigits(document.mutedHex, fallback: "5B605C")
        var previous: ExportBlock.Kind? = nil
        for block in document.blocks {
            x += paragraph(block, previous: previous, muted: muted, links: &links)
            previous = block.kind
        }
        x += "<w:sectPr>"
        x += "<w:pgSz w:w=\"\(pageW)\" w:h=\"\(pageH)\"/>"
        x += "<w:pgMar w:top=\"\(top)\" w:right=\"\(side)\" w:bottom=\"\(bottom)\" w:left=\"\(side)\" w:header=\"0\" w:footer=\"0\" w:gutter=\"0\"/>"
        x += "</w:sectPr>"
        x += "</w:body></w:document>"
        return x
    }

    private static func paragraph(_ block: ExportBlock, previous: ExportBlock.Kind?, muted: String, links: inout [String]) -> String {
        let rtl: Bool = block.isRightToLeft
        var style: String? = nil
        var spacing: String = ""
        var numbered: Bool = false
        var keepNext: Bool = false

        switch block.kind {
        case .name: style = "Title"
        case .subtitle: style = "Subtitle"
        case .contact: style = "Contact"
        case .heading: style = "Heading1"
        case .entryTitle:
            style = "Heading2"
            if previous == .heading { spacing = "<w:spacing w:before=\"0\"/>" }
        case .entryMeta: style = "EntryDetails"
        case .entryNote: style = "EntryNote"
        case .paragraph: style = nil
        case .line:
            spacing = "<w:spacing w:after=\"0\"/>"
        case .signature:
            spacing = "<w:spacing w:after=\"0\"/>"
        case .gap:
            spacing = "<w:spacing w:after=\"0\"/>"
            keepNext = true
        case .bullet:
            style = "ListBullet"
            numbered = true
        }

        var pPr: String = ""
        if let s = style { pPr += "<w:pStyle w:val=\"" + s + "\"/>" }
        if keepNext { pPr += "<w:keepNext/>" }
        if numbered { pPr += "<w:numPr><w:ilvl w:val=\"0\"/><w:numId w:val=\"1\"/></w:numPr>" }
        if rtl { pPr += "<w:bidi/>" }
        pPr += spacing

        var x: String = "<w:p>"
        if !pPr.isEmpty { x += "<w:pPr>" + pPr + "</w:pPr>" }
        for run in block.runs where !run.text.isEmpty {
            x += runXML(run, muted: muted, links: &links)
        }
        x += "</w:p>"
        return x
    }

    private static func runXML(_ run: ExportRun, muted: String, links: inout [String]) -> String {
        let link: String? = ExportText.safeLink(run.url)
        let rtl: Bool = RenderTextDirection.containsRTL(run.text)
        var rPr: String = ""
        if link != nil { rPr += "<w:rStyle w:val=\"Hyperlink\"/>" }
        if run.bold { rPr += "<w:b/><w:bCs/>" }
        if run.italic { rPr += "<w:i/><w:iCs/>" }
        if run.muted && link == nil { rPr += "<w:color w:val=\"" + muted + "\"/>" }
        if rtl { rPr += "<w:rtl/>" }

        var r: String = "<w:r>"
        if !rPr.isEmpty { r += "<w:rPr>" + rPr + "</w:rPr>" }
        r += textXML(run.text)
        r += "</w:r>"

        if let target = link {
            var index: Int = links.count
            if let existing = links.firstIndex(of: target) {
                index = existing
            } else {
                links.append(target)
            }
            return "<w:hyperlink r:id=\"" + linkID(index) + "\" w:history=\"1\">" + r + "</w:hyperlink>"
        }
        return r
    }

    /// Text with line breaks as <w:br/> and tabs as <w:tab/>, every piece in a w:t with preserved spaces.
    private static func textXML(_ text: String) -> String {
        var out: String = ""
        var buffer: String = ""
        func flush() {
            if !buffer.isEmpty {
                out += "<w:t xml:space=\"preserve\">" + esc(buffer) + "</w:t>"
                buffer = ""
            }
        }
        for ch in text {
            if ch == "\n" || ch == "\r\n" || ch == "\r" || ch == "\u{2028}" {
                flush()
                out += "<w:br/>"
            } else if ch == "\t" {
                flush()
                out += "<w:tab/>"
            } else {
                buffer.append(ch)
            }
        }
        flush()
        return out
    }
}
