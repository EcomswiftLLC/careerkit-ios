import XCTest
@testable import CareerKit

final class AdsFileNameTests: XCTestCase {
    func testStripsForbiddenCharacters() {
        XCTAssertEqual(ExportFileName.sanitized("a/b\\c:d?e*f\"g<h>i|j"), "abcdefghij")
    }

    func testKeepsNormalNames() {
        XCTAssertEqual(ExportFileName.sanitized("Jane Doe Resume"), "Jane Doe Resume")
        XCTAssertEqual(ExportFileName.sanitized("Résumé 2026"), "Résumé 2026")
    }

    func testTrimsWhitespaceAndDots() {
        XCTAssertEqual(ExportFileName.sanitized("  Jane Doe  "), "Jane Doe")
        XCTAssertEqual(ExportFileName.sanitized("..hidden.."), "hidden")
    }

    func testCollapsesRepeatedSpacesAndLineBreaks() {
        XCTAssertEqual(ExportFileName.sanitized("Jane   Doe\nResume\tv2"), "Jane Doe Resume v2")
    }

    func testFallbackWhenNothingLeft() {
        XCTAssertEqual(ExportFileName.sanitized(""), "Resume")
        XCTAssertEqual(ExportFileName.sanitized("   "), "Resume")
        XCTAssertEqual(ExportFileName.sanitized("///???"), "Resume")
        XCTAssertEqual(ExportFileName.sanitized("..."), "Resume")
    }

    func testLengthIsLimited() {
        let long = String(repeating: "a", count: 500)
        XCTAssertLessThanOrEqual(ExportFileName.sanitized(long).count, ExportFileName.maxLength)
    }

    func testPDFFileNameAddsExtension() {
        XCTAssertEqual(ExportFileName.pdfFileName(for: "Jane/Doe"), "JaneDoe.pdf")
        XCTAssertEqual(ExportFileName.pdfFileName(for: ""), "Resume.pdf")
    }

    func testWriterUsesExactFileName() throws {
        let data = Data("%PDF-1.4 test".utf8)
        let written = try ExportFileWriter.write(pdfData: data, baseName: "My: Resume?")
        defer { try? FileManager.default.removeItem(at: written.directory) }
        XCTAssertEqual(written.url.lastPathComponent, "My Resume.pdf")
        XCTAssertEqual(try Data(contentsOf: written.url), data)
    }
}

final class AdsConfigurationTests: XCTestCase {
    func testNormalizedUnitID() {
        XCTAssertNil(AdsConfiguration.normalizedUnitID(nil))
        XCTAssertNil(AdsConfiguration.normalizedUnitID(42))
        XCTAssertNil(AdsConfiguration.normalizedUnitID(""))
        XCTAssertNil(AdsConfiguration.normalizedUnitID("   "))
        XCTAssertNil(AdsConfiguration.normalizedUnitID("$(ADMOB_BANNER_UNIT_ID)"))
        XCTAssertEqual(
            AdsConfiguration.normalizedUnitID(" ca-app-pub-3940256099942544/2435281174 \n"),
            "ca-app-pub-3940256099942544/2435281174"
        )
    }

    func testReleaseBuildsHaveNoTestDevices() {
        #if !DEBUG
        XCTAssertTrue(AdsConfiguration.testDeviceIdentifiers.isEmpty)
        #endif
    }
}

final class AdsRetryPolicyTests: XCTestCase {
    func testBackoffDoublesAndIsCapped() {
        let policy = RewardedRetryPolicy(baseDelay: 4, maxDelay: 20, maxAutomaticRetries: 5)
        XCTAssertEqual(policy.delay(afterFailure: 1), 4)
        XCTAssertEqual(policy.delay(afterFailure: 2), 8)
        XCTAssertEqual(policy.delay(afterFailure: 3), 16)
        XCTAssertEqual(policy.delay(afterFailure: 4), 20)
        XCTAssertEqual(policy.delay(afterFailure: 5), 20)
    }

    func testStopsAfterMaximumRetries() {
        let policy = RewardedRetryPolicy()
        XCTAssertNil(policy.delay(afterFailure: 0))
        XCTAssertNotNil(policy.delay(afterFailure: policy.maxAutomaticRetries))
        XCTAssertNil(policy.delay(afterFailure: policy.maxAutomaticRetries + 1))
    }

    func testDefaultDelaysNeverExceedCap() {
        let policy = RewardedRetryPolicy()
        for attempt in 1...policy.maxAutomaticRetries {
            XCTAssertLessThanOrEqual(policy.delay(afterFailure: attempt) ?? 0, policy.maxDelay)
        }
    }
}
