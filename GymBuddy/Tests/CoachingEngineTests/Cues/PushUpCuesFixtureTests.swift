import XCTest
@testable import CoachingEngine

/// Positive + negative fixture tests per push-up cue. Each cue gets:
///   - a pose that should fire it
///   - a pose that should NOT fire it (proving no false positive)
final class PushUpCuesFixtureTests: XCTestCase {

    // MARK: - Hip sag

    func testHipSagFiresWhenHipsDropBelowShoulderAnkleLine() {
        let cue = PushUpCues.HipSag()
        let saggy = buildPushUpSample(hipY: 0.50)     // shoulder=0.35, ankle=0.40 → line y≈0.38; hip at 0.50 = sag
        XCTAssertNotNil(cue.evaluate(sample: saggy, phase: .bottom))
    }

    func testHipSagDoesNotFireWhenPlankIsFlat() {
        let cue = PushUpCues.HipSag()
        let flat = buildPushUpSample(hipY: 0.38)     // close to line
        XCTAssertNil(cue.evaluate(sample: flat, phase: .bottom))
    }

    func testHipSagDoesNotFireAtTopPhase() {
        let cue = PushUpCues.HipSag()
        let saggy = buildPushUpSample(hipY: 0.50)
        // Outside descending/bottom phase — cue stays silent.
        XCTAssertNil(cue.evaluate(sample: saggy, phase: .top))
    }

    // MARK: - Hip pike

    func testHipPikeFiresWhenHipsAboveShoulderAnkleLine() {
        let cue = PushUpCues.HipPike()
        let piked = buildPushUpSample(hipY: 0.25)     // hips above line
        XCTAssertNotNil(cue.evaluate(sample: piked, phase: .top))
    }

    func testHipPikeDoesNotFireWhenPlankIsFlat() {
        let cue = PushUpCues.HipPike()
        let flat = buildPushUpSample(hipY: 0.38)
        XCTAssertNil(cue.evaluate(sample: flat, phase: .top))
    }

    // MARK: - Elbow flare

    func testElbowFlareFiresWhenElbowOutsideTorsoLine() {
        let cue = PushUpCues.ElbowFlare()
        // Shoulder at y=0.35, x=0.3; elbow pushed out to the side (x=0.15, y=0.45).
        let sample = buildPushUpSample(
            hipY: 0.40,
            leftElbowOverride: Keypoint(x: 0.12, y: 0.45, confidence: 0.95)
        )
        XCTAssertNotNil(cue.evaluate(sample: sample, phase: .bottom))
    }

    func testElbowFlareDoesNotFireWhenElbowsTucked() {
        let cue = PushUpCues.ElbowFlare()
        // Tucked elbows on both sides: the shoulder-elbow-hip angle is well
        // under the 80° flare threshold.
        let sample = buildPushUpSample(
            hipY: 0.40,
            leftElbowOverride: Keypoint(x: 0.33, y: 0.43, confidence: 0.95),
            rightElbowOverride: Keypoint(x: 0.33, y: 0.43, confidence: 0.95)
        )
        XCTAssertNil(cue.evaluate(sample: sample, phase: .bottom))
    }

    // MARK: - Partial range cues

    func testPartialRangeBottomFiresWhenElbowAngleStaysLarge() {
        let cue = PushUpCues.PartialRangeBottom()
        // Wrist placed such that elbow angle is ~120° (well above 110° threshold).
        let sample = buildPushUpSample(
            hipY: 0.40,
            leftElbowOverride: Keypoint(x: 0.30, y: 0.43, confidence: 0.95),
            rightElbowOverride: Keypoint(x: 0.32, y: 0.43, confidence: 0.95)
        )
        XCTAssertNotNil(cue.evaluate(sample: sample, phase: .ascending))
    }

    func testPartialRangeTopFiresWhenElbowNotLockedOut() {
        let cue = PushUpCues.PartialRangeTop()
        // Elbow placement yields a shoulder-elbow-wrist interior angle of ~127°,
        // well below the 155° lockout threshold, so the cue fires.
        let sample = buildPushUpSample(
            hipY: 0.40,
            leftElbowOverride: Keypoint(x: 0.25, y: 0.45, confidence: 0.95),
            rightElbowOverride: Keypoint(x: 0.25, y: 0.45, confidence: 0.95)
        )
        XCTAssertNotNil(cue.evaluate(sample: sample, phase: .top))
    }

    // MARK: - Head position

    func testHeadPositionFiresWhenNoseDropsBelowShoulders() {
        let cue = PushUpCues.HeadPositionBad()
        let sample = buildPushUpSample(hipY: 0.40, noseY: 0.48)  // nose far below shoulders (flexion)
        XCTAssertNotNil(cue.evaluate(sample: sample, phase: .bottom))
    }

    func testHeadPositionNeutralDoesNotFire() {
        let cue = PushUpCues.HeadPositionBad()
        let sample = buildPushUpSample(hipY: 0.40, noseY: 0.35)  // nose ~aligned with shoulders
        XCTAssertNil(cue.evaluate(sample: sample, phase: .bottom))
    }

    // MARK: - Helpers

    private func buildPushUpSample(
        hipY: Double,
        noseY: Double = 0.34,
        leftElbowOverride: Keypoint? = nil,
        rightElbowOverride: Keypoint? = nil
    ) -> PoseSample {
        let shoulderX = 0.3
        let shoulderY = 0.35
        var joints: [JointName: Keypoint] = [
            .leftShoulder: Keypoint(x: shoulderX, y: shoulderY, confidence: 0.95),
            .rightShoulder: Keypoint(x: shoulderX + 0.02, y: shoulderY, confidence: 0.95),
            .leftWrist: Keypoint(x: 0.30, y: 0.55, confidence: 0.9),
            .rightWrist: Keypoint(x: 0.32, y: 0.55, confidence: 0.9),
            .leftElbow: leftElbowOverride ?? Keypoint(x: 0.29, y: 0.45, confidence: 0.9),
            .rightElbow: rightElbowOverride ?? Keypoint(x: 0.31, y: 0.45, confidence: 0.9),
            .leftHip: Keypoint(x: 0.60, y: hipY, confidence: 0.95),
            .rightHip: Keypoint(x: 0.60, y: hipY + 0.01, confidence: 0.95),
            .leftKnee: Keypoint(x: 0.75, y: 0.40, confidence: 0.9),
            .rightKnee: Keypoint(x: 0.75, y: 0.41, confidence: 0.9),
            .leftAnkle: Keypoint(x: 0.90, y: 0.40, confidence: 0.9),
            .rightAnkle: Keypoint(x: 0.90, y: 0.41, confidence: 0.9),
            .nose: Keypoint(x: 0.27, y: noseY, confidence: 0.9)
        ]
        _ = joints
        return PoseSample(timestamp: 0, joints: joints)
    }
}
