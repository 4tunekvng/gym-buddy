import Foundation

/// A morning readiness check-in.
///
/// Inputs we might read:
///   - user soreness rating (1–5)
///   - user energy rating (1–5)
///   - user sleep hours (from HealthKit or self-report)
///   - HRV delta vs. baseline (from HealthKit)
public struct ReadinessCheck: Equatable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let date: Date
    public let soreness: Int?          // 1 (none) — 5 (severe)
    public let energy: Int?            // 1 (low) — 5 (high)
    public let sleepHours: Double?
    public let hrvDeltaPct: Double?    // percentage below baseline, positive number
    public let userFreeformNote: String?

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        soreness: Int? = nil,
        energy: Int? = nil,
        sleepHours: Double? = nil,
        hrvDeltaPct: Double? = nil,
        userFreeformNote: String? = nil
    ) {
        self.id = id
        self.date = date
        self.soreness = soreness
        self.energy = energy
        self.sleepHours = sleepHours
        self.hrvDeltaPct = hrvDeltaPct
        self.userFreeformNote = userFreeformNote
    }
}
