import Foundation
import CoachingEngine

/// Identifies a Tier-1 (pre-cached) phrase. Encodes phrase kind + tone + optional
/// numeric argument (for rep counts). Runtime picks one of the N variants per id.
public struct PhraseID: Equatable, Hashable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case repCount          // "three"
        case encourageOneMore  // "one more"
        case encouragePush     // "push"
        case encourageDrive    // "drive"
        case encourageLastOne  // "last one"
        case encourageSteady   // "steady"
        case encourageValidate // "there we go"
        case safetyPainStop    // pre-recorded pain-stop safe response
        case safetyDiagnosisDeflect
        case safetyNutritionDeflect
        case safetyGenericDeflect
    }

    public let kind: Kind
    public let tone: CoachingTone
    public let number: Int?

    public init(kind: Kind, tone: CoachingTone, number: Int? = nil) {
        self.kind = kind
        self.tone = tone
        self.number = number
    }

    public var assetName: String {
        if let n = number {
            return "\(kind.rawValue)-\(tone.rawValue)-\(n)"
        }
        return "\(kind.rawValue)-\(tone.rawValue)"
    }
}

/// Map an engine encouragement intent to a PhraseID.Kind.
public extension CoachingIntent.EncouragementKind {
    func phraseKind() -> PhraseID.Kind {
        switch self {
        case .pushThrough: .encouragePush
        case .oneMore: .encourageOneMore
        case .drive: .encourageDrive
        case .lastOne: .encourageLastOne
        case .steady: .encourageSteady
        case .validate: .encourageValidate
        }
    }
}
