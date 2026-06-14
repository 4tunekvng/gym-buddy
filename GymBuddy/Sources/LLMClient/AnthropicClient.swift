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
        /// Override the default Anthropic endpoint (e.g. a gateway proxy).
        /// Reads from ANTHROPIC_BASE_URL at call-site; nil falls back to the
        /// canonical Anthropic Messages URL.
        public let baseURL: URL?
        public init(apiKey: String, baseURL: URL? = nil) {
            self.apiKey = apiKey
            self.baseURL = baseURL
        }
    }

    private let configuration: LLMConfiguration
    private let credentials: Credentials
    private let urlSession: URLSession

    private static let defaultBaseURL: URL = {
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
        let endpoint = credentials.baseURL ?? Self.defaultBaseURL
        var urlRequest = URLRequest(
            url: endpoint,
            timeoutInterval: configuration.requestTimeout
        )
        urlRequest.httpMethod = "POST"
        urlRequest.addValue(credentials.apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.addValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.addValue("prompt-caching-2024-07-31", forHTTPHeaderField: "anthropic-beta")

        let payload = AnthropicRequestPayload(
            model: configuration.modelId,
            system: [.init(text: request.system)],
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
            let task = Task {
                do {
                    // Minimal MVP implementation delegates to non-streaming complete.
                    // Real SSE parsing is Chapter 1+ polish; the protocol surface
                    // here is stable regardless.
                    let full = try await self.complete(request: request)
                    continuation.yield(full.text)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private struct AnthropicRequestPayload: Encodable {
    let model: String
    let system: [SystemBlock]
    let max_tokens: Int
    let temperature: Double
    let messages: [Message]

    struct SystemBlock: Encodable {
        let type: String = "text"
        let text: String
        let cache_control: CacheControl = .init()
        struct CacheControl: Encodable { let type: String = "ephemeral" }
    }

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
