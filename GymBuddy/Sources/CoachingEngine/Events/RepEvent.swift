import Foundation

/// A completed rep. Emitted when the rep FSM returns to `.top` after a full cycle.
public struct RepEvent: Equatable, Codable, Sendable {
    public let exerciseId: ExerciseID
    public let repNumber: Int
    public let startedAt: TimeInterval
    public let endedAt: TimeInterval
    public let concentricDuration: TimeInterval
    public let eccentricDuration: TimeInterval
    public let rangeOfMotionScore: Double
    public let isPartial: Bool

    public init(
        exerciseId: ExerciseID,
        repNumber: Int,
        startedAt: TimeInterval,
        endedAt: TimeInterval,
        concentricDuration: TimeInterval,
        eccentricDuration: TimeInterval,
        rangeOfMotionScore: Double,
        isPartial: Bool
    ) {
        self.exerciseId = exerciseId
        self.repNumber = repNumber
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.concentricDuration = concentricDuration
        self.eccentricDuration = eccentricDuration
        self.rangeOfMotionScore = rangeOfMotionScore
        self.isPartial = isPartial
    }

    public var totalDuration: TimeInterval { endedAt - startedAt }
}
