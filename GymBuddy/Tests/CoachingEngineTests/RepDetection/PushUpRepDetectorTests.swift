import XCTest
@testable import CoachingEngine

final class PushUpRepDetectorTests: XCTestCase {

    /// Helper: build a push-up pose sample with a target elbow flexion angle.
    /// Delegates to NorthStarDemoTest.sample so there's one canonical geometry
    /// formula shared by every push-up test in this target.
    private func sample(elbowDegrees: Double, t: TimeInterval, hipY: Double = 0.40) -> PoseSample {
        NorthStarDemoTest.sample(elbowDegrees: elbowDegrees, hipY: hipY, t: t)
    }

    func testDetectorStartsIdle() {
        let d = PushUpRepDetector()
        XCTAssertEqual(d.phase, .idle)
        XCTAssertEqual(d.currentRepNumber, 0)
    }

    func testSingleCycleProducesOneRepEvent() {
        let d = PushUpRepDetector()
        var emitted: [RepEvent] = []
        // Start idle at top (170°).
        for i in 0..<5 {
            if let r = d.observe(sample(elbowDegrees: 170, t: Double(i) * 0.033)) { emitted.append(r) }
        }
        XCTAssertEqual(d.phase, .top)

        // Descend through 150 → 130 → 110 → 95 (bottom).
        let descAngles: [Double] = [150, 130, 110, 95]
        for (i, a) in descAngles.enumerated() {
            if let r = d.observe(sample(elbowDegrees: a, t: 0.2 + Double(i) * 0.033)) { emitted.append(r) }
        }
        XCTAssertEqual(d.phase, .bottom)

        // Ascend through 110 → 130 → 150 → 170 (top).
        let ascAngles: [Double] = [110, 130, 150, 170]
        for (i, a) in ascAngles.enumerated() {
            if let r = d.observe(sample(elbowDegrees: a, t: 0.5 + Double(i) * 0.033)) { emitted.append(r) }
        }

        XCTAssertEqual(emitted.count, 1, "Exactly one rep should be emitted per full cycle")
        XCTAssertEqual(d.currentRepNumber, 1)
        XCTAssertEqual(emitted.first?.repNumber, 1)
    }

    func testRepEventTimestampsAreMonotonic() {
        let d = PushUpRepDetector()
        var events: [RepEvent] = []

        func runRep(startT: TimeInterval) {
            let angles = [170, 170, 150, 130, 110, 95, 95, 110, 130, 150, 170]
            for (i, a) in angles.enumerated() {
                if let r = d.observe(sample(elbowDegrees: Double(a), t: startT + Double(i) * 0.1)) {
                    events.append(r)
                }
            }
        }

        runRep(startT: 0.0)
        runRep(startT: 2.0)
        runRep(startT: 4.0)

        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events.map(\.repNumber), [1, 2, 3])
        for (prev, next) in zip(events, events.dropFirst()) {
            XCTAssertGreaterThan(next.startedAt, prev.startedAt)
            XCTAssertGreaterThanOrEqual(next.endedAt, next.startedAt)
        }
    }

    func testMissingJointsDoNotCrashAndDoNotCountReps() {
        let d = PushUpRepDetector()
        // Feed a sample with no shoulders → detector should just skip.
        let s = PoseSample(timestamp: 0, joints: [
            .leftElbow: Keypoint(x: 0.2, y: 0.4, confidence: 0.9)
        ])
        XCTAssertNil(d.observe(s))
        XCTAssertEqual(d.currentRepNumber, 0)
    }

    func testResetReturnsToIdle() {
        let d = PushUpRepDetector()
        _ = d.observe(sample(elbowDegrees: 170, t: 0))
        _ = d.observe(sample(elbowDegrees: 140, t: 0.1))
        d.reset()
        XCTAssertEqual(d.phase, .idle)
        XCTAssertEqual(d.currentRepNumber, 0)
    }
}
