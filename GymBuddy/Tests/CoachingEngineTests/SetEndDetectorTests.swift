import XCTest
@testable import CoachingEngine

final class SetEndDetectorTests: XCTestCase {

    private func sample(hipY: Double, t: TimeInterval) -> PoseSample {
        PoseSample(timestamp: t, joints: [
            .leftHip: Keypoint(x: 0.5, y: hipY, confidence: 0.95),
            .rightHip: Keypoint(x: 0.52, y: hipY, confidence: 0.95)
        ])
    }

    func testDoesNotTriggerBeforeFirstRep() {
        let detector = SetEndDetector(exerciseId: .pushUp)
        // Feed 5s of stillness with no rep noted; should not trigger.
        for t in stride(from: 0.0, through: 5.0, by: 0.1) {
            XCTAssertNil(detector.observe(sample(hipY: 0.40, t: t)))
        }
    }

    func testStillnessTriggersAfterRep() {
        let detector = SetEndDetector(exerciseId: .pushUp, stillnessSeconds: 1.0)
        detector.noteRepCompleted()
        // Produce one active sample then stay still.
        _ = detector.observe(sample(hipY: 0.40, t: 0.0))
        _ = detector.observe(sample(hipY: 0.41, t: 0.05))   // motion
        var fired: SetEndEvent.EndReason?
        for t in stride(from: 0.1, through: 1.3, by: 0.05) {
            if let r = detector.observe(sample(hipY: 0.41, t: t)) { fired = r; break }
        }
        XCTAssertEqual(fired, .autoDetectedStill)
    }

    func testStanceChangeTriggersWhenHipsRise() {
        let detector = SetEndDetector(exerciseId: .pushUp, stanceChangeThreshold: 0.1)
        detector.noteRepCompleted()
        // Baseline at y=0.40 then user stands up (y drops to 0.25).
        _ = detector.observe(sample(hipY: 0.40, t: 0))
        _ = detector.observe(sample(hipY: 0.40, t: 0.1))
        var fired: SetEndEvent.EndReason?
        for (i, y) in [0.37, 0.33, 0.30, 0.28, 0.25].enumerated() {
            if let r = detector.observe(sample(hipY: y, t: 0.2 + Double(i) * 0.05)) { fired = r; break }
        }
        XCTAssertEqual(fired, .autoDetectedStanceChange)
    }

    func testResetClearsBaselineAndMotion() {
        let detector = SetEndDetector(exerciseId: .pushUp)
        detector.noteRepCompleted()
        _ = detector.observe(sample(hipY: 0.40, t: 0))
        detector.reset()
        // After reset, even with rep-noted gone and fresh baseline, a later sample
        // shouldn't immediately produce a stance-change event.
        detector.noteRepCompleted()
        _ = detector.observe(sample(hipY: 0.40, t: 10))
        XCTAssertNil(detector.observe(sample(hipY: 0.40, t: 10.1)))
    }
}
