import Foundation

/// The set of joints (body keypoints) the coaching engine reasons about.
///
/// This is an abstraction over whatever pose-estimation vendor is being used.
/// Apple Vision exposes 17 keypoints; MediaPipe exposes 33. Mapping from vendor
/// to this enum happens in PoseVision, not here — the engine never sees a
/// vendor-specific keypoint type. This is the reason Chapter 5 (IMU fusion) and
/// Chapter 10 (Android) don't need engine rewrites.
public enum JointName: String, Codable, CaseIterable, Sendable {
    case nose
    case leftEye, rightEye
    case leftEar, rightEar
    case leftShoulder, rightShoulder
    case leftElbow, rightElbow
    case leftWrist, rightWrist
    case leftHip, rightHip
    case leftKnee, rightKnee
    case leftAnkle, rightAnkle
}

public extension JointName {
    /// The symmetric joint on the opposite side of the body, if any.
    var mirrored: JointName? {
        switch self {
        case .leftEye: .rightEye
        case .rightEye: .leftEye
        case .leftEar: .rightEar
        case .rightEar: .leftEar
        case .leftShoulder: .rightShoulder
        case .rightShoulder: .leftShoulder
        case .leftElbow: .rightElbow
        case .rightElbow: .leftElbow
        case .leftWrist: .rightWrist
        case .rightWrist: .leftWrist
        case .leftHip: .rightHip
        case .rightHip: .leftHip
        case .leftKnee: .rightKnee
        case .rightKnee: .leftKnee
        case .leftAnkle: .rightAnkle
        case .rightAnkle: .leftAnkle
        case .nose: nil
        }
    }
}
