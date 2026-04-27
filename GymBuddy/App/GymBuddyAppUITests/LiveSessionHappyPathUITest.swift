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

        // PRD §6.5 — the Today screen opens with a personal greeting that
        // includes the user's name. A generic "friend" fallback would mean
        // the profile didn't actually persist, which is a real regression.
        let greeting = app.staticTexts["today_greeting"]
        XCTAssertTrue(greeting.waitForExistence(timeout: 5))
        XCTAssertFalse(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Good to see you, friend'")).firstMatch.exists,
            "Today greeting should use the onboarded name (Fortune), not the 'friend' fallback"
        )

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

        // PRD §10.3 / §6.3: post-set summary must reference specific numeric
        // facts from the set ("X reps of Push-up. ..."), never generic praise.
        // We assert the summary text contains a digit so the user always sees
        // a concrete fact about what just happened.
        let summary = app.staticTexts["post_session_summary_text"]
        let summaryText = summary.label
        XCTAssertTrue(
            summaryText.range(of: #"\d"#, options: .regularExpression) != nil,
            "Post-set summary must contain a numeric fact (rep count). Got: '\(summaryText)'"
        )
        XCTAssertFalse(
            summaryText.lowercased().contains("good job"),
            "Post-set summary must not be generic praise. Got: '\(summaryText)'"
        )

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
