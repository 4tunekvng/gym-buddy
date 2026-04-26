import XCTest
@testable import CoachingEngine
@testable import Persistence

final class InMemoryRepositoriesTests: XCTestCase {

    func testUserProfileRoundTrip() async throws {
        let repo = InMemoryUserProfileRepository()
        let profile = UserProfile(
            displayName: "Fortune", tone: .standard,
            experience: .intermediate, goal: .hypertrophy,
            equipment: .dumbbells, sessionsPerWeek: 3
        )
        await repo.save(profile)
        let loaded = await repo.load()
        XCTAssertEqual(loaded?.id, profile.id)
        XCTAssertEqual(loaded?.displayName, "Fortune")
    }

    func testPlanRoundTrip() async throws {
        let repo = InMemoryPlanRepository()
        let gen = PlanGenerator()
        let plan = gen.generate(from: PlanGenerator.Inputs(
            goal: .strength, experience: .intermediate,
            equipment: .dumbbells, sessionsPerWeek: 3
        ))
        await repo.save(plan)
        let loaded = await repo.activePlan()
        XCTAssertEqual(loaded?.id, plan.id)
    }

    func testSessionBestRepsReturnsMax() async throws {
        let repo = InMemorySessionRepository()
        let session = WorkoutSessionRecord(
            startedAt: Date(), endedAt: Date(),
            performedExercises: [
                PerformedExerciseRecord(exerciseId: .pushUp, performedSets: [
                    PerformedSetRecord(setNumber: 1, reps: 8, partialReps: 0, durationSeconds: 30, cues: []),
                    PerformedSetRecord(setNumber: 2, reps: 11, partialReps: 0, durationSeconds: 30, cues: [])
                ])
            ]
        )
        try await repo.record(session)
        let best = try await repo.bestReps(for: .pushUp)
        XCTAssertEqual(best, 11)
    }

    func testMemoryRepositoryRetrievalByTag() async throws {
        let repo = InMemoryMemoryRepository()
        try await repo.add(CoachMemoryNote(content: "knee thing", tags: ["body-part:knee"]))
        try await repo.add(CoachMemoryNote(content: "schedule thing", tags: ["schedule"]))
        let knee = try await repo.recent(matching: ["body-part:knee"], limit: 5)
        XCTAssertEqual(knee.count, 1)
    }

    func testReadinessLatestReturnsMostRecent() async throws {
        let repo = InMemoryReadinessRepository()
        let old = ReadinessCheck(date: Date(timeIntervalSinceNow: -86400), soreness: 2)
        let new = ReadinessCheck(date: Date(), soreness: 5)
        try await repo.saveCheck(old)
        try await repo.saveCheck(new)
        let latest = try await repo.latest()
        XCTAssertEqual(latest?.soreness, 5)
    }
}
