import Foundation

/// The result of laying out a document. The same data feeds the live preview and the export.
struct RenderedDocument {
    let pdfData: Data
    let pageCount: Int
    let pageSize: PageSize
}

/// Outcome of checking a rendered PDF against the resume it came from.
struct PDFValidationReport {
    let passed: Bool
    let issues: [String]
    let extractedText: String
    let pageCount: Int
}
