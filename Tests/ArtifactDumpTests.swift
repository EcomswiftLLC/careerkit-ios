import XCTest
import PDFKit
@testable import CareerKit

/// Writes real PDFs for human review when CAREERKIT_DUMP_DIR is set (CI sets it).
/// Does nothing during normal local test runs.
final class ArtifactDumpTests: XCTestCase {
    private var dumpDirectory: URL? {
        guard let path = ProcessInfo.processInfo.environment["CAREERKIT_DUMP_DIR"], !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testDumpSampleResumesAndLetters() throws {
        guard let dir = dumpDirectory else { throw XCTSkip("CAREERKIT_DUMP_DIR not set") }
        var summary: [String] = []

        for template in TemplateLibrary.all {
            let resume: Resume = SampleContent.resume(for: template)
            let doc: RenderedDocument = DocumentRenderer.render(resume, template: template)
            try doc.pdfData.write(to: dir.appendingPathComponent("resume-\(template.id).pdf"))
            let report: PDFValidationReport = PDFValidator.validate(doc, resume: resume)
            summary.append("\(template.id)\tpages=\(doc.pageCount)\ttypical=\(template.typicalPages)\tvalid=\(report.passed)\t\(report.issues.joined(separator: " | "))")
            if !report.passed {
                try report.extractedText.write(to: dir.appendingPathComponent("text-\(template.id).txt"), atomically: true, encoding: .utf8)
            }
        }

        let letter: CoverLetter = SampleContent.coverLetter()
        for template in CoverLetterTemplateLibrary.all {
            var copy: CoverLetter = letter
            copy.templateID = template.id
            let doc: RenderedDocument = CoverLetterRenderer.render(copy, template: template)
            try doc.pdfData.write(to: dir.appendingPathComponent("letter-\(template.id).pdf"))
            summary.append("\(template.id)\tpages=\(doc.pageCount)")
        }

        // Stress cases that failed in the first run, with the extracted text for diagnosis.
        let specs: [TemplateSpec] = EngineFixtures.specs
        for testCase in EngineFixtures.cases() {
            for spec in specs {
                let doc: RenderedDocument = DocumentRenderer.render(testCase.resume, template: spec)
                let report: PDFValidationReport = PDFValidator.validate(doc, resume: testCase.resume)
                if !report.passed || doc.pageCount > testCase.maxPages {
                    let safe: String = (testCase.name + "-" + spec.id).replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "/", with: "_")
                    try doc.pdfData.write(to: dir.appendingPathComponent("stress-\(safe).pdf"))
                    try report.extractedText.write(to: dir.appendingPathComponent("stress-\(safe).txt"), atomically: true, encoding: .utf8)
                }
            }
        }

        try summary.joined(separator: "\n").write(to: dir.appendingPathComponent("summary.tsv"), atomically: true, encoding: .utf8)
    }
}
