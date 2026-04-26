import Foundation

/// Canonical cue types across all exercises.
///
/// Each cue binds to an observable pose-geometry signal with a tunable threshold,
/// documented in ExerciseTuning. Every cue has positive (should-fire) and
/// negative (should-not-fire) pose fixtures in the test suite.
public enum CueType: String, Codable, CaseIterable, Sendable {
    // --- Push-up cues
    case hipSag             // shoulder-hip-ankle out of line, hips low
    case hipPike            // hips high, inverted-V
    case elbowFlare         // elbows past shoulder plane
    case partialRangeBottom // didn't reach full depth (elbow angle threshold)
    case partialRangeTop    // didn't lock out at top
    case headPositionBad    // neck extension/flexion out of range

    // --- Goblet-squat cues
    case squatShallow       // hip crease above knee (above parallel)
    case kneeValgusLeft     // left knee caves in
    case kneeValgusRight    // right knee caves in
    case torsoForward       // trunk leans forward past threshold
    case heelLift           // heel rises from floor
    case dumbbellDrift      // dumbbell leaves sternum

    // --- Dumbbell-row cues
    case lumbarFlexion      // back rounding under load
    case elbowFlareRow      // elbow driving out rather than back
    case torsoInstability   // hip sway during the pull
    case partialRangeRowTop // elbow doesn't reach full extension
    case tempoJerkyRow      // explosive eccentric instead of controlled

    // --- Cross-exercise encouragement / guidance (not form cues but priority-ranked)
    case tempoEncourage     // "push through"
    case tempoDrive         // "one more — drive"
    case tempoLastOne       // "last one"

    /// The exercises a given cue applies to (others will never fire it).
    public var applicableExercises: Set<ExerciseID> {
        switch self {
        case .hipSag, .hipPike, .elbowFlare, .partialRangeBottom, .partialRangeTop, .headPositionBad:
            return [.pushUp]
        case .squatShallow, .kneeValgusLeft, .kneeValgusRight, .torsoForward, .heelLift, .dumbbellDrift:
            return [.gobletSquat]
        case .lumbarFlexion, .elbowFlareRow, .torsoInstability, .partialRangeRowTop, .tempoJerkyRow:
            return [.dumbbellRow]
        case .tempoEncourage, .tempoDrive, .tempoLastOne:
            return Set(ExerciseID.allCases)
        }
    }
}
