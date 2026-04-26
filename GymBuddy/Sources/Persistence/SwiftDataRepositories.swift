import Foundation
import CoachingEngine

#if canImport(SwiftData)
import SwiftData

/// Concrete SwiftData-backed repositories. They encode/decode DTOs as JSON into
/// the `payload` blob fields. This keeps the SwiftData schema simple and makes
/// the domain DTOs the source of truth — a schema evolution is an encoder change
/// in most cases, not a CoreData-style migration.

@available(iOS 17.0, macOS 14.0, *)
public final class SwiftDataUserProfileRepository: UserProfileRepository {
    private let container: ModelContainer
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(container: ModelContainer) {
        self.container = container
    }

    public func load() async throws -> UserProfile? {
        let context = ModelContext(container)
        let stored = try context.fetch(FetchDescriptor<GymBuddySchemaV1.StoredUserProfile>()).first
        guard let data = stored?.payload else { return nil }
        return try decoder.decode(UserProfile.self, from: data)
    }

    public func save(_ profile: UserProfile) async throws {
        let context = ModelContext(container)
        let existing = try context.fetch(FetchDescriptor<GymBuddySchemaV1.StoredUserProfile>()).first
        let data = try encoder.encode(profile)
        if let existing {
            existing.payload = data
            existing.updatedAt = Date()
        } else {
            let row = GymBuddySchemaV1.StoredUserProfile(id: profile.id, payload: data, updatedAt: Date())
            context.insert(row)
        }
        try context.save()
    }
}

@available(iOS 17.0, macOS 14.0, *)
public final class SwiftDataPlanRepository: PlanRepository {
    private let container: ModelContainer
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(container: ModelContainer) { self.container = container }

    public func activePlan() async throws -> Plan? {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<GymBuddySchemaV1.StoredPlan>(
            predicate: #Predicate { $0.isActive }
        )
        guard let stored = try context.fetch(descriptor).first else { return nil }
        return try decoder.decode(Plan.self, from: stored.payload)
    }

    public func save(_ plan: Plan) async throws {
        let context = ModelContext(container)
        // Deactivate previous active plan(s).
        let active = try context.fetch(FetchDescriptor<GymBuddySchemaV1.StoredPlan>(
            predicate: #Predicate { $0.isActive }
        ))
        active.forEach { $0.isActive = false }
        let data = try encoder.encode(plan)
        let row = GymBuddySchemaV1.StoredPlan(
            id: plan.id, createdAt: plan.createdAt, payload: data, isActive: true
        )
        context.insert(row)
        try context.save()
    }

    public func delete(_ planId: UUID) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<GymBuddySchemaV1.StoredPlan>(
            predicate: #Predicate { $0.id == planId }
        )
        for row in try context.fetch(descriptor) {
            context.delete(row)
        }
        try context.save()
    }
}

@available(iOS 17.0, macOS 14.0, *)
public final class SwiftDataSessionRepository: SessionRepository {
    private let container: ModelContainer
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(container: ModelContainer) { self.container = container }

    public func record(_ session: WorkoutSessionRecord) async throws {
        let context = ModelContext(container)
        let data = try encoder.encode(session)
        let row = GymBuddySchemaV1.StoredWorkoutSession(
            id: session.id,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            payload: data
        )
        context.insert(row)
        try context.save()
    }

    public func recent(limit: Int) async throws -> [WorkoutSessionRecord] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<GymBuddySchemaV1.StoredWorkoutSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor).compactMap {
            try? decoder.decode(WorkoutSessionRecord.self, from: $0.payload)
        }
    }

    public func bestReps(for exerciseId: ExerciseID) async throws -> Int? {
        let recent = try await recent(limit: 200)
        let reps: [Int] = recent
            .flatMap(\.performedExercises)
            .filter { $0.exerciseId == exerciseId }
            .flatMap(\.performedSets)
            .map(\.reps)
        return reps.max()
    }
}

@available(iOS 17.0, macOS 14.0, *)
public final class SwiftDataMemoryRepository: MemoryRepository {
    private let container: ModelContainer

    public init(container: ModelContainer) { self.container = container }

    public func add(_ note: CoachMemoryNote) async throws {
        let context = ModelContext(container)
        let row = GymBuddySchemaV1.StoredCoachMemoryNote(
            id: note.id,
            content: note.content,
            tagsCSV: note.tags.sorted().joined(separator: ","),
            createdAt: note.createdAt
        )
        context.insert(row)
        try context.save()
    }

    public func recent(matching tags: Set<String>, limit: Int) async throws -> [CoachMemoryNote] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<GymBuddySchemaV1.StoredCoachMemoryNote>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = max(limit * 4, 20)  // oversample, filter in memory
        let rows = try context.fetch(descriptor)
        let notes: [CoachMemoryNote] = rows.map { row in
            CoachMemoryNote(
                id: row.id,
                content: row.content,
                tags: Set(row.tagsCSV.split(separator: ",").map(String.init)),
                createdAt: row.createdAt
            )
        }
        let filtered = tags.isEmpty ? notes : notes.filter { !$0.tags.isDisjoint(with: tags) }
        return Array(filtered.prefix(limit))
    }

    public func remove(_ id: UUID) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<GymBuddySchemaV1.StoredCoachMemoryNote>(
            predicate: #Predicate { $0.id == id }
        )
        for row in try context.fetch(descriptor) {
            context.delete(row)
        }
        try context.save()
    }
}

@available(iOS 17.0, macOS 14.0, *)
public final class SwiftDataReadinessRepository: ReadinessRepository {
    private let container: ModelContainer
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(container: ModelContainer) { self.container = container }

    public func saveCheck(_ check: ReadinessCheck) async throws {
        let context = ModelContext(container)
        let data = try encoder.encode(check)
        let row = GymBuddySchemaV1.StoredReadinessCheck(id: check.id, date: check.date, payload: data)
        context.insert(row)
        try context.save()
    }

    public func latest() async throws -> ReadinessCheck? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<GymBuddySchemaV1.StoredReadinessCheck>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let row = try context.fetch(descriptor).first else { return nil }
        return try decoder.decode(ReadinessCheck.self, from: row.payload)
    }
}

#endif
