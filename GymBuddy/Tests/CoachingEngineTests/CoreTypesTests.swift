import XCTest
@testable import CoachingEngine

final class CoreTypesTests: XCTestCase {

    func testExerciseIDAllCasesCoversThreeMVPExercises() {
        XCTAssertEqual(ExerciseID.allCases.count, 3)
        XCTAssertTrue(ExerciseID.allCases.contains(.pushUp))
        XCTAssertTrue(ExerciseID.allCases.contains(.gobletSquat))
        XCTAssertTrue(ExerciseID.allCases.contains(.dumbbellRow))
    }

    func testExerciseIDMovementPatterns() {
        XCTAssertEqual(ExerciseID.pushUp.movementPattern, .horizontalPush)
        XCTAssertEqual(ExerciseID.gobletSquat.movementPattern, .squat)
        XCTAssertEqual(ExerciseID.dumbbellRow.movementPattern, .horizontalPull)
    }

    func testJointNameMirroringCoversEveryLateralJoint() {
        // Every left/right joint pair mirrors to its counterpart; the nose has
        // no mirror.
        for joint in JointName.allCases {
            if joint == .nose {
                XCTAssertNil(joint.mirrored)
            } else if joint.rawValue.hasPrefix("left") {
                XCTAssertEqual(joint.mirrored?.rawValue, "right" + joint.rawValue.dropFirst(4))
            } else if joint.rawValue.hasPrefix("right") {
                XCTAssertEqual(joint.mirrored?.rawValue, "left" + joint.rawValue.dropFirst(5))
            }
        }
    }

    func testKeypointReliabilityThreshold() {
        let reliable = Keypoint(x: 0.5, y: 0.5, confidence: 0.9)
        let unreliable = Keypoint(x: 0.5, y: 0.5, confidence: 0.1)
        XCTAssertTrue(reliable.isReliable)
        XCTAssertFalse(unreliable.isReliable)
    }

    func testPoseSampleSubscriptAndContainsSet() {
        let sample = PoseSample(timestamp: 0, joints: [
            .leftShoulder: Keypoint(x: 0.3, y: 0.4, confidence: 0.9),
            .rightShoulder: Keypoint(x: 0.35, y: 0.4, confidence: 0.9),
            .leftHip: Keypoint(x: 0.6, y: 0.5, confidence: 0.2)   // unreliable
        ])
        XCTAssertNotNil(sample[.leftShoulder])
        XCTAssertNil(sample[.nose])
        XCTAssertTrue(sample.contains(joints: [.leftShoulder, .rightShoulder]))
        XCTAssertFalse(sample.contains(joints: [.leftShoulder, .leftHip]))  // hip unreliable
    }

    func testBodyStateTimestampAndPoseAccessors() {
        let sample = PoseSample(timestamp: 1.5, joints: [:])
        let state = BodyState.pose(sample)
        XCTAssertEqual(state.timestamp, 1.5)
        XCTAssertNotNil(state.pose)
    }

    func testCueSeverityOrdering() {
        XCTAssertTrue(CueSeverity.optimization < .quality)
        XCTAssertTrue(CueSeverity.quality < .safety)
    }

    func testAngleConversions() {
        let ninety = Angle(degrees: 90)
        XCTAssertEqual(ninety.radians, .pi / 2, accuracy: 1e-9)
        XCTAssertEqual(ninety.degrees, 90, accuracy: 1e-9)
    }

    func testSessionClockFixedReturnsSameValue() {
        let clock = SessionClock.fixed(42.0)
        XCTAssertEqual(clock.now(), 42.0)
        XCTAssertEqual(clock.now(), 42.0)
    }
}
