import Foundation

/// Turns raw engine events into coaching intents that the platform layer can consume.
///
/// Responsibilities:
///   - Emit `sayRepCount` for every completed rep.
///   - Surface at most one cue per rep, prioritized safety > quality > optimization.
///   - Emit `encouragement(.oneMore)` and `.lastOne` in response to fatigue triggers.
///   - Emit `setEnded` when the set end is signaled.
///
/// This type is stateless across sessions — instantiate per session.
public final class CoachingIntentEmitter {
    public struct Output: Equatable, Sendable {
        public let intents: [CoachingIntent]
        public init(intents: [CoachingIntent]) { self.intents = intents }

        public static let empty = Output(intents: [])
    }

    private let exerciseId: ExerciseID
    private var pendingCuesForCurrentRep: [CueEvent] = []
    private var currentRepSurfaced: Bool = false

    public init(exerciseId: ExerciseID) {
        self.exerciseId = exerciseId
    }

    public func stageCues(_ cues: [CueEvent]) {
        pendingCuesForCurrentRep.append(contentsOf: cues)
    }

    public func onRepCompleted(_ rep: RepEvent) -> Output {
        var intents: [CoachingIntent] = []

        // 1) Announce the rep count.
        intents.append(.sayRepCount(number: rep.repNumber, timestamp: rep.endedAt))

        // 2) Surface the highest-severity cue observed during this rep (if any).
        if let topCue = CueEngine.selectHighestPriority(pendingCuesForCurrentRep) {
            intents.append(.formCue(topCue))
        }

        pendingCuesForCurrentRep.removeAll(keepingCapacity: true)
        currentRepSurfaced = false
        return Output(intents: intents)
    }

    public func onFatigueTriggered(
        _ trigger: TempoTracker.FatigueTrigger,
        at timestamp: TimeInterval
    ) -> Output {
        switch trigger {
        case .firstSlowdown:
            return Output(intents: [
                .encouragement(kind: .oneMore, timing: .bottomOfRep, timestamp: timestamp),
                .encouragement(kind: .pushThrough, timing: .duringConcentric, timestamp: timestamp)
            ])
        case .secondSlowdown:
            return Output(intents: [
                .encouragement(kind: .lastOne, timing: .bottomOfRep, timestamp: timestamp),
                .encouragement(kind: .drive, timing: .duringConcentric, timestamp: timestamp)
            ])
        case .eccentricFatigue:
            // Early-warning: eccentric phase slowed before concentric — coach
            // cues a controlled lowering to preserve power for the next push.
            return Output(intents: [
                .encouragement(kind: .steady, timing: .duringEccentric, timestamp: timestamp)
            ])
        }
    }

    public func onSetEnded(_ event: SetEndEvent) -> Output {
        Output(intents: [.setEnded(event), .startRest(seconds: 90)])
    }

    public func onPainDetected(trigger: String) -> Output {
        Output(intents: [.painStop(trigger: trigger)])
    }
}
