import XCTest

/// Raw App Store screenshots from stable, local-only app surfaces.
///
/// The test launch skips the first-launch tutorial and Game Center login so the
/// capture is repeatable and never depends on an account or a network session.
/// `appstore/capture.sh` exports these attachments into the packaging pipeline.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureMarketingScreens() throws {
        let app = XCUIApplication()

        launch(app)
        capture(app, "title")

        tapFirst(app, labels: ["Rules"])
        XCTAssertTrue(app.staticTexts["How to play"].waitForExistence(timeout: 5))
        capture(app, "rules")

        app.terminate()
        launch(app)
        tapFirst(app, labels: ["Solo 81"])
        waitForGame(app)
        capture(app, "solo-81")

        app.terminate()
        launch(app)
        tapFirst(app, labels: ["Quick 27"])
        waitForGame(app)
        capture(app, "quick-27")

        app.terminate()
        launch(app)
        tapFirst(app, labels: ["Duel, one phone"])
        waitForGame(app)
        capture(app, "duel")

        app.terminate()
        launch(app)
        tapFirst(app, labels: ["Rules"])
        XCTAssertTrue(app.staticTexts["How to play"].waitForExistence(timeout: 5))
        tapFirst(app, labels: ["The mathematics"])
        XCTAssertTrue(app.staticTexts["The mathematics"].waitForExistence(timeout: 5))
        capture(app, "mathematics")
    }

    @MainActor
    private func launch(_ app: XCUIApplication) {
        app.launchArguments = ["-ESTScreenshotMode"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        Thread.sleep(forTimeInterval: 1.2)
    }

    @MainActor
    private func waitForGame(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["deck"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.2)
    }

    @MainActor
    private func tapFirst(_ app: XCUIApplication, labels: [String]) {
        for label in labels {
            let button = app.buttons[label]
            if button.waitForExistence(timeout: 4), button.isHittable {
                button.tap()
                Thread.sleep(forTimeInterval: 0.8)
                return
            }

            let text = app.staticTexts[label]
            if text.waitForExistence(timeout: 2), text.isHittable {
                text.tap()
                Thread.sleep(forTimeInterval: 0.8)
                return
            }
        }
        XCTFail("Could not find any of: \(labels.joined(separator: ", "))")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
