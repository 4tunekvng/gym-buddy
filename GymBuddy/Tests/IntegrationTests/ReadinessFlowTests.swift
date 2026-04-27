import XCTest
@testable import CoachingEngine
@testable import Persistence

/// Flow: morning readiness check → scaler → plan day adjusted → persisted.
final class ReadinessFlowTests: XCTestCase {

    func testShortSleepReducesLoad_AdjustedPlanPersists() async throws {
        let planRepo = InMemoryPlanRepository()
        let readinessRepo = InMemoryReadinessRepository()

        let plan = PlanGenerator().generate(from: PlanGenerator.Inputs(
            goal: .strength, experience: .intermediate,
            equipment: .dumbbells, sessionsPerWeek: 3
        ))
        try await planRepo.save(plan)

        let check = ReadinessCheck(sleepHours: 4.0)
        try await readinessRepo.saveCheck(check)

        let scaler = ReadinessScaler()
        let loaded = try await planRepo.activePlan()
        let active = try XCTUnwrap(loaded, "Plan should have been saved before scaling")
        let todayTemplate = active.weeks[0].days[0]
        let (adjusted, scaling) = scaler.scale(todayTemplate, basedOn: check)
        XCTAssertEqual(scaling.loadMultiplier, 0.9, accuracy: 1e-9)
        XCTAssertEqual(adjusted.exercises.count, todayTemplate.exercises.count)
    }
}
