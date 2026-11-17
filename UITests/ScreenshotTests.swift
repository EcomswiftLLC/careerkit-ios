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
        tap(app.buttons["Get started"], wait: 3)
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

        for name in ["Preview", "Style", "Sections", "Template", "ATS check"] {
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

    // MARK: - Helpers for the newer screens

    private static let sampleJobAd: String = "Senior Product Designer\nWe are looking for a designer with Figma, prototyping and user research skills. Experience with design systems, accessibility and A/B testing is required. You will work closely with engineering and product managers."

    private static let sampleResumeText: String = "Jordan Lee\nProduct Designer\njordan.lee@example.com\n\nSummary\nProduct designer with six years of experience in mobile apps.\n\nExperience\nSenior Product Designer, Northwind Studio\n2021 - Present\nLed the redesign of the booking flow.\n\nEducation\nBA Design, State University, 2017\n\nSkills\nFigma, Prototyping, User research"

    /// Any element with this accessibility identifier.
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Scrolls content up with a short drag in the upper half of the screen, away from the keyboard.
    private func dragUp() {
        let start: XCUICoordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42))
        let end: XCUICoordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    @discardableResult
    private func scrollUntilHittable(_ target: XCUIElement, attempts: Int = 5) -> Bool {
        for _ in 0..<attempts {
            if target.exists && target.isHittable { return true }
            dragUp()
        }
        return target.exists && target.isHittable
    }

    private func launchSeeded() {
        app.launchArguments = ["-ck-screenshots", "-ck-seed"]
        app.launch()
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 8)
    }

    private func openSeededEditor() throws {
        launchSeeded()
        tap(tab("My Resumes"))
        guard tap(app.staticTexts["UX Designer"].firstMatch, wait: 5) else {
            throw XCTSkip("Seeded resume not found, editor shots skipped")
        }
    }

    private func openImportSheet() throws {
        launchSeeded()
        tap(tab("My Resumes"))
        let menu: XCUIElement = element("myResumes.newResumeMenu")
        if !tap(menu, wait: 4) {
            guard tap(app.navigationBars.buttons["New resume"].firstMatch, wait: 2) else {
                throw XCTSkip("New resume menu not found")
            }
        }
        guard tap(app.buttons["Import resume"].firstMatch, wait: 3) else {
            throw XCTSkip("Import resume menu item not found")
        }
        guard app.staticTexts["Bring in your current resume"].waitForExistence(timeout: 6) else {
            throw XCTSkip("Import sheet did not appear")
        }
    }

    // MARK: - Home empty state with Import (runs right after onboarding, before any seeding)

    func test1b_HomeEmptyImport() throws {
        app.launchArguments = ["-ck-screenshots"]
        app.launch()
        // Finish onboarding first if it is still showing.
        if app.buttons["Continue"].waitForExistence(timeout: 4) {
            for _ in 0..<6 {
                guard app.buttons["Continue"].exists else { break }
                app.buttons["Continue"].tap()
            }
        }
        tap(app.buttons["Get started"], wait: 2)
        let importButton: XCUIElement = element("home.importResume")
        guard importButton.waitForExistence(timeout: 8) else {
            throw XCTSkip("Home is not in its empty state (documents already exist)")
        }
        scrollUntilHittable(importButton, attempts: 2)
        shot("75-home-empty-import")
    }

    // MARK: - Export sheet with Word selected

    func test4_ExportWordSelected() throws {
        try openSeededEditor()
        guard tap(app.buttons["Export"].firstMatch, wait: 4) else {
            throw XCTSkip("Export button not found")
        }
        shot("70-export-paywall")
        let wordRow: XCUIElement = element("export.format.docx")
        guard wordRow.waitForExistence(timeout: 5), scrollUntilHittable(wordRow, attempts: 2) else {
            throw XCTSkip("Word row not found in the export sheet")
        }
        wordRow.tap()
        shot("71-export-sheet-word-selected")
        // Put PDF back so later runs on this simulator start from the default.
        let pdfRow: XCUIElement = element("export.format.pdf")
        if pdfRow.exists && pdfRow.isHittable { pdfRow.tap() }
    }

    // MARK: - ATS check, job ad match

    func test5_ATSJobMatch() throws {
        try openSeededEditor()
        guard tap(app.buttons["ATS check"].firstMatch, wait: 4) else {
            throw XCTSkip("ATS check button not found")
        }
        // Let the general checks finish first so the layout stops moving.
        _ = app.buttons["Check again"].waitForExistence(timeout: 12)

        let jobBox: XCUIElement = app.textViews["Job description"].firstMatch
        guard jobBox.waitForExistence(timeout: 5), scrollUntilHittable(jobBox, attempts: 8) else {
            throw XCTSkip("Job description box not found")
        }
        // Bring the box higher so the Compare button stays above the keyboard.
        if jobBox.frame.minY > app.frame.height * 0.4 {
            dragUp()
        }
        guard jobBox.exists, jobBox.isHittable else { throw XCTSkip("Job description box scrolled away") }
        jobBox.tap()
        jobBox.typeText(ScreenshotTests.sampleJobAd)

        let compare: XCUIElement = element("ats.jobMatch.compare")
        guard compare.exists, scrollUntilHittable(compare, attempts: 3) else {
            throw XCTSkip("Compare button not reachable")
        }
        compare.tap()

        let summary: XCUIElement = element("ats.jobMatch.summary")
        guard summary.waitForExistence(timeout: 12) else {
            throw XCTSkip("Job match results did not appear")
        }
        Thread.sleep(forTimeInterval: 0.6)
        scrollUntilHittable(summary, attempts: 4)
        // Show as much of the results as possible below the summary.
        if summary.exists && summary.frame.minY > app.frame.height * 0.45 {
            dragUp()
        }
        shot("72-ats-job-match")
    }

    // MARK: - Import

    func test6_ImportSheet() throws {
        try openImportSheet()
        shot("73-import-sheet")
    }

    func test7_ImportReview() throws {
        try openImportSheet()
        let pasteBox: XCUIElement = app.textViews["Resume text"].firstMatch
        guard pasteBox.waitForExistence(timeout: 4), scrollUntilHittable(pasteBox, attempts: 4) else {
            throw XCTSkip("Paste box not found")
        }
        pasteBox.tap()
        pasteBox.typeText(ScreenshotTests.sampleResumeText)

        let continueButton: XCUIElement = element("import.continueWithText")
        guard continueButton.exists, scrollUntilHittable(continueButton, attempts: 4) else {
            throw XCTSkip("Continue button not reachable")
        }
        continueButton.tap()

        guard element("import.review.title").waitForExistence(timeout: 12) else {
            throw XCTSkip("Review screen did not appear")
        }
        shot("74-import-review")
    }
}
