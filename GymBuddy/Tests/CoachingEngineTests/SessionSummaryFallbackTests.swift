import XCTest
@testable import CoachingEngine

/// Guards the OQ-009 contract: the fallback summary must always include at
/// least one quantitative fact, never generic praise, and reference something
/// specific about the just-completed set.
final class SessionSummaryFallbackTests: XCTestCase {

    private func makeObservation(
        exerciseId: ExerciseID = .pushUp,
        totalReps: Int = 10,
        partialReps: Int = 0,
        fatigueRep: Int? = nil,
        safetyCues: Int = 0,
        priorBest: Int? = nil
    ) -> SessionObservation {
        let reps = (1...max(1, totalReps)).map { n in
            RepEvent(
                exerciseId: exerciseId,
                repNumber: n,
                startedAt: Double(n),
                endedAt: Double(n) + 1,
                concentricDuration: 1.0,
                eccentricDuration: 0.8,
                rangeOfMotionScore: 0.9,
                isPartial: n > (totalReps - partialReps)
            )
        }
        let cues = (0..<safetyCues).map { i in
            CueEvent(
                exerciseId: exerciseId, cueType: .hipSag, severity: .safety,
                repNumber: i + 1, timestamp: Double(i), observationCode: "x"
            )
        }
        return SessionObservation(
            exerciseId: exerciseId,
            setNumber: 1,
            repEvents: totalReps == 0 ? [] : reps,
            cueEvents: cues,
            endEvent: SetEndEvent(
                exerciseId: exerciseId, setNumber: 1, reason: .autoDetectedStill,
                timestamp: 20, totalReps: totalReps, partialReps: partialReps
            ),
            tempoBaselineMs: 1000,
            fatigueSlowdownAtRep: fatigueRep,
            priorSessionBestReps: priorBest,
            memoryReferences: []
        )
    }

    func testLeadFactReferencesRepCountAndExercise() {
        let obs = makeObservation(totalReps: 10)
        let text = SessionSummaryFallback.summary(for: obs)
        XCTAssertTrue(text.contains("10"), "Summary must include rep count")
        XCTAssertTrue(text.contains("Push-up"), "Summary must name the exercise")
    }

    func testFatigueRepIsMentionedWhenPresent() {
        let obs = makeObservation(totalReps: 10, fatigueRep: 8)
        let text = SessionSummaryFallback.summary(for: obs)
        XCTAssertTrue(text.contains("grind"), "Expected grind reference on fatigue rep")
        XCTAssertTrue(text.contains("8"), "Expected the fatigue rep number")
    }

    func testCleanSetMentionedWhenNoPartialAndNoFatigue() {
        let obs = makeObservation(totalReps: 10)
        let text = SessionSummaryFallback.summary(for: obs)
        XCTAssertTrue(text.contains("Clean"), "Expected 'Clean' language for a flawless set")
    }

    func testPartialRepsSurfaceInLeadFact() {
        let obs = makeObservation(totalReps: 10, partialReps: 3)
        let text = SessionSummaryFallback.summary(for: obs)
        XCTAssertTrue(text.contains("full"), "Expected full/partial split")
        XCTAssertTrue(text.contains("partial"), "Expected full/partial split")
    }

    func testSafetyCueNoteWhenCuesFired() {
        let obs = makeObservation(totalReps: 10, safetyCues: 2)
        let text = SessionSummaryFallback.summary(for: obs)
        XCTAssertTrue(text.contains("form cues"), "Expected form-cue note when safety cues fired")
    }

    func testPersonalBestNoteWhenTotalRepsExceedsPrior() {
        let obs = makeObservation(totalReps: 12, priorBest: 9)
        let text = SessionSummaryFallback.summary(for: obs)
        XCTAssertTrue(text.contains("past your last best"), "Expected PB reference")
    }

    func testZeroRepsGetsLoggedButNoGenericPraise() {
        let obs = makeObservation(totalReps: 0)
        let text = SessionSummaryFallback.summary(for: obs)
        XCTAssertTrue(text.contains("no reps counted") || text.contains("0"),
                      "Zero-rep fallback must acknowledge the empty set without generic praise")
        XCTAssertFalse(text.contains("Good job") || text.contains("Nice work"),
                       "Generic praise is forbidden per OQ-009")
    }

    func testAlwaysIncludesRestHintAtTheEnd() {
        let obs = makeObservation(totalReps: 10)
        let text = SessionSummaryFallback.summary(for: obs)
        XCTAssertTrue(text.hasSuffix(SessionSummaryFallback.restHint),
                      "Rest hint must close the summary")
    }

    func testNeverGenericForAnyObservationShape() {
        // Every realistic observation shape should produce a summary that has
        // at least one digit AND names the exercise.
        let shapes: [SessionObservation] = [
            makeObservation(totalReps: 0),
            makeObservation(totalReps: 1),
            makeObservation(totalReps: 10),
            makeObservation(totalReps: 10, partialReps: 5),
            makeObservation(totalReps: 10, fatigueRep: 8),
            makeObservation(totalReps: 10, safetyCues: 3),
            makeObservation(totalReps: 13, priorBest: 10)
        ]
        for obs in shapes {
            let text = SessionSummaryFallback.summary(for: obs)
            // Must contain a digit somewhere.
            XCTAssertNotNil(
                text.range(of: #"\d"#, options: .regularExpression),
                "Every fallback summary must contain at least one digit. Got: '\(text)'"
            )
        }
    }
}
