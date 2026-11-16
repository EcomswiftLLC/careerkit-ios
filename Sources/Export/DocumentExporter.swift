import Foundation

enum DocumentExportError: Error {
    case emptyOutput
}

/// The one entry point for every export format. Takes the same models and templates as the PDF renderer
/// and returns the file bytes. Pure and safe to call from a background task.
enum DocumentExporter {
    /// `language` sets the fixed words and date formats of text formats; it defaults to the app language.
    static func export(_ source: ExportSource, as format: DocumentExportFormat, date: Date = Date(),
                       language: String = ExportStrings.currentLanguage) throws -> Data {
        let data: Data
        switch format {
        case .pdf:
            data = renderPDF(source).pdfData
        case .docx:
            data = DocxWriter.data(ExportDocumentBuilder.build(source, language: language), date: date)
        case .rtf:
            data = RTFExporter.data(ExportDocumentBuilder.build(source, language: language))
        case .txt:
            data = PlainTextExporter.data(ExportDocumentBuilder.build(source, language: language))
        case .html:
            data = HTMLExporter.data(ExportDocumentBuilder.build(source, language: language))
        }
        guard !data.isEmpty else { throw DocumentExportError.emptyOutput }
        return data
    }

    static func export(resume: Resume, template: TemplateSpec, as format: DocumentExportFormat) throws -> Data {
        return try export(.resume(resume, template), as: format)
    }

    static func export(letter: CoverLetter, template: CoverLetterTemplateSpec, as format: DocumentExportFormat) throws -> Data {
        return try export(.coverLetter(letter, template), as: format)
    }

    static func renderPDF(_ source: ExportSource) -> RenderedDocument {
        switch source {
        case .resume(let resume, let template):
            return DocumentRenderer.render(resume, template: template)
        case .coverLetter(let letter, let template):
            return CoverLetterRenderer.render(letter, template: template)
        }
    }
}

extension ExportSource {
    /// The source for a resume, using the same template lookup as the editor preview.
    static func forResume(_ resume: Resume) -> ExportSource {
        return .resume(resume, EditorRender.template(id: resume.templateID))
    }

    /// The source for a cover letter, using the same template lookup as the editor preview.
    static func forCoverLetter(_ letter: CoverLetter) -> ExportSource {
        return .coverLetter(letter, EditorRender.coverTemplate(id: letter.templateID))
    }
}
