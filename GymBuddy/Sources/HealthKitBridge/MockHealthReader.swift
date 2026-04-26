import Foundation

/// Deterministic mock for tests and offline dev.
public final class MockHealthReader: HealthReader, @unchecked Sendable {
    public var authorization: Bool
    public var hrv: Double?
    public var sleep: Double?
    public var heartRate: Double?

    public init(
        authorization: Bool = true,
        hrv: Double? = 55.0,
        sleep: Double? = 7.5,
        heartRate: Double? = 60.0
    ) {
        self.authorization = authorization
        self.hrv = hrv
        self.sleep = sleep
        self.heartRate = heartRate
    }

    public func requestAuthorization() async throws -> Bool { authorization }
    public func latestHRV() async throws -> Double? { hrv }
    public func sleepLastNight() async throws -> Double? { sleep }
    public func latestHeartRate() async throws -> Double? { heartRate }
}
