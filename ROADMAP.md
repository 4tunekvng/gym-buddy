# Gym Buddy — Roadmap

*How we get from the MVP to the full vision. Sequenced by dependency, not by date.*

---

## How to read this

- Each chapter is a milestone that is demo-able to users and friends, not an internal checkpoint.
- Chapters are ordered by dependency: each unlocks the next.
- No dates — dates create lies. Sequence is the contract.
- A chapter ships when it meets its demo criterion, not when a calendar says it does.
- Scope creep into an earlier chapter to make it "more complete" is the #1 failure mode. The MVP stays the MVP.

---

## Chapter 1 — Live Session Foundation (the MVP)

**Ships (see PRD.md for full spec):**
- iOS app on TestFlight
- Three exercises, fully coached: push-up, goblet squat, dumbbell row
- Live Session: camera-based rep counting, tempo-aware real-time voice cues, premium streaming TTS
- Conversational onboarding (5–7 min, feels like a first consultation)
- Coach memory across sessions (qualitative notes + session history)
- 4-week linear plan, morning readiness check-in, warm post-session summary
- Simple history view: per-exercise progression, session-by-session notes
- HealthKit read: heart rate overlay during live sessions

**Demo criterion (the north-star moment):**
One recorded 30-second clip where a user performs a set of push-ups, the bar of their rep tempo visibly slows on rep N, and the coach says *"one more — push"* at the exact right instant in a human-sounding voice. User grinds out the rep. Coach says *"that's the one you weren't going to do alone."* Zero misfires, voice feels real, timing feels human.

**Why first:**
Without this loop working end-to-end, nothing else matters. Everything else is commentary on this.

**Unlocks (the durable abstractions):**
- `CoachingEngine` (platform-pure rep/cue state machine)
- `PoseVision` (pluggable pose detector)
- `VoiceIO` (pluggable TTS/STT)
- `LLMClient` (reasoning layer with versioned prompts + evals)
- `Persistence` (local-first data store)
- `HealthKitBridge`, `DesignSystem`, `Telemetry`

---

## Chapter 2 — Lift library expansion

**Ships:**
- Add: dumbbell bench press, dumbbell overhead press, dumbbell lunge, pull-up (when pull-up bar detected), bodyweight dip, Romanian deadlift (dumbbell), dumbbell curl
- Core ML barbell detection model (trained on a small custom dataset) — unlocks bar-path cues for the next chapter
- Form score formula, stabilized and tuned per lift
- Per-exercise progression analytics

**Demo criterion:**
Twelve exercises, each with full cue catalogue, passing the pose-fixture test suite. User can train a full push/pull/legs split end-to-end.

**Depends on:** Chapter 1 `CoachingEngine` and `PoseVision` abstractions. Each new lift is a cue catalogue + fixtures, not new infra. If it's not, the Chapter 1 abstraction was wrong and must be fixed first.

---

## Chapter 3 — Barbell lifts (with care)

**Ships:**
- Barbell back squat, conventional deadlift, barbell bench, barbell overhead press
- Bar path tracking via Core ML barbell detection (Chapter 2 prerequisite)
- Enhanced safety cues: lumbar flexion detection on deadlift, bar-drift on squat, uneven-lockout on bench

**Demo criterion:**
User sets up barbell back squat, coach correctly identifies bar position, counts reps, catches a representative form deviation (e.g., knee cave) in real time.

**Depends on:** Chapter 2 barbell detection model + CoachingEngine's pose input being abstract enough to fuse "human pose + barbell position" as one joint signal.

---

## Chapter 4 — Apple Watch companion

**Ships:**
- Watch app with live HR overlay, haptic rep/tempo cues, between-set rest timer on wrist
- HR-guided intensity: coach scales today's load or volume off live HR and resting HR
- "Silent mode" — coach communicates through Watch haptics only, no voice (for gyms where headphones aren't practical or not wanted)

**Demo criterion:**
User trains a full session without looking at their phone — Watch handles all communication.

**Depends on:** `HealthKitBridge` extension into WatchKit, stable live session loop.

---

## Chapter 5 — In-ear screenless mode

**Ships:**
- Pose estimation from **AirPods Pro head IMU + Watch wrist IMU**, sensor-fused, for a subset of exercises (push-ups, squats, curls, overhead press — movements where head + wrist trajectories are high-signal)
- Phone can be in a pocket or bag — no camera needed for these lifts
- Opt-in, clearly marked as beta for the subset of exercises it covers

**Demo criterion:**
User trains push-ups and bodyweight squats without ever taking the phone out of their pocket. Coach counts reps and cues correctly from IMU fusion alone.

**Depends on:**
- `CoreMotion` wrapper covering both devices.
- `CoachingEngine` accepts an abstract "body state stream" as input, where pose skeleton is one implementation and IMU fusion is another. If Chapter 1's engine is truly pose-agnostic at its input boundary, this chapter is additive, not a rewrite. **This is the biggest test of whether Chapter 1's architecture was sound.**

This is the dream experience — the product we're really building toward. Everything before this is necessary infrastructure.

---

## Chapter 6 — Recovery & readiness depth

**Ships:**
- HRV-aware deload triggers ("your HRV is trending down — I'm cutting today's volume")
- Sleep-informed morning check-in ("you slept 5 hours — we're skipping the heavy set today")
- Perceived-effort voice journal (user freeform voice note, coach parses)
- Weekly recovery summary

**Depends on:** Mature HealthKit integration + 6-week minimum of session history to calibrate baselines.

---

## Chapter 7 — Nutrition vertical

**Ships:**
- Photo a meal → coach conversation about what you ate, how it fits the goal
- Goal-aligned macro guidance (strength gain, hypertrophy, body recomposition, maintenance)
- Hard safety floors: never below medically safe minima; never diagnose; always defer to physician for eating-disorder signals
- Hydration nudges tied to sweat-loss estimates

**Demo criterion:** User has a real conversation about a meal, gets useful feedback, never gets unsafe advice. Passes a red-team safety audit.

**Depends on:** Mature content-safety guardrails (nutrition is a higher-risk domain than form coaching). Do not ship this without a real safety review.

---

## Chapter 8 — Goal programs

**Ships:**
- User picks a concrete goal: first pull-up, 2× bodyweight squat, sub-25-min 5K, body recomposition
- Coach builds a multi-week arc toward the goal
- Visible progress toward goal each session
- Re-goaling flow when life changes

---

## Chapter 9 — Dual-camera 3D form review

**Ships:**
- iPhone + iPad paired for two-angle pose capture
- True 3D bar path on barbell lifts
- Post-workout technique review mode with annotated clips (generated locally, not uploaded)

**Depends on:** Chapter 2 barbell detection + PoseVision abstraction supporting multi-camera fusion.

---

## Chapter 10 — Android

**Ships:**
- Android client using the shared `CoachingEngine`
- MediaPipe for pose detection on Android
- Feature parity with Chapter 5 or later (depending on timing)

**Depends on:** `CoachingEngine` has remained pure of platform dependencies across Chapters 1–9. This is the reason the PRD is strict about this from day one. If we ever break the discipline, this chapter becomes a rewrite.

---

## Chapter 11 — Social, marketplace, ecosystem

**Ships:**
- Optional partner/friend mode: two users train together remotely, coach manages both
- Programs marketplace: vetted human coaches publish programs, AI delivers them (hybrid model — human authorship, AI coaching)
- Integrations: Whoop, Oura, Garmin (read-only)
- Cloud sync with end-to-end encryption (opt-in)
- Mac companion for post-workout review and long-form analytics

---

## Chapter 12+ — Open horizon

- Rehabilitation protocols (physician-authored, MSK-condition-aware programming)
- Sport-specific programs (climbing, Brazilian jiu-jitsu strength, running cross-training)
- Video highlight exports
- Team/coach view: actual human coaches use Gym Buddy to monitor their in-person clients remotely

---

## The architectural constraint that holds across every chapter

The `CoachingEngine` module must never import `UIKit`, `SwiftUI`, `Vision`, `HealthKit`, `AVFoundation`, or any vendor SDK. It is a pure-Swift domain layer that takes body-state streams + user state in, emits coaching intents out. If a later chapter ever requires this to break, **the Chapter 1 architecture was wrong and we fix that first.** Chapters 5 and 10 are the ones that will surface this — if the engine stays pure through them, we've built the right foundation.

If we lose this, we lose the product — because the compounding value is in the engine, and if the engine is coupled to iOS or to one vendor, the product ages out of relevance the moment the platform shifts.
