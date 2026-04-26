import Foundation

/// The main entry point for the engine during a live set.
///
/// Takes a `BodyStateStream` as input, emits a stream of `CoachingIntent`s as
/// output. Internal orchestration chains: rep detector → tempo tracker → cue
/// engine → intent emitter. Also owns the set-end detector and the pain-detector
/// hook (pain comes through an out-of-band input; see `signalPainDetected`).
public final class SessionOrchestrator {
    public let config: SessionConfig
    public let context: SessionContext

    private let repDetector: RepDetector
    private let setEndDetector: SetEndDetector
    private let cueEngine: CueEngine
    private let intentEmitter: CoachingIntentEmitter
    private var tempoTracker = TempoTracker()

    private(set) var repEvents: [RepEvent] = []
    private(set) var cueEvents: [CueEvent] = []
    private var setEnded = false
    private var painStopped = false
    private var endReason: SetEndEvent.EndReason?

    public init(config: SessionConfig, context: SessionContext) {
        self.config = config
        self.context = context
        self.repDetector = RepDetectorFactory.make(for: config.exerciseId)
        self.setEndDetector = SetEndDetector(exerciseId: config.exerciseId)
        self.cueEngine = CueEngine(exerciseId: config.exerciseId)
        self.intentEmitter = CoachingIntentEmitter(exerciseId: config.exerciseId)
    }

    /// Feed a single pose sample. Returns any intents emitted by this sample.
    public func observe(sample: PoseSample) -> [CoachingIntent] {
        guard !painStopped, !setEnded else { return [] }

        // Evaluate cues against the current phase. Rep-number context for cues
        // is the in-progress rep = completed count + 1.
        let phase = repDetector.phase
        let inProgressRepNumber = repDetector.currentRepNumber + 1
        let cues = cueEngine.evaluate(sample: sample, phase: phase, repNumber: inProgressRepNumber)
        intentEmitter.stageCues(cues)
        cueEvents.append(contentsOf: cues)

        var intents: [CoachingIntent] = []

        // Step the rep detector; if a rep was completed, process tempo and emit intents.
        if let rep = repDetector.observe(sample) {
            repEvents.append(rep)
            setEndDetector.noteRepCompleted()
            let repCompletedOutput = intentEmitter.onRepCompleted(rep)
            intents.append(contentsOf: repCompletedOutput.intents)
            if let trigger = tempoTracker.ingest(rep) {
                let fatigueOutput = intentEmitter.onFatigueTriggered(trigger, at: rep.endedAt)
                intents.append(contentsOf: fatigueOutput.intents)
            }
            // After emitting this rep, also check the reached target.
            if let target = config.targetReps, rep.repNumber >= target {
                intents.append(.encouragement(
                    kind: .lastOne, timing: .topOfRep, timestamp: rep.endedAt
                ))
            }
        }

        // Check set-end conditions on every sample.
        if !setEnded, let reason = setEndDetector.observe(sample) {
            setEnded = true
            endReason = reason
            let event = SetEndEvent(
                exerciseId: config.exerciseId,
                setNumber: config.setNumber,
                reason: reason,
                timestamp: sample.timestamp,
                totalReps: repEvents.count,
                partialReps: repEvents.filter { $0.isPartial }.count
            )
            intents.append(contentsOf: intentEmitter.onSetEnded(event).intents)
        }

        return intents
    }

    /// Explicit user-initiated set end (tap or voice command).
    public func finishSetExplicitly(reason: SetEndEvent.EndReason) -> [CoachingIntent] {
        guard !setEnded else { return [] }
        setEnded = true
        endReason = reason
        let now = repEvents.last?.endedAt ?? 0
        let event = SetEndEvent(
            exerciseId: config.exerciseId,
            setNumber: config.setNumber,
            reason: reason,
            timestamp: now,
            totalReps: repEvents.count,
            partialReps: repEvents.filter { $0.isPartial }.count
        )
        return intentEmitter.onSetEnded(event).intents
    }

    /// Signals that pain was detected (via STT or user tap). Stops everything.
    public func signalPainDetected(trigger: String) -> [CoachingIntent] {
        guard !painStopped else { return [] }
        painStopped = true
        endReason = .painPause
        return intentEmitter.onPainDetected(trigger: trigger).intents
    }

    /// Produce the final structured observation for this set — input to the LLM
    /// summary generator.
    public func buildObservation() -> SessionObservation {
        let endEvent = SetEndEvent(
            exerciseId: config.exerciseId,
            setNumber: config.setNumber,
            reason: endReason ?? .userTapped,
            timestamp: repEvents.last?.endedAt ?? 0,
            totalReps: repEvents.count,
            partialReps: repEvents.filter { $0.isPartial }.count
        )
        return SessionObservation(
            exerciseId: config.exerciseId,
            setNumber: config.setNumber,
            repEvents: repEvents,
            cueEvents: cueEvents,
            endEvent: endEvent,
            tempoBaselineMs: tempoTracker.baselineMs,
            fatigueSlowdownAtRep: tempoTracker.firstFatigueTriggeredAtRep,
            priorSessionBestReps: context.priorSessionBestReps[config.exerciseId],
            memoryReferences: context.memoryReferences
        )
    }
}
