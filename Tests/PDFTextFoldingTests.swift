import XCTest
@testable import CareerKit

/// PDFKit returns some Chinese text as radicals and splits hyphenated words across lines; the checks must still match.
final class PDFTextFoldingTests: XCTestCase {
    func testSimplifiedRadicalsFoldToTheOrdinaryCharacter() {
        // U+2ED3 is the simplified radical for 长; U+2F0B (Kangxi) is 八.
        XCTAssertEqual(CJKText.foldingRadicals("擅\u{2ED3}"), "擅长")
        XCTAssertEqual(CJKText.foldingRadicals("\u{2F0B}年"), "八年")
        XCTAssertEqual(CJKText.foldingRadicals("\u{2EE4}"), "\u{2EE4}", "an unmapped radical is left alone")
    }

    func testValidatorMatchesRadicalText() {
        let haystack: String = PDFValidator.normalise("\u{2F0B}年后端开发经验，擅\u{2ED3}性能优化。")
        XCTAssertTrue(PDFValidator.appears("八年后端开发经验，擅长性能优化。", in: haystack))
    }

    func testValidatorAcceptsAHyphenatedWordSplitByExtraction() {
        let extracted: String = PDFValidator.normalise("Profil\nups.\nBerufserfahrung\nMärz 2021 Digitale Dienste für Banken und Start-\n")
        XCTAssertTrue(PDFValidator.appears("Digitale Dienste für Banken und Start-ups.", in: extracted))
    }

    func testValidatorStillRejectsMissingText() {
        let extracted: String = PDFValidator.normalise("Digitale Dienste für Banken")
        XCTAssertFalse(PDFValidator.appears("Digitale Dienste für Behörden und Start-ups.", in: extracted))
    }
}
