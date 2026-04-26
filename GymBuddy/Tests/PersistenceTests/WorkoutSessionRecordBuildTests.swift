import XCTest
@testable import CoachingEngine
@testable import Persistence

final class WorkoutSessionRecordBuildTests: XCTestCase {

    func testBuildsRecordFromSingleObservation() {
        let reps = (1...5).map { n in
            RepEvent(
                exerciseId: .pushUp, repNumber: n,
                startedAt: TimeInterval(n), endedAt: TimeInterval(n) + 1,
                concentricDuration: 0.8, eccentricDuration: 0.6,
                rangeOfMotionScore: 0.9, isPartial: false
            )
        }
        let end = SetEndEvent(exerciseId: .pushUp, setNumber: 1, reason: .autoDetectedStill, timestamp: 6, totalReps: 5, partialReps: 0)
        let obs = SessionObservation(
            exerciseId: .pushUp, setNumber: 1,
            repEvents: reps, cueEvents: [], endEvent: end,
            tempoBaselineMs: 800, fatigueSlowdownAtRep: nil,
            priorSessionBestReps: nil, memoryReferences: []
        )
        let record = WorkoutSessionRecord.build(from: [obs], painFlag: false, summary: "Solid 5.")
        XCTAssertEqual(record.performedExercises.count, 1)
        XCTAssertEqual(record.performedExercises.first?.performedSets.first?.reps, 5)
        XCTAssertFalse(record.painFlag)
    }
}
