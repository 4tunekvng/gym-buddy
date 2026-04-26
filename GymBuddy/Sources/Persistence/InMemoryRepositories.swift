import Foundation
import CoachingEngine

/// In-memory implementations of every repository. Used in tests, the CLI, and
/// previews. Production app uses the SwiftData implementations.

public actor InMemoryUserProfileRepository: UserProfileRepository {
    private var profile: UserProfile?
    public init(seed: UserProfile? = nil) { self.profile = seed }
    public func load() -> UserProfile? { profile }
    public func save(_ profile: UserProfile) {
        var next = profile
        next.updatedAt = Date()
        self.profile = next
    }
}

public actor InMemoryPlanRepository: PlanRepository {
    private var active: Plan?
    public init(seed: Plan? = nil) { self.active = seed }
    public func activePlan() -> Plan? { active }
    public func save(_ plan: Plan) { self.active = plan }
    public func delete(_ planId: UUID) {
        if active?.id == planId { active = nil }
    }
}

public actor InMemorySessionRepository: SessionRepository {
    private var sessions: [WorkoutSessionRecord] = []
    public init() {}
    public func record(_ session: WorkoutSessionRecord) { sessions.append(session) }
    public func recent(limit: Int) -> [WorkoutSessionRecord] {
        sessions.sorted(by: { $0.startedAt > $1.startedAt }).prefix(limit).map { $0 }
    }
    public func bestReps(for exerciseId: ExerciseID) -> Int? {
        sessions
            .flatMap(\.performedExercises)
            .filter { $0.exerciseId == exerciseId }
            .flatMap(\.performedSets)
            .map(\.reps)
            .max()
    }
}

public actor InMemoryReadinessRepository: ReadinessRepository {
    private var checks: [ReadinessCheck] = []
    public init() {}
    public func saveCheck(_ check: ReadinessCheck) { checks.append(check) }
    public func latest() -> ReadinessCheck? {
        checks.sorted(by: { $0.date > $1.date }).first
    }
}

public actor InMemoryMemoryRepository: MemoryRepository {
    private var notes: [CoachMemoryNote] = []
    public init(seed: [CoachMemoryNote] = []) { self.notes = seed }
    public func add(_ note: CoachMemoryNote) { notes.append(note) }
    public func recent(matching tags: Set<String>, limit: Int) -> [CoachMemoryNote] {
        if tags.isEmpty {
            return notes.sorted(by: { $0.createdAt > $1.createdAt }).prefix(limit).map { $0 }
        }
        return notes
            .filter { !$0.tags.isDisjoint(with: tags) }
            .sorted(by: { $0.createdAt > $1.createdAt })
            .prefix(limit)
            .map { $0 }
    }
    public func remove(_ id: UUID) {
        notes.removeAll { $0.id == id }
    }
}
