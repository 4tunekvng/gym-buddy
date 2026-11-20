import XCTest

/// Settings changes persist to the user profile store.
///
/// Walks: onboard → settings → change tone → back to today → relaunch app →
/// settings again → verify the previously-chosen tone is still selected.
final class SettingsPersistsUITest: XCTestCase {

    func testTonePickerPersistsAcrossRelaunch() throws {
        let app = XCUIApplication()
        // The shared helper waits for each onboarding step before tapping;
        // an unguarded copy of that walk lost taps mid-transition (#18).
        XCTAssertTrue(UITestSupport.launchAndReachTodayScreen(app))

        // Open Settings and switch tone to Intense.
        app.buttons["today_settings_button"].tap()
        _ = app.otherElements["screen_settings"].waitForExistence(timeout: 5)
        let tonePicker = app.buttons["settings_tone_picker"]
        XCTAssertTrue(tonePicker.waitForExistence(timeout: 5))
        tonePicker.tap()
        app.buttons["Intense"].tap()

        // Give the save a moment.
        sleep(1)
        app.buttons["settings_back"].tap()

        // Relaunch to verify persistence. RootView checks for a saved profile
        // on first appearance and routes onboarded users straight to Today.
        app.terminate()
        UITestSupport.configureForScriptedDemo(app)
        app.launch()
        XCTAssertTrue(app.otherElements["screen_today"].waitForExistence(timeout: 10),
                      "Expected onboarded user to skip welcome on relaunch")

        app.buttons["today_settings_button"].tap()
        _ = app.otherElements["screen_settings"].waitForExistence(timeout: 5)

        // The tone picker label reflects the selected value. SwiftUI renders
        // the Picker as a button showing the current selection.
        let picker = app.buttons["settings_tone_picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        // The label format is "Tone, Intense" in SwiftUI form pickers.
        XCTAssertTrue(
            picker.label.contains("Intense"),
            "Expected tone to persist as Intense after relaunch, got '\(picker.label)'"
        )
    }
}
