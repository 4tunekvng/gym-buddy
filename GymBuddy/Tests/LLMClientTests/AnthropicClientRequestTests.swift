import XCTest
@testable import LLMClient

final class AnthropicClientRequestTests: XCTestCase {
    // Claude 4.7+ models reject non-default sampling values with a 400, and
    // API version 2026-10-21 rejects the fields outright.
    func testRequestBodySendsNoSamplingParameters() throws {
        let request = LLMRequest(
            promptId: "post_set_summary", promptVersion: 1,
            system: "Coach.", user: "10 push-ups.", maxTokens: 200
        )

        let data = try AnthropicClient.body(for: request, modelId: "claude-opus-5-5")
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(
            Set(json.keys), ["model", "system", "max_tokens", "messages"]
        )
    }
}
