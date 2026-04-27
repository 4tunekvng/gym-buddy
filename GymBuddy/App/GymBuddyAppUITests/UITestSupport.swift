import XCTest

/// Shared helpers for UI tests.
///
/// iOS Simulator preserves the app's SwiftData store across test invocations —
/// once a test onboards, subsequent tests launch straight to Today. These
/// helpers make each test tolerant of either starting point.
enum UITestSupport {

    static func configureForScriptedDemo(_ app: XCUIApplication) {
        app.launchEnvironment["GYMBUDDY_POSE_MODE"] = "demo"
        app.launchEnvironment["GYMBUDDY_LLM_MODE"] = "mock"
        app.launchEnvironment["GYMBUDDY_VOICE_MODE"] = "mock"
        app.launchEnvironment["GYMBUDDY_SCRIPTED_DEMO_PLAYBACK_RATE"] = "3.0"
    }

    /// Launch the app and ensure we end on the Today screen with a profile.
    /// If the app shows Welcome, runs through onboarding with a generic name.
    @discardableResult
    static func launchAndReachTodayScreen(_ app: XCUIApplication, name: String = "QA") -> Bool {
        configureForScriptedDemo(app)
        app.launch()

        let welcome = app.buttons["welcome_start_button"]
        if welcome.waitForExistence(timeout: 3) {
            welcome.tap()
            let field = app.textFields["onboarding_name_field"]
            _ = field.waitForExistence(timeout: 5)
            field.tap()
            field.typeText(name)
            // Drive the 7 advance taps + 1 finish tap. We re-resolve and gate
            // on `exists` each iteration because rapid taps can outrun the
            // SwiftUI step transition (the button identifier is the same
            // across steps, but the underlying view re-mounts with the new
            // step content). This makes the helper robust without slowing
            // down anything that wasn't already waiting.
            let next = app.buttons["onboarding_next"]
            for _ in 0..<8 where next.waitForExistence(timeout: 2) {
                next.tap()
            }
        }

        return app.otherElements["screen_today"].waitForExistence(timeout: 10)
    }
}
