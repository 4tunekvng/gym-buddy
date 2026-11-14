import XCTest
@testable import LLMClient

final class AnthropicClientResponseTests: XCTestCase {
    private func body(usage: String) -> Data {
        Data("""
        {"id": "msg_1", "model": "claude-sonnet-5-5",
         "content": [{"type": "text", "text": "Nice set."}],
         "usage": \(usage)}
        """.utf8)
    }

    func testTokensInIncludesCachedPromptReadsAndWrites() throws {
        let data = body(usage: """
        {"input_tokens": 12, "output_tokens": 30,
         "cache_read_input_tokens": 900, "cache_creation_input_tokens": 100}
        """)

        let response = try AnthropicClient.response(from: data)

        XCTAssertEqual(response.tokensIn, 1012)
        XCTAssertEqual(response.tokensOut, 30)
        XCTAssertEqual(response.text, "Nice set.")
    }

    func testTokensInWithoutCacheFieldsIsInputTokens() throws {
        let data = body(usage: #"{"input_tokens": 12, "output_tokens": 30}"#)

        let response = try AnthropicClient.response(from: data)

        XCTAssertEqual(response.tokensIn, 12)
    }
}
