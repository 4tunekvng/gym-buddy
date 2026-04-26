import Foundation

/// A set has ended. Carries the reason so the presentation layer can choose
/// the right follow-up (e.g., auto-detected → offer next set; user-paused → offer resume).
public struct SetEndEvent: Equatable, Codable, Sendable {
    public let exerciseId: ExerciseID
    public let setNumber: Int
    public let reason: EndReason
    public let timestamp: TimeInterval
    public let totalReps: Int
    public let partialReps: Int

    public init(
        exerciseId: ExerciseID,
        setNumber: Int,
        reason: EndReason,
        timestamp: TimeInterval,
        totalReps: Int,
        partialReps: Int
    ) {
        self.exerciseId = exerciseId
        self.setNumber = setNumber
        self.reason = reason
        self.timestamp = timestamp
        self.totalReps = totalReps
        self.partialReps = partialReps
    }

    public enum EndReason: String, Codable, Sendable {
        case autoDetectedStill
        case autoDetectedStanceChange
        case userTapped
        case userVoice
        case painPause
        case externalInterrupt
    }
}
