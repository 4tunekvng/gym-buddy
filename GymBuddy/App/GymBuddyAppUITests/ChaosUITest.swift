import XCTest

/// Chaos / edge-case UI behaviour. These aren't assertion-heavy; they look for
/// "does the app survive and stay responsive?" over a rough treatment.
final class ChaosUITest: XCTestCase {

    /// Rapidly tap the onboarding Next button without waiting. Should end up on
    /// Today without spinning or crashing.
    func testRapidOnboardingTapsLandOnToday() throws {
        let app = XCUIApplication()
        app.launch()

        if app.buttons["welcome_start_button"].waitForExistence(timeout: 3) {
            app.buttons["welcome_start_button"].tap()
            let nameField = app.textFields["onboarding_name_field"]
            _ = nameField.waitForExistence(timeout: 5)
            nameField.tap()
            nameField.typeText("Chaos")
            app.buttons["onboarding_next"].tap()
            // Fire all 7 Next taps as fast as possible — no sleeps, no waits.
            let next = app.buttons["onboarding_next"]
            for _ in 0..<7 where next.exists {
                next.tap()
            }
        }

        XCTAssertTrue(app.otherElements["screen_today"].waitForExistence(timeout: 10))
    }

    /// Start a live session, immediately end it. Should route to post-session
    /// with a non-empty observation (0 reps is fine; the summary view handles
    /// that gracefully with its specific-numeric fallback).
    func testImmediateEndSetShowsPostSession() throws {
        let app = XCUIApplication()
        XCTAssertTrue(UITestSupport.launchAndReachTodayScreen(app))
        app.buttons["today_start_push_up"].tap()
        _ = app.buttons["setup_start_button"].waitForExistence(timeout: 5)
        app.buttons["setup_start_button"].tap()
        // Hit End set the moment it appears — don't wait for any reps.
        let endSet = app.buttons["live_end_set"]
        XCTAssertTrue(endSet.waitForExistence(timeout: 5))
        endSet.tap()
        XCTAssertTrue(app.otherElements["screen_post_session"].waitForExistence(timeout: 10))
    }

    /// Navigate rapidly: today → settings → back → history → back → today.
    /// The router should stay consistent.
    func testRapidNavigationLoopIsStable() throws {
        let app = XCUIApplication()
        XCTAssertTrue(UITestSupport.launchAndReachTodayScreen(app))

        for _ in 0..<3 {
            app.buttons["today_settings_button"].tap()
            _ = app.otherElements["screen_settings"].waitForExistence(timeout: 3)
            app.buttons["settings_back"].tap()
            _ = app.otherElements["screen_today"].waitForExistence(timeout: 3)

            app.buttons["today_history_button"].tap()
            _ = app.otherElements["screen_history"].waitForExistence(timeout: 3)
            app.buttons["history_back"].tap()
            _ = app.otherElements["screen_today"].waitForExistence(timeout: 3)
        }

        XCTAssertTrue(app.otherElements["screen_today"].exists)
    }

    /// Background the app during a live set; foreground it; session continues
    /// and eventually reaches post-session.
    func testBackgroundingDuringLiveSessionStillCompletes() throws {
        let app = XCUIApplication()
        XCTAssertTrue(UITestSupport.launchAndReachTodayScreen(app))
        app.buttons["today_start_push_up"].tap()
        _ = app.buttons["setup_start_button"].waitForExistence(timeout: 5)
        app.buttons["setup_start_button"].tap()
        _ = app.staticTexts["rep_counter"].waitForExistence(timeout: 10)

        // Send to background and back. XCUIDevice supports this via Springboard.
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()

        // Should still reach post-session.
        XCTAssertTrue(app.otherElements["screen_post_session"].waitForExistence(timeout: 30))
    }
}
