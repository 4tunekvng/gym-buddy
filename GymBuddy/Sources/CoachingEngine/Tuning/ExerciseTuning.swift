import Foundation

/// All tunable thresholds live here, in one place, per exercise.
///
/// Values are calibrated against the fixture suite. Changing them is expected
/// to require fixture test updates — that's intentional. Rationale:
/// - Push-up angles: elbow flexion at "bottom" ≈ 90° or less (arms bent).
/// - Goblet squat depth: hip y below knee y = below parallel.
/// - Row top: elbow roughly at shoulder height, past torso line.
public struct ExerciseTuning: Sendable {
    public let repEnteringDescent: Angle
    public let repAtBottom: Angle
    public let repExitingBottom: Angle
    public let repAtTop: Angle
    public let partialRomThreshold: Double   // 0..1, ROM score below = partial
    public let cueTuning: [CueType: Double]

    public static let pushUp = ExerciseTuning(
        repEnteringDescent: Angle(degrees: 150),
        repAtBottom: Angle(degrees: 100),
        repExitingBottom: Angle(degrees: 110),
        repAtTop: Angle(degrees: 160),
        partialRomThreshold: 0.75,
        cueTuning: [
            .hipSag: 0.06,                 // normalized deviation tolerance
            .hipPike: 0.08,
            .elbowFlare: Angle(degrees: 80).radians,   // elbow-to-torso angle
            .partialRangeBottom: Angle(degrees: 110).radians,
            .partialRangeTop: Angle(degrees: 155).radians,
            .headPositionBad: 0.05
        ]
    )

    public static let gobletSquat = ExerciseTuning(
        repEnteringDescent: Angle(degrees: 160),
        repAtBottom: Angle(degrees: 85),
        repExitingBottom: Angle(degrees: 95),
        repAtTop: Angle(degrees: 165),
        partialRomThreshold: 0.80,
        cueTuning: [
            .squatShallow: 0.02,           // hip-below-knee margin in normalized image coords
            .kneeValgusLeft: 0.05,
            .kneeValgusRight: 0.05,
            .torsoForward: Angle(degrees: 45).radians,
            .heelLift: 0.03,
            .dumbbellDrift: 0.07
        ]
    )

    public static let dumbbellRow = ExerciseTuning(
        repEnteringDescent: Angle(degrees: 160),
        repAtBottom: Angle(degrees: 85),
        repExitingBottom: Angle(degrees: 95),
        repAtTop: Angle(degrees: 80),
        partialRomThreshold: 0.75,
        cueTuning: [
            .lumbarFlexion: 0.07,
            .elbowFlareRow: Angle(degrees: 45).radians,
            .torsoInstability: 0.04,
            .partialRangeRowTop: Angle(degrees: 95).radians,
            .tempoJerkyRow: 0.25
        ]
    )

    public static func `for`(_ exercise: ExerciseID) -> ExerciseTuning {
        switch exercise {
        case .pushUp: .pushUp
        case .gobletSquat: .gobletSquat
        case .dumbbellRow: .dumbbellRow
        }
    }
}
