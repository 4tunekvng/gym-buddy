import Foundation

/// A 4-week linear-progression plan.
///
/// Each `PlanDay` has a concrete prescribed workout. Progression is simple:
/// reps or sets add a small delta week-over-week, per `PlanGenerator` rules.
public struct Plan: Equatable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let weeks: [PlanWeek]
    public let rationale: String

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        weeks: [PlanWeek],
        rationale: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.weeks = weeks
        self.rationale = rationale
    }
}

public struct PlanWeek: Equatable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let weekNumber: Int
    public let days: [PlanDay]

    public init(id: UUID = UUID(), weekNumber: Int, days: [PlanDay]) {
        self.id = id
        self.weekNumber = weekNumber
        self.days = days
    }
}

public struct PlanDay: Equatable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let weekNumber: Int
    public let dayOfWeek: Int         // 1 = Monday
    public let isRestDay: Bool
    public let exercises: [PlannedExercise]

    public init(
        id: UUID = UUID(),
        weekNumber: Int,
        dayOfWeek: Int,
        isRestDay: Bool,
        exercises: [PlannedExercise]
    ) {
        self.id = id
        self.weekNumber = weekNumber
        self.dayOfWeek = dayOfWeek
        self.isRestDay = isRestDay
        self.exercises = exercises
    }
}

public struct PlannedExercise: Equatable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let exerciseId: ExerciseID
    public let sets: [PlannedSet]

    public init(id: UUID = UUID(), exerciseId: ExerciseID, sets: [PlannedSet]) {
        self.id = id
        self.exerciseId = exerciseId
        self.sets = sets
    }
}

public struct PlannedSet: Equatable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let setNumber: Int
    public let targetReps: Int
    public let isAmrap: Bool
    public let targetLoadKg: Double?

    public init(
        id: UUID = UUID(),
        setNumber: Int,
        targetReps: Int,
        isAmrap: Bool = false,
        targetLoadKg: Double? = nil
    ) {
        self.id = id
        self.setNumber = setNumber
        self.targetReps = targetReps
        self.isAmrap = isAmrap
        self.targetLoadKg = targetLoadKg
    }
}
