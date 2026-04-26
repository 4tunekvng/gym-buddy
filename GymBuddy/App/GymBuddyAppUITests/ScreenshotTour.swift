import XCTest

/// Walks through the app flow and drops a screenshot for every screen.
/// The screenshots land as XCTAttachments; the test runner also writes them
/// into `/tmp/gym-tour/<N>-<name>.png` so they're easy to inspect from disk.
///
/// Robust to test-ordering: if SwiftData has a carried-over profile we skip the
/// onboarding section, otherwise we capture every onboarding step too. The
/// tour always ends with today → live session → post-session → settings → history.
final class ScreenshotTour: XCTestCase {

    func testCaptureEveryScreen() throws {
        let app = XCUIApplication()
        app.launch()

        var stepIdx = 1

        if app.buttons["welcome_start_button"].waitForExistence(timeout: 3) {
            save(app: app, index: stepIdx, name: "welcome"); stepIdx += 1

            app.buttons["welcome_start_button"].tap()
            save(app: app, index: stepIdx, name: "onboarding-name"); stepIdx += 1

            let nameField = app.textFields["onboarding_name_field"]
            _ = nameField.waitForExistence(timeout: 5)
            nameField.tap()
            nameField.typeText("Fortune")
            app.buttons["onboarding_next"].tap()
            save(app: app, index: stepIdx, name: "onboarding-goal"); stepIdx += 1

            app.buttons["onboarding_next"].tap()
            save(app: app, index: stepIdx, name: "onboarding-experience"); stepIdx += 1
            app.buttons["onboarding_next"].tap()
            save(app: app, index: stepIdx, name: "onboarding-equipment"); stepIdx += 1
            app.buttons["onboarding_next"].tap()
            save(app: app, index: stepIdx, name: "onboarding-frequency"); stepIdx += 1
            app.buttons["onboarding_next"].tap()
            save(app: app, index: stepIdx, name: "onboarding-injuries"); stepIdx += 1
            app.buttons["onboarding_next"].tap()
            save(app: app, index: stepIdx, name: "onboarding-tone"); stepIdx += 1
            app.buttons["onboarding_next"].tap()
            save(app: app, index: stepIdx, name: "onboarding-review"); stepIdx += 1
            app.buttons["onboarding_next"].tap()
        }

        _ = app.otherElements["screen_today"].waitForExistence(timeout: 10)
        save(app: app, index: stepIdx, name: "today"); stepIdx += 1

        app.buttons["today_start_push_up"].tap()
        _ = app.buttons["setup_start_button"].waitForExistence(timeout: 5)
        save(app: app, index: stepIdx, name: "live-setup"); stepIdx += 1
        app.buttons["setup_start_button"].tap()
        sleep(3)
        save(app: app, index: stepIdx, name: "live-midset"); stepIdx += 1
        _ = app.otherElements["screen_post_session"].waitForExistence(timeout: 30)
        save(app: app, index: stepIdx, name: "post-session"); stepIdx += 1
        app.buttons["post_session_done"].tap()
        _ = app.otherElements["screen_today"].waitForExistence(timeout: 5)

        app.buttons["today_settings_button"].tap()
        _ = app.otherElements["screen_settings"].waitForExistence(timeout: 5)
        save(app: app, index: stepIdx, name: "settings"); stepIdx += 1
        app.buttons["settings_back"].tap()

        app.buttons["today_history_button"].tap()
        _ = app.otherElements["screen_history"].waitForExistence(timeout: 5)
        save(app: app, index: stepIdx, name: "history"); stepIdx += 1
    }

    private func save(app: XCUIApplication, index: Int, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(index)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)

        try? FileManager.default.createDirectory(
            atPath: "/tmp/gym-tour",
            withIntermediateDirectories: true
        )
        try? screenshot.pngRepresentation.write(
            to: URL(fileURLWithPath: "/tmp/gym-tour/\(String(format: "%02d", index))-\(name).png")
        )
    }
}
