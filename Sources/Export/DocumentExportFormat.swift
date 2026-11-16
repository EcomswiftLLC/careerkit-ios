import Foundation
import UniformTypeIdentifiers

/// The file types a resume or cover letter can be exported as. Every format goes through the same export gate.
enum DocumentExportFormat: String, CaseIterable, Identifiable, Codable {
    case pdf
    case docx
    case rtf
    case txt
    case html

    var id: String { rawValue }

    /// UserDefaults key for the format the person picked last time.
    static let storageKey = "ck.export.lastFormat.v1"
    static let defaultFormat: DocumentExportFormat = .pdf

    /// Reads a stored raw value, falling back to PDF for missing or unknown values.
    static func stored(_ raw: String?) -> DocumentExportFormat {
        guard let raw = raw, let format = DocumentExportFormat(rawValue: raw) else { return defaultFormat }
        return format
    }

    /// Name shown in the format picker.
    var displayName: String {
        switch self {
        case .pdf: return String(localized: "PDF")
        case .docx: return String(localized: "Word (.docx)")
        case .rtf: return String(localized: "Rich Text (opens in Word)")
        case .txt: return String(localized: "Plain text")
        case .html: return String(localized: "Web page")
        }
    }

    /// One line under the name in the picker.
    var shortDescription: String {
        switch self {
        case .pdf:
            return String(localized: "Keeps your design exactly. Best for most applications.")
        case .docx:
            return String(localized: "Edit it in Word, Pages or Google Docs.")
        case .rtf:
            return String(localized: "A simple file you can edit in Word, Pages or TextEdit.")
        case .txt:
            return String(localized: "Text only, for pasting into online application forms.")
        case .html:
            return String(localized: "One page that opens in any web browser.")
        }
    }

    /// Used inside sentences: "Preparing your Word document".
    var noun: String {
        switch self {
        case .pdf: return String(localized: "PDF")
        case .docx: return String(localized: "Word document")
        case .rtf: return String(localized: "Rich Text file")
        case .txt: return String(localized: "text file")
        case .html: return String(localized: "web page")
        }
    }

    var fileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .docx: return "docx"
        case .rtf: return "rtf"
        case .txt: return "txt"
        case .html: return "html"
        }
    }

    var mimeType: String {
        switch self {
        case .pdf: return "application/pdf"
        case .docx: return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case .rtf: return "application/rtf"
        case .txt: return "text/plain"
        case .html: return "text/html"
        }
    }

    /// The uniform type identifier for the file.
    var utType: UTType {
        switch self {
        case .pdf:
            return UTType.pdf
        case .docx:
            if let type = UTType("org.openxmlformats.wordprocessingml.document") { return type }
            if let type = UTType(filenameExtension: "docx") { return type }
            return UTType.data
        case .rtf:
            return UTType.rtf
        case .txt:
            return UTType.utf8PlainText
        case .html:
            return UTType.html
        }
    }

    /// Only the PDF keeps an exact page layout, so only PDF is offered for printing.
    var supportsPrint: Bool {
        return self == .pdf
    }

    /// SF Symbol for the picker row.
    var systemImage: String {
        switch self {
        case .pdf: return "doc.richtext"
        case .docx: return "doc.text"
        case .rtf: return "doc.plaintext"
        case .txt: return "text.alignleft"
        case .html: return "globe"
        }
    }
}
