# ADR-0004: Pose detection = Apple Vision (MediaPipe as documented fallback)

**Date:** 2026-04-19
**Status:** Accepted
**Context window:** PRD §7.7, §13 item 4

## Context

Two viable on-device pose engines: Apple's `VNDetectHumanBodyPoseRequest` (via Vision framework) and Google's MediaPipe Pose.

## Comparison (qualitative — numbers filled in during M2)

| Axis                         | Apple Vision                                    | MediaPipe                                |
|------------------------------|-------------------------------------------------|------------------------------------------|
| Frame rate (iPhone 13)       | ~30 fps @ 1080p                                 | ~30 fps @ 1080p (TFLite GPU delegate)    |
| Keypoints                    | 17 (COCO-like)                                  | 33 (BlazePose)                           |
| First-party?                 | Yes                                             | No                                       |
| Binary size cost             | 0                                               | ~8 MB model                              |
| Licensing                    | Apple system framework                          | Apache 2.0                               |
| Per-exercise accuracy        | TBD (benchmark in M2)                           | TBD (benchmark in M2)                    |

## Decision

**Apple Vision as default.** PRD's own default. First-party, zero binary cost, tight integration with AVCaptureSession, Apple's privacy posture aligns with our "pose never leaves the device" promise (Vision is literally on-device).

**MediaPipe kept as a documented fallback** for specific exercises if we measure per-exercise accuracy drops below the bar defined below. `PoseVision` exposes a `PoseDetector` protocol so the swap is additive — a new `PoseDetectorMediaPipe` adapter can be dropped in per-exercise without touching `CoachingEngine`.

## Accuracy bar (enforced in M2)

On our fixture set for each of the 3 MVP exercises:
- Rep-count agreement with ground truth: ≥ 98% over 100 fixture reps per exercise.
- Cue firing true-positive rate: ≥ 90%.
- Cue firing false-positive rate: ≤ 5%.

If Apple Vision misses any of these bars on any exercise, we benchmark MediaPipe on the same fixtures and write a follow-up ADR to swap that one exercise.

## Trade-offs

- **+** First-party, no dependency.
- **+** Integrates cleanly with AVCaptureSession and Core ML.
- **−** Fewer keypoints than MediaPipe. For our 3 MVP exercises, the 17-point set is enough (documented cues map to available joints).
- **−** Less community tuning for edge cases (poor lighting, oblique angles). Mitigated by the setup overlay enforcing good framing before a session can start.

## Revisit date

M2 exit. If accuracy numbers force a swap, the ADR follow-up lives in `0004a-pose-mediapipe-for-{exercise}.md`.
