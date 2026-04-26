import Foundation
import CoachingEngine

/// A pose-detecting source. CoachingEngine doesn't know about Vision, MediaPipe,
/// or anything camera-related — it only consumes `BodyStateStream`s produced by
/// implementors of this protocol.
public protocol PoseDetecting: AnyObject, Sendable {
    /// A stream of body states. Infinite; caller stops by cancelling the task
    /// consuming the stream.
    func bodyStateStream() -> BodyStateStream

    /// Start emitting frames. Platform implementations typically start the
    /// camera capture session here.
    func start() async throws

    /// Stop emitting frames. Platform implementations tear down the capture session.
    func stop() async
}

/// Errors surfaced by pose detection implementations.
public enum PoseDetectionError: Error, Equatable, Sendable {
    case cameraPermissionDenied
    case cameraUnavailable
    case sessionConfigurationFailed(reason: String)
    case alreadyStarted
    case notStarted
}
