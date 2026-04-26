import XCTest

/// Closes the persistence loop: onboard, run a live set, go to history, verify
/// the just-completed session is listed. Exercises SwiftData writes from
/// `LiveSessionViewModel.completeLifecycle` and reads from
/// `HistoryView.load`.
final class HistoryPersistenceUITest: XCTestCase {

    func testCompletedSessionShowsInHistory() throws {
        let app = XCUIApplication()
        XCTAssertTrue(UITestSupport.launchAndReachTodayScreen(app))
        app.buttons["today_start_push_up"].tap()
        _ = app.buttons["setup_start_button"].waitForExistence(timeout: 5)
        app.buttons["setup_start_button"].tap()

        // Wait for post-session.
        XCTAssertTrue(app.otherElements["screen_post_session"].waitForExistence(timeout: 30))
        app.buttons["post_session_done"].tap()

        // History should show at least one session now.
        _ = app.otherElements["screen_today"].waitForExistence(timeout: 5)
        app.buttons["today_history_button"].tap()
        XCTAssertTrue(app.otherElements["screen_history"].waitForExistence(timeout: 5))

        // The list should have at least one row — the row contains the exercise
        // name "Push-up" and a rep summary. We assert that at least the word
        // "Push-up" is on screen.
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Push-up'")).firstMatch.waitForExistence(timeout: 5),
            "Expected history to show a Push-up session row"
        )
    }
}
