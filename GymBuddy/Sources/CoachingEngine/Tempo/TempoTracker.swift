import Foundation

/// Tracks per-rep tempo, establishes a baseline, and flags fatigue slowdowns.
///
/// Baselines (reps 2–4, full reps only, per OQ-001):
///   - `baselineMs`: median concentric duration.
///   - `eccentricBaselineMs`: median eccentric duration.
///
/// Fatigue signals (concentric path — primary):
///   - `firstSlowdown`: concentric ratio >= 1.35 for the first time.
///   - `secondSlowdown`: concentric ratio >= 1.50, only after firstSlowdown.
///
/// Fatigue signals (eccentric path — early-warning):
///   - `eccentricFatigue`: eccentric ratio >= 1.40 fires once, independent of
///     the concentric path. Research shows the eccentric phase often slows before
///     the concentric does, making it a useful early-warning signal for the coach.
///
/// Partial reps are excluded from all baselines and all fatigue detection
/// (OQ-002 — users can't fake incomplete reps to trigger the push moment).
public struct TempoTracker: Sendable {
    public var baselineMs: Int?
    public var eccentricBaselineMs: Int?
    public var reps: [RepTempoSample] = []
    public var firstFatigueTriggeredAtRep: Int?
    public var secondFatigueTriggeredAtRep: Int?
    public var eccentricFatigueTriggeredAtRep: Int?

    public init() {}

    public struct RepTempoSample: Equatable, Codable, Sendable {
        public let repNumber: Int
        public let concentricMs: Int
        public let eccentricMs: Int
        public let isPartial: Bool
    }

    /// Ingest a completed rep. Returns a fatigue trigger if this rep produced one.
    /// The concentric path takes priority; if no concentric trigger fires this rep,
    /// the eccentric path is checked.
    public mutating func ingest(_ rep: RepEvent) -> FatigueTrigger? {
        let sample = RepTempoSample(
            repNumber: rep.repNumber,
            concentricMs: Int((rep.concentricDuration * 1000.0).rounded()),
            eccentricMs: Int((rep.eccentricDuration * 1000.0).rounded()),
            isPartial: rep.isPartial
        )
        reps.append(sample)

        // Baselines: once we have reps 2, 3, 4 as full reps, compute medians.
        let baselineCandidates = reps.filter { !$0.isPartial && (2...4).contains($0.repNumber) }
        if baselineCandidates.count >= 3 {
            if baselineMs == nil {
                let sorted = baselineCandidates.map(\.concentricMs).sorted()
                baselineMs = sorted[sorted.count / 2]
            }
            if eccentricBaselineMs == nil {
                let sorted = baselineCandidates.map(\.eccentricMs).sorted()
                eccentricBaselineMs = sorted[sorted.count / 2]
            }
        }

        guard !rep.isPartial else { return nil }

        // Concentric path (primary).
        if let baseline = baselineMs, baseline > 0 {
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
        }

        // Eccentric path (early-warning — fires once, independently of concentric).
        if let eccBaseline = eccentricBaselineMs, eccBaseline > 0,
           eccentricFatigueTriggeredAtRep == nil {
            let eccRatio = Double(sample.eccentricMs) / Double(eccBaseline)
            if eccRatio >= 1.40 {
                eccentricFatigueTriggeredAtRep = rep.repNumber
                return .eccentricFatigue(ratio: eccRatio, atRep: rep.repNumber)
            }
        }

        return nil
    }

    public enum FatigueTrigger: Equatable, Sendable {
        /// First time the concentric ratio exceeded 1.35 — triggers the "one more — push" moment.
        case firstSlowdown(ratio: Double, atRep: Int)
        /// Second time the concentric ratio exceeded 1.50 — triggers "last one — drive".
        case secondSlowdown(ratio: Double, atRep: Int)
        /// Eccentric phase slowed >= 1.40× baseline before the concentric did.
        /// Early-warning signal for the coach — fires at most once per set.
        case eccentricFatigue(ratio: Double, atRep: Int)

        public var atRep: Int {
            switch self {
            case .firstSlowdown(_, let rep),
                 .secondSlowdown(_, let rep),
                 .eccentricFatigue(_, let rep): return rep
            }
        }
    }
}
