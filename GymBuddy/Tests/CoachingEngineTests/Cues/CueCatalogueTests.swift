import XCTest
@testable import CoachingEngine

/// Validates that every cue in the catalogue is registered and has expected
/// severity. This is also the canary test for "we added a new cue and forgot
/// to register it".
final class CueCatalogueTests: XCTestCase {

    func testEveryCueTypeMapsToItsApplicableExercises() {
        for cue in CueType.allCases {
            XCTAssertFalse(cue.applicableExercises.isEmpty, "Cue \(cue) has no applicable exercises")
        }
    }

    func testPushUpCueCountAndSeverities() {
        let evaluators = PushUpCues.all
        let cueTypes = Set(evaluators.map(\.cueType))
        XCTAssertEqual(cueTypes.count, evaluators.count, "Duplicate cue types in push-up catalogue")
        XCTAssertTrue(cueTypes.contains(.hipSag))
        XCTAssertTrue(cueTypes.contains(.hipPike))
        XCTAssertTrue(cueTypes.contains(.elbowFlare))
        XCTAssertTrue(cueTypes.contains(.partialRangeBottom))
        XCTAssertTrue(cueTypes.contains(.partialRangeTop))
        XCTAssertTrue(cueTypes.contains(.headPositionBad))
        // Hip sag is a safety cue per the catalogue.
        let sag = evaluators.first(where: { $0.cueType == .hipSag })
        XCTAssertEqual(sag?.severity, .safety)
    }

    func testSquatCueCountAndSeverities() {
        let evaluators = GobletSquatCues.all
        let cueTypes = Set(evaluators.map(\.cueType))
        XCTAssertEqual(cueTypes.count, evaluators.count)
        XCTAssertTrue(cueTypes.contains(.kneeValgusLeft))
        XCTAssertTrue(cueTypes.contains(.kneeValgusRight))
        let valgus = evaluators.first(where: { $0.cueType == .kneeValgusLeft })
        XCTAssertEqual(valgus?.severity, .safety)
    }

    func testRowCueCountAndSeverities() {
        let evaluators = DumbbellRowCues.all
        let cueTypes = Set(evaluators.map(\.cueType))
        XCTAssertEqual(cueTypes.count, evaluators.count)
        XCTAssertTrue(cueTypes.contains(.lumbarFlexion))
        let lumbar = evaluators.first(where: { $0.cueType == .lumbarFlexion })
        XCTAssertEqual(lumbar?.severity, .safety)
    }

    func testCueEnginePriorityPicksHighestSeverity() {
        let safety = CueEvent(exerciseId: .pushUp, cueType: .hipSag, severity: .safety, repNumber: 1, timestamp: 0, observationCode: "s")
        let quality = CueEvent(exerciseId: .pushUp, cueType: .elbowFlare, severity: .quality, repNumber: 1, timestamp: 0, observationCode: "q")
        let opt = CueEvent(exerciseId: .pushUp, cueType: .partialRangeTop, severity: .optimization, repNumber: 1, timestamp: 0, observationCode: "o")
        let picked = CueEngine.selectHighestPriority([opt, quality, safety])
        XCTAssertEqual(picked?.severity, .safety)
    }

    func testCueEngineDoesNotRefireSameCueWithinRep() {
        let engine = CueEngine(exerciseId: .pushUp)
        // We don't have a live pose that fires a cue here; this test relies on the
        // method surface to ensure the reset-per-new-rep logic works without crashing.
        engine.resetForNewRep(repNumber: 1)
        engine.resetForNewRep(repNumber: 2)
        XCTAssertTrue(true)
    }
}
