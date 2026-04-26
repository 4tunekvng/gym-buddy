import XCTest
@testable import CoachingEngine

final class TempoTrackerTests: XCTestCase {

    private func rep(_ repNumber: Int, concentricSeconds: Double, isPartial: Bool = false) -> RepEvent {
        RepEvent(
            exerciseId: .pushUp,
            repNumber: repNumber,
            startedAt: 0,
            endedAt: 1,
            concentricDuration: concentricSeconds,
            eccentricDuration: 1,
            rangeOfMotionScore: isPartial ? 0.5 : 0.95,
            isPartial: isPartial
        )
    }

    func testBaselineIsComputedFromReps2Through4() {
        var tracker = TempoTracker()
        _ = tracker.ingest(rep(1, concentricSeconds: 0.9))    // rep 1 excluded
        _ = tracker.ingest(rep(2, concentricSeconds: 1.0))
        _ = tracker.ingest(rep(3, concentricSeconds: 1.0))
        _ = tracker.ingest(rep(4, concentricSeconds: 1.2))
        XCTAssertEqual(tracker.baselineMs, 1000)
    }

    func testFirstSlowdownTriggersAtRatioAtLeast135() {
        var tracker = TempoTracker()
        _ = tracker.ingest(rep(1, concentricSeconds: 0.9))
        _ = tracker.ingest(rep(2, concentricSeconds: 1.0))
        _ = tracker.ingest(rep(3, concentricSeconds: 1.0))
        _ = tracker.ingest(rep(4, concentricSeconds: 1.0))
        // Baseline = 1000 ms. A rep at 1350 ms = ratio 1.35 should fire.
        let trigger = tracker.ingest(rep(5, concentricSeconds: 1.35))
        if case .firstSlowdown(let ratio, let at) = trigger {
            XCTAssertEqual(at, 5)
            XCTAssertGreaterThanOrEqual(ratio, 1.35)
        } else {
            XCTFail("Expected firstSlowdown trigger, got \(String(describing: trigger))")
        }
    }

    func testFirstSlowdownDoesNotRefire() {
        var tracker = TempoTracker()
        for (n, s) in [(1, 0.9), (2, 1.0), (3, 1.0), (4, 1.0)] {
            _ = tracker.ingest(rep(n, concentricSeconds: s))
        }
        _ = tracker.ingest(rep(5, concentricSeconds: 1.4))  // first
        let second = tracker.ingest(rep(6, concentricSeconds: 1.4))  // should NOT be another firstSlowdown
        XCTAssertNil(second, "Second call at ratio ~1.4 must not re-trigger first slowdown")
    }

    func testSecondSlowdownTriggersOnlyAfterFirstAndAtHigherRatio() {
        var tracker = TempoTracker()
        for (n, s) in [(1, 0.9), (2, 1.0), (3, 1.0), (4, 1.0)] {
            _ = tracker.ingest(rep(n, concentricSeconds: s))
        }
        _ = tracker.ingest(rep(5, concentricSeconds: 1.4))    // first
        let second = tracker.ingest(rep(6, concentricSeconds: 1.6))  // 1.6 ratio → second
        if case .secondSlowdown(_, let at) = second {
            XCTAssertEqual(at, 6)
        } else {
            XCTFail("Expected secondSlowdown, got \(String(describing: second))")
        }
    }

    func testPartialRepsAreExcludedFromBaseline() {
        var tracker = TempoTracker()
        _ = tracker.ingest(rep(2, concentricSeconds: 1.0, isPartial: true))
        _ = tracker.ingest(rep(3, concentricSeconds: 1.0, isPartial: true))
        _ = tracker.ingest(rep(4, concentricSeconds: 1.0, isPartial: true))
        XCTAssertNil(tracker.baselineMs, "Partials should not be used to establish baseline")
    }

    func testPartialRepsDoNotTriggerFatigue() {
        var tracker = TempoTracker()
        for (n, s) in [(1, 0.9), (2, 1.0), (3, 1.0), (4, 1.0)] {
            _ = tracker.ingest(rep(n, concentricSeconds: s))
        }
        let trigger = tracker.ingest(rep(5, concentricSeconds: 2.0, isPartial: true))
        XCTAssertNil(trigger, "Partials must not produce fatigue triggers")
    }
}
