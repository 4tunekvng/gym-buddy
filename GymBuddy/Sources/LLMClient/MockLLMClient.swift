import Foundation
import CoachingEngine

/// An in-memory mock LLM. Responses are prewritten per prompt id so tests get
/// deterministic output without hitting the network. Offline-fallback mode in
/// the real app also uses this when the network is unavailable.
public final class MockLLMClient: LLMClientProtocol, @unchecked Sendable {

    public enum Script: Sendable {
        /// Always return this text for the given request.
        case fixed(String)
        /// Return a text constructed from the request.
        case transform(@Sendable (LLMRequest) -> String)
        /// Simulate a network error.
        case error(LLMClientError)
    }

    private var scripts: [String: Script]
    private let modelId: String
    public private(set) var callLog: [LLMRequest] = []

    public init(
        scripts: [String: Script] = [:],
        modelId: String = "mock-claude"
    ) {
        self.scripts = scripts
        self.modelId = modelId
    }

    public func setScript(_ script: Script, for promptId: String) {
        scripts[promptId] = script
    }

    public func complete(request: LLMRequest) async throws -> LLMResponse {
        callLog.append(request)
        guard let script = scripts[request.promptId] else {
            return LLMResponse(
                text: defaultFallback(for: request),
                tokensIn: request.user.count / 4,
                tokensOut: 20,
                modelId: modelId
            )
        }
        switch script {
        case .fixed(let text):
            return LLMResponse(text: text, tokensIn: request.user.count / 4, tokensOut: text.count / 4, modelId: modelId)
        case .transform(let f):
            let text = f(request)
            return LLMResponse(text: text, tokensIn: request.user.count / 4, tokensOut: text.count / 4, modelId: modelId)
        case .error(let err):
            throw err
        }
    }

    public func stream(request: LLMRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let resp = try await self.complete(request: request)
                    // Chunk into sentences.
                    let chunks = resp.text.split(separator: ".", omittingEmptySubsequences: true).map { String($0) + "." }
                    for chunk in chunks {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func defaultFallback(for request: LLMRequest) -> String {
        // Deterministic, specific-enough canned responses by prompt id. These
        // are also the offline-fallback responses for the real app.
        switch request.promptId {
        case PromptRegistry.postSetSummaryId:
            return "Set done. Clean work through the middle; last two reps were the grind. Rest up."
        case PromptRegistry.betweenSetQAId:
            return "Stay where you are for this set. Judge by the last two reps — if they were smooth, add next time."
        case PromptRegistry.morningReadinessId:
            return "Morning. Ready when you are."
        case PromptRegistry.memoryExtractionId:
            return "[]"
        default:
            return "Okay."
        }
    }
}
