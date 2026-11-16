import Foundation
import PDFKit

/// Checks a rendered PDF against the resume it came from. It opens the PDF the way a reader would,
/// extracts the text and looks for the content that should be there.
enum PDFValidator {
    static func extractText(from pdfData: Data) -> String {
        guard let document = PDFDocument(data: pdfData) else { return "" }
        return document.string ?? ""
    }

    static func validate(_ doc: RenderedDocument, resume: Resume) -> PDFValidationReport {
        guard let pdf = PDFDocument(data: doc.pdfData) else {
            return PDFValidationReport(passed: false,
                                       issues: [String(localized: "The PDF could not be opened.")],
                                       extractedText: "",
                                       pageCount: 0)
        }
        var issues: [String] = []
        let text: String = pdf.string ?? ""
        let pages: Int = pdf.pageCount
        let expected: [String] = RenderContent.expectedStrings(for: resume)

        if pages != doc.pageCount {
            issues.append(String(localized: "The PDF has \(pages) pages but \(doc.pageCount) were expected."))
        }
        if pages == 0 {
            issues.append(String(localized: "The PDF has no pages."))
        }

        // Page size.
        let wanted: CGSize = doc.pageSize.size
        for index in 0..<pages {
            guard let page = pdf.page(at: index) else { continue }
            let box: CGRect = page.bounds(for: .mediaBox)
            if abs(box.width - wanted.width) > 1 || abs(box.height - wanted.height) > 1 {
                issues.append(String(localized: "Page \(index + 1) is not \(doc.pageSize.displayName) size."))
                break
            }
        }

        // Blank pages (only when the resume has something to show).
        if !expected.isEmpty {
            for index in 0..<pages {
                guard let page = pdf.page(at: index) else { continue }
                var pageText: String = (page.string ?? "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                // The page footer ("Name · 2 / 3") alone does not make a page non-blank.
                if let footer = RenderPageFooter.text(name: resume.personal.fullName, page: index + 1, of: pages) {
                    pageText = RenderPageFooter.removingFooter(footer, from: pageText)
                }
                if pageText.isEmpty {
                    issues.append(String(localized: "Page \(index + 1) has no text."))
                }
            }
        }

        if text.contains("\u{FFFD}") {
            issues.append(String(localized: "The PDF text contains characters that could not be read."))
        }

        // Content.
        let haystack: String = normalise(text)
        var missing: [String] = []
        for value in expected where !appears(value, in: haystack) {
            missing.append(value)
        }
        let shown: Int = min(missing.count, 10)
        for value in missing.prefix(shown) {
            issues.append(String(localized: "Not found in the PDF text: \(abbreviate(value))"))
        }
        if missing.count > shown {
            issues.append(String(localized: "\(missing.count - shown) more items were not found."))
        }

        return PDFValidationReport(passed: issues.isEmpty, issues: issues, extractedText: text, pageCount: pages)
    }

    // MARK: Helpers

    private static func abbreviate(_ value: String) -> String {
        let flat: String = value.replacingOccurrences(of: "\n", with: " ")
        if flat.count <= 60 { return flat }
        return String(flat.prefix(57)) + "..."
    }

    /// Core Text can write Arabic with the dots of a letter as separate marks, so extraction returns the
    /// dotless base shape. Letters that share a base shape compare as equal, and anything outside the
    /// Arabic block is returned unchanged.
    static func arabicSkeleton(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        let mapped: UInt32
        switch scalar.value {
        case 0x0628, 0x062A, 0x062B, 0x0646, 0x064A, 0x0649, 0x0626, 0x067E, 0x0679, 0x06CC, 0x06D2, 0x066E:
            mapped = 0x066E
        case 0x0641, 0x0642, 0x06A1, 0x066F:
            mapped = 0x06A1
        case 0x062C, 0x062E, 0x0686:
            mapped = 0x062D
        case 0x0630: mapped = 0x062F
        case 0x0632, 0x0698: mapped = 0x0631
        case 0x0634: mapped = 0x0633
        case 0x0636: mapped = 0x0635
        case 0x0638: mapped = 0x0637
        case 0x063A: mapped = 0x0639
        case 0x0629: mapped = 0x0647
        default: return scalar
        }
        return Unicode.Scalar(mapped) ?? scalar
    }

    /// Case, spacing, ligatures and width forms are ignored so layout choices cannot cause false alarms.
    static func normalise(_ raw: String) -> String {
        let folded: String = raw.precomposedStringWithCompatibilityMapping.lowercased()
        var scalars = String.UnicodeScalarView()
        for scalar in folded.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) { continue }
            switch scalar.value {
            case 0x00AD, 0x200B, 0x200C, 0x200D, 0x200E, 0x200F, 0x2060, 0xFEFF,
                 0x202A...0x202E, 0x2066...0x2069:
                continue
            // Some fonts draw Arabic letters with Persian or Urdu shaped glyphs, and compatibility
            // folding then returns those code points. They are the same letters to a reader.
            case 0x06CC, 0x06D2:
                scalars.append(Unicode.Scalar(0x064A)!)
            case 0x06A9:
                scalars.append(Unicode.Scalar(0x0643)!)
            case 0x06BE, 0x06C1:
                scalars.append(Unicode.Scalar(0x0647)!)
            default:
                scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    /// `haystack` must already be passed through `normalise`.
    static func appears(_ expected: String, in haystack: String) -> Bool {
        let needle: String = normalise(expected)
        if needle.isEmpty { return true }
        if haystack.contains(needle) { return true }

        // PDFKit reads right to left runs in visual order: words come back reversed, marks detach from
        // their letters, and a phone number in a right-aligned header reads "014-2290 )555( 1+".
        // Accept the reversed text, and compare scalars so detached marks still match.
        if haystack.contains(String(needle.reversed())) { return true }
        if RenderTextDirection.containsRTL(expected) {
            let available: Set<Unicode.Scalar> = Set(haystack.unicodeScalars)
            let skeleton: Set<Unicode.Scalar> = Set(haystack.unicodeScalars.map { arabicSkeleton($0) })
            return needle.unicodeScalars.allSatisfy { scalar in
                available.contains(scalar) || skeleton.contains(arabicSkeleton(scalar))
            }
        }

        // Columns can interleave lines in extraction. Fall back to checking each word, in either direction.
        let words: [String] = expected
            .split(whereSeparator: { $0.isWhitespace })
            .map { normalise(String($0)) }
            .filter { !$0.isEmpty }
        if words.count > 1 {
            return words.allSatisfy { haystack.contains($0) || haystack.contains(String($0.reversed())) }
        }
        return false
    }
}
