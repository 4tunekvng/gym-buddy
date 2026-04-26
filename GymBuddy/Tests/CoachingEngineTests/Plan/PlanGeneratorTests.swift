import XCTest
@testable import CoachingEngine

final class PlanGeneratorTests: XCTestCase {

    func testGeneratesFourWeeks() {
        let gen = PlanGenerator()
        let inputs = PlanGenerator.Inputs(
            goal: .hypertrophy,
            experience: .intermediate,
            equipment: .dumbbells,
            sessionsPerWeek: 3
        )
        let plan = gen.generate(from: inputs)
        XCTAssertEqual(plan.weeks.count, 4)
        XCTAssertEqual(plan.weeks.map(\.weekNumber), [1, 2, 3, 4])
    }

    func testLinearProgressionAddsOneRepPerSetPerWeek() {
        let gen = PlanGenerator()
        let inputs = PlanGenerator.Inputs(
            goal: .strength,
            experience: .intermediate,
            equipment: .dumbbells,
            sessionsPerWeek: 3
        )
        let plan = gen.generate(from: inputs)
        let week1Day = plan.weeks[0].days.first(where: { !$0.isRestDay })
        let week4Day = plan.weeks[3].days.first(where: { !$0.isRestDay })
        guard let w1 = week1Day, let w4 = week4Day else { return XCTFail("no workout days") }
        let w1Reps = w1.exercises.first?.sets.first?.targetReps ?? 0
        let w4Reps = w4.exercises.first?.sets.first?.targetReps ?? 0
        XCTAssertEqual(w4Reps - w1Reps, 3, "+1 per week across 4 weeks = +3 reps")
    }

    func testInjuryExclusionRemovesAffectedExercise() {
        let gen = PlanGenerator()
        let inputs = PlanGenerator.Inputs(
            goal: .hypertrophy,
            experience: .intermediate,
            equipment: .dumbbells,
            sessionsPerWeek: 3,
            injuryBodyParts: [.bodyPartKnee]
        )
        let plan = gen.generate(from: inputs)
        for week in plan.weeks {
            for day in week.days {
                XCTAssertFalse(day.exercises.contains { $0.exerciseId == .gobletSquat },
                               "Goblet squat must be excluded when knee injury is present")
            }
        }
    }

    func testFrequencyDeterminesRestVsWorkoutDayCount() {
        let gen = PlanGenerator()
        let inputs = PlanGenerator.Inputs(
            goal: .maintenance,
            experience: .beginner,
            equipment: .dumbbells,
            sessionsPerWeek: 3
        )
        let plan = gen.generate(from: inputs)
        let workoutDays = plan.weeks[0].days.filter { !$0.isRestDay }.count
        XCTAssertEqual(workoutDays, 3)
    }

    func testRationaleStringDescribesInputs() {
        let gen = PlanGenerator()
        let inputs = PlanGenerator.Inputs(
            goal: .recomp,
            experience: .advanced,
            equipment: .dumbbellsAndBench,
            sessionsPerWeek: 4
        )
        let plan = gen.generate(from: inputs)
        XCTAssertTrue(plan.rationale.contains("4"))
        XCTAssertTrue(plan.rationale.contains("recomp"))
    }
}
