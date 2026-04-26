import Foundation
import CoachingEngine

/// Decorator that routes every LLM response through ContentSafetyFilter.
///
/// Any client wrapped by this gets the post-LLM safety filter for free. A
/// substituted response replaces the model output with a pre-written safe
/// phrase id (which VoiceIO then plays from the pre-recorded library).
public final class SafeLLMClient: LLMClientProtocol {
    private let inner: LLMClientProtocol
    private let filter: ContentSafetyFilter
    private let onSubstitution: @Sendable (SafetyCategory) -> Void

    public init(
        inner: LLMClientProtocol,
        filter: ContentSafetyFilter = ContentSafetyFilter(),
        onSubstitution: @escaping @Sendable (SafetyCategory) -> Void = { _ in }
    ) {
        self.inner = inner
        self.filter = filter
        self.onSubstitution = onSubstitution
    }

    public func complete(request: LLMRequest) async throws -> LLMResponse {
        let response = try await inner.complete(request: request)
        let result = filter.inspect(response.text)
        switch result.action {
        case .proceed:
            return response
        case .substituteResponse(let category, let safeResponseId):
            onSubstitution(category)
            // Replace the text with a marker that VoiceIO will map to a
            // pre-recorded safe response. Callers should detect `safe:` prefix.
            return LLMResponse(
                text: "safe:\(safeResponseId)",
                tokensIn: response.tokensIn,
                tokensOut: 0,
                modelId: response.modelId
            )
        case .stopSet:
            throw LLMClientError.safetyRefused
        }
    }

    public func stream(request: LLMRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = try await self.complete(request: request)
                    continuation.yield(response.text)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
