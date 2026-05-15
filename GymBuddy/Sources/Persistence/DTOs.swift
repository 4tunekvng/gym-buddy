import Foundation
import CoachingEngine

/// Plain, Codable data transfer objects. SwiftData models will mirror these;
/// the repositories return DTOs so the app layer never touches SwiftData types.

public struct UserProfile: Equatable, Codable, Sendable, Identifiable {
    public let id: UUID
    public var displayName: String
    public var tone: CoachingTone
    public var experience: PlanGenerator.Inputs.Experience
    public var goal: PlanGenerator.Inputs.Goal
    public var equipment: PlanGenerator.Inputs.Equipment
    public var sessionsPerWeek: Int
    public var injuryBodyParts: Set<MemoryTag>
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        displayName: String,
        tone: CoachingTone,
        experience: PlanGenerator.Inputs.Experience,
        goal: PlanGenerator.Inputs.Goal,
        equipment: PlanGenerator.Inputs.Equipment,
        sessionsPerWeek: Int,
        injuryBodyParts: Set<MemoryTag> = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.tone = tone
        self.experience = experience
        self.goal = goal
        self.equipment = equipment
        self.sessionsPerWeek = sessionsPerWeek
        self.injuryBodyParts = injuryBodyParts
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct WorkoutSessionRecord: Equatable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date
    public let performedExercises: [PerformedExerciseRecord]
    public let painFlag: Bool
    public let summaryText: String?

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        performedExercises: [PerformedExerciseRecord],
        painFlag: Bool = false,
        summaryText: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.performedExercises = performedExercises
        self.painFlag = painFlag
        self.summaryText = summaryText
    }
}

public struct PerformedExerciseRecord: Equatable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let exerciseId: ExerciseID
    public let performedSets: [PerformedSetRecord]

    public init(
        id: UUID = UUID(),
        exerciseId: ExerciseID,
        performedSets: [PerformedSetRecord]
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.performedSets = performedSets
    }
}

public struct PerformedSetRecord: Equatable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let setNumber: Int
    public let reps: Int
    public let partialReps: Int
    public let durationSeconds: TimeInterval
    public let cues: [CueEventDTO]

    public init(
        id: UUID = UUID(),
        setNumber: Int,
        reps: Int,
        partialReps: Int,
        durationSeconds: TimeInterval,
        cues: [CueEventDTO]
    ) {
        self.id = id
        self.setNumber = setNumber
        self.reps = reps
        self.partialReps = partialReps
        self.durationSeconds = durationSeconds
        self.cues = cues
    }
}

public struct CueEventDTO: Equatable, Codable, Sendable {
    public let cueType: CueType
    public let severity: CueSeverity
    public let repNumber: Int
    public let timestamp: TimeInterval

    public init(cueType: CueType, severity: CueSeverity, repNumber: Int, timestamp: TimeInterval) {
        self.cueType = cueType
        self.severity = severity
        self.repNumber = repNumber
        self.timestamp = timestamp
    }

    public init(from event: CueEvent) {
        self.init(
            cueType: event.cueType,
            severity: event.severity,
            repNumber: event.repNumber,
            timestamp: event.timestamp
        )
    }
}

public extension WorkoutSessionRecord {
    /// Build a record from one or more SessionObservations produced by the engine.
    static func build(from observations: [SessionObservation], painFlag: Bool, summary: String?) -> WorkoutSessionRecord {
        let now = Date()
        let allReps = observations.flatMap(\.repEvents)
        let startedAt = allReps.first.map { Date(timeIntervalSinceReferenceDate: $0.startedAt) } ?? now
        let endedAt = allReps.last.map { Date(timeIntervalSinceReferenceDate: $0.endedAt) } ?? now
        let performed = Dictionary(grouping: observations, by: \.exerciseId)
            .map { (exerciseId, obs) in
                PerformedExerciseRecord(
                    exerciseId: exerciseId,
                    performedSets: obs.map { ob in
                        PerformedSetRecord(
                            setNumber: ob.setNumber,
                            reps: ob.totalReps,
                            partialReps: ob.partialReps,
                            durationSeconds: (ob.repEvents.last?.endedAt ?? 0) - (ob.repEvents.first?.startedAt ?? 0),
                            cues: ob.cueEvents.map { CueEventDTO(from: $0) }
                        )
                    }
                )
            }
        return WorkoutSessionRecord(
            startedAt: startedAt,
            endedAt: endedAt,
            performedExercises: performed,
            painFlag: painFlag,
            summaryText: summary
        )
    }
}
