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

    func testURLRequestAppendsMessagesPathToGatewayBaseURLAndUses2026Headers() throws {
        let request = LLMRequest(
            promptId: "post_set_summary", promptVersion: 1,
            system: "Coach.", user: "10 push-ups.", maxTokens: 200
        )
        let creds = AnthropicClient.Credentials(
            apiKey: "gw-token",
            baseURL: URL(string: "https://fortune-llm.fortunee.workers.dev")
        )
        let urlReq = try AnthropicClient.urlRequest(
            for: request,
            configuration: LLMConfiguration(),
            credentials: creds
        )

        XCTAssertEqual(
            urlReq.url?.absoluteString,
            "https://fortune-llm.fortunee.workers.dev/v1/messages"
        )
        XCTAssertEqual(urlReq.value(forHTTPHeaderField: "Authorization"), "Bearer gw-token")
        XCTAssertEqual(urlReq.value(forHTTPHeaderField: "anthropic-version"), "2026-10-21")
        XCTAssertNil(urlReq.value(forHTTPHeaderField: "x-api-key"))

        let fullCreds = AnthropicClient.Credentials(
            apiKey: "gw-token",
            baseURL: URL(string: "https://api.anthropic.com/v1/messages")
        )
        let fullReq = try AnthropicClient.urlRequest(
            for: request,
            configuration: LLMConfiguration(),
            credentials: fullCreds
        )
        XCTAssertEqual(
            fullReq.url?.absoluteString,
            "https://api.anthropic.com/v1/messages"
        )
    }
}
