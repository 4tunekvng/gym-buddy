import XCTest
@testable import CoachingEngine

final class IntentEmitterTests: XCTestCase {

    func testOnRepCompletedEmitsSayRepCount() {
        let emitter = CoachingIntentEmitter(exerciseId: .pushUp)
        let rep = RepEvent(
            exerciseId: .pushUp, repNumber: 3, startedAt: 0, endedAt: 1,
            concentricDuration: 0.5, eccentricDuration: 0.4,
            rangeOfMotionScore: 0.9, isPartial: false
        )
        let out = emitter.onRepCompleted(rep)
        if case .sayRepCount(let n, _) = out.intents.first {
            XCTAssertEqual(n, 3)
        } else {
            XCTFail("Expected sayRepCount intent first")
        }
    }

    func testStagedCuesAreSurfacedAfterRepCompletionWithHighestSeverity() {
        let emitter = CoachingIntentEmitter(exerciseId: .pushUp)
        let rep = RepEvent(
            exerciseId: .pushUp, repNumber: 4, startedAt: 0, endedAt: 1,
            concentricDuration: 0.5, eccentricDuration: 0.4,
            rangeOfMotionScore: 0.9, isPartial: false
        )
        emitter.stageCues([
            CueEvent(exerciseId: .pushUp, cueType: .partialRangeTop, severity: .optimization, repNumber: 4, timestamp: 0.5, observationCode: "o"),
            CueEvent(exerciseId: .pushUp, cueType: .hipSag, severity: .safety, repNumber: 4, timestamp: 0.6, observationCode: "s"),
            CueEvent(exerciseId: .pushUp, cueType: .elbowFlare, severity: .quality, repNumber: 4, timestamp: 0.7, observationCode: "q")
        ])
        let out = emitter.onRepCompleted(rep)
        let cueIntents = out.intents.compactMap { intent -> CueEvent? in
            if case .formCue(let c) = intent { return c } else { return nil }
        }
        XCTAssertEqual(cueIntents.count, 1, "At most one cue per rep")
        XCTAssertEqual(cueIntents.first?.severity, .safety)
    }

    func testFirstFatigueTriggerEmitsOneMoreAndPushThrough() {
        let emitter = CoachingIntentEmitter(exerciseId: .pushUp)
        let out = emitter.onFatigueTriggered(.firstSlowdown(ratio: 1.4, atRep: 8), at: 5.0)
        let kinds = out.intents.compactMap { intent -> CoachingIntent.EncouragementKind? in
            if case .encouragement(let k, _, _) = intent { return k } else { return nil }
        }
        XCTAssertEqual(kinds, [.oneMore, .pushThrough])
    }

    func testSecondFatigueTriggerEmitsLastOneAndDrive() {
        let emitter = CoachingIntentEmitter(exerciseId: .pushUp)
        let out = emitter.onFatigueTriggered(.secondSlowdown(ratio: 1.6, atRep: 13), at: 12.0)
        let kinds = out.intents.compactMap { intent -> CoachingIntent.EncouragementKind? in
            if case .encouragement(let k, _, _) = intent { return k } else { return nil }
        }
        XCTAssertEqual(kinds, [.lastOne, .drive])
    }

    func testEccentricFatigueTriggerEmitsSteadyDuringEccentric() {
        let emitter = CoachingIntentEmitter(exerciseId: .pushUp)
        let out = emitter.onFatigueTriggered(.eccentricFatigue(ratio: 1.45, atRep: 6), at: 4.0)
        XCTAssertEqual(out.intents.count, 1)
        if case .encouragement(let kind, let timing, _) = out.intents[0] {
            XCTAssertEqual(kind, .steady)
            XCTAssertEqual(timing, .duringEccentric)
        } else {
            XCTFail("Expected encouragement intent, got \(out.intents[0])")
        }
    }

    func testPainTriggerEmitsPainStop() {
        let emitter = CoachingIntentEmitter(exerciseId: .pushUp)
        let out = emitter.onPainDetected(trigger: "sharp pain")
        if case .painStop(let trigger) = out.intents.first {
            XCTAssertEqual(trigger, "sharp pain")
        } else {
            XCTFail("Expected painStop intent")
        }
    }
}
