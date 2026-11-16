import XCTest
import PDFKit
@testable import CareerKit

/// Page footers on pages 2 and later, and link annotation geometry.
final class EngineFooterAndLinkTests: XCTestCase {
    private func compact(_ text: String?) -> String {
        return (text ?? "").filter { !$0.isWhitespace }
    }

    // MARK: Footer text and geometry

    func testFooterTextRules() {
        XCTAssertNil(RenderPageFooter.text(name: "Ada Park", page: 1, of: 1))
        XCTAssertNil(RenderPageFooter.text(name: "Ada Park", page: 1, of: 3), "page 1 never has a footer")
        XCTAssertEqual(RenderPageFooter.text(name: "  Ada Park ", page: 2, of: 3), "Ada Park  \u{00B7}  2 / 3")
        XCTAssertEqual(RenderPageFooter.text(name: "", page: 3, of: 3), "3 / 3")
        XCTAssertNil(RenderPageFooter.text(name: "Ada Park", page: 4, of: 3))
        let text = RenderPageFooter.text(name: "Ada Park", page: 2, of: 2) ?? ""
        XCTAssertFalse(text.contains("\u{2014}"), "no em dashes")
    }

    func testFooterFrameStaysInsideTheBottomMargin() {
        for margin in [18.0, 24.0, 36.0, 72.0] as [CGFloat] {
            let pageHeight: CGFloat = 842
            let contentBottom: CGFloat = pageHeight - margin
            let rect = RenderPageFooter.frame(columnLeft: 40, columnWidth: 400, contentBottom: contentBottom,
                                              pageHeight: pageHeight, lineHeight: 10)
            XCTAssertGreaterThan(rect.minY, contentBottom, "margin \(margin)")
            XCTAssertLessThanOrEqual(rect.maxY, pageHeight, "margin \(margin)")
            XCTAssertEqual(rect.minX, 40)
            XCTAssertEqual(rect.width, 400)
        }
    }

    func testRemovingFooterLeavesOnlyOtherText() {
        let footer = "Ada Park  \u{00B7}  2 / 3"
        XCTAssertTrue(RenderPageFooter.removingFooter(footer, from: "Ada Park \u{00B7} 2 / 3\n").isEmpty)
        XCTAssertFalse(RenderPageFooter.removingFooter(footer, from: "Experience\nAda Park \u{00B7} 2 / 3").isEmpty)
    }

    // MARK: Footer in real documents

    func testMultiPageResumeHasFootersFromPageTwo() throws {
        let longCase = try XCTUnwrap(EngineFixtures.cases().first(where: { $0.name == "long cv" }))
        let name: String = longCase.resume.personal.fullName
        for spec in EngineFixtures.specs {
            let doc = DocumentRenderer.render(longCase.resume, template: spec)
            XCTAssertGreaterThanOrEqual(doc.pageCount, 2, spec.id)
            let pdf = try XCTUnwrap(PDFDocument(data: doc.pdfData), spec.id)
            let first = compact(pdf.page(at: 0)?.string)
            XCTAssertFalse(first.contains("1/\(doc.pageCount)"), "page 1 has no footer in \(spec.id)")
            for index in 1..<pdf.pageCount {
                let text = compact(pdf.page(at: index)?.string)
                XCTAssertTrue(text.contains("\(index + 1)/\(doc.pageCount)"), "page \(index + 1) footer missing in \(spec.id)")
                if !name.isEmpty {
                    XCTAssertTrue(text.contains(name.filter { !$0.isWhitespace }), "name missing on page \(index + 1) in \(spec.id)")
                }
            }
            // The footer text must not upset the validator.
            let report = PDFValidator.validate(doc, resume: longCase.resume)
            XCTAssertTrue(report.passed, "\(spec.id): \(report.issues.joined(separator: " | "))")
        }
    }

    func testOnePageResumeHasNoFooter() throws {
        let tiny = try XCTUnwrap(EngineFixtures.cases().first(where: { $0.name == "very short" }))
        let doc = DocumentRenderer.render(tiny.resume, template: EngineFixtures.specs[0])
        XCTAssertEqual(doc.pageCount, 1)
        let text = compact(PDFValidator.extractText(from: doc.pdfData))
        XCTAssertFalse(text.contains("1/1"))
    }

    func testMultiPageLetterHasFootersFromPageTwo() throws {
        let letter = EngineFixtures.letter(long: true)
        for spec in EngineFixtures.coverLetterSpecs() {
            let doc = CoverLetterRenderer.render(letter, template: spec)
            XCTAssertGreaterThanOrEqual(doc.pageCount, 2, spec.id)
            let pdf = try XCTUnwrap(PDFDocument(data: doc.pdfData), spec.id)
            XCTAssertFalse(compact(pdf.page(at: 0)?.string).contains("1/\(doc.pageCount)"), spec.id)
            let second = compact(pdf.page(at: 1)?.string)
            XCTAssertTrue(second.contains("2/\(doc.pageCount)"), "letter footer missing in \(spec.id)")
        }
    }

    func testFooterDoesNotOverlapContent() throws {
        let longCase = try XCTUnwrap(EngineFixtures.cases().first(where: { $0.name == "long cv" }))
        let doc = DocumentRenderer.render(longCase.resume, template: EngineFixtures.specs[0])
        let pdf = try XCTUnwrap(PDFDocument(data: doc.pdfData))
        let page = try XCTUnwrap(pdf.page(at: 1))
        let box = page.bounds(for: .mediaBox)
        let counter = "2 / \(doc.pageCount)"
        let found = try XCTUnwrap(pdf.findString(counter, withOptions: []).first(where: { $0.pages.first == page }),
                                  "counter not found on page 2")
        let footerRect = found.bounds(for: page)
        // PDF space has its origin at the bottom left: the footer sits in the lowest band of the page.
        XCTAssertGreaterThanOrEqual(footerRect.minY, box.minY)
        XCTAssertLessThan(footerRect.maxY, box.minY + 72, "footer should be inside the bottom margin")
        // Nothing else on the page is drawn at or below the footer's top.
        let below = page.selection(for: CGRect(x: box.minX, y: box.minY, width: box.width, height: max(0, footerRect.maxY - box.minY)))
        let belowText = compact(below?.string)
        let footerText = compact(RenderPageFooter.text(name: longCase.resume.personal.fullName, page: 2, of: doc.pageCount))
        XCTAssertTrue(footerText.contains(belowText) || belowText.isEmpty, "unexpected text near the footer: \(belowText)")
    }

    // MARK: Link annotations

    func testLinkRectanglesLieInsideThePageOverTheirText() throws {
        let resume = EngineFixtures.resume("Links", person: EngineFixtures.person("Linked Person"), sections: [
            EngineFixtures.section(.summary, text: "Portfolio at https://example.com/work for review.")
        ])
        let doc = DocumentRenderer.render(resume, template: EngineFixtures.specs[0])
        let pdf = try XCTUnwrap(PDFDocument(data: doc.pdfData))
        let page = try XCTUnwrap(pdf.page(at: 0))
        let box = page.bounds(for: .mediaBox)

        var bodyLinkText = ""
        var mailText = ""
        var checked = 0
        for annotation in page.annotations {
            guard let action = annotation.action as? PDFActionURL, let url = action.url else { continue }
            let rect = annotation.bounds
            XCTAssertTrue(box.insetBy(dx: -1, dy: -1).contains(rect), "\(url) rect \(rect) is outside the page \(box)")
            XCTAssertGreaterThan(rect.width, 1)
            XCTAssertGreaterThan(rect.height, 1)
            let covered = page.selection(for: rect)?.string ?? ""
            XCTAssertFalse(covered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           "\(url) rect \(rect) does not sit over any text")
            if url.absoluteString.contains("example.com/work") { bodyLinkText += covered }
            if url.scheme == "mailto" { mailText += covered }
            checked += 1
        }
        XCTAssertGreaterThan(checked, 0)
        XCTAssertTrue(bodyLinkText.lowercased().contains("example.com"), "body link covers: \(bodyLinkText)")
        XCTAssertTrue(mailText.contains("@"), "mail link covers: \(mailText)")
    }
}
