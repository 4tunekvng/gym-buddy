import Foundation

/// Scales today's plan based on a readiness check-in.
///
/// Rules (intentionally simple for MVP):
///   - HRV down > 10% from baseline  →  volume -1 set
///   - Sleep < 5 hours                →  load -10%
///   - Soreness >= 4                  →  deload day (offer skip or easier variant)
///   - Energy <= 2                    →  load -10%
///
/// These decisions are applied to each set in the day plan. Multiple triggers
/// compound but load scaling is clamped to -15%.
public struct ReadinessScaler: Sendable {
    public struct Scaling: Equatable, Sendable {
        public let loadMultiplier: Double
        public let volumeSetsDelta: Int
        public let isDeloadOffered: Bool
        public let reasons: [String]

        public static let neutral = Scaling(
            loadMultiplier: 1.0, volumeSetsDelta: 0, isDeloadOffered: false, reasons: []
        )
    }

    public init() {}

    public func scale(_ day: PlanDay, basedOn check: ReadinessCheck) -> (PlanDay, Scaling) {
        var loadMultiplier = 1.0
        var volumeDelta = 0
        var deload = false
        var reasons: [String] = []

        if let hrv = check.hrvDeltaPct, hrv > 10 {
            volumeDelta -= 1
            reasons.append("HRV is \(Int(hrv))% below baseline — cutting one set")
        }
        if let sleep = check.sleepHours, sleep < 5 {
            loadMultiplier -= 0.10
            reasons.append("Short sleep — pulling load back 10%")
        }
        if let soreness = check.soreness, soreness >= 4 {
            deload = true
            reasons.append("Heavy soreness — deload offered")
        }
        if let energy = check.energy, energy <= 2 {
            loadMultiplier -= 0.10
            reasons.append("Low energy — pulling load back 10%")
        }

        loadMultiplier = max(0.85, min(1.0, loadMultiplier))

        let scaling = Scaling(
            loadMultiplier: loadMultiplier,
            volumeSetsDelta: volumeDelta,
            isDeloadOffered: deload,
            reasons: reasons
        )
        let adjustedExercises = day.exercises.map { planned -> PlannedExercise in
            var sets = planned.sets
            if volumeDelta < 0, sets.count > 1 {
                sets = Array(sets.prefix(max(1, sets.count + volumeDelta)))
            }
            sets = sets.map { set in
                PlannedSet(
                    id: set.id,
                    setNumber: set.setNumber,
                    targetReps: set.targetReps,
                    isAmrap: set.isAmrap,
                    targetLoadKg: set.targetLoadKg.map { $0 * loadMultiplier }
                )
            }
            return PlannedExercise(id: planned.id, exerciseId: planned.exerciseId, sets: sets)
        }
        let adjustedDay = PlanDay(
            id: day.id,
            weekNumber: day.weekNumber,
            dayOfWeek: day.dayOfWeek,
            isRestDay: day.isRestDay,
            exercises: adjustedExercises
        )
        return (adjustedDay, scaling)
    }
}
