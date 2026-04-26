import Foundation
import CoachingEngine

/// Repository protocols — the app depends on these, not on SwiftData directly.
/// This is the seam that lets us swap to GRDB (ADR-0001) or to cloud sync in
/// Chapter 11 without the app layer caring.

public protocol UserProfileRepository: Sendable {
    func load() async throws -> UserProfile?
    func save(_ profile: UserProfile) async throws
}

public protocol PlanRepository: Sendable {
    func activePlan() async throws -> Plan?
    func save(_ plan: Plan) async throws
    func delete(_ planId: UUID) async throws
}

public protocol SessionRepository: Sendable {
    func record(_ session: WorkoutSessionRecord) async throws
    func recent(limit: Int) async throws -> [WorkoutSessionRecord]
    func bestReps(for exerciseId: ExerciseID) async throws -> Int?
}

public protocol ReadinessRepository: Sendable {
    func saveCheck(_ check: ReadinessCheck) async throws
    func latest() async throws -> ReadinessCheck?
}

public protocol MemoryRepository: Sendable {
    func add(_ note: CoachMemoryNote) async throws
    func recent(matching tags: Set<String>, limit: Int) async throws -> [CoachMemoryNote]
    func remove(_ id: UUID) async throws
}
