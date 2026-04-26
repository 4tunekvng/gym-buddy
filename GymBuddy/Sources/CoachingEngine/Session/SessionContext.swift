import Foundation

/// Context the engine needs about the user, independent of any one set.
///
/// Kept intentionally minimal. Anything the engine doesn't actually need to
/// reason in-set stays out of this struct (profile is big; session context is
/// what's *relevant* to the currently-running set).
public struct SessionContext: Equatable, Codable, Sendable {
    public let userId: UUID
    public let tone: CoachingTone
    public let priorSessionBestReps: [ExerciseID: Int]
    public let activeInjuryNotes: [String]     // e.g. "left knee clicks on deep squats"
    public let memoryReferences: [String]

    public init(
        userId: UUID,
        tone: CoachingTone,
        priorSessionBestReps: [ExerciseID: Int] = [:],
        activeInjuryNotes: [String] = [],
        memoryReferences: [String] = []
    ) {
        self.userId = userId
        self.tone = tone
        self.priorSessionBestReps = priorSessionBestReps
        self.activeInjuryNotes = activeInjuryNotes
        self.memoryReferences = memoryReferences
    }
}
