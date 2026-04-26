import Foundation

/// A qualitative note about the athlete that isn't captured in structured
/// workout data. Examples:
///   - "left knee clicks on deep squats"
///   - "hates tempo work, loves AMRAP"
///   - "lifts at 7pm on weekdays"
public struct CoachMemoryNote: Equatable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let content: String
    public let tags: Set<String>
    public let createdAt: Date
    public let linkedSessionId: UUID?

    public init(
        id: UUID = UUID(),
        content: String,
        tags: Set<String>,
        createdAt: Date = Date(),
        linkedSessionId: UUID? = nil
    ) {
        self.id = id
        self.content = content
        self.tags = tags
        self.createdAt = createdAt
        self.linkedSessionId = linkedSessionId
    }
}

/// Canonical tag vocabulary. Using a small closed set in MVP; additions require
/// a code change so we can't drift (this is intentional in Chapter 1).
public enum MemoryTag: String, Codable, CaseIterable, Sendable {
    case injury
    case preference
    case mood
    case context
    case schedule
    case equipment
    case bodyPartKnee = "body-part:knee"
    case bodyPartShoulder = "body-part:shoulder"
    case bodyPartBack = "body-part:back"
    case bodyPartElbow = "body-part:elbow"
    case goalStrength = "goal:strength"
    case goalHypertrophy = "goal:hypertrophy"
    case goalRecomp = "goal:recomp"
}
