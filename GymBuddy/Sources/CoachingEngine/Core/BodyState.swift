import Foundation

/// An abstract body state observation.
///
/// Today (Chapter 1) the only kind is a camera-based pose. Chapter 5 will add
/// an IMU-fusion kind. The engine only consumes `BodyState`, so adding a new
/// kind is a new case — not an engine rewrite.
public enum BodyState: Equatable, Sendable {
    case pose(PoseSample)
    // Future: case imuFusion(IMUFusionSample)
}

public extension BodyState {
    var timestamp: TimeInterval {
        switch self {
        case .pose(let sample): sample.timestamp
        }
    }

    var pose: PoseSample? {
        switch self {
        case .pose(let sample): sample
        }
    }
}
