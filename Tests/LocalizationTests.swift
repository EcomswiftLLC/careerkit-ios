import XCTest
@testable import CareerKit

/// Checks the String Catalog that ships with the app and that the compiled bundle really serves each language.
final class LocalizationTests: XCTestCase {
    private static let languages = ["es", "fr", "de", "zh-Hans"]

    private struct Catalog {
        let strings: [String: [String: Any]]
    }

    private func loadCatalog() throws -> Catalog {
        // #filePath is the real path of this file on the machine that compiled the tests (CI checkout or a Mac).
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let url = testsDir.deletingLastPathComponent().appendingPathComponent("Sources/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: [String: Any]])
        return Catalog(strings: strings)
    }

    private func values(_ entry: Any?) -> [String] {
        guard let dict = entry as? [String: Any] else { return [] }
        if let unit = dict["stringUnit"] as? [String: Any], let value = unit["value"] as? String { return [value] }
        if let variations = dict["variations"] as? [String: Any],
           let plural = variations["plural"] as? [String: Any] {
            return plural.values.compactMap { (($0 as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String }
        }
        return []
    }

    private func specifiers(_ text: String) -> [String] {
        let pattern = "%(?:\\d+\\$)?(?:lld|ld|d|@|f|lf|s)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range).replacingOccurrences(of: "\\d+\\$", with: "", options: .regularExpression) }
            .sorted()
    }

    func testEveryKeyIsTranslatedIntoAllFourLanguages() throws {
        let catalog = try loadCatalog()
        XCTAssertGreaterThan(catalog.strings.count, 300, "the catalog looks empty")
        var gaps: [String] = []
        for (key, entry) in catalog.strings {
            let locs = entry["localizations"] as? [String: Any] ?? [:]
            for lang in Self.languages where values(locs[lang]).isEmpty {
                gaps.append("\(lang): \(key)")
            }
        }
        XCTAssertTrue(gaps.isEmpty, "missing translations (\(gaps.count)): \(gaps.sorted().prefix(25))")
    }

    func testPlaceholdersMatchTheEnglishKey() throws {
        let catalog = try loadCatalog()
        var problems: [String] = []
        for (key, entry) in catalog.strings {
            let locs = entry["localizations"] as? [String: Any] ?? [:]
            let expected = specifiers(key)
            for lang in Self.languages {
                for value in values(locs[lang]) {
                    let got = specifiers(value)
                    // Plural forms such as "one" may legitimately drop the number ("a page"); only compare when present.
                    if got != expected && !(got.isEmpty && expected.count == 1 && value.count > 0 && (locs[lang] as? [String: Any])?["variations"] != nil) {
                        problems.append("\(lang) \(key) -> \(value)")
                    }
                }
            }
        }
        XCTAssertTrue(problems.isEmpty, "placeholder mismatch (\(problems.count)): \(problems.sorted().prefix(20))")
    }

    func testNoTranslationIsIdenticalGarbage() throws {
        // A translation that still contains obvious English UI words in a non-English language usually means a copy-paste miss.
        let catalog = try loadCatalog()
        var suspicious: [String] = []
        for (key, entry) in catalog.strings where key.count > 24 && key.contains(" ") {
            let locs = entry["localizations"] as? [String: Any] ?? [:]
            for lang in ["de", "fr", "es"] {
                if values(locs[lang]).contains(key) { suspicious.append("\(lang): \(key)") }
            }
        }
        XCTAssertLessThan(suspicious.count, 6, "long strings left untranslated: \(suspicious.prefix(10))")
    }

    func testCompiledBundleServesTheLanguages() throws {
        let bundle = Bundle(for: AppState.self)
        let expectations: [(String, String)] = [("de", "Abbrechen"), ("fr", "Annuler"), ("es", "Cancelar"), ("zh-Hans", "取消")]
        for (lang, expected) in expectations {
            guard let path = bundle.path(forResource: lang, ofType: "lproj"), let langBundle = Bundle(path: path) else {
                XCTFail("no \(lang).lproj in the app bundle")
                continue
            }
            let value = langBundle.localizedString(forKey: "Cancel", value: "Cancel", table: nil)
            XCTAssertEqual(value, expected, "\(lang) did not translate Cancel")
        }
    }

    func testInfoPlistStringsAreLocalized() throws {
        let bundle = Bundle(for: AppState.self)
        for lang in Self.languages {
            guard let path = bundle.path(forResource: lang, ofType: "lproj"), let langBundle = Bundle(path: path) else {
                XCTFail("no \(lang).lproj")
                continue
            }
            let value = langBundle.localizedString(forKey: "NSPhotoLibraryUsageDescription", value: "", table: "InfoPlist")
            XCTAssertFalse(value.isEmpty, "\(lang) photo permission text missing")
            XCTAssertNotEqual(value, "CareerKit uses a photo only if you choose one for your resume. Photos stay on your device.")
        }
    }
}
