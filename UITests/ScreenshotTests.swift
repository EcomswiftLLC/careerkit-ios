import XCTest

/// Walks through the main screens and writes PNG screenshots to CAREERKIT_SHOT_DIR.
/// Each step is best effort: a missing element never aborts the walk, it just skips that shot.
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private var outDir: URL!

    override func setUpWithError() throws {
        continueAfterFailure = true
        let path: String = ProcessInfo.processInfo.environment["CAREERKIT_SHOT_DIR"] ?? "/tmp/careerkit-shots"
        outDir = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication()
    }

    private func shot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.8)
        let data: Data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: outDir.appendingPathComponent(name + ".png"))
    }

    @discardableResult
    private func tap(_ element: XCUIElement, wait: TimeInterval = 4) -> Bool {
        guard element.waitForExistence(timeout: wait) else { return false }
        element.tap()
        return true
    }

    private func tab(_ name: String) -> XCUIElement {
        let inBar: XCUIElement = app.tabBars.buttons[name]
        return inBar.exists ? inBar : app.buttons[name].firstMatch
    }

    func test1_Onboarding() {
        app.launchArguments = ["-ck-screenshots"]
        app.launch()
        shot("01-onboarding-1")
        for index in 2...5 {
            if tap(app.buttons["Continue"], wait: 3) { shot("01-onboarding-\(index)") }
        }
        tap(app.buttons["Get Started"], wait: 3)
        shot("02-home-empty")
    }

    func test2_MainScreens() {
        app.launchArguments = ["-ck-screenshots", "-ck-seed"]
        app.launch()
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
        if tap(app.staticTexts["Executive"].firstMatch, wait: 3) || tap(app.staticTexts["Modern Minimal"].firstMatch, wait: 2) {
            shot("32-template-preview")
            app.swipeDown(velocity: .fast)
        }

        tap(tab("Cover Letters"))
        shot("40-cover-letters")
        if tap(app.staticTexts["Finance Manager cover letter"].firstMatch, wait: 3) {
            shot("41-cover-letter-editor")
        }

        tap(tab("Profile"))
        shot("50-profile")
        app.swipeUp()
        shot("51-profile-scrolled")
    }

    func test3_Editor() {
        app.launchArguments = ["-ck-screenshots", "-ck-seed"]
        app.launch()
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 8)
        tap(tab("My Resumes"))
        guard tap(app.staticTexts["UX Designer"].firstMatch, wait: 5) else { shot("60-editor-missing"); return }
        shot("60-editor")
        app.swipeUp()
        shot("61-editor-scrolled")

        for name in ["Preview", "Style", "Sections", "Template", "ATS Check"] {
            let button: XCUIElement = app.buttons[name].firstMatch
            if tap(button, wait: 2) {
                shot("62-editor-" + name.replacingOccurrences(of: " ", with: "-").lowercased())
                if app.buttons["Done"].exists { app.buttons["Done"].tap() } else { app.swipeDown(velocity: .fast) }
            }
        }
        if tap(app.buttons["Export"].firstMatch, wait: 2) {
            shot("70-export-sheet")
        }
    }
}
