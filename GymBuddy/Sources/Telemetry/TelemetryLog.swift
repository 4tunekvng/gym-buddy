import Foundation

/// Protocol for anything that can receive telemetry events.
public protocol TelemetryLog: Sendable {
    func log(_ event: TelemetryEvent) async
    func snapshot() async -> [TelemetryEvent]
    func clear() async
}

/// In-memory ring buffer. The Persistence package provides a SQLite-backed
/// implementation for the production app; this one is used in tests, the CLI,
/// and anywhere persistence isn't wired up yet.
public actor InMemoryTelemetryLog: TelemetryLog {
    private var events: [TelemetryEvent] = []
    private let maxEvents: Int
    private let maxAge: TimeInterval

    public init(maxEvents: Int = 10_000, maxAge: TimeInterval = 7 * 24 * 60 * 60) {
        self.maxEvents = maxEvents
        self.maxAge = maxAge
    }

    public func log(_ event: TelemetryEvent) {
        events.append(event)
        prune()
    }

    public func snapshot() -> [TelemetryEvent] { events }

    public func clear() { events.removeAll() }

    private func prune() {
        let cutoff = Date().addingTimeInterval(-maxAge)
        events.removeAll { $0.timestamp < cutoff }
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }
}

/// No-op log for when telemetry is disabled.
public struct NoOpTelemetryLog: TelemetryLog, Sendable {
    public init() {}
    public func log(_ event: TelemetryEvent) async {}
    public func snapshot() async -> [TelemetryEvent] { [] }
    public func clear() async {}
}
