import XCTest
@testable import CoachingEngine

final class TempoTrackerTests: XCTestCase {

    private func rep(
        _ repNumber: Int,
        concentricSeconds: Double,
        eccentricSeconds: Double = 1.0,
        isPartial: Bool = false
    ) -> RepEvent {
        RepEvent(
            exerciseId: .pushUp,
            repNumber: repNumber,
            startedAt: 0,
            endedAt: 1,
            concentricDuration: concentricSeconds,
            eccentricDuration: eccentricSeconds,
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

    // MARK: - Eccentric baseline

    func testEccentricBaselineIsComputedFromReps2Through4() {
        var tracker = TempoTracker()
        _ = tracker.ingest(rep(1, concentricSeconds: 0.9, eccentricSeconds: 0.8))
        _ = tracker.ingest(rep(2, concentricSeconds: 1.0, eccentricSeconds: 1.0))
        _ = tracker.ingest(rep(3, concentricSeconds: 1.0, eccentricSeconds: 1.2))
        _ = tracker.ingest(rep(4, concentricSeconds: 1.2, eccentricSeconds: 1.0))
        XCTAssertEqual(tracker.eccentricBaselineMs, 1000, "Median of [1000, 1200, 1000] = 1000")
    }

    func testEccentricBaselineNotSetFromPartials() {
        var tracker = TempoTracker()
        _ = tracker.ingest(rep(2, concentricSeconds: 1.0, eccentricSeconds: 1.0, isPartial: true))
        _ = tracker.ingest(rep(3, concentricSeconds: 1.0, eccentricSeconds: 1.0, isPartial: true))
        _ = tracker.ingest(rep(4, concentricSeconds: 1.0, eccentricSeconds: 1.0, isPartial: true))
        XCTAssertNil(tracker.eccentricBaselineMs, "Partials must not seed the eccentric baseline")
    }

    // MARK: - Eccentric fatigue trigger

    func testEccentricFatigueTriggersAtRatioAtLeast140() {
        var tracker = TempoTracker()
        _ = tracker.ingest(rep(1, concentricSeconds: 0.9, eccentricSeconds: 0.9))
        _ = tracker.ingest(rep(2, concentricSeconds: 1.0, eccentricSeconds: 1.0))
        _ = tracker.ingest(rep(3, concentricSeconds: 1.0, eccentricSeconds: 1.0))
        _ = tracker.ingest(rep(4, concentricSeconds: 1.0, eccentricSeconds: 1.0))
        // Eccentric baseline = 1000 ms. Eccentric at 1400 ms (ratio 1.40) should fire.
        let trigger = tracker.ingest(rep(5, concentricSeconds: 1.1, eccentricSeconds: 1.40))
        if case .eccentricFatigue(let ratio, let at) = trigger {
            XCTAssertEqual(at, 5)
            XCTAssertGreaterThanOrEqual(ratio, 1.40)
        } else {
            XCTFail("Expected eccentricFatigue trigger, got \(String(describing: trigger))")
        }
    }

    func testEccentricFatigueDoesNotRefire() {
        var tracker = TempoTracker()
        for n in 1...4 {
            _ = tracker.ingest(rep(n, concentricSeconds: 1.0, eccentricSeconds: 1.0))
        }
        _ = tracker.ingest(rep(5, concentricSeconds: 1.1, eccentricSeconds: 1.5))
        let second = tracker.ingest(rep(6, concentricSeconds: 1.1, eccentricSeconds: 1.6))
        XCTAssertNil(second, "Eccentric fatigue must not re-fire after first trigger")
    }

    func testConcentricSlowdownTakesPriorityOverEccentricWhenBothFire() {
        var tracker = TempoTracker()
        for n in 1...4 {
            _ = tracker.ingest(rep(n, concentricSeconds: 1.0, eccentricSeconds: 1.0))
        }
        // Both concentric (ratio 1.4) and eccentric (ratio 1.5) exceed their thresholds.
        let trigger = tracker.ingest(rep(5, concentricSeconds: 1.40, eccentricSeconds: 1.50))
        if case .firstSlowdown = trigger {
            // correct — concentric path fires first
        } else {
            XCTFail("Concentric firstSlowdown should take priority, got \(String(describing: trigger))")
        }
        // Now eccentric fatigue fires on the next rep (eccentric still elevated).
        let next = tracker.ingest(rep(6, concentricSeconds: 1.1, eccentricSeconds: 1.50))
        if case .eccentricFatigue = next {
            // correct — eccentric fires on the subsequent rep
        } else {
            XCTFail("Expected eccentricFatigue on next rep, got \(String(describing: next))")
        }
    }

    func testEccentricFatigueDoesNotFireBelowThreshold() {
        var tracker = TempoTracker()
        for n in 1...4 {
            _ = tracker.ingest(rep(n, concentricSeconds: 1.0, eccentricSeconds: 1.0))
        }
        let trigger = tracker.ingest(rep(5, concentricSeconds: 1.1, eccentricSeconds: 1.39))
        XCTAssertNil(trigger, "Eccentric ratio below 1.40 must not fire eccentricFatigue")
    }
}
