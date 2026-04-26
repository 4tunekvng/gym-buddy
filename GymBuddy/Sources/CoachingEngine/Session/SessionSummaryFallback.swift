import Foundation

/// OQ-009 fallback: never ship generic praise.
///
/// Used when the LLM either fails (network, timeout) or returns a safety-
/// substituted payload. The summary we produce here is required to include at
/// least one quantitative fact tied to the actual set the user just completed,
/// so the coach's voice stays grounded even in the degraded path.
///
/// Extracted into the domain layer so it's covered by Swift Package tests
/// (macOS + CI), not only exercised via the iOS view layer.
public enum SessionSummaryFallback {

    /// Generate a specific, non-generic summary string for the given observation.
    public static func summary(for obs: SessionObservation) -> String {
        var parts: [String] = []
        parts.append(leadFact(for: obs))
        if let qualitative = qualitativeNote(for: obs) {
            parts.append(qualitative)
        }
        parts.append(restHint)
        return parts.joined(separator: " ")
    }

    // MARK: - Helpers

    /// Lead fact — always quantitative.
    static func leadFact(for obs: SessionObservation) -> String {
        if obs.totalReps == 0 {
            return "Set logged — no reps counted this time."
        }
        if obs.partialReps > 0 && obs.fullReps > 0 {
            return "\(obs.fullReps) full reps + \(obs.partialReps) partial on \(obs.exerciseId.displayName)."
        }
        return "\(obs.totalReps) reps of \(obs.exerciseId.displayName)."
    }

    /// Qualitative note that references something specific from the observation.
    /// Priority order (most specific → most generic):
    ///   1. Safety cues fired — acknowledge the concern first.
    ///   2. Hit a personal-best (prior-session comparison).
    ///   3. Tempo fatigue surfaced — name the rep.
    ///   4. Clean full-ROM set — celebrate the effort.
    /// Returns nil when there's nothing honest to say.
    static func qualitativeNote(for obs: SessionObservation) -> String? {
        if obs.safetyCueCount > 0 {
            return "A few form cues fired — check the history for details."
        }
        if let prior = obs.priorSessionBestReps, obs.totalReps > prior {
            let delta = obs.totalReps - prior
            return "That's \(delta) past your last best."
        }
        if let fatigue = obs.fatigueSlowdownAtRep {
            return "You hit the grind at rep \(fatigue)."
        }
        if obs.totalReps > 0 && obs.partialReps == 0 {
            return "Clean through the whole set."
        }
        return nil
    }

    static let restHint = "Rest 90s and go again."
}
