import Foundation
import CoachingEngine

/// Extracts coach memory notes from unstructured conversation text via the LLM.
/// Output is JSON shaped per `PromptRegistry.memoryExtractionId`.
public struct MemoryExtractor: Sendable {
    public enum Source: String, Sendable {
        case onboarding
        case betweenSet
        case postSession
        case morningCheckIn
    }

    public let client: LLMClientProtocol

    public init(client: LLMClientProtocol) {
        self.client = client
    }

    public func extract(
        from conversation: String,
        source: Source
    ) async throws -> [CoachMemoryNote] {
        let rendered = PromptRegistry.renderMemoryExtraction(
            sourceKind: source.rawValue,
            conversationText: conversation
        )
        let request = LLMRequest(
            promptId: rendered.id,
            promptVersion: rendered.version,
            system: rendered.system,
            user: rendered.user,
            temperature: 0.0,
            maxTokens: 400
        )
        let response = try await client.complete(request: request)
        return try Self.parse(response.text)
    }

    public static func parse(_ jsonText: String) throws -> [CoachMemoryNote] {
        // Trim to the JSON array portion in case the model wraps the output in prose.
        let trimmed = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else { return [] }
        struct Raw: Decodable { let content: String; let tags: [String] }
        let rawNotes = (try? JSONDecoder().decode([Raw].self, from: data)) ?? []
        return rawNotes.map {
            CoachMemoryNote(content: $0.content, tags: Set($0.tags))
        }
    }
}
