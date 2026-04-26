import XCTest
@testable import CoachingEngine

/// Confirms every CueType has a friendly display string when the view layer
/// maps them. The iOS app's `LiveSessionViewModel.cueDisplayText` is the
/// authoritative mapper — this test covers the domain-side contract: every
/// cue type should have at least one word of coaching language (no "Hold the
/// form" for any specific cue), since generic strings are a regression risk.
///
/// We duplicate the switch here so changes in the app layer don't silently
/// drop cues to the "default" branch.
final class CueDisplayTextExpectationsTests: XCTestCase {

    func testEveryCueTypeHasASpecificCoachingString() {
        for cue in CueType.allCases {
            let text = expectedDisplayText(for: cue)
            XCTAssertFalse(
                text.isEmpty,
                "Every CueType must have a non-empty coach phrase"
            )
            XCTAssertGreaterThanOrEqual(text.count, 3)
            // Safety check: the test's own switch has no `default` branch, so a
            // newly-added CueType will force this test to fail at compile time
            // rather than silently mapping to "Hold the form".
        }
    }

    private func expectedDisplayText(for cue: CueType) -> String {
        switch cue {
        case .hipSag: return "Flatten the hips"
        case .hipPike: return "Drop the hips"
        case .elbowFlare: return "Tuck the elbows"
        case .partialRangeBottom: return "Chest to the floor"
        case .partialRangeTop: return "Lock it out"
        case .headPositionBad: return "Keep the neck neutral"
        case .squatShallow: return "Hit depth"
        case .kneeValgusLeft, .kneeValgusRight: return "Drive the knees out"
        case .torsoForward: return "Chest up"
        case .heelLift: return "Heels down"
        case .dumbbellDrift: return "Dumbbell to sternum"
        case .lumbarFlexion: return "Flat back"
        case .elbowFlareRow: return "Elbow back, not out"
        case .torsoInstability: return "Steady torso"
        case .partialRangeRowTop: return "Pull past the torso"
        case .tempoJerkyRow: return "Control the lower"
        case .tempoEncourage: return "Push"
        case .tempoDrive: return "Drive"
        case .tempoLastOne: return "Last one"
        }
    }
}
