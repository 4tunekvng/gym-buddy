import Foundation

/// Detects when a set has ended based on body stillness and/or stance change.
///
/// End conditions (either triggers, after at least one rep has been observed):
///   - Stillness: hip displacement stays below `stillnessWindowDisplacement`
///     for at least `stillnessSeconds` of continuous samples.
///   - Stance change: hip has risen by more than `stanceChangeThreshold`
///     relative to the baseline observed during the set.
///
/// Implementation note: we track the *start of the current stillness streak*
/// rather than keeping a rolling buffer. A sample that drifts beyond the
/// displacement tolerance resets the streak. Once the streak has lasted
/// `stillnessSeconds` worth of sample time, we fire. This is robust to
/// floating-point pruning quirks and is cheaper than buffering.
public final class SetEndDetector {
    public let exerciseId: ExerciseID
    private let stillnessSeconds: TimeInterval
    private let stillnessWindowDisplacement: Double
    private let stanceChangeThreshold: Double

    private var baselineHipY: Double?
    private var repObservedAtLeastOnce = false

    // Stillness streak state:
    //   `streakStart` — timestamp of the first sample in the current stillness streak.
    //   `streakMin`/`streakMax` — the min/max hip y observed during the streak.
    //   The streak breaks (resets) when a new sample would push max-min beyond
    //   the displacement threshold.
    private var streakStart: TimeInterval?
    private var streakMin: Double = .infinity
    private var streakMax: Double = -.infinity

    public init(
        exerciseId: ExerciseID,
        stillnessSeconds: TimeInterval = 3.0,
        stillnessWindowDisplacement: Double = 0.01,
        stanceChangeThreshold: Double = 0.12
    ) {
        self.exerciseId = exerciseId
        self.stillnessSeconds = stillnessSeconds
        self.stillnessWindowDisplacement = stillnessWindowDisplacement
        self.stanceChangeThreshold = stanceChangeThreshold
    }

    public func noteRepCompleted() {
        repObservedAtLeastOnce = true
        // A new rep started some time ago; any stillness streak built during
        // the rep is meaningless. Reset.
        resetStillnessStreak()
    }

    public func reset() {
        baselineHipY = nil
        repObservedAtLeastOnce = false
        resetStillnessStreak()
    }

    /// Returns a reason if the set has ended at this sample.
    public func observe(_ sample: PoseSample) -> SetEndEvent.EndReason? {
        guard let hip = PoseGeometry.midpoint(
            sample[.leftHip] ?? missing,
            sample[.rightHip] ?? missing
        ) else { return nil }

        if baselineHipY == nil { baselineHipY = hip.y }
        updateStillnessStreak(hipY: hip.y, at: sample.timestamp)

        // Stillness: streak length covers stillnessSeconds.
        if repObservedAtLeastOnce, let start = streakStart,
           sample.timestamp - start >= stillnessSeconds {
            return .autoDetectedStill
        }

        // Stance change: hips have risen (smaller y in image coords) above the
        // baseline by more than the threshold, indicating the user stood up.
        if repObservedAtLeastOnce, let baseline = baselineHipY,
           baseline - hip.y >= stanceChangeThreshold {
            return .autoDetectedStanceChange
        }
        return nil
    }

    // MARK: - Streak bookkeeping

    private func updateStillnessStreak(hipY: Double, at t: TimeInterval) {
        if streakStart == nil {
            streakStart = t
            streakMin = hipY
            streakMax = hipY
            return
        }
        let newMin = Swift.min(streakMin, hipY)
        let newMax = Swift.max(streakMax, hipY)
        if newMax - newMin <= stillnessWindowDisplacement {
            streakMin = newMin
            streakMax = newMax
        } else {
            // Motion detected — restart the streak from the current sample.
            streakStart = t
            streakMin = hipY
            streakMax = hipY
        }
    }

    private func resetStillnessStreak() {
        streakStart = nil
        streakMin = .infinity
        streakMax = -.infinity
    }

    private let missing = Keypoint(x: 0, y: 0, confidence: 0)
}
