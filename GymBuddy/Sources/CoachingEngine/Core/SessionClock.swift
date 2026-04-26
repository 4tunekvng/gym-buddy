import Foundation

/// A clock abstraction for the engine so tests can drive time deterministically.
///
/// Production code constructs `SessionClock.system`; tests construct
/// `SessionClock.fixed(..)` or advance a controlled clock step-by-step.
public struct SessionClock: Sendable {
    public let now: @Sendable () -> TimeInterval

    public init(now: @escaping @Sendable () -> TimeInterval) {
        self.now = now
    }

    public static let system = SessionClock(now: { Date().timeIntervalSinceReferenceDate })

    public static func fixed(_ value: TimeInterval) -> SessionClock {
        SessionClock(now: { value })
    }
}
