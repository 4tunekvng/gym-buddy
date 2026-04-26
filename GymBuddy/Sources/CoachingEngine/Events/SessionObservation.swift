import Foundation

/// The full structured record of what was observed during a set. Fed into the
/// LLM layer to generate a warm, grounded summary. Never generic.
///
/// Per OQ-009 the summary generator requires at least one quantitative fact AND
/// one qualitative observation. This struct is the source of those facts.
public struct SessionObservation: Equatable, Codable, Sendable {
    public let exerciseId: ExerciseID
    public let setNumber: Int
    public let repEvents: [RepEvent]
    public let cueEvents: [CueEvent]
    public let endEvent: SetEndEvent
    public let tempoBaselineMs: Int?
    public let fatigueSlowdownAtRep: Int?
    public let priorSessionBestReps: Int?
    public let memoryReferences: [String]   // tag-filtered memory note contents

    public init(
        exerciseId: ExerciseID,
        setNumber: Int,
        repEvents: [RepEvent],
        cueEvents: [CueEvent],
        endEvent: SetEndEvent,
        tempoBaselineMs: Int?,
        fatigueSlowdownAtRep: Int?,
        priorSessionBestReps: Int?,
        memoryReferences: [String]
    ) {
        self.exerciseId = exerciseId
        self.setNumber = setNumber
        self.repEvents = repEvents
        self.cueEvents = cueEvents
        self.endEvent = endEvent
        self.tempoBaselineMs = tempoBaselineMs
        self.fatigueSlowdownAtRep = fatigueSlowdownAtRep
        self.priorSessionBestReps = priorSessionBestReps
        self.memoryReferences = memoryReferences
    }

    public var totalReps: Int { repEvents.count }
    public var fullReps: Int { repEvents.filter { !$0.isPartial }.count }
    public var partialReps: Int { repEvents.filter { $0.isPartial }.count }

    public var hadAnyCues: Bool { !cueEvents.isEmpty }
    public var safetyCueCount: Int { cueEvents.filter { $0.severity == .safety }.count }
}
