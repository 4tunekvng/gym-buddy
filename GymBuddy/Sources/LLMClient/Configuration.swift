import Foundation

/// LLM configuration. See ADR-0003 for vendor rationale.
///
/// The model id is a single constant — changing it is the single-line swap
/// required to point the client at a different Anthropic model without source
/// surgery anywhere else.
public struct LLMConfiguration: Equatable, Sendable {
    public let modelId: String
    public let maxTokensDefault: Int
    public let requestTimeout: TimeInterval
    public let streamingEnabled: Bool

    public init(
        modelId: String = "claude-opus-5-5",
        maxTokensDefault: Int = 400,
        requestTimeout: TimeInterval = 30,
        streamingEnabled: Bool = true
    ) {
        self.modelId = modelId
        self.maxTokensDefault = maxTokensDefault
        self.requestTimeout = requestTimeout
        self.streamingEnabled = streamingEnabled
    }
}
