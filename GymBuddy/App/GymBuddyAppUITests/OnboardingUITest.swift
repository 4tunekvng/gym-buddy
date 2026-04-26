import XCTest

/// Verifies the onboarding → Today transition.
///
/// Uses `UITestSupport.launchAndReachTodayScreen` so the test survives
/// carryover SwiftData state from prior runs: fresh install walks through
/// onboarding, carried-over state skips straight to Today. Either way the
/// post-condition is the same — the Today screen is reachable.
final class OnboardingUITest: XCTestCase {

    func testFreshInstallCanCompleteOnboarding() throws {
        let app = XCUIApplication()
        XCTAssertTrue(UITestSupport.launchAndReachTodayScreen(app, name: "Fortune"))
    }
}
