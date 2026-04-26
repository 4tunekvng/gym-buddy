import Foundation
import CoachingEngine

/// The canonical list of Tier-1 phrases we must ship for a tone.
/// This is both the spec for the TTS build step and the runtime validation list.
public enum PhraseManifest {
    public static func required(for tone: CoachingTone, maxRepCount: Int = 50) -> [PhraseID] {
        var ids: [PhraseID] = []
        for n in 1...maxRepCount {
            ids.append(PhraseID(kind: .repCount, tone: tone, number: n))
        }
        let basic: [PhraseID.Kind] = [
            .encourageOneMore, .encouragePush, .encourageDrive,
            .encourageLastOne, .encourageSteady, .encourageValidate
        ]
        for k in basic {
            ids.append(PhraseID(kind: k, tone: tone, number: nil))
        }
        let safety: [PhraseID.Kind] = [
            .safetyPainStop, .safetyDiagnosisDeflect,
            .safetyNutritionDeflect, .safetyGenericDeflect
        ]
        for k in safety {
            ids.append(PhraseID(kind: k, tone: tone, number: nil))
        }
        return ids
    }

    /// Minimum variants required per phrase for each kind. Rep counts ship fewer
    /// because the content is quite constrained; motivational phrases ship more
    /// to resist the "coach is looping" perception.
    public static let minimumVariantsByKind: [PhraseID.Kind: Int] = [
        .repCount: 3,
        .encourageOneMore: 7,
        .encouragePush: 7,
        .encourageDrive: 5,
        .encourageLastOne: 5,
        .encourageSteady: 5,
        .encourageValidate: 5,
        .safetyPainStop: 2,
        .safetyDiagnosisDeflect: 2,
        .safetyNutritionDeflect: 2,
        .safetyGenericDeflect: 2
    ]
}
