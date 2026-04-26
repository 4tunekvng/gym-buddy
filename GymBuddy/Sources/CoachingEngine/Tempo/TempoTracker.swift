import Foundation

/// Tracks per-rep tempo, establishes a baseline, and flags fatigue slowdowns.
///
/// Baseline = median concentric duration of reps 2–4 (per OQ-001).
/// Fatigue signals:
///   - `first("one more — push")`: ratio to baseline >= 1.35 for the first time.
///   - `second("last one — drive")`: ratio >= 1.50, only after the first has been observed.
///
/// Partial reps are excluded from the baseline calculation AND from fatigue
/// detection (OQ-002 — users can't fake incomplete reps to trigger the push moment).
public struct TempoTracker: Sendable {
    public var baselineMs: Int?
    public var reps: [RepTempoSample] = []
    public var firstFatigueTriggeredAtRep: Int?
    public var secondFatigueTriggeredAtRep: Int?

    public init() {}

    public struct RepTempoSample: Equatable, Codable, Sendable {
        public let repNumber: Int
        public let concentricMs: Int
        public let isPartial: Bool
    }

    /// Ingest a completed rep. Returns a fatigue trigger if this rep produced one.
    public mutating func ingest(_ rep: RepEvent) -> FatigueTrigger? {
        let sample = RepTempoSample(
            repNumber: rep.repNumber,
            concentricMs: Int((rep.concentricDuration * 1000.0).rounded()),
            isPartial: rep.isPartial
        )
        reps.append(sample)

        // Baseline: once we have reps 2, 3, 4 as full reps, compute median.
        if baselineMs == nil {
            let candidates = reps.filter { !$0.isPartial && (2...4).contains($0.repNumber) }
            if candidates.count >= 3 {
                let sorted = candidates.map(\.concentricMs).sorted()
                baselineMs = sorted[sorted.count / 2]
            }
        }

        guard !rep.isPartial, let baseline = baselineMs, baseline > 0 else { return nil }
        let ratio = Double(sample.concentricMs) / Double(baseline)

        if firstFatigueTriggeredAtRep == nil, ratio >= 1.35 {
            firstFatigueTriggeredAtRep = rep.repNumber
            return .firstSlowdown(ratio: ratio, atRep: rep.repNumber)
        }

        if let first = firstFatigueTriggeredAtRep,
           secondFatigueTriggeredAtRep == nil,
           ratio >= 1.50,
           rep.repNumber > first {
            secondFatigueTriggeredAtRep = rep.repNumber
            return .secondSlowdown(ratio: ratio, atRep: rep.repNumber)
        }

        return nil
    }

    public enum FatigueTrigger: Equatable, Sendable {
        /// First time the tempo ratio exceeded 1.35 — triggers the "one more — push" moment.
        case firstSlowdown(ratio: Double, atRep: Int)
        /// Second time, ratio exceeded 1.50 — triggers "last one — drive".
        case secondSlowdown(ratio: Double, atRep: Int)

        public var atRep: Int {
            switch self {
            case .firstSlowdown(_, let rep), .secondSlowdown(_, let rep): return rep
            }
        }
    }
}
