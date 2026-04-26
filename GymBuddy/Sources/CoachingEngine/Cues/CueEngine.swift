import Foundation

/// Evaluates every registered cue against each pose sample.
///
/// Priorities: at most one cue fires per rep. Higher-severity cues win;
/// ties are broken by the order cues were registered (safety cues come first).
/// Once a cue has fired for a given rep number, that cue type won't re-fire for
/// the same rep. Different cue types can still fire later in the rep — but the
/// orchestrator surfaces at most one per rep (PRD §5.1).
public final class CueEngine {
    private let exerciseId: ExerciseID
    private let evaluators: [CueEvaluator]
    private var firedCuesThisRep: Set<CueType> = []
    private var lastRepNumberSeen: Int = 0

    public init(exerciseId: ExerciseID) {
        self.exerciseId = exerciseId
        self.evaluators = Self.evaluators(for: exerciseId)
    }

    public func resetForNewRep(repNumber: Int) {
        firedCuesThisRep.removeAll(keepingCapacity: true)
        lastRepNumberSeen = repNumber
    }

    /// Evaluate all cues against this sample at the given phase. Returns any cue
    /// events that fired. Caller is responsible for applying priority and the
    /// at-most-one-per-rep rule when surfacing.
    public func evaluate(
        sample: PoseSample,
        phase: RepPhase,
        repNumber: Int
    ) -> [CueEvent] {
        if repNumber != lastRepNumberSeen { resetForNewRep(repNumber: repNumber) }
        var events: [CueEvent] = []
        for evaluator in evaluators {
            guard !firedCuesThisRep.contains(evaluator.cueType) else { continue }
            if let obs = evaluator.evaluate(sample: sample, phase: phase) {
                firedCuesThisRep.insert(evaluator.cueType)
                events.append(CueEvent(
                    exerciseId: exerciseId,
                    cueType: evaluator.cueType,
                    severity: evaluator.severity,
                    repNumber: repNumber,
                    timestamp: sample.timestamp,
                    observationCode: obs
                ))
            }
        }
        return events
    }

    private static func evaluators(for exerciseId: ExerciseID) -> [CueEvaluator] {
        switch exerciseId {
        case .pushUp: PushUpCues.all
        case .gobletSquat: GobletSquatCues.all
        case .dumbbellRow: DumbbellRowCues.all
        }
    }

    /// Selects the single highest-priority cue from a batch, per the PRD rule
    /// (safety > quality > optimization). Returns nil if batch is empty.
    public static func selectHighestPriority(_ cues: [CueEvent]) -> CueEvent? {
        cues.max(by: { $0.severity < $1.severity })
    }
}

/// Protocol for individual cue evaluators.
public protocol CueEvaluator {
    var cueType: CueType { get }
    var severity: CueSeverity { get }
    /// Returns an observation code string if the cue should fire.
    func evaluate(sample: PoseSample, phase: RepPhase) -> String?
}
