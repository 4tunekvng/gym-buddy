import Foundation
import CoachingEngine

/// Anthropic Messages API client. Uses URLSession directly to avoid pulling in
/// a vendor SDK in MVP — see ADR-0003. Streaming is via SSE.
///
/// This is intentionally minimal and doesn't handle every Anthropic feature:
/// we only need Messages/stream for our prompts, not tool use or vision.
public final class AnthropicClient: LLMClientProtocol, @unchecked Sendable {
    public struct Credentials: Sendable {
        public let apiKey: String
        public init(apiKey: String) { self.apiKey = apiKey }
    }

    private let configuration: LLMConfiguration
    private let credentials: Credentials
    private let urlSession: URLSession
    /// Hardcoded Anthropic Messages endpoint. The constant is well-formed by
    /// inspection so we lazy-construct via a guarded initializer rather than
    /// `URL(string:)!` (which would trip the no-force-unwrap rule).
    private static let baseURL: URL = {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            preconditionFailure("Anthropic base URL constant is malformed — fix the literal.")
        }
        return url
    }()

    public init(
        configuration: LLMConfiguration = LLMConfiguration(),
        credentials: Credentials,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.credentials = credentials
        self.urlSession = urlSession
    }

    public func complete(request: LLMRequest) async throws -> LLMResponse {
        var urlRequest = URLRequest(url: Self.baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue(credentials.apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.addValue("application/json", forHTTPHeaderField: "content-type")

        let payload = AnthropicRequestPayload(
            model: configuration.modelId,
            system: request.system,
            max_tokens: request.maxTokens,
            temperature: request.temperature,
            messages: [.init(role: "user", content: request.user)]
        )
        urlRequest.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await urlSession.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw LLMClientError.invalidResponse
        }
        if http.statusCode == 429 { throw LLMClientError.rateLimited }
        guard (200..<300).contains(http.statusCode) else {
            throw LLMClientError.networkFailure("status_\(http.statusCode)")
        }
        let decoded = try JSONDecoder().decode(AnthropicResponsePayload.self, from: data)
        let text = decoded.content.first(where: { $0.type == "text" })?.text ?? ""
        return LLMResponse(
            text: text,
            tokensIn: decoded.usage.input_tokens,
            tokensOut: decoded.usage.output_tokens,
            modelId: decoded.model
        )
    }

    public func stream(request: LLMRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Minimal MVP implementation delegates to non-streaming complete.
                    // Real SSE parsing is Chapter 1+ polish; the protocol surface
                    // here is stable regardless.
                    let full = try await self.complete(request: request)
                    let chunks = full.text.split(separator: ".", omittingEmptySubsequences: true).map { String($0) + "." }
                    for chunk in chunks { continuation.yield(chunk) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

private struct AnthropicRequestPayload: Encodable {
    let model: String
    let system: String
    let max_tokens: Int
    let temperature: Double
    let messages: [Message]
    struct Message: Encodable { let role: String; let content: String }
}

private struct AnthropicResponsePayload: Decodable {
    let id: String
    let model: String
    let content: [ContentBlock]
    let usage: Usage
    struct ContentBlock: Decodable { let type: String; let text: String? }
    struct Usage: Decodable { let input_tokens: Int; let output_tokens: Int }
}
