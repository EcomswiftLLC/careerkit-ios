import Foundation

/// Plain UTF-8 text for online application forms and applicant tracking systems.
/// Headings are in capitals with a rule under them, list items start with "- ", links are written out.
enum PlainTextExporter {
    static let bulletPrefix = "- "

    static func text(_ document: ExportDocument) -> String {
        var lines: [String] = []
        var previous: ExportBlock.Kind? = nil

        func blankLine() {
            if let last = lines.last, !last.isEmpty {
                lines.append("")
            }
        }

        for block in document.blocks {
            let text: String = clean(block.plainText)
            switch block.kind {
            case .gap:
                blankLine()
            case .heading:
                guard !text.isEmpty else { continue }
                blankLine()
                let upper: String = text.uppercased()
                lines.append(upper)
                lines.append(String(repeating: "-", count: max(3, min(upper.count, 60))))
            case .entryTitle:
                guard !text.isEmpty else { continue }
                if previous != .heading { blankLine() }
                lines.append(text)
            case .paragraph:
                guard !text.isEmpty else { continue }
                let tight: [ExportBlock.Kind] = [.heading, .entryTitle, .entryMeta, .entryNote, .line]
                if let last = previous, tight.contains(last) {
                    // Directly under a heading or entry, or the last line of a tight block.
                } else {
                    blankLine()
                }
                lines.append(text)
            case .line:
                guard !text.isEmpty else { continue }
                if previous == .paragraph || previous == .bullet { blankLine() }
                lines.append(text)
            case .bullet:
                guard !text.isEmpty else { continue }
                lines.append(bulletPrefix + text)
            case .name, .subtitle, .contact, .entryMeta, .entryNote, .signature:
                guard !text.isEmpty else { continue }
                lines.append(text)
            }
            previous = block.kind
        }
        while let last = lines.last, last.isEmpty {
            lines.removeLast()
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func data(_ document: ExportDocument) -> Data {
        return Data(text(document).utf8)
    }

    /// Drops control characters except tab, and turns line breaks inside one block into spaces.
    static func clean(_ raw: String) -> String {
        var out = String.UnicodeScalarView()
        for scalar in raw.unicodeScalars {
            let v: UInt32 = scalar.value
            if v == 0x0A || v == 0x0D || v == 0x2028 || v == 0x2029 {
                out.append(Unicode.Scalar(UInt8(0x20)))
            } else if v == 0x09 {
                out.append(scalar)
            } else if v < 0x20 || (v >= 0x7F && v < 0xA0) || v == 0xFFFE || v == 0xFFFF {
                continue
            } else {
                out.append(scalar)
            }
        }
        return String(out).trimmingCharacters(in: CharacterSet.whitespaces)
    }
}
