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
        // are also the offline-fallback responses for the real app, so they
        // MUST honor the prompt contract — PRD §10.3 + the postSetSummary
        // system prompt both require a numeric fact (rep count) in the
        // summary. We grep that fact out of the structured user payload
        // rather than ship a generic line that would silently violate the
        // contract every time the network is down.
        switch request.promptId {
        case PromptRegistry.postSetSummaryId:
            return groundedPostSetSummary(for: request)
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

    /// Extract the rep count + fatigue + exercise from the structured prompt
    /// payload and produce a summary that always includes the rep count
    /// (PRD §10.3) and references at least one specific observation. We do
    /// the grounded-summary work here so the mock + offline-fallback path
    /// can never silently regress to generic praise.
    private func groundedPostSetSummary(for request: LLMRequest) -> String {
        let facts = parseFacts(from: request.user)
        let reps = facts["total_reps"].flatMap(Int.init) ?? 0
        let partial = facts["partial_reps"].flatMap(Int.init) ?? 0
        let exercise = humanExerciseName(facts["exercise"] ?? "")
        let fatigueAt = facts["fatigue_at_rep"].flatMap(Int.init)
        let priorBest = facts["prior_best_reps"].flatMap(Int.init)

        var parts: [String] = []
        if partial > 0 && reps > partial {
            let full = reps - partial
            parts.append("\(reps) reps of \(exercise) — \(full) full, \(partial) partial.")
        } else {
            parts.append("\(reps) reps of \(exercise).")
        }

        if let fatigueAt {
            parts.append("You hit the grind at rep \(fatigueAt) — that last stretch was the work.")
        } else if reps > 0 {
            parts.append("Tempo held all the way through.")
        }

        if let priorBest, reps > priorBest {
            parts.append("That's \(reps - priorBest) more than last time.")
        }

        parts.append("Rest 90 seconds; we go again.")
        return parts.joined(separator: " ")
    }

    private func parseFacts(from userPayload: String) -> [String: String] {
        var out: [String: String] = [:]
        for line in userPayload.split(separator: "\n") {
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            if !key.isEmpty { out[key] = value }
        }
        return out
    }

    private func humanExerciseName(_ raw: String) -> String {
        switch raw {
        case "push-up": return "Push-up"
        case "goblet-squat": return "Goblet Squat"
        case "dumbbell-row": return "Dumbbell Row"
        default:
            return raw.isEmpty ? "the set" : raw
        }
    }
}
