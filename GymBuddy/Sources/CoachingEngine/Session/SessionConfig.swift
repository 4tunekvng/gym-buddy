import Foundation

/// Configuration for a single set within a live session.
public struct SessionConfig: Equatable, Codable, Sendable {
    public let exerciseId: ExerciseID
    public let setNumber: Int
    public let targetReps: Int?
    public let tone: CoachingTone
    public let restSeconds: TimeInterval

    public init(
        exerciseId: ExerciseID,
        setNumber: Int,
        targetReps: Int?,
        tone: CoachingTone,
        restSeconds: TimeInterval = 90
    ) {
        self.exerciseId = exerciseId
        self.setNumber = setNumber
        self.targetReps = targetReps
        self.tone = tone
        self.restSeconds = restSeconds
    }
}
