import Foundation
import CoachingEngine

/// Versioned prompt templates.
///
/// Each prompt has an id, a version, and a rendering function that maps
/// structured inputs to (system, user) strings. Version increments on any
/// content change; the eval suite must pass for every version in the registry.
///
/// Organizing this in one file keeps it obvious what prompts exist and makes
/// schema drift impossible to hide.
public enum PromptRegistry {

    public struct RenderedPrompt: Equatable, Sendable {
        public let id: String
        public let version: Int
        public let system: String
        public let user: String
    }

    // MARK: - Prompt-injection sanitizer

    /// Neutralizes any externally-sourced string before it is interpolated into a
    /// prompt. Strips carriage returns, newlines, and double-quotes (replacing
    /// each with a space) so caller-supplied text — a user question, a freeform
    /// note, an LLM-extracted memory reference, a raw conversation transcript —
    /// cannot break out of its quoted/structural context and inject instructions.
    ///
    /// The prompt is plain text (no JSON/markdown escaping), so newline + an
    /// imperative ("ignore previous instructions…") is the whole attack. Removing
    /// those three characters defangs it while preserving the semantic content
    /// (words are kept; only structural whitespace is flattened to spaces).
    ///
    /// Apply to EVERY value that originates outside this codebase. Do NOT apply to
    /// enum `rawValue`s or numeric fields — those are a controlled vocabulary.
    static func sanitizeForPrompt(_ s: String) -> String {
        s.replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\"", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Safety preamble

    /// Prepended to every system prompt. See docs/Safety.md.
    public static let safetyPreamble: String = """
    You are Gym Buddy, a strength coach for an intermediate lifter.
    You will never: diagnose injuries or medical conditions, recommend specific calorie targets below 1,500 kcal/day or weight-cut plans, shame the user, or push through sharp pain signals.
    If the user describes sharp pain, tell them to stop and consult a physician or physical therapist.
    You are warm, technically fluent, honest, and demanding when earned. You never use pet names or gym-bro language unless the user has chosen an "intense" tone.
    """

    // MARK: - Post-set summary

    public static let postSetSummaryId = "post_set_summary"
    public static let postSetSummaryVersion = 1

    public static func renderPostSetSummary(
        observation: SessionObservation,
        tone: CoachingTone
    ) -> RenderedPrompt {
        let quantFacts: [String] = [
            "exercise=\(observation.exerciseId.rawValue)",
            "set_number=\(observation.setNumber)",
            "total_reps=\(observation.totalReps)",
            "full_reps=\(observation.fullReps)",
            "partial_reps=\(observation.partialReps)",
            "cue_events=\(observation.cueEvents.map(\.cueType.rawValue).joined(separator: ","))",
            "safety_cues=\(observation.safetyCueCount)",
            "tempo_baseline_ms=\(observation.tempoBaselineMs.map { "\($0)" } ?? "n/a")",
            "fatigue_at_rep=\(observation.fatigueSlowdownAtRep.map { "\($0)" } ?? "n/a")",
            "prior_best_reps=\(observation.priorSessionBestReps.map { "\($0)" } ?? "n/a")",
            "memory_refs=\(observation.memoryReferences.prefix(3).map(Self.sanitizeForPrompt).joined(separator: " | "))"
        ]

        let system = """
        \(safetyPreamble)

        Task: generate ONE short paragraph (2–4 sentences) summarizing the just-completed set. Tone: \(tone.rawValue).

        Rules:
        - MUST include at least one quantitative fact (rep count or delta vs prior session).
        - MUST include at least one qualitative observation grounded in the provided inputs.
        - MUST NOT use generic praise like "good job!" or "nice work!". Be specific.
        - If memory references are provided and relevant, reference ONE naturally. Never force it.
        - Never reference data not provided.
        """

        let user = """
        Session observations (structured):
        \(quantFacts.joined(separator: "\n"))

        Write the summary now.
        """

        return RenderedPrompt(
            id: postSetSummaryId,
            version: postSetSummaryVersion,
            system: system,
            user: user
        )
    }

    // MARK: - Between-set Q&A

    public static let betweenSetQAId = "between_set_qa"
    public static let betweenSetQAVersion = 1

    public static func renderBetweenSetQA(
        userQuestion: String,
        observation: SessionObservation,
        tone: CoachingTone
    ) -> RenderedPrompt {
        let system = """
        \(safetyPreamble)

        Task: answer the user's question in 1–3 sentences, grounded in the set they just completed and their memory notes (if provided).

        Rules:
        - Be specific. If you recommend adding weight, anchor the recommendation to today's rep count / tempo data.
        - Do NOT diagnose or recommend calorie cuts. If the question is medical, defer to a professional.
        - Tone: \(tone.rawValue).
        """

        let user = """
        Just-completed set:
        - exercise=\(observation.exerciseId.rawValue)
        - reps=\(observation.totalReps) (\(observation.partialReps) partial)
        - fatigue_at_rep=\(observation.fatigueSlowdownAtRep.map { "\($0)" } ?? "n/a")
        - prior_best_reps=\(observation.priorSessionBestReps.map { "\($0)" } ?? "n/a")

        Memory references:
        \(observation.memoryReferences.prefix(5).map { "- \(Self.sanitizeForPrompt($0))" }.joined(separator: "\n"))

        User question: "\(Self.sanitizeForPrompt(userQuestion))"
        """

        return RenderedPrompt(
            id: betweenSetQAId,
            version: betweenSetQAVersion,
            system: system,
            user: user
        )
    }

    // MARK: - Morning readiness

    public static let morningReadinessId = "morning_readiness"
    public static let morningReadinessVersion = 1

    public static func renderMorningReadiness(
        check: ReadinessCheck,
        memoryReferences: [String],
        tone: CoachingTone
    ) -> RenderedPrompt {
        let system = """
        \(safetyPreamble)

        Task: produce a morning check-in that is 1–3 sentences. It must:
        - Greet the user briefly and warmly.
        - Reference at least one specific thing from their memory notes if available (e.g. a body part they mentioned).
        - If HRV/sleep/soreness/energy inputs suggest a deload, say it.
        - Be shorter than 50 words. Tone: \(tone.rawValue).
        """
        let user = """
        Readiness inputs:
        - soreness=\(check.soreness.map { "\($0)" } ?? "n/a")
        - energy=\(check.energy.map { "\($0)" } ?? "n/a")
        - sleep_hours=\(check.sleepHours.map { "\($0)" } ?? "n/a")
        - hrv_delta_pct=\(check.hrvDeltaPct.map { "\($0)" } ?? "n/a")
        - user_note=\(Self.sanitizeForPrompt(check.userFreeformNote ?? ""))

        Memory references:
        \(memoryReferences.prefix(5).map { "- \(Self.sanitizeForPrompt($0))" }.joined(separator: "\n"))
        """
        return RenderedPrompt(
            id: morningReadinessId,
            version: morningReadinessVersion,
            system: system,
            user: user
        )
    }

    // MARK: - Coach memory note extraction

    public static let memoryExtractionId = "memory_extraction"
    public static let memoryExtractionVersion = 1

    public static func renderMemoryExtraction(
        sourceKind: String,
        conversationText: String
    ) -> RenderedPrompt {
        let system = """
        \(safetyPreamble)

        Task: extract durable coach-memory notes from the conversation.

        Output strictly as JSON array of objects with fields: content (string), tags (array of strings from the allowed vocabulary).

        Allowed tag vocabulary:
        injury, preference, mood, context, schedule, equipment, body-part:knee, body-part:shoulder, body-part:back, body-part:elbow, goal:strength, goal:hypertrophy, goal:recomp

        Rules:
        - Do not fabricate. Only capture things literally stated.
        - Do not speculate about the user's motivation.
        - Skip pleasantries ("thanks", "sounds good").
        - If nothing durable, output [].
        """
        let user = """
        Source: \(Self.sanitizeForPrompt(sourceKind))
        Conversation:
        \(Self.sanitizeForPrompt(conversationText))

        Output JSON now.
        """
        return RenderedPrompt(
            id: memoryExtractionId,
            version: memoryExtractionVersion,
            system: system,
            user: user
        )
    }
}
