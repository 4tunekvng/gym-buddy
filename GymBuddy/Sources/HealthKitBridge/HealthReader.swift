import Foundation
import CoachingEngine

/// Read-only HealthKit abstraction. See docs/Privacy.md — the app writes
/// nothing in MVP.
public protocol HealthReader: Sendable {
    func requestAuthorization() async throws -> Bool
    func latestHRV() async throws -> Double?
    func sleepLastNight() async throws -> Double?  // hours
    func latestHeartRate() async throws -> Double? // bpm
}

public struct HealthReading: Equatable, Sendable {
    public let hrvMs: Double?
    public let sleepHours: Double?
    public let restingHRBpm: Double?
    public init(hrvMs: Double? = nil, sleepHours: Double? = nil, restingHRBpm: Double? = nil) {
        self.hrvMs = hrvMs
        self.sleepHours = sleepHours
        self.restingHRBpm = restingHRBpm
    }
}
