import XCTest
import UIKit

/// Rotates an iPad to landscape and screenshots the main screens, failing when the window does not end up wider than tall.
/// Only runs when CAREERKIT_LANDSCAPE=1 is set (the `ipad-landscape` CI job), so the other UI test runs skip it.
final class LandscapeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CAREERKIT_LANDSCAPE"] == "1", "CAREERKIT_LANDSCAPE not set")
        app = XCUIApplication()
    }

    /// The simulator hands back its portrait frame buffer with a landscape picture lying on its side, so turn it upright.
    private func uprightScreenshot() -> UIImage {
        // Redraw first so the image's own orientation flag is applied to the pixels that get saved.
        let source: UIImage = XCUIScreen.main.screenshot().image
        let sourceFormat = UIGraphicsImageRendererFormat()
        sourceFormat.scale = source.scale
        let image: UIImage = UIGraphicsImageRenderer(size: source.size, format: sourceFormat).image { _ in source.draw(at: .zero) }
        guard image.size.height > image.size.width else { return image }
        let size = CGSize(width: image.size.height, height: image.size.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.rotate(by: -.pi / 2)
            image.draw(at: .zero)
        }
    }

    private func launch(seeded: Bool) {
        app.launchArguments = seeded ? ["-ck-screenshots", "-ck-seed"] : ["-ck-screenshots"]
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        let window: XCUIElement = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 30), "No app window")
        let deadline = Date().addingTimeInterval(12)
        while Date() < deadline, window.frame.width <= window.frame.height {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTAssertGreaterThan(window.frame.width, window.frame.height, "Window is \(Int(window.frame.width))x\(Int(window.frame.height)), not landscape")
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 10)
    }

    private func shot(_ name: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        let attachment = XCTAttachment(image: uprightScreenshot())
        attachment.name = "landscape-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertEqual(app.state, .runningForeground, "\(name): app left the foreground")
    }

    /// The tab bar on iPhone, or a sidebar row on iPad.
    private func tab(_ name: String) -> XCUIElement {
        let inBar: XCUIElement = app.tabBars.buttons[name]
        if inBar.exists { return inBar }
        let button: XCUIElement = app.buttons[name].firstMatch
        if button.exists { return button }
        let row: XCUIElement = app.cells.containing(.staticText, identifier: name).firstMatch
        return row.exists ? row : app.staticTexts[name].firstMatch
    }

    /// The Home screen greets the user, so no other tab shows a "Good morning/afternoon/evening" line.
    private var homeGreetingVisible: Bool {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Good '")).firstMatch.exists
    }

    func testOnboarding() {
        launch(seeded: false)
        shot("onboarding")
    }

    func testMainTabs() {
        launch(seeded: true)
        shot("home")
        for (name, label) in [("My Resumes", "my-resumes"), ("Templates", "templates"), ("Cover Letters", "cover-letters"), ("Profile", "profile")] {
            let item: XCUIElement = tab(name)
            XCTAssertTrue(item.waitForExistence(timeout: 5), "\(name) tab not found")
            item.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(1.5))
            XCTAssertFalse(homeGreetingVisible, "\(name): still showing Home after tapping the tab")
            shot(label)
        }
    }

    func testEditor() {
        launch(seeded: true)
        let resumes: XCUIElement = tab("My Resumes")
        if resumes.waitForExistence(timeout: 5) { resumes.tap() }
        let resume: XCUIElement = app.staticTexts["UX Designer"].firstMatch
        guard resume.waitForExistence(timeout: 6) else { XCTFail("Seeded resume not found"); return }
        resume.tap()
        shot("editor")
        let export: XCUIElement = app.buttons["Export"].firstMatch
        if export.waitForExistence(timeout: 3) {
            export.tap()
            shot("export-sheet")
        }
    }
}
