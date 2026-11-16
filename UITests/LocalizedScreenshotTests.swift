import XCTest

/// Walks the main screens in another language and writes PNG screenshots to CAREERKIT_SHOT_DIR.
/// CAREERKIT_LANG picks the language (es, fr, de, zh-Hans); without it the test does nothing.
/// Element names come from the String Catalog, so the same walk works in every language.
final class LocalizedScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private var outDir: URL!
    private var language: String = ""
    private var catalog: [String: [String: Any]] = [:]

    override func setUpWithError() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        language = env["CAREERKIT_LANG"] ?? ""
        try XCTSkipIf(language.isEmpty, "CAREERKIT_LANG not set")
        let path: String = env["CAREERKIT_SHOT_DIR"] ?? "/tmp/careerkit-shots-l10n"
        outDir = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let url = testsDir.deletingLastPathComponent().appendingPathComponent("Sources/Resources/Localizable.xcstrings")
        if let data = try? Data(contentsOf: url),
           let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
           let strings = root["strings"] as? [String: [String: Any]] {
            catalog = strings
        }
        app = XCUIApplication()
    }

    /// The catalog translation of an English key (falls back to the key itself).
    private func L(_ key: String) -> String {
        guard let locs = catalog[key]?["localizations"] as? [String: Any],
              let entry = locs[language] as? [String: Any],
              let unit = entry["stringUnit"] as? [String: Any],
              let value = unit["value"] as? String else { return key }
        return value
    }

    private func launch(seeded: Bool) {
        var args: [String] = ["-ck-screenshots", "-AppleLanguages", "(\(language))", "-AppleLocale", language.replacingOccurrences(of: "-", with: "_")]
        if seeded { args.append("-ck-seed") }
        app.launchArguments = args
        app.launch()
    }

    private func shot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.8)
        let data: Data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: outDir.appendingPathComponent("\(language)-\(name).png"))
    }

    @discardableResult
    private func tap(_ element: XCUIElement, wait: TimeInterval = 4) -> Bool {
        guard element.waitForExistence(timeout: wait) else { return false }
        element.tap()
        return true
    }

    private func tab(_ englishName: String) -> XCUIElement {
        let name = L(englishName)
        let inBar: XCUIElement = app.tabBars.buttons[name]
        return inBar.exists ? inBar : app.buttons[name].firstMatch
    }

    func testOnboardingLocalized() {
        launch(seeded: false)
        shot("01-onboarding-1")
        for index in 2...5 {
            if tap(app.buttons[L("Continue")], wait: 3) { shot("01-onboarding-\(index)") }
        }
        tap(app.buttons[L("Get started")], wait: 3)
        shot("02-home-empty")
    }

    func testMainScreensLocalized() {
        launch(seeded: true)
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 8)
        shot("10-home")
        app.swipeUp()
        shot("11-home-scrolled")
        app.swipeDown()

        tap(tab("My Resumes"))
        shot("20-my-resumes")

        tap(tab("Templates"))
        shot("30-templates")
        app.swipeUp()
        shot("31-templates-scrolled")
        app.swipeDown()

        tap(tab("Cover Letters"))
        shot("40-cover-letters")

        tap(tab("Profile"))
        shot("50-profile")
        app.swipeUp()
        shot("51-profile-scrolled")
    }

    func testEditorLocalized() {
        launch(seeded: true)
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 8)
        tap(tab("My Resumes"))
        guard tap(app.staticTexts["UX Designer"].firstMatch, wait: 5) else { shot("60-editor-missing"); return }
        shot("60-editor")
        app.swipeUp()
        shot("61-editor-scrolled")
        for name in ["Preview", "Style", "Sections", "Template", "ATS check"] {
            let button: XCUIElement = app.buttons[L(name)].firstMatch
            if tap(button, wait: 2) {
                shot("62-editor-" + name.replacingOccurrences(of: " ", with: "-").lowercased())
                if app.buttons[L("Done")].exists { app.buttons[L("Done")].tap() } else { app.swipeDown(velocity: .fast) }
            }
        }
        if tap(app.buttons[L("Export")].firstMatch, wait: 2) {
            shot("70-export-sheet")
        }
    }
}
