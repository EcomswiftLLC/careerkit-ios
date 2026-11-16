import XCTest
import PDFKit
@testable import CareerKit

final class EngineRenderTests: XCTestCase {
    // MARK: Helpers

    private func check(_ testCase: EngineFixtures.Case, spec: TemplateSpec, file: StaticString = #filePath, line: UInt = #line) {
        let label: String = "\(testCase.name) / \(spec.id)"
        let doc: RenderedDocument = DocumentRenderer.render(testCase.resume, template: spec)

        XCTAssertGreaterThanOrEqual(doc.pageCount, 1, label, file: file, line: line)
        XCTAssertGreaterThanOrEqual(doc.pageCount, testCase.minPages, "too few pages: " + label, file: file, line: line)
        XCTAssertLessThanOrEqual(doc.pageCount, testCase.maxPages, "too many pages: " + label, file: file, line: line)
        XCTAssertEqual(doc.pageSize, testCase.resume.pageSize, label, file: file, line: line)

        guard let pdf = PDFDocument(data: doc.pdfData) else {
            XCTFail("PDFKit could not open " + label, file: file, line: line)
            return
        }
        XCTAssertEqual(pdf.pageCount, doc.pageCount, label, file: file, line: line)

        let text: String = PDFValidator.normalise(PDFValidator.extractText(from: doc.pdfData))
        for key in testCase.keys {
            XCTAssertTrue(PDFValidator.appears(key, in: text), "missing '\(key)' in " + label, file: file, line: line)
        }

        let report: PDFValidationReport = PDFValidator.validate(doc, resume: testCase.resume)
        XCTAssertTrue(report.passed, "validator: \(report.issues.joined(separator: " | ")) in " + label, file: file, line: line)
    }

    // MARK: Resumes

    func testEveryFixtureRendersWithRotatingTemplates() {
        let cases = EngineFixtures.cases()
        XCTAssertGreaterThanOrEqual(cases.count, 20)
        let specs = EngineFixtures.specs
        for (i, testCase) in cases.enumerated() {
            let picks: [Int] = [i % specs.count, (i + 5) % specs.count, (i + 8) % specs.count]
            for index in Set(picks).sorted() {
                check(testCase, spec: specs[index])
            }
        }
    }

    func testRichResumeRendersWithEveryTemplate() {
        guard let rich = EngineFixtures.cases().first(where: { $0.name == "one page" }) else {
            XCTFail("fixture missing")
            return
        }
        var withPhoto = rich
        var resume = rich.resume
        resume.personal.photoData = EngineFixtures.photoData()
        withPhoto = EngineFixtures.Case(name: rich.name, resume: resume, keys: rich.keys, minPages: 1, maxPages: 4)
        for spec in EngineFixtures.specs {
            check(withPhoto, spec: spec)
        }
    }

    func testLongCVUsesSeveralPagesAndKeepsEverything() {
        guard let longCase = EngineFixtures.cases().first(where: { $0.name == "long cv" }) else {
            XCTFail("fixture missing")
            return
        }
        for spec in EngineFixtures.specs {
            let doc = DocumentRenderer.render(longCase.resume, template: spec)
            XCTAssertGreaterThanOrEqual(doc.pageCount, 2, spec.id)
            let report = PDFValidator.validate(doc, resume: longCase.resume)
            XCTAssertTrue(report.passed, "\(spec.id): \(report.issues.joined(separator: " | "))")
        }
    }

    func testVeryShortResumeIsOnePage() {
        guard let tiny = EngineFixtures.cases().first(where: { $0.name == "very short" }) else {
            XCTFail("fixture missing")
            return
        }
        for spec in EngineFixtures.specs {
            XCTAssertEqual(DocumentRenderer.render(tiny.resume, template: spec).pageCount, 1, spec.id)
        }
    }

    func testEmptyResumeRendersOneBlankLayoutPage() {
        let empty = Resume(title: "Empty", templateID: "x", sections: [])
        for spec in EngineFixtures.specs {
            let doc = DocumentRenderer.render(empty, template: spec)
            XCTAssertEqual(doc.pageCount, 1, spec.id)
            XCTAssertNotNil(PDFDocument(data: doc.pdfData), spec.id)
            XCTAssertTrue(PDFValidator.validate(doc, resume: empty).passed, spec.id)
        }
    }

    func testHiddenSectionsAreNotInThePDF() {
        guard let hidden = EngineFixtures.cases().first(where: { $0.name == "hidden sections" }) else {
            XCTFail("fixture missing")
            return
        }
        for spec in EngineFixtures.specs {
            let doc = DocumentRenderer.render(hidden.resume, template: spec)
            let text = PDFValidator.extractText(from: doc.pdfData)
            XCTAssertFalse(text.contains("SECRETHIDDEN"), spec.id)
        }
    }

    func testPastedBulletMarkersAreNotDoubled() {
        guard let marked = EngineFixtures.cases().first(where: { $0.name == "pasted bullet markers" }) else {
            XCTFail("fixture missing")
            return
        }
        let doc = DocumentRenderer.render(marked.resume, template: EngineFixtures.specs[0])
        let text = PDFValidator.extractText(from: doc.pdfData)
        XCTAssertFalse(text.contains("\u{2022} \u{2022}"))
        XCTAssertFalse(text.contains("- Cleaned"))
    }

    func testPageSizesMatchTheResume() {
        for size in PageSize.allCases {
            var resume = EngineFixtures.resume("Size", person: EngineFixtures.person("Sized Person"), sections: [
                EngineFixtures.section(.experience, entries: EngineFixtures.jobs(2, bulletsEach: 2))
            ])
            resume.pageSize = size
            let doc = DocumentRenderer.render(resume, template: EngineFixtures.specs[0])
            XCTAssertEqual(doc.pageSize, size)
            guard let page = PDFDocument(data: doc.pdfData)?.page(at: 0) else {
                XCTFail("no page")
                continue
            }
            let box = page.bounds(for: .mediaBox)
            XCTAssertEqual(box.width, size.size.width, accuracy: 1)
            XCTAssertEqual(box.height, size.size.height, accuracy: 1)
        }
    }

    func testMetadataAndLinkAnnotations() {
        let resume = EngineFixtures.resume("Metadata Test", person: EngineFixtures.person("Linked Person"), sections: [
            EngineFixtures.section(.summary, text: "Portfolio at https://example.com/work for review.")
        ])
        let doc = DocumentRenderer.render(resume, template: EngineFixtures.specs[0])
        guard let pdf = PDFDocument(data: doc.pdfData) else {
            XCTFail("could not open")
            return
        }
        let attributes = pdf.documentAttributes ?? [:]
        XCTAssertEqual(attributes[PDFDocumentAttribute.titleAttribute] as? String, "Metadata Test")
        XCTAssertEqual(attributes[PDFDocumentAttribute.authorAttribute] as? String, "Linked Person")

        var targets: [String] = []
        for index in 0..<pdf.pageCount {
            guard let page = pdf.page(at: index) else { continue }
            for annotation in page.annotations {
                if let action = annotation.action as? PDFActionURL, let url = action.url {
                    targets.append(url.absoluteString)
                }
            }
        }
        XCTAssertTrue(targets.contains(where: { $0.hasPrefix("mailto:") }), "no mailto link: \(targets)")
        XCTAssertTrue(targets.contains(where: { $0.hasPrefix("tel:") }), "no tel link: \(targets)")
        XCTAssertTrue(targets.contains(where: { $0.contains("example.com/work") }), "no body link: \(targets)")
    }

    func testRenderingWorksOffTheMainThread() {
        let resume = EngineFixtures.cases()[1].resume
        let done = expectation(description: "rendered")
        DispatchQueue.global(qos: .userInitiated).async {
            let doc = DocumentRenderer.render(resume, template: EngineFixtures.specs[2])
            XCTAssertGreaterThanOrEqual(doc.pageCount, 1)
            done.fulfill()
        }
        wait(for: [done], timeout: 30)
    }

    func testRenderingIsDeterministicInPageCount() {
        let resume = EngineFixtures.cases()[2].resume
        let first = DocumentRenderer.render(resume, template: EngineFixtures.specs[3])
        let second = DocumentRenderer.render(resume, template: EngineFixtures.specs[3])
        XCTAssertEqual(first.pageCount, second.pageCount)
    }

    func testValidatorFlagsMissingContent() {
        let original = EngineFixtures.resume("Original", person: EngineFixtures.person("Original Person"), sections: [
            EngineFixtures.section(.summary, text: "Plain summary text.")
        ])
        let doc = DocumentRenderer.render(original, template: EngineFixtures.specs[0])
        var changed = original
        changed.sections.append(EngineFixtures.section(.experience, entries: [
            EngineFixtures.entry("Zyxwvut Quillfeather Wrangler", bullets: ["Unrendered quixotic achievement"])
        ]))
        let report = PDFValidator.validate(doc, resume: changed)
        XCTAssertFalse(report.passed)
        XCTAssertFalse(report.issues.isEmpty)
    }

    func testValidatorFlagsWrongPageSize() {
        let resume = EngineFixtures.resume("Size", person: EngineFixtures.person("Sized Person"), sections: [])
        let doc = DocumentRenderer.render(resume, template: EngineFixtures.specs[0])
        let lying = RenderedDocument(pdfData: doc.pdfData, pageCount: doc.pageCount, pageSize: .usLetter)
        XCTAssertFalse(PDFValidator.validate(lying, resume: resume).passed)
    }

    // MARK: Cover letters

    func testEveryCoverLetterHeaderLayoutRenders() {
        for spec in EngineFixtures.coverLetterSpecs() {
            for size in PageSize.allCases {
                let letter = EngineFixtures.letter(size: size)
                let doc = CoverLetterRenderer.render(letter, template: spec)
                XCTAssertEqual(doc.pageCount, 1, spec.id)
                guard let pdf = PDFDocument(data: doc.pdfData) else {
                    XCTFail("cannot open \(spec.id)")
                    continue
                }
                let text = PDFValidator.normalise(pdf.string ?? "")
                for key in ["Jordan Whitfield", "Alex Rivera", "Northwind Studio", "Sincerely", "Dear Alex Rivera", "welcome a conversation"] {
                    XCTAssertTrue(PDFValidator.appears(key, in: text), "\(spec.id) missing \(key)")
                }
            }
        }
    }

    func testLongCoverLetterPaginatesWithoutLosingText() {
        for spec in EngineFixtures.coverLetterSpecs() {
            let letter = EngineFixtures.letter(long: true)
            let doc = CoverLetterRenderer.render(letter, template: spec)
            XCTAssertGreaterThanOrEqual(doc.pageCount, 2, spec.id)
            let text = PDFValidator.normalise(PDFValidator.extractText(from: doc.pdfData))
            XCTAssertTrue(PDFValidator.appears("In project 0 I led design work", in: text), spec.id)
            XCTAssertTrue(PDFValidator.appears("In project 59 I led design work", in: text), spec.id)
            XCTAssertTrue(PDFValidator.appears("Sincerely,", in: text), spec.id)
        }
    }

    func testEmptyCoverLetterDoesNotCrash() {
        let letter = CoverLetter(title: "Empty", templateID: "cl.test.0")
        for spec in EngineFixtures.coverLetterSpecs() {
            let doc = CoverLetterRenderer.render(letter, template: spec)
            XCTAssertGreaterThanOrEqual(doc.pageCount, 1)
            XCTAssertNotNil(PDFDocument(data: doc.pdfData))
        }
    }
}
