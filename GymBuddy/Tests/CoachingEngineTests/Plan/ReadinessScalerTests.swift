import XCTest
@testable import CoachingEngine

final class ReadinessScalerTests: XCTestCase {

    private func makeDay() -> PlanDay {
        PlanDay(
            weekNumber: 1,
            dayOfWeek: 1,
            isRestDay: false,
            exercises: [
                PlannedExercise(
                    exerciseId: .pushUp,
                    sets: (1...3).map {
                        PlannedSet(setNumber: $0, targetReps: 10, isAmrap: false, targetLoadKg: 40)
                    }
                )
            ]
        )
    }

    func testNeutralInputsLeavePlanUnchanged() {
        let scaler = ReadinessScaler()
        let day = makeDay()
        let (next, scaling) = scaler.scale(day, basedOn: ReadinessCheck())
        XCTAssertEqual(next.exercises.first?.sets.count, 3)
        XCTAssertEqual(scaling.loadMultiplier, 1.0)
        XCTAssertEqual(scaling.volumeSetsDelta, 0)
        XCTAssertFalse(scaling.isDeloadOffered)
    }

    func testShortSleepDropsLoadByTenPct() {
        let scaler = ReadinessScaler()
        let check = ReadinessCheck(sleepHours: 4.0)
        let (next, scaling) = scaler.scale(makeDay(), basedOn: check)
        XCTAssertEqual(scaling.loadMultiplier, 0.9, accuracy: 1e-9)
        XCTAssertEqual(next.exercises.first?.sets.first?.targetLoadKg ?? 0, 36.0, accuracy: 1e-9)
    }

    func testHighSorenessOffersDeload() {
        let scaler = ReadinessScaler()
        let check = ReadinessCheck(soreness: 5)
        let (_, scaling) = scaler.scale(makeDay(), basedOn: check)
        XCTAssertTrue(scaling.isDeloadOffered)
    }

    func testHRVDropReducesVolumeByOneSet() {
        let scaler = ReadinessScaler()
        let check = ReadinessCheck(hrvDeltaPct: 15.0)
        let (next, scaling) = scaler.scale(makeDay(), basedOn: check)
        XCTAssertEqual(scaling.volumeSetsDelta, -1)
        XCTAssertEqual(next.exercises.first?.sets.count, 2)
    }

    func testLoadFloorsAt85PctEvenWithMultipleTriggers() {
        let scaler = ReadinessScaler()
        let check = ReadinessCheck(energy: 1, sleepHours: 3.0)
        let (_, scaling) = scaler.scale(makeDay(), basedOn: check)
        XCTAssertEqual(scaling.loadMultiplier, 0.85, accuracy: 1e-9)
    }
}
