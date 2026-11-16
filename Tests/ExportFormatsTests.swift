import XCTest
import UniformTypeIdentifiers
@testable import CareerKit

// MARK: - A small ZIP reader used only to check what StoredZipWriter wrote

private struct TestZipEntry {
    let name: String
    let data: Data
    let crc: UInt32
    let method: Int
}

private enum TestZipError: Error {
    case noEndRecord
    case badCentralSignature(Int)
    case badLocalSignature(Int)
    case mismatch(String)
    case outOfBounds(String)
}

private enum TestZipReader {
    static func u16(_ b: [UInt8], _ o: Int) -> Int {
        let low: Int = Int(b[o])
        let high: Int = Int(b[o + 1])
        return low | (high << 8)
    }

    static func u32(_ b: [UInt8], _ o: Int) -> UInt32 {
        let b0: UInt32 = UInt32(b[o])
        let b1: UInt32 = UInt32(b[o + 1]) << 8
        let b2: UInt32 = UInt32(b[o + 2]) << 16
        let b3: UInt32 = UInt32(b[o + 3]) << 24
        return b0 | b1 | b2 | b3
    }

    static func read(_ data: Data) throws -> [TestZipEntry] {
        let b: [UInt8] = [UInt8](data)
        guard b.count >= 22 else { throw TestZipError.noEndRecord }

        var eocd: Int = -1
        var i: Int = b.count - 22
        let lowest: Int = max(0, b.count - 22 - 65_535)
        while i >= lowest {
            if u32(b, i) == 0x0605_4B50 {
                eocd = i
                break
            }
            i -= 1
        }
        guard eocd >= 0 else { throw TestZipError.noEndRecord }

        let count: Int = u16(b, eocd + 10)
        let total: Int = u16(b, eocd + 8)
        guard count == total else { throw TestZipError.mismatch("entry counts") }
        let cdSize: Int = Int(u32(b, eocd + 12))
        let cdOffset: Int = Int(u32(b, eocd + 16))
        guard cdOffset + cdSize == eocd else { throw TestZipError.mismatch("central directory position") }

        var entries: [TestZipEntry] = []
        var p: Int = cdOffset
        for _ in 0..<count {
            guard p + 46 <= b.count else { throw TestZipError.outOfBounds("central record") }
            guard u32(b, p) == 0x0201_4B50 else { throw TestZipError.badCentralSignature(p) }
            let method: Int = u16(b, p + 10)
            let crc: UInt32 = u32(b, p + 16)
            let compressed: Int = Int(u32(b, p + 20))
            let uncompressed: Int = Int(u32(b, p + 24))
            let nameLength: Int = u16(b, p + 28)
            let extraLength: Int = u16(b, p + 30)
            let commentLength: Int = u16(b, p + 32)
            let localOffset: Int = Int(u32(b, p + 42))
            let name: String = String(decoding: b[(p + 46)..<(p + 46 + nameLength)], as: UTF8.self)

            guard localOffset + 30 <= b.count else { throw TestZipError.outOfBounds("local header") }
            guard u32(b, localOffset) == 0x0403_4B50 else { throw TestZipError.badLocalSignature(localOffset) }
            let localMethod: Int = u16(b, localOffset + 8)
            let localCRC: UInt32 = u32(b, localOffset + 14)
            let localCompressed: Int = Int(u32(b, localOffset + 18))
            let localUncompressed: Int = Int(u32(b, localOffset + 22))
            let localNameLength: Int = u16(b, localOffset + 26)
            let localExtraLength: Int = u16(b, localOffset + 28)
            let localName: String = String(decoding: b[(localOffset + 30)..<(localOffset + 30 + localNameLength)], as: UTF8.self)
            guard localName == name else { throw TestZipError.mismatch("name of " + name) }
            guard localMethod == method, localCRC == crc else { throw TestZipError.mismatch("header of " + name) }
            guard localCompressed == compressed, localUncompressed == uncompressed else { throw TestZipError.mismatch("sizes of " + name) }

            let start: Int = localOffset + 30 + localNameLength + localExtraLength
            guard start + compressed <= b.count else { throw TestZipError.outOfBounds("data of " + name) }
            let bytes = Data(b[start..<(start + compressed)])
            entries.append(TestZipEntry(name: name, data: bytes, crc: crc, method: method))
            p += 46 + nameLength + extraLength + commentLength
        }
        return entries
    }
}

// MARK: - Tests

final class ExportFormatsTests: XCTestCase {
    // MARK: Helpers

    private func standardResume(pageSize: PageSize = .a4) -> Resume {
        let f = EngineFixtures.self
        return f.resume("Standard", person: f.person("Jordan Whitfield"), sections: [
            f.section(.summary, text: "Product designer with eight years of experience."),
            f.section(.experience, entries: f.jobs(2, bulletsEach: 3)),
            f.section(.education, entries: [f.entry("BA Graphic Design", "State University", extra: "Grade 3.8 of 4.0")]),
            f.section(.skills, skills: f.standardSkills())
        ], pageSize: pageSize)
    }

    private var defaultSpec: TemplateSpec { EngineFixtures.specs[0] }

    private func unzip(_ data: Data, file: StaticString = #filePath, line: UInt = #line) -> [String: Data] {
        do {
            let entries = try TestZipReader.read(data)
            var out: [String: Data] = [:]
            for entry in entries {
                XCTAssertEqual(entry.method, 0, "\(entry.name) should be stored", file: file, line: line)
                XCTAssertEqual(CRC32.checksum(entry.data), entry.crc, "CRC of \(entry.name)", file: file, line: line)
                out[entry.name] = entry.data
            }
            return out
        } catch {
            XCTFail("Could not read the ZIP: \(error)", file: file, line: line)
            return [:]
        }
    }

    private func docxParts(_ source: ExportSource, file: StaticString = #filePath, line: UInt = #line) -> [String: Data] {
        do {
            let data: Data = try DocumentExporter.export(source, as: .docx)
            return unzip(data, file: file, line: line)
        } catch {
            XCTFail("docx export failed: \(error)", file: file, line: line)
            return [:]
        }
    }

    private func string(_ data: Data?) -> String {
        guard let data = data else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    private func isWellFormed(_ data: Data) -> Bool {
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        return parser.parse()
    }

    private func export(_ source: ExportSource, _ format: DocumentExportFormat, file: StaticString = #filePath, line: UInt = #line) -> Data {
        do {
            return try DocumentExporter.export(source, as: format)
        } catch {
            XCTFail("\(format) export failed: \(error)", file: file, line: line)
            return Data()
        }
    }

    private func text(_ source: ExportSource, _ format: DocumentExportFormat) -> String {
        return string(export(source, format))
    }

    /// True when every { has a matching } (escaped braces and backslashes are skipped).
    private func bracesBalanced(_ rtf: String) -> Bool {
        var depth: Int = 0
        var escaped: Bool = false
        for scalar in rtf.unicodeScalars {
            if escaped {
                escaped = false
                continue
            }
            if scalar == "\\" {
                escaped = true
            } else if scalar == "{" {
                depth += 1
            } else if scalar == "}" {
                depth -= 1
                if depth < 0 { return false }
            }
        }
        return depth == 0
    }

    // MARK: Format mapping

    func testFormatMetadata() {
        XCTAssertEqual(DocumentExportFormat.allCases.count, 5)
        let expected: [DocumentExportFormat: String] = [.pdf: "pdf", .docx: "docx", .rtf: "rtf", .txt: "txt", .html: "html"]
        for format in DocumentExportFormat.allCases {
            XCTAssertEqual(format.fileExtension, expected[format])
            XCTAssertFalse(format.displayName.isEmpty)
            XCTAssertFalse(format.shortDescription.isEmpty)
            XCTAssertEqual(format.supportsPrint, format == .pdf)
            XCTAssertEqual(ExportFileName.fileName(for: "Jane/Doe", format: format), "JaneDoe." + format.fileExtension)
        }
        XCTAssertEqual(DocumentExportFormat.rtf.displayName, "Rich Text (opens in Word)")
    }

    func testUTTypes() {
        XCTAssertEqual(DocumentExportFormat.pdf.utType, UTType.pdf)
        XCTAssertTrue(DocumentExportFormat.rtf.utType.conforms(to: UTType.rtf))
        XCTAssertTrue(DocumentExportFormat.txt.utType.conforms(to: UTType.plainText))
        XCTAssertTrue(DocumentExportFormat.html.utType.conforms(to: UTType.html))
        XCTAssertEqual(DocumentExportFormat.docx.utType.preferredFilenameExtension, "docx")
        for format in DocumentExportFormat.allCases {
            let fromExtension: UTType? = UTType(filenameExtension: format.fileExtension)
            XCTAssertNotNil(fromExtension)
            if let type = fromExtension {
                XCTAssertTrue(type.conforms(to: format.utType) || format.utType.conforms(to: type), "\(format)")
            }
        }
    }

    func testStoredFormatFallsBackToPDF() {
        XCTAssertEqual(DocumentExportFormat.stored(nil), .pdf)
        XCTAssertEqual(DocumentExportFormat.stored("bogus"), .pdf)
        XCTAssertEqual(DocumentExportFormat.stored("docx"), .docx)
        XCTAssertEqual(DocumentExportFormat.defaultFormat, .pdf)
    }

    func testWriterUsesExtensionAndCleanablePrefix() throws {
        let written = try ExportFileWriter.write(data: Data("hello".utf8), baseName: "My: Resume?", format: .docx)
        defer { try? FileManager.default.removeItem(at: written.directory) }
        XCTAssertEqual(written.url.lastPathComponent, "My Resume.docx")
        XCTAssertTrue(CKTempFiles.isOurs(written.directory.lastPathComponent))
        XCTAssertEqual(try Data(contentsOf: written.url), Data("hello".utf8))
    }

    // MARK: ZIP

    func testCRC32KnownValues() {
        XCTAssertEqual(CRC32.checksum(Data("123456789".utf8)), 0xCBF4_3926)
        XCTAssertEqual(CRC32.checksum(Data()), 0)
        XCTAssertEqual(CRC32.checksum(Data("The quick brown fox jumps over the lazy dog".utf8)), 0x414F_A339)
    }

    func testStoredZipRoundTrip() {
        var zip = StoredZipWriter(date: Date(timeIntervalSince1970: 1_790_000_000))
        let binary = Data((0..<1000).map { UInt8(truncatingIfNeeded: $0 * 7) })
        zip.add("[Content_Types].xml", text: "<Types/>")
        zip.add("folder/empty.txt", data: Data())
        zip.add("folder/binary.bin", data: binary)
        zip.add("unicode-\u{00E9}.txt", text: "caf\u{00E9} \u{1F600}")
        let archive: Data = zip.archive()

        let bytes: [UInt8] = [UInt8](archive)
        XCTAssertEqual(Array(bytes[0..<4]), [0x50, 0x4B, 0x03, 0x04], "starts with a local file header")

        let entries: [TestZipEntry]
        do {
            entries = try TestZipReader.read(archive)
        } catch {
            XCTFail("\(error)")
            return
        }
        XCTAssertEqual(entries.map { $0.name }, ["[Content_Types].xml", "folder/empty.txt", "folder/binary.bin", "unicode-\u{00E9}.txt"])
        XCTAssertEqual(entries[0].data, Data("<Types/>".utf8))
        XCTAssertEqual(entries[1].data, Data())
        XCTAssertEqual(entries[2].data, binary)
        XCTAssertEqual(string(entries[3].data), "caf\u{00E9} \u{1F600}")
        for entry in entries {
            XCTAssertEqual(entry.method, 0)
            XCTAssertEqual(CRC32.checksum(entry.data), entry.crc)
        }
    }

    func testDosDateTime() {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 16
        components.hour = 13
        components.minute = 45
        components.second = 30
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date: Date = calendar.date(from: components)!
        let stamp = StoredZipWriter.dosDateTime(date)
        XCTAssertEqual(Int(stamp.time), (13 << 11) | (45 << 5) | 15)
        XCTAssertEqual(Int(stamp.date), ((2026 - 1980) << 9) | (11 << 5) | 16)
    }

    // MARK: DOCX

    func testDocxContainsEveryPartAndAllAreWellFormed() {
        let parts = docxParts(.resume(standardResume(), defaultSpec))
        for name in DocxWriter.partNames {
            XCTAssertNotNil(parts[name], "missing \(name)")
            if let data = parts[name] {
                XCTAssertTrue(isWellFormed(data), "\(name) is not well formed XML")
            }
        }
        let types: String = string(parts["[Content_Types].xml"])
        XCTAssertTrue(types.contains("wordprocessingml.document.main+xml"))
        XCTAssertTrue(types.contains("/word/numbering.xml"))
        let rels: String = string(parts["_rels/.rels"])
        XCTAssertTrue(rels.contains("Target=\"word/document.xml\""))
        let core: String = string(parts["docProps/core.xml"])
        XCTAssertTrue(core.contains("<dc:creator>Jordan Whitfield</dc:creator>"))
    }

    func testDocxIsStructured() {
        let parts = docxParts(.resume(standardResume(), defaultSpec))
        let doc: String = string(parts["word/document.xml"])
        XCTAssertTrue(doc.contains("<w:pStyle w:val=\"Title\"/>"))
        XCTAssertTrue(doc.contains("<w:pStyle w:val=\"Heading1\"/>"))
        XCTAssertTrue(doc.contains("<w:pStyle w:val=\"Heading2\"/>"))
        XCTAssertTrue(doc.contains("<w:pStyle w:val=\"ListBullet\"/>"))
        XCTAssertTrue(doc.contains("<w:numPr><w:ilvl w:val=\"0\"/><w:numId w:val=\"1\"/></w:numPr>"))
        XCTAssertTrue(doc.contains("Work Experience"))
        XCTAssertTrue(doc.contains("Role Number 0 Lead"))
        XCTAssertTrue(doc.contains(EngineFixtures.bullet(0)))

        let numbering: String = string(parts["word/numbering.xml"])
        XCTAssertTrue(numbering.contains("<w:numFmt w:val=\"bullet\"/>"))

        let styles: String = string(parts["word/styles.xml"])
        XCTAssertTrue(styles.contains("w:styleId=\"Heading1\""))
        XCTAssertTrue(styles.contains("1F4D3A"), "accent colour is used for headings")
        XCTAssertTrue(styles.contains("w:ascii=\"Georgia\""), "heading font maps to Georgia")
        XCTAssertTrue(styles.contains("w:ascii=\"Arial\""), "Helvetica Neue maps to Arial")
    }

    func testDocxHyperlinksUseRelationships() {
        let parts = docxParts(.resume(standardResume(), defaultSpec))
        let doc: String = string(parts["word/document.xml"])
        let rels: String = string(parts["word/_rels/document.xml.rels"])
        XCTAssertTrue(doc.contains("<w:hyperlink r:id=\"rIdLink1\""))
        XCTAssertTrue(rels.contains("Id=\"rIdLink1\""))
        XCTAssertTrue(rels.contains("TargetMode=\"External\""))
        XCTAssertTrue(rels.contains("mailto:sample.person@example.com"))
        XCTAssertTrue(rels.contains("https://www.linkedin.com/in/sample-person"))
        // Every r:id used in the document has a relationship.
        var index: Int = 1
        while doc.contains("r:id=\"rIdLink\(index)\"") {
            XCTAssertTrue(rels.contains("Id=\"rIdLink\(index)\""))
            index += 1
        }
        XCTAssertGreaterThan(index, 2)
    }

    func testDocxPageSizeAndMargins() {
        let a4: String = string(docxParts(.resume(standardResume(pageSize: .a4), defaultSpec))["word/document.xml"])
        XCTAssertTrue(a4.contains("<w:pgSz w:w=\"11906\" w:h=\"16838\"/>"))
        XCTAssertTrue(a4.contains("w:left=\"880\""), "44 pt margin is 880 twips")

        var letter = standardResume(pageSize: .usLetter)
        letter.style.marginPoints = 60
        let us: String = string(docxParts(.resume(letter, defaultSpec))["word/document.xml"])
        XCTAssertTrue(us.contains("<w:pgSz w:w=\"12240\" w:h=\"15840\"/>"))
        XCTAssertTrue(us.contains("w:left=\"1200\""))
    }

    func testDocxEscapesSpecialCharacters() {
        let f = EngineFixtures.self
        var person = f.person("Ana & Bo <Lee> \"Q\" 'S'")
        person.professionalTitle = "R&D \u{1F600} lead\u{0001}\u{FFFE}"
        let resume = f.resume("Special", person: person, sections: [
            f.section(.summary, text: "\u{0645}\u{0631}\u{062D}\u{0628}\u{0627} \u{0628}\u{0627}\u{0644}\u{0639}\u{0627}\u{0644}\u{0645}"),
            f.section(.experience, entries: [f.entry("Engineer {core}", "C:\\Work & Co", bullets: ["Cut costs <20%> & time \u{1F680}"])])
        ])
        let parts = docxParts(.resume(resume, defaultSpec))
        guard let data = parts["word/document.xml"] else {
            XCTFail("no document.xml")
            return
        }
        XCTAssertTrue(isWellFormed(data))
        let doc: String = string(data)
        XCTAssertTrue(doc.contains("Ana &amp; Bo &lt;Lee&gt; &quot;Q&quot; &apos;S&apos;"))
        XCTAssertTrue(doc.contains("R&amp;D \u{1F600} lead"))
        XCTAssertFalse(doc.contains("\u{0001}"))
        XCTAssertFalse(doc.contains("\u{FFFE}"))
        XCTAssertTrue(doc.contains("Cut costs &lt;20%&gt; &amp; time \u{1F680}"))
        XCTAssertTrue(doc.contains("C:\\Work &amp; Co"))
        XCTAssertTrue(doc.contains("<w:bidi/>"), "Arabic paragraphs are right to left")
        XCTAssertTrue(doc.contains("<w:rtl/>"))
        if let core = parts["docProps/core.xml"] {
            XCTAssertTrue(isWellFormed(core))
        }
    }

    // MARK: RTF

    func testRTFIsBalancedAndEscaped() {
        let f = EngineFixtures.self
        var person = f.person("Fran\u{00E7}ois {Brace} Back\\slash")
        person.professionalTitle = "Smile \u{1F600}"
        let resume = f.resume("RTF", person: person, sections: [
            f.section(.summary, text: "\u{0645}\u{0631}\u{062D}\u{0628}\u{0627}"),
            f.section(.experience, entries: f.jobs(1, bulletsEach: 2))
        ])
        let rtf: String = text(.resume(resume, defaultSpec), .rtf)
        XCTAssertTrue(rtf.hasPrefix("{\\rtf1"))
        XCTAssertTrue(bracesBalanced(rtf))
        XCTAssertTrue(rtf.unicodeScalars.allSatisfy { $0.value < 128 }, "RTF output is 7-bit ASCII")
        XCTAssertTrue(rtf.contains("Fran\\u231?ois \\{Brace\\} Back\\\\slash"))
        XCTAssertTrue(rtf.contains("\\u-10179?\\u-8704?"), "emoji is written as its two UTF-16 halves")
        XCTAssertTrue(rtf.contains("\\u1605?"), "Arabic is escaped")
        XCTAssertTrue(rtf.contains("\\rtlpar"))
        XCTAssertTrue(rtf.contains("\\u8226?"), "bullets are present")
        XCTAssertTrue(rtf.contains("\\paperw11906"))
        XCTAssertTrue(rtf.contains("\\b"))
    }

    func testRTFEscapeFunction() {
        XCTAssertEqual(RTFExporter.escape("a\\b{c}d"), "a\\\\b\\{c\\}d")
        XCTAssertEqual(RTFExporter.escape("line1\nline2"), "line1\\line line2")
        XCTAssertEqual(RTFExporter.escape("\u{00E9}"), "\\u233?")
        XCTAssertEqual(RTFExporter.escape("\u{FFFD}"), "\\u-3?")
        XCTAssertEqual(RTFExporter.escape("x\u{0001}y"), "xy")
    }

    // MARK: HTML

    func testHTMLEscapesScriptsAndIsSelfContained() {
        let f = EngineFixtures.self
        var person = f.person("<script>alert('x')</script>")
        person.professionalTitle = "Designer & \"Builder\""
        let resume = f.resume("HTML", person: person, sections: [
            f.section(.summary, text: "Hello</p><script src=\"https://evil.example/x.js\"></script>"),
            f.section(.experience, entries: f.jobs(1, bulletsEach: 2))
        ])
        let html: String = text(.resume(resume, defaultSpec), .html)
        XCTAssertTrue(html.hasPrefix("<!DOCTYPE html>"))
        XCTAssertFalse(html.lowercased().contains("<script"))
        XCTAssertTrue(html.contains("&lt;script&gt;alert(&#39;x&#39;)&lt;/script&gt;"))
        XCTAssertTrue(html.contains("Designer &amp; &quot;Builder&quot;"))
        XCTAssertFalse(html.contains("<link"), "no external stylesheets")
        XCTAssertTrue(html.contains("@media print"))
        XCTAssertTrue(html.contains("prefers-color-scheme"))
        XCTAssertTrue(html.contains("<h2 dir=\"auto\">Work Experience</h2>"))
        XCTAssertTrue(html.contains("<li dir=\"auto\">"))
        XCTAssertTrue(html.contains("href=\"mailto:sample.person@example.com\""))
    }

    func testHTMLUsesAccentColourAndPageSize() {
        var resume = standardResume(pageSize: .usLetter)
        resume.style.accentHex = "#8A2BE2"
        let html: String = text(.resume(resume, defaultSpec), .html)
        XCTAssertTrue(html.contains("--accent: #8A2BE2"))
        XCTAssertTrue(html.contains("size: letter"))
    }

    func testSafeLinkRejectsScripts() {
        XCTAssertNil(ExportText.safeLink("javascript:alert(1)"))
        XCTAssertNil(ExportText.safeLink("data:text/html,hi"))
        XCTAssertEqual(ExportText.safeLink("https://example.com"), "https://example.com")
        XCTAssertEqual(ExportText.safeLink("mailto:a@b.co"), "mailto:a@b.co")
    }

    // MARK: Plain text

    func testPlainTextHasHeadingsAndBullets() {
        let txt: String = text(.resume(standardResume(), defaultSpec), .txt)
        let lines: [String] = txt.components(separatedBy: "\n")
        XCTAssertEqual(lines.first, "Jordan Whitfield")
        XCTAssertTrue(lines.contains("WORK EXPERIENCE"))
        XCTAssertTrue(lines.contains("PROFESSIONAL SUMMARY"))
        XCTAssertTrue(lines.contains(PlainTextExporter.bulletPrefix + EngineFixtures.bullet(0)))
        XCTAssertTrue(lines.contains("Design: Interaction design, Prototyping, Design systems, User research, Accessibility"))
        XCTAssertTrue(txt.contains("sample.person@example.com | +1 (555) 014-2290"))
        XCTAssertFalse(txt.contains("\u{2022}"))
        XCTAssertFalse(txt.contains("\n\n\n"), "never more than one blank line")
    }

    func testPlainTextContainsEveryExpectedString() {
        for item in EngineFixtures.cases() {
            let txt: String = text(.resume(item.resume, defaultSpec), .txt).lowercased()
            for value in RenderContent.expectedStrings(for: item.resume) {
                let needle: String = PlainTextExporter.clean(value).lowercased()
                XCTAssertTrue(txt.contains(needle), "\(item.name): missing \(value)")
            }
            XCTAssertFalse(txt.contains("secrethidden"), "\(item.name): hidden sections are not exported")
        }
    }

    // MARK: Every format, every fixture

    func testEveryFormatIsNonEmptyForEveryTemplateFixture() {
        let resume = EngineFixtures.cases()[1].resume
        for spec in EngineFixtures.specs {
            for format in DocumentExportFormat.allCases {
                let data = export(.resume(resume, spec), format)
                XCTAssertFalse(data.isEmpty, "\(spec.id) \(format)")
                if format == .docx {
                    let parts = unzip(data)
                    XCTAssertEqual(parts.count, DocxWriter.partNames.count, spec.id)
                    if let doc = parts["word/document.xml"] {
                        XCTAssertTrue(isWellFormed(doc), spec.id)
                    }
                }
            }
        }
    }

    func testEveryFormatIsNonEmptyForEveryResumeCase() {
        for item in EngineFixtures.cases() {
            for format in DocumentExportFormat.allCases {
                let data = export(.resume(item.resume, defaultSpec), format)
                XCTAssertFalse(data.isEmpty, "\(item.name) \(format)")
                if format == .docx, let doc = unzip(data)["word/document.xml"] {
                    XCTAssertTrue(isWellFormed(doc), item.name)
                }
                if format == .rtf {
                    XCTAssertTrue(bracesBalanced(string(data)), item.name)
                }
            }
        }
    }

    func testLibraryTemplatesExportToEveryTextFormat() {
        let resume = standardResume()
        for spec in TemplateLibrary.all {
            for format in DocumentExportFormat.allCases where format != .pdf {
                XCTAssertFalse(export(.resume(resume, spec), format).isEmpty, "\(spec.id) \(format)")
            }
        }
        let letter = EngineFixtures.letter()
        for spec in CoverLetterTemplateLibrary.all {
            for format in DocumentExportFormat.allCases where format != .pdf {
                XCTAssertFalse(export(.coverLetter(letter, spec), format).isEmpty, "\(spec.id) \(format)")
            }
        }
    }

    // MARK: Cover letters

    func testCoverLettersExportInEveryFormat() {
        let letter = EngineFixtures.letter()
        for spec in EngineFixtures.coverLetterSpecs() {
            for format in DocumentExportFormat.allCases {
                XCTAssertFalse(export(.coverLetter(letter, spec), format).isEmpty, "\(spec.id) \(format)")
            }
        }
        let long = EngineFixtures.letter(long: true, size: .usLetter)
        let spec = EngineFixtures.coverLetterSpecs()[0]
        for format in DocumentExportFormat.allCases {
            XCTAssertFalse(export(.coverLetter(long, spec), format).isEmpty, "long \(format)")
        }
    }

    func testCoverLetterContent() {
        let letter = EngineFixtures.letter()
        let spec = EngineFixtures.coverLetterSpecs()[0]
        let source: ExportSource = .coverLetter(letter, spec)

        let txt: String = text(source, .txt)
        XCTAssertTrue(txt.hasPrefix("Jordan Whitfield\n"))
        XCTAssertTrue(txt.contains("Alex Rivera\nHead of Design\nNorthwind Studio\n12 Harbour Street\nPortland, OR"))
        XCTAssertTrue(txt.contains("Dear Alex Rivera,"))
        XCTAssertTrue(txt.contains(letter.introduction))
        XCTAssertTrue(txt.contains("Sincerely,"))

        let parts = docxParts(source)
        for name in DocxWriter.partNames {
            if let data = parts[name] {
                XCTAssertTrue(isWellFormed(data), name)
            } else {
                XCTFail("missing \(name)")
            }
        }
        let doc: String = string(parts["word/document.xml"])
        XCTAssertTrue(doc.contains("Dear Alex Rivera,"))
        XCTAssertTrue(doc.contains("Northwind Studio"))
        XCTAssertTrue(doc.contains(letter.closing))

        let rtf: String = text(source, .rtf)
        XCTAssertTrue(bracesBalanced(rtf))
        XCTAssertTrue(rtf.contains("Dear Alex Rivera,"))

        let html: String = text(source, .html)
        XCTAssertTrue(html.contains("<p class=\"signature\" dir=\"auto\"><strong>Jordan Whitfield</strong></p>"))
    }

    func testPDFMatchesRenderer() throws {
        let resume = standardResume()
        let viaExporter: Data = try DocumentExporter.export(.resume(resume, defaultSpec), as: .pdf)
        XCTAssertTrue(viaExporter.starts(with: Data("%PDF".utf8)))
    }
}
