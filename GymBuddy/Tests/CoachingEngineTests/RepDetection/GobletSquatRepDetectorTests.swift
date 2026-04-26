import XCTest
@testable import CoachingEngine

final class GobletSquatRepDetectorTests: XCTestCase {

    /// Build a squat pose sample with a target interior angle at the knee.
    /// Geometry: ankle fixed on the floor (y=0.78, x aligned with hip); hip
    /// lowers in y as depth increases; knee placed forward of the hip-ankle line
    /// by `(D/2)·cot(θ/2)` so the hip-knee-ankle interior angle equals `kneeDegrees`
    /// to within ~0.1°.
    private func sample(kneeDegrees: Double, t: TimeInterval) -> PoseSample {
        let hipX = 0.50
        let ankleX = 0.50
        let ankleY = 0.78

        // Hip y moves with depth: standing (170°) → 0.48; deep (85°) → 0.65.
        let hipY = 0.48 + (170.0 - kneeDegrees) / 85.0 * 0.17
        let D = ankleY - hipY
        let theta = kneeDegrees * .pi / 180.0
        let halfAngle = theta / 2
        let kneeForward = (D / 2) * (cos(halfAngle) / sin(halfAngle))  // (D/2) * cot(θ/2)
        let kneeX = hipX + kneeForward
        let kneeY = (hipY + ankleY) / 2

        let shoulderY = hipY - 0.28
        return PoseSample(timestamp: t, joints: [
            .leftShoulder: Keypoint(x: hipX - 0.02, y: shoulderY, confidence: 0.95),
            .rightShoulder: Keypoint(x: hipX + 0.02, y: shoulderY, confidence: 0.95),
            .leftHip: Keypoint(x: hipX - 0.02, y: hipY, confidence: 0.95),
            .rightHip: Keypoint(x: hipX + 0.02, y: hipY, confidence: 0.95),
            .leftKnee: Keypoint(x: kneeX - 0.02, y: kneeY, confidence: 0.92),
            .rightKnee: Keypoint(x: kneeX + 0.02, y: kneeY, confidence: 0.92),
            .leftAnkle: Keypoint(x: ankleX - 0.02, y: ankleY, confidence: 0.88),
            .rightAnkle: Keypoint(x: ankleX + 0.02, y: ankleY, confidence: 0.88),
            .leftElbow: Keypoint(x: hipX - 0.05, y: shoulderY + 0.08, confidence: 0.85),
            .rightElbow: Keypoint(x: hipX + 0.05, y: shoulderY + 0.08, confidence: 0.85),
            .leftWrist: Keypoint(x: hipX - 0.01, y: shoulderY + 0.16, confidence: 0.85),
            .rightWrist: Keypoint(x: hipX + 0.01, y: shoulderY + 0.16, confidence: 0.85),
            .nose: Keypoint(x: hipX, y: shoulderY - 0.06, confidence: 0.9)
        ])
    }

    func testSingleSquatCycleProducesOneRepEvent() {
        let d = GobletSquatRepDetector()
        var emitted: [RepEvent] = []
        // Idle at top (170°).
        for i in 0..<5 {
            if let r = d.observe(sample(kneeDegrees: 170, t: Double(i) * 0.05)) { emitted.append(r) }
        }
        XCTAssertEqual(d.phase, .top)

        // Descend. Target angles cross the tuning thresholds (enteringDescent=160,
        // atBottom=85) strictly, not at the boundary.
        for (i, a) in [155.0, 135, 115, 95, 80].enumerated() {
            if let r = d.observe(sample(kneeDegrees: a, t: 0.3 + Double(i) * 0.05)) { emitted.append(r) }
        }
        XCTAssertEqual(d.phase, .bottom)

        // Ascend — exit the bottom phase via the exitingBottom threshold (95°).
        for (i, a) in [100.0, 120, 140, 160, 170].enumerated() {
            if let r = d.observe(sample(kneeDegrees: a, t: 0.6 + Double(i) * 0.05)) { emitted.append(r) }
        }

        XCTAssertEqual(emitted.count, 1)
        XCTAssertEqual(emitted.first?.exerciseId, .gobletSquat)
    }

    func testMultipleRepsIncrementRepNumber() {
        let d = GobletSquatRepDetector()
        var events: [RepEvent] = []

        func run(startT: TimeInterval) {
            // Angles cross the tuning thresholds cleanly in both directions so
            // the FSM completes top→descending→bottom→ascending→top each time.
            for (i, a) in [170, 170, 150, 130, 100, 80, 80, 100, 130, 150, 170].enumerated() {
                if let r = d.observe(sample(kneeDegrees: Double(a), t: startT + Double(i) * 0.05)) {
                    events.append(r)
                }
            }
        }
        run(startT: 0)
        run(startT: 2)
        run(startT: 4)

        XCTAssertEqual(events.map(\.repNumber), [1, 2, 3])
    }
}
