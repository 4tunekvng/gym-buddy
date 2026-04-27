import XCTest

/// Full end-to-end happy path for the hero flow.
///
/// Walks: (welcome → onboarding →)? today → tap Push-up → setup overlay →
/// "Start set" → rep counter advances → post-session summary → back to today.
///
/// The test explicitly forces scripted demo mode through launch environment.
/// That keeps the end-to-end run deterministic while making the fallback mode
/// visible in the UI rather than silently pretending the camera path is live.
final class LiveSessionHappyPathUITest: XCTestCase {

    func testOnboardThenPushUpSet() throws {
        let app = XCUIApplication()
        XCTAssertTrue(UITestSupport.launchAndReachTodayScreen(app, name: "Fortune"))

        let pushUpStart = app.buttons["today_start_push_up"]
        XCTAssertTrue(pushUpStart.waitForExistence(timeout: 5))
        pushUpStart.tap()

        XCTAssertTrue(app.otherElements["live_runtime_status"].waitForExistence(timeout: 5))
        let setupStart = app.buttons["setup_start_button"]
        XCTAssertTrue(setupStart.waitForExistence(timeout: 5))
        setupStart.tap()

        XCTAssertTrue(app.otherElements["live_demo_banner"].waitForExistence(timeout: 5))
        let counter = app.staticTexts["rep_counter"]
        XCTAssertTrue(counter.waitForExistence(timeout: 10))

        XCTAssertTrue(app.otherElements["screen_post_session"].waitForExistence(timeout: 25))
        XCTAssertTrue(app.staticTexts["post_session_summary_text"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["post_session_summary_source"].waitForExistence(timeout: 5))

        app.buttons["post_session_done"].tap()
        XCTAssertTrue(app.otherElements["screen_today"].waitForExistence(timeout: 5))
    }

    /// Pressing "End set" before the stillness auto-end should still navigate
    /// to the post-session summary.
    func testExplicitEndSetShowsSummary() throws {
        let app = XCUIApplication()
        XCTAssertTrue(UITestSupport.launchAndReachTodayScreen(app))
        app.buttons["today_start_push_up"].tap()
        _ = app.buttons["setup_start_button"].waitForExistence(timeout: 5)
        app.buttons["setup_start_button"].tap()

        _ = app.staticTexts["rep_counter"].waitForExistence(timeout: 10)
        sleep(2)
        app.buttons["live_end_set"].tap()

        XCTAssertTrue(app.otherElements["screen_post_session"].waitForExistence(timeout: 10))
    }
}
