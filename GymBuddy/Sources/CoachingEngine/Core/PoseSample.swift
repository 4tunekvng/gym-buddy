import Foundation

/// A single pose-estimation frame.
///
/// The engine consumes `PoseSample` through the `BodyStateStream` abstraction so
/// that future body-state sources (IMU fusion in Chapter 5) can provide samples
/// derived from non-camera signals without rewriting the engine.
public struct PoseSample: Equatable, Codable, Sendable {
    public let timestamp: TimeInterval
    public let joints: [JointName: Keypoint]

    public init(timestamp: TimeInterval, joints: [JointName: Keypoint]) {
        self.timestamp = timestamp
        self.joints = joints
    }

    public subscript(joint: JointName) -> Keypoint? {
        joints[joint]
    }

    /// Whether at least one keypoint is visible for each joint in the given set.
    public func contains(joints required: Set<JointName>) -> Bool {
        required.allSatisfy { self.joints[$0]?.isReliable ?? false }
    }
}
