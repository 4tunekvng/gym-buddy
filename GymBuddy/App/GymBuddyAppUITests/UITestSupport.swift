import XCTest

/// Shared helpers for UI tests.
///
/// iOS Simulator preserves the app's SwiftData store across test invocations —
/// once a test onboards, subsequent tests launch straight to Today. These
/// helpers make each test tolerant of either starting point.
enum UITestSupport {

    /// Launch the app and ensure we end on the Today screen with a profile.
    /// If the app shows Welcome, runs through onboarding with a generic name.
    @discardableResult
    static func launchAndReachTodayScreen(_ app: XCUIApplication, name: String = "QA") -> Bool {
        app.launch()

        let welcome = app.buttons["welcome_start_button"]
        if welcome.waitForExistence(timeout: 3) {
            welcome.tap()
            let field = app.textFields["onboarding_name_field"]
            _ = field.waitForExistence(timeout: 5)
            field.tap()
            field.typeText(name)
            app.buttons["onboarding_next"].tap()
            for _ in 0..<7 { app.buttons["onboarding_next"].tap() }
        }

        return app.otherElements["screen_today"].waitForExistence(timeout: 10)
    }
}
