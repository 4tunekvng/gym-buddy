import Foundation
import CoachingEngine

/// The abstract LLM interface CoachingEngine uses when it needs a contextual
/// phrase — warm post-set summaries, between-set Q&A, morning readiness.
///
/// The implementation is pluggable: real Anthropic-SDK calls for production,
/// an in-memory mock for tests, a canned fallback for offline mode. CoachingEngine
/// never imports this package — the app composition root wires it in.
public protocol LLMClientProtocol: AnyObject, Sendable {
    /// Generate one response. Returns the full text after streaming completes.
    func complete(request: LLMRequest) async throws -> LLMResponse

    /// Streaming variant. Returns an AsyncSequence of text chunks as they arrive.
    func stream(request: LLMRequest) -> AsyncThrowingStream<String, Error>
}

public struct LLMRequest: Equatable, Sendable {
    public let promptId: String
    public let promptVersion: Int
    public let system: String
    public let user: String
    public let temperature: Double
    public let maxTokens: Int

    public init(
        promptId: String,
        promptVersion: Int,
        system: String,
        user: String,
        temperature: Double = 0.6,
        maxTokens: Int = 400
    ) {
        self.promptId = promptId
        self.promptVersion = promptVersion
        self.system = system
        self.user = user
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

public struct LLMResponse: Equatable, Sendable {
    public let text: String
    public let tokensIn: Int
    public let tokensOut: Int
    public let modelId: String

    public init(text: String, tokensIn: Int, tokensOut: Int, modelId: String) {
        self.text = text
        self.tokensIn = tokensIn
        self.tokensOut = tokensOut
        self.modelId = modelId
    }
}

public enum LLMClientError: Error, Equatable {
    case networkFailure(String)
    case rateLimited
    case invalidResponse
    case cancelled
    case safetyRefused
}
