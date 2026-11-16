import XCTest
@testable import CareerKit

/// The per-document language (`StyleOverrides.language`): resolution rules, tolerant decoding and the word lookup.
final class ResumeLanguageTests: XCTestCase {

    // MARK: Contract

    func testCasesRawValuesAndNativeNames() {
        XCTAssertEqual(ResumeLanguage.allCases, [.en, .es, .fr, .de, .zhHans])
        XCTAssertEqual(ResumeLanguage.allCases.map { $0.rawValue }, ["en", "es", "fr", "de", "zh-Hans"])
        XCTAssertEqual(ResumeLanguage.zhHans.id, "zh-Hans")
        XCTAssertEqual(ResumeLanguage.en.displayName, "English")
        XCTAssertEqual(ResumeLanguage.es.displayName, "Español")
        XCTAssertEqual(ResumeLanguage.fr.displayName, "Français")
        XCTAssertEqual(ResumeLanguage.de.displayName, "Deutsch")
        XCTAssertEqual(ResumeLanguage.zhHans.displayName, "简体中文")
    }

    func testLocaleSpeaksTheLanguage() {
        for language in ResumeLanguage.allCases {
            let code: String = language.locale.language.languageCode?.identifier ?? ""
            let expected: String = language == .zhHans ? "zh" : language.rawValue
            XCTAssertEqual(code, expected, language.rawValue)
        }
    }

    // MARK: Resolution

    func testMatchingMapsCodesToDocumentLanguages() {
        XCTAssertEqual(ResumeLanguage.matching("en"), .en)
        XCTAssertEqual(ResumeLanguage.matching("en-GB"), .en)
        XCTAssertEqual(ResumeLanguage.matching("ES"), .es)
        XCTAssertEqual(ResumeLanguage.matching("es-MX"), .es)
        XCTAssertEqual(ResumeLanguage.matching("fr_CA"), .fr)
        XCTAssertEqual(ResumeLanguage.matching("de-AT"), .de)
        XCTAssertEqual(ResumeLanguage.matching("zh-Hans"), .zhHans)
        XCTAssertEqual(ResumeLanguage.matching("zh-Hant"), .zhHans)
        XCTAssertEqual(ResumeLanguage.matching("zh-Hant-TW"), .zhHans)
        XCTAssertEqual(ResumeLanguage.matching("zh"), .zhHans)
        XCTAssertEqual(ResumeLanguage.matching("zh_CN"), .zhHans)
        // Unsupported languages and junk fall back to English.
        XCTAssertEqual(ResumeLanguage.matching("pt-BR"), .en)
        XCTAssertEqual(ResumeLanguage.matching("ja"), .en)
        XCTAssertEqual(ResumeLanguage.matching("Base"), .en)
        XCTAssertEqual(ResumeLanguage.matching(""), .en)
    }

    func testResolvedKeepsAChoiceAndFollowsTheAppOtherwise() {
        for language in ResumeLanguage.allCases {
            XCTAssertEqual(ResumeLanguage.resolved(language), language)
        }
        let app: String = Bundle.main.preferredLocalizations.first ?? "en"
        let expected: ResumeLanguage = app == "Base"
            ? ResumeLanguage.matching(Locale.preferredLanguages.first ?? "en")
            : ResumeLanguage.matching(app)
        XCTAssertEqual(ResumeLanguage.resolved(nil), expected)
    }

    // MARK: Decoding

    private func decode(_ json: String) throws -> StyleOverrides {
        return try JSONDecoder().decode(StyleOverrides.self, from: Data(json.utf8))
    }

    func testLanguageDecodes() throws {
        XCTAssertEqual(try decode(#"{"language":"de"}"#).language, .de)
        XCTAssertEqual(try decode(#"{"language":"zh-Hans"}"#).language, .zhHans)
        XCTAssertEqual(try decode(#"{"language":"es","accentHex":"#123456"}"#).language, .es)
    }

    func testMissingKeyMeansAppLanguage() throws {
        let decoded: StyleOverrides = try decode(#"{"accentHex":"#123456","fontScale":1.1}"#)
        XCTAssertNil(decoded.language)
        XCTAssertEqual(decoded.accentHex, "#123456")
    }

    func testUnknownOrWrongTypeFallsBackWithoutLosingTheDocument() throws {
        let unknown: StyleOverrides = try decode(#"{"language":"ja","accentHex":"#123456","photoSize":"small"}"#)
        XCTAssertNil(unknown.language)
        XCTAssertEqual(unknown.accentHex, "#123456")
        XCTAssertEqual(unknown.photoSize, .small)

        XCTAssertNil(try decode(#"{"language":7}"#).language)
        XCTAssertNil(try decode(#"{"language":null}"#).language)
        XCTAssertNil(try decode(#"{"language":{"code":"de"}}"#).language)
        // The raw value is exact: "zh" alone is not a stored value.
        XCTAssertNil(try decode(#"{"language":"zh"}"#).language)
    }

    func testWholeResumeWithUnknownLanguageStillOpens() throws {
        var resume = EngineFixtures.resume("Lang", person: EngineFixtures.person("Élodie Müller"), sections: [
            EngineFixtures.section(.summary, text: "Kurzprofil.")
        ])
        resume.style.language = .de
        let encoded: Data = try JSONEncoder().encode(resume)
        guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any],
              var style = object["style"] as? [String: Any] else {
            XCTFail("unexpected JSON shape")
            return
        }
        XCTAssertEqual(style["language"] as? String, "de")
        style["language"] = "klingon"
        object["style"] = style
        let changed: Data = try JSONSerialization.data(withJSONObject: object)
        let decoded: Resume = try JSONDecoder().decode(Resume.self, from: changed)
        XCTAssertNil(decoded.style.language)
        XCTAssertEqual(decoded.personal.fullName, "Élodie Müller")
        XCTAssertEqual(decoded.sections, resume.sections)
    }

    func testEncodingOnlyWritesAChosenLanguage() throws {
        let plain: Data = try JSONEncoder().encode(StyleOverrides())
        let plainObject = try JSONSerialization.jsonObject(with: plain) as? [String: Any]
        XCTAssertNil(plainObject?["language"], "older builds must read a default style unchanged")

        for language in ResumeLanguage.allCases {
            var o = StyleOverrides()
            o.language = language
            let data: Data = try JSONEncoder().encode(o)
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(object?["language"] as? String, language.rawValue)
            let back: StyleOverrides = try JSONDecoder().decode(StyleOverrides.self, from: data)
            XCTAssertEqual(back, o)
            XCTAssertEqual(back.language, language)
        }
    }

    func testCoverLetterStyleRoundTrip() throws {
        var letter = EngineFixtures.letter()
        letter.style.language = .fr
        let decoded: CoverLetter = try JSONDecoder().decode(CoverLetter.self, from: try JSONEncoder().encode(letter))
        XCTAssertEqual(decoded.style.language, .fr)
        XCTAssertEqual(decoded.comparableContent(), letter.comparableContent())
    }

    // MARK: Words

    func testDocumentStringsUseTheCatalogTranslations() {
        // Exact wording from tools/l10n_parts/shell.json.
        XCTAssertEqual(DocumentStrings.present(.en), "Present")
        XCTAssertEqual(DocumentStrings.present(.es), "Actualidad")
        XCTAssertEqual(DocumentStrings.present(.fr), "Aujourd\u{2019}hui")
        XCTAssertEqual(DocumentStrings.present(.de), "Heute")
        XCTAssertEqual(DocumentStrings.present(.zhHans), "至今")
        XCTAssertEqual(DocumentStrings.signOff(.de), "Mit freundlichen Grüßen")
        XCTAssertEqual(DocumentStrings.greetingWithoutName(.fr), "Madame, Monsieur,")
        XCTAssertEqual(DocumentStrings.greeting(name: "Ana Ruiz", language: .es), "Estimado/a Ana Ruiz:")
        XCTAssertEqual(DocumentStrings.greeting(name: "Taylor", language: .en), "Dear Taylor,")
        XCTAssertEqual(DocumentStrings.defaultTitle(.experience, language: .de), "Berufserfahrung")
        XCTAssertEqual(DocumentStrings.defaultTitle(.experience, language: .zhHans), "工作经历")
        XCTAssertEqual(DocumentStrings.defaultTitle(.experience, language: .en), "Work Experience")
    }

    func testUnknownKeyFallsBackToTheKey() {
        for language in ResumeLanguage.allCases {
            XCTAssertEqual(DocumentStrings.string("CK test key that is not in the catalog", language: language),
                           "CK test key that is not in the catalog")
        }
    }

    func testDateRangeKeepsEnglishOutputAndLocalisesOthers() {
        var entry = ResumeEntry()
        entry.start = MonthYear(year: 2020, month: 3)
        entry.isCurrent = true
        // Existing call sites are unchanged.
        XCTAssertEqual(entry.dateRange(format: .numeric), "03/2020 – \(CKDateWords.present)")
        XCTAssertEqual(entry.dateRange(format: .numeric, locale: .current, present: "Heute"), "03/2020 – Heute")
        XCTAssertEqual(entry.dateRange(format: .numeric, language: .de), "03/2020 – Heute")
        XCTAssertEqual(entry.dateRange(format: .yearOnly, language: .zhHans), "2020 – 至今")
        XCTAssertEqual(entry.dateRange(format: nil, language: .es),
                       MonthYear(year: 2020, month: 3).formatted(locale: ResumeLanguage.es.locale) + " – Actualidad")
        XCTAssertTrue(entry.dateRange(format: nil, language: .zhHans).contains("年"))
        XCTAssertTrue(entry.dateRange(format: nil, language: .de).contains("März"))
    }

    func testDefaultTitlesFollowAChosenLanguageButTypedTitlesStay() {
        let untouched = EngineFixtures.section(.experience, title: "Work Experience")
        let german = EngineFixtures.section(.experience, title: "Berufserfahrung")
        let typed = EngineFixtures.section(.experience, title: "Where I worked")
        let empty = EngineFixtures.section(.skills, title: " ")

        // No choice: the original behaviour.
        XCTAssertEqual(RenderContent.label(for: german, language: nil), "Berufserfahrung")
        XCTAssertEqual(RenderContent.label(for: untouched, language: nil), "Work Experience")

        XCTAssertEqual(RenderContent.label(for: untouched, language: .de), "Berufserfahrung")
        XCTAssertEqual(RenderContent.label(for: german, language: .en), "Work Experience")
        XCTAssertEqual(RenderContent.label(for: german, language: .zhHans), "工作经历")
        XCTAssertEqual(RenderContent.label(for: typed, language: .fr), "Where I worked")
        XCTAssertEqual(RenderContent.label(for: empty, language: .es), "Habilidades")
    }

    func testCoverLetterDefaultsFollowAChosenLanguage() {
        var letter = CoverLetter(title: "Letter", templateID: "cl.test.0")
        letter.signOff = "Sincerely,"
        letter.greeting = ""
        letter.recipientName = ""
        XCTAssertEqual(letter.effectiveGreeting(language: .de, explicit: true), "Sehr geehrte Damen und Herren,")
        XCTAssertEqual(letter.effectiveSignOff(language: .de, explicit: true), "Mit freundlichen Grüßen")
        // Without a chosen language the saved sign-off is kept as it is.
        XCTAssertEqual(letter.effectiveSignOff(language: .de, explicit: false), "Sincerely,")

        letter.signOff = "Atentamente,"
        XCTAssertEqual(letter.effectiveSignOff(language: .en, explicit: true), "Sincerely,")
        letter.signOff = "Warm regards,"
        XCTAssertEqual(letter.effectiveSignOff(language: .zhHans, explicit: true), "Warm regards,")

        letter.recipientName = "Ana Ruiz"
        XCTAssertEqual(letter.effectiveGreeting(language: .es, explicit: true), "Estimado/a Ana Ruiz:")
        letter.greeting = "Hola Ana,"
        XCTAssertEqual(letter.effectiveGreeting(language: .de, explicit: true), "Hola Ana,")
    }

    // MARK: Initials

    func testInitialsUseWholeCharacters() {
        XCTAssertEqual(RenderInitials.initials(for: "Jordan Whitfield"), "JW")
        XCTAssertEqual(RenderInitials.initials(for: "Élodie Müller"), "ÉM")
        XCTAssertEqual(RenderInitials.initials(for: "e\u{0301}lodie o\u{0308}zil"), "E\u{0301}O\u{0308}")
        XCTAssertEqual(RenderInitials.initials(for: "王小明"), "王")
        XCTAssertEqual(RenderInitials.initials(for: "欧阳 娜娜"), "欧")
        XCTAssertEqual(RenderInitials.initials(for: "(Sam) Okafor"), "SO")
        XCTAssertEqual(RenderInitials.initials(for: "Cher"), "C")
        XCTAssertEqual(RenderInitials.initials(for: "   "), "")
    }

    func testUppercasingSkipsChinese() {
        XCTAssertEqual(RenderScript.uppercased("王小明", language: .zhHans), "王小明")
        XCTAssertEqual(RenderScript.uppercased("Müller", language: .de), "MÜLLER")
        XCTAssertTrue(RenderScript.isCJK("工作经历"))
        XCTAssertFalse(RenderScript.isCJK("Berufserfahrung"))
    }

    // MARK: Validator

    func testValidatorComparesAccentsAndChinese() {
        let decomposed: String = "E\u{0301}lodie Mu\u{0308}ller"
        let haystack: String = PDFValidator.normalise("Résumé of " + decomposed)
        XCTAssertTrue(PDFValidator.appears("Élodie Müller", in: haystack))
        XCTAssertTrue(PDFValidator.appears("Résumé", in: haystack))

        // An uppercase German heading writes "ß" as "SS".
        XCTAssertTrue(PDFValidator.appears("Straße", in: PDFValidator.normalise("STRASSE 5")))

        // A Chinese line wrapped and interleaved with another column still counts, in order.
        let needle: String = "负责支付系统核心模块的设计与开发并带领团队完成上线"
        let wrapped: String = PDFValidator.normalise("负责支付系统核心模块的设计 技能 Swift\n与开发并带领团队完成上线")
        XCTAssertTrue(PDFValidator.appears(needle, in: wrapped))
        // Scattered single characters do not.
        let scattered: String = PDFValidator.normalise("负 责 支 付 系 统 核 心 模 块 的 设 计 与 开 发 并 带 领 团 队 完 成 上 线".split(separator: " ").reversed().joined(separator: "x"))
        XCTAssertFalse(PDFValidator.appears(needle, in: scattered))
    }
}
