import Foundation

/// LLM configuration. See ADR-0003 for vendor rationale.
///
/// The model id is a single constant — changing it is the single-line swap
/// required to point the client at a different Anthropic model without source
/// surgery anywhere else.
public struct LLMConfiguration: Equatable, Sendable {
    public let modelId: String
    public let maxTokensDefault: Int
    public let temperatureDefault: Double
    public let requestTimeout: TimeInterval
    public let streamingEnabled: Bool

    public init(
        modelId: String = "claude-opus-4-7",
        maxTokensDefault: Int = 400,
        temperatureDefault: Double = 0.6,
        requestTimeout: TimeInterval = 30,
        streamingEnabled: Bool = true
    ) {
        self.modelId = modelId
        self.maxTokensDefault = maxTokensDefault
        self.temperatureDefault = temperatureDefault
        self.requestTimeout = requestTimeout
        self.streamingEnabled = streamingEnabled
    }
}
