import XCTest
@testable import CoachingEngine
@testable import PoseVision

final class SetupEvaluatorTests: XCTestCase {

    func testPushUpFixturePassesSetupChecks() {
        let sample = SyntheticPoseGenerator.pushUps(repCount: 1)[20]
        let evaluation = SetupEvaluator.evaluate(sample: sample, exerciseId: .pushUp)

        XCTAssertTrue(evaluation.fullBodyOkay)
        XCTAssertTrue(evaluation.distanceOkay)
        XCTAssertTrue(evaluation.lightingOkay)
        XCTAssertTrue(evaluation.angleOkay)
        XCTAssertTrue(evaluation.allPassing)
    }

    func testSquatFixturePassesSetupChecks() {
        let sample = SyntheticPoseGenerator.gobletSquats(repCount: 1)[20]
        let evaluation = SetupEvaluator.evaluate(sample: sample, exerciseId: .gobletSquat)

        XCTAssertTrue(evaluation.allPassing)
    }

    func testMissingKeypointsFailFullBodyCheck() {
        let evaluation = SetupEvaluator.evaluate(
            sample: PoseSample(
                timestamp: 0,
                joints: [
                    .leftShoulder: Keypoint(x: 0.4, y: 0.3, confidence: 0.9),
                    .leftHip: Keypoint(x: 0.4, y: 0.6, confidence: 0.9)
                ]
            ),
            exerciseId: .pushUp
        )

        XCTAssertFalse(evaluation.fullBodyOkay)
        XCTAssertFalse(evaluation.allPassing)
    }
}
