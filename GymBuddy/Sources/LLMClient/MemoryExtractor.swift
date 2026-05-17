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
        // Trim whitespace and strip optional markdown code fences so the parser
        // tolerates model responses that wrap JSON in ```json ... ``` blocks or
        // add prose before/after the array.
        var trimmed = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            // Drop the opening fence line (e.g. "```json\n" or "```\n").
            if let newline = trimmed.range(of: "\n") {
                trimmed = String(trimmed[newline.upperBound...])
            }
        }
        if trimmed.hasSuffix("```") {
            trimmed = String(trimmed.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Locate the outermost JSON array so leading prose is skipped.
        if let start = trimmed.firstIndex(of: "["), let end = trimmed.lastIndex(of: "]"),
           start <= end {
            trimmed = String(trimmed[start...end])
        }
        guard let data = trimmed.data(using: .utf8) else { return [] }
        struct Raw: Decodable { let content: String; let tags: [String] }
        // Return empty rather than throwing so callers aren't broken by a
        // model response that doesn't conform exactly to the expected schema.
        do {
            let rawNotes = try JSONDecoder().decode([Raw].self, from: data)
            return rawNotes.map {
                CoachMemoryNote(content: $0.content, tags: Set($0.tags))
            }
        } catch {
            return []
        }
    }
}
