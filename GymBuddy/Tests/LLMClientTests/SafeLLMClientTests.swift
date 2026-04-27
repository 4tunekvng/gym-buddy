import XCTest
@testable import CoachingEngine
@testable import LLMClient

/// Holds a captured value across a `Sendable` closure boundary — Swift 6
/// strict concurrency forbids mutating a captured `var` from inside a
/// `@Sendable` callback, so tests that need to record state from a callback
/// route it through this class.
private final class CapturedValue<Value: Sendable>: @unchecked Sendable {
    var value: Value?
}

final class SafeLLMClientTests: XCTestCase {

    func testUnsafeResponseIsSubstitutedWithSafeMarker() async throws {
        let mock = MockLLMClient()
        mock.setScript(.fixed("It sounds like a tear in your rotator cuff."), for: "x")
        let captured = CapturedValue<SafetyCategory>()
        let safe = SafeLLMClient(inner: mock, onSubstitution: { captured.value = $0 })
        let resp = try await safe.complete(request: LLMRequest(
            promptId: "x", promptVersion: 1, system: "", user: ""
        ))
        XCTAssertTrue(resp.text.hasPrefix("safe:"))
        XCTAssertEqual(captured.value, .diagnosis)
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
