import XCTest
@testable import CoachingEngine
@testable import LLMClient

final class SafeLLMClientTests: XCTestCase {

    func testUnsafeResponseIsSubstitutedWithSafeMarker() async throws {
        let mock = MockLLMClient()
        mock.setScript(.fixed("It sounds like a tear in your rotator cuff."), for: "x")
        var substitutedCategory: SafetyCategory?
        let safe = SafeLLMClient(inner: mock, onSubstitution: { cat in substitutedCategory = cat })
        let resp = try await safe.complete(request: LLMRequest(
            promptId: "x", promptVersion: 1, system: "", user: ""
        ))
        XCTAssertTrue(resp.text.hasPrefix("safe:"))
        XCTAssertEqual(substitutedCategory, .diagnosis)
    }

    func testSafeResponsePassesThroughUnchanged() async throws {
        let mock = MockLLMClient()
        mock.setScript(.fixed("Good set — rest 90s."), for: "y")
        let safe = SafeLLMClient(inner: mock)
        let resp = try await safe.complete(request: LLMRequest(
            promptId: "y", promptVersion: 1, system: "", user: ""
        ))
        XCTAssertEqual(resp.text, "Good set — rest 90s.")
    }
}
