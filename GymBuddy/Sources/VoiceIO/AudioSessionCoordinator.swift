import Foundation

#if canImport(AVFoundation) && !os(macOS)
import AVFoundation

/// Coordinates the shared `AVAudioSession` for coaching playback + STT.
///
/// Category: `.playAndRecord` with `.mixWithOthers + .duckOthers + .defaultToSpeaker`.
/// This ducks the user's music (instead of stopping it) and lets incoming calls
/// interrupt cleanly. See PRD §7.8.
///
/// The coordinator listens for route changes and interruptions and surfaces them
/// as an `AsyncStream<SessionEvent>` that the app layer consumes to react (pause
/// the session during a call, resume after).
public final class AudioSessionCoordinator: @unchecked Sendable {
    public enum SessionEvent: Equatable, Sendable {
        case interruptionBegan(cause: InterruptionCause)
        case interruptionEnded(shouldResume: Bool)
        case routeChanged(reason: RouteChangeReason)
    }

    public enum InterruptionCause: String, Sendable {
        case phoneCall
        case siri
        case unknown
    }

    public enum RouteChangeReason: String, Sendable {
        case newDeviceAvailable
        case oldDeviceUnavailable
        case categoryChange
        case unknown
    }

    private let session = AVAudioSession.sharedInstance()
    private var continuation: AsyncStream<SessionEvent>.Continuation?
    private var notificationObservers: [NSObjectProtocol] = []

    public init() {}

    public var eventStream: AsyncStream<SessionEvent> {
        AsyncStream { continuation in
            self.continuation = continuation
            self.installObservers()
            continuation.onTermination = { [weak self] _ in
                self?.removeObservers()
            }
        }
    }

    public func activate() throws {
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.mixWithOthers, .duckOthers, .defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
        )
        try session.setActive(true, options: [])
    }

    public func deactivate() throws {
        try session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func installObservers() {
        let center = NotificationCenter.default
        let interruption = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { [weak self] note in
            guard let self else { return }
            guard let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let interruption = AVAudioSession.InterruptionType(rawValue: type) else { return }
            switch interruption {
            case .began:
                self.continuation?.yield(.interruptionBegan(cause: .unknown))
            case .ended:
                let shouldResume: Bool = {
                    guard let options = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt else { return false }
                    return AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)
                }()
                self.continuation?.yield(.interruptionEnded(shouldResume: shouldResume))
            @unknown default: break
            }
        }
        let route = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] note in
            guard let self else { return }
            guard let rawReason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else { return }
            let mapped: RouteChangeReason = {
                switch reason {
                case .newDeviceAvailable: return .newDeviceAvailable
                case .oldDeviceUnavailable: return .oldDeviceUnavailable
                case .categoryChange: return .categoryChange
                default: return .unknown
                }
            }()
            self.continuation?.yield(.routeChanged(reason: mapped))
        }
        notificationObservers = [interruption, route]
    }

    private func removeObservers() {
        let center = NotificationCenter.default
        notificationObservers.forEach { center.removeObserver($0) }
        notificationObservers.removeAll()
    }
}
#endif
