import XCTest

/// Settings changes persist to the user profile store.
///
/// Walks: onboard → settings → change tone → back to today → relaunch app →
/// settings again → verify the previously-chosen tone is still selected.
final class SettingsPersistsUITest: XCTestCase {

    func testTonePickerPersistsAcrossRelaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // First-run or carryover state from a prior test. Either land on welcome
        // (onboard) or land on today (already onboarded). Either path ends on
        // screen_today.
        if app.buttons["welcome_start_button"].waitForExistence(timeout: 3) {
            app.buttons["welcome_start_button"].tap()
            let nameField = app.textFields["onboarding_name_field"]
            _ = nameField.waitForExistence(timeout: 5)
            nameField.tap()
            nameField.typeText("QA")
            app.buttons["onboarding_next"].tap()
            for _ in 0..<7 { app.buttons["onboarding_next"].tap() }
        }
        _ = app.otherElements["screen_today"].waitForExistence(timeout: 10)

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
