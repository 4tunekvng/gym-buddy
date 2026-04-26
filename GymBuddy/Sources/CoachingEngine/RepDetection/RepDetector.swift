import Foundation

/// Per-exercise rep detectors share this protocol.
///
/// Invariants enforced by tests:
///   - Every emitted `RepEvent.repNumber` strictly increases by 1.
///   - `endedAt >= startedAt`.
///   - A rep event is only emitted after a full top→bottom→top cycle.
///   - Observing a sample never throws; samples with missing joints are skipped cleanly.
public protocol RepDetector: AnyObject, Sendable {
    var exerciseId: ExerciseID { get }
    var phase: RepPhase { get }
    var currentRepNumber: Int { get }

    /// Feed a pose sample. Returns a `RepEvent` if this sample completed a rep.
    func observe(_ sample: PoseSample) -> RepEvent?

    /// Reset internal state (e.g. between sets).
    func reset()
}

/// Factory to create a fresh detector for a given exercise.
public enum RepDetectorFactory {
    public static func make(for exercise: ExerciseID) -> RepDetector {
        switch exercise {
        case .pushUp: return PushUpRepDetector()
        case .gobletSquat: return GobletSquatRepDetector()
        case .dumbbellRow: return DumbbellRowRepDetector()
        }
    }
}
