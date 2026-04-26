import Foundation

/// A form cue fired by the CueEngine. Priority is determined by severity first,
/// then by specificity. At most one cue is surfaced per rep (PRD §5.1).
public struct CueEvent: Equatable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let exerciseId: ExerciseID
    public let cueType: CueType
    public let severity: CueSeverity
    public let repNumber: Int
    public let timestamp: TimeInterval
    /// Short machine-readable reason the cue fired. Useful for telemetry and tests.
    public let observationCode: String

    public init(
        id: UUID = UUID(),
        exerciseId: ExerciseID,
        cueType: CueType,
        severity: CueSeverity,
        repNumber: Int,
        timestamp: TimeInterval,
        observationCode: String
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.cueType = cueType
        self.severity = severity
        self.repNumber = repNumber
        self.timestamp = timestamp
        self.observationCode = observationCode
    }
}

public enum CueSeverity: Int, Codable, Comparable, Sendable {
    case optimization = 0    // "drive harder on the way up"
    case quality = 1         // "chest to the floor"
    case safety = 2          // "flatten that back"

    public static func < (lhs: CueSeverity, rhs: CueSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
