import Foundation

/// Hand-written Rich Text Format. Opens as an editable document in Word, Pages, TextEdit and Google Docs.
/// Text outside ASCII is written as \uN? escapes, so the file itself is plain 7-bit ASCII.
enum RTFExporter {
    static func data(_ document: ExportDocument) -> Data {
        return Data(text(document).utf8)
    }

    static func text(_ document: ExportDocument) -> String {
        let bodyFont: String = ExportFonts.wordFont(document.bodyFont)
        let headingFont: String = ExportFonts.wordFont(document.headingFont)
        let accent = ExportText.rgb(document.accentHex)
        let ink = ExportText.rgb(document.inkHex)
        let muted = ExportText.rgb(document.mutedHex)

        let body: Int = halfPoints(document.bodySize)
        let small: Int = halfPoints(document.bodySize * 0.92)
        let heading: Int = halfPoints(document.headingSize * 1.05)
        let name: Int = halfPoints(document.nameSize)
        let lineSpacing: Int = Int((240.0 * document.lineSpacing).rounded())

        let size = document.pageSize.size
        let paperW: Int = twips(Double(size.width))
        let paperH: Int = twips(Double(size.height))
        let side: Int = twips(document.marginSide)
        let top: Int = twips(document.marginTop)
        let bottom: Int = twips(document.marginBottom)

        var out: String = ""
        out += "{\\rtf1\\ansi\\ansicpg1252\\deff0\\uc1\n"
        out += "{\\fonttbl"
        out += "{\\f0\\f" + family(document.bodyFont) + "\\fcharset0 " + escape(bodyFont) + ";}"
        out += "{\\f1\\f" + family(document.headingFont) + "\\fcharset0 " + escape(headingFont) + ";}"
        out += "{\\f2\\fswiss\\fcharset0 " + ExportFonts.complexScriptFont + ";}"
        out += "}\n"
        out += "{\\colortbl;"
        out += color(accent) + color(ink) + color(muted)
        out += "}\n"
        out += "{\\info{\\title " + escape(document.title) + "}{\\author " + escape(document.author) + "}}\n"
        out += "\\paperw\(paperW)\\paperh\(paperH)\\margl\(side)\\margr\(side)\\margt\(top)\\margb\(bottom)\n"
        out += "\\widowctrl\\viewkind4\n"

        // Colour indexes: 1 accent, 2 ink, 3 muted.
        let spacing: String = "\\sl\(lineSpacing)\\slmult1"
        var previous: ExportBlock.Kind? = nil

        for block in document.blocks {
            let rtl: Bool = block.isRightToLeft
            let direction: String = rtl ? "\\rtlpar\\qr" : "\\ltrpar\\ql"
            var paragraph: String = ""
            switch block.kind {
            case .name:
                paragraph = "\\pard\\plain" + direction + "\\sa40\\keepn\\f1\\fs\(name)\\b\\cf2 " + runs(block.runs, mutedColor: 3) + "\\par\n"
            case .subtitle:
                paragraph = "\\pard\\plain" + direction + "\\sa60\\keepn\\f0\\fs\(halfPoints(document.bodySize * 1.1))\\cf1 " + runs(block.runs, mutedColor: 3) + "\\par\n"
            case .contact:
                paragraph = "\\pard\\plain" + direction + "\\sa200\\f0\\fs\(small)\\cf3 " + runs(block.runs, mutedColor: 3) + "\\par\n"
            case .heading:
                let caps: String = document.uppercaseHeadings ? "\\caps" : ""
                paragraph = "\\pard\\plain" + direction + "\\sb280\\sa100\\keepn\\brdrb\\brdrs\\brdrw10\\brsp20\\brdrcf1 \\f1\\fs\(heading)\\b\(caps)\\cf1 " + runs(block.runs, mutedColor: 3) + "\\par\n"
            case .entryTitle:
                let before: Int = previous == .heading ? 0 : 160
                paragraph = "\\pard\\plain" + direction + "\\sb\(before)\\sa0\\keepn\\f0\\fs\(body)\\b\\cf2 " + runs(block.runs, mutedColor: 3) + "\\par\n"
            case .entryMeta:
                paragraph = "\\pard\\plain" + direction + "\\sa40\\keepn\\f0\\fs\(body)\\cf2 " + runs(block.runs, mutedColor: 3) + "\\par\n"
            case .entryNote:
                paragraph = "\\pard\\plain" + direction + "\\sa40\\f0\\fs\(small)\\i\\cf3 " + runs(block.runs, mutedColor: 3) + "\\par\n"
            case .paragraph:
                paragraph = "\\pard\\plain" + direction + spacing + "\\sa120\\f0\\fs\(body)\\cf2 " + runs(block.runs, mutedColor: 3) + "\\par\n"
            case .line, .signature:
                paragraph = "\\pard\\plain" + direction + spacing + "\\sa0\\f0\\fs\(body)\\cf2 " + runs(block.runs, mutedColor: 3) + "\\par\n"
            case .bullet:
                // Hanging indent: the bullet sits at the margin, wrapped lines line up with the text.
                let indent: String = rtl ? "\\ri360\\fi-240" : "\\li360\\fi-240"
                paragraph = "\\pard\\plain" + direction + spacing + indent + "\\tx360\\sa40\\f0\\fs\(body)\\cf2 {\\cf1\\b \\u8226?}\\tab " + runs(block.runs, mutedColor: 3) + "\\par\n"
            case .gap:
                paragraph = "\\pard\\plain\\sa0\\f0\\fs\(body)\\par\n"
            }
            out += paragraph
            previous = block.kind
        }
        out += "}\n"
        return out
    }

    // MARK: Pieces

    private static func runs(_ runs: [ExportRun], mutedColor: Int) -> String {
        var out: String = ""
        for run in runs where !run.text.isEmpty {
            var open: String = ""
            if run.bold { open += "\\b" }
            if run.italic { open += "\\i" }
            if run.muted { open += "\\cf\(mutedColor)" }
            if RenderTextDirection.containsRTL(run.text) { open += "\\rtlch\\f2" }
            let body: String = escape(run.text)
            if open.isEmpty {
                out += body
            } else {
                out += "{" + open + " " + body + "}"
            }
        }
        return out
    }

    private static func color(_ c: (Int, Int, Int)) -> String {
        return "\\red\(c.0)\\green\(c.1)\\blue\(c.2);"
    }

    private static func family(_ choice: FontChoice) -> String {
        if choice == .menlo { return "modern" }
        return ExportFonts.isSerif(choice) ? "roman" : "swiss"
    }

    static func halfPoints(_ points: Double) -> Int {
        return max(12, Int((points * 2).rounded()))
    }

    static func twips(_ points: Double) -> Int {
        return Int((points * 20).rounded())
    }

    /// Escapes text for an RTF body. Backslash and braces get a backslash, line breaks become \line,
    /// tabs become \tab, and every character outside printable ASCII becomes \uN? with N as a signed
    /// 16-bit number (characters outside the BMP are written as their two UTF-16 halves).
    static func escape(_ text: String) -> String {
        var out: String = ""
        out.reserveCapacity(text.utf16.count)
        for unit in text.utf16 {
            switch unit {
            case 0x5C:
                out += "\\\\"
            case 0x7B:
                out += "\\{"
            case 0x7D:
                out += "\\}"
            case 0x0A, 0x2028:
                out += "\\line "
            case 0x0D:
                continue
            case 0x09:
                out += "\\tab "
            case 0x20...0x7E:
                out.unicodeScalars.append(Unicode.Scalar(UInt8(unit)))
            case 0x00...0x1F, 0x7F:
                continue
            default:
                let signed: Int = unit > 0x7FFF ? Int(unit) - 0x10000 : Int(unit)
                out += "\\u\(signed)?"
            }
        }
        return out
    }
}
