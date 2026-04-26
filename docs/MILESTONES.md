# Gym Buddy — Milestones (Chapter 1)

*Each milestone is demo-able to you and to friends. Not an internal checkpoint. Each has explicit tests, demo criteria, and an exit bar.*

---

## M0 — Skeleton (week 1)

### Deliverables
- Root SwiftPM workspace with all 8 packages scaffolded.
- Empty iOS App target that boots to a welcome screen.
- SwiftLint + SwiftFormat configured; GitHub Actions CI running `swift build` and `swift test`.
- Design tokens: typography, color ramps (dark + light), spacing, elevation.
- Dependency-direction lint (custom CI step that greps forbidden imports per module).

### Tests
- CI: `swift build` green, `swift test` green (with empty tests), lint green.
- Unit: dependency-direction test asserts forbidden imports aren't present in each package.

### Demo
"Clone, run `swift test` and the iOS app in a simulator. Welcome screen. CI badge green."

### Exit bar
- CI green on an empty push.
- All 8 packages resolve and build.
- Welcome screen renders with DesignSystem tokens on iPhone 13 and iPhone 13 mini simulators in both dark and light mode.

---

## M1 — Offline coaching engine (weeks 2–3)

### Deliverables
- `CoachingEngine` fully implemented for all 3 MVP exercises:
  - `RepDetector` FSM (4 states) per exercise with joint-angle thresholds.
  - `SetEndDetector` (stillness + stance change + explicit command).
  - `TempoTracker` (baseline + per-rep concentric/eccentric duration).
  - `CueEngine` with full cue catalogue per exercise (see `PRD §5.2`).
  - `CoachingIntentEmitter` with priority model (safety > rep count > quality > optimization > encouragement).
  - `PlanGenerator` (4-week linear progression from onboarding inputs).
  - `CoachMemoryStore` (tag + recency retrieval).
  - `ReadinessScaler` (load ±10%, volume ± one set, optional deload).
  - `ContentSafetyFilter`.
- Pose fixtures: good rep + bad rep per cue type per exercise, JSON on disk.
- CLI harness that pipes a fixture through the engine and prints events.

### Tests
- ≥ 85% line coverage in `CoachingEngine`.
- Property-based invariants: no cue without observation, no rep event without tempo sample, set-end always follows a rep, cue priority never inverted.
- Pose-fixture tests: each cue has ≥ 1 positive fixture (should fire) and ≥ 1 negative fixture (should not fire).
- **The north-star demo test passes** against a synthetic push-up fixture (reps 1–7 normal, reps 8–13 progressively slowing): exactly 13 reps counted, `"one more"` fires on rep-13 concentric window (±200 ms), summary contains `"13"`.

### Demo
`swift run coaching-cli push-ups/fatigue-set-13reps.json` prints every rep, tempo delta, cue, intent, and final summary. Same for each of the 3 exercises.

### Exit bar
- All listed tests green.
- Coverage report in PR.
- Coaching CLI demo recorded on video.

---

## M2 — Live on-device (weeks 4–5)

### Deliverables
- `PoseVision` with Apple Vision integration behind the protocol.
- Camera capture pipeline in the iOS app (AVCaptureSession, front/rear switching).
- Setup overlay (angle guide, distance guide, lighting check, full-body-in-frame). Session cannot start until 4/4 green.
- On-screen rep counter HUD, large and non-distracting.
- On-screen text cue display.
- Pose visualization overlay (optional, toggle via settings).

### Tests
- `PoseVisionTests`: Vision adapter produces `BodyState` samples with the expected joint set; frame drops don't crash.
- UI test: Setup overlay blocks start until all 4 checks green (driven by mocked pose frames).
- Performance: ≥ 28 fps sustained pose inference on iPhone 13 (mocked benchmarks in CI, real on-device measurement required for acceptance).

### Demo
"Real push-up in the office, rep counter hits 10, at least one cue surfaces on-screen if you pike your hips."

### Exit bar
- Setup overlay is bulletproof across 3 common framing screwups.
- Rep count matches hand count across 10 reps each of 3 exercises, 3 trials.

---

## M3 — Voice coach (week 6)

### Deliverables
- `VoiceIO` with:
  - ElevenLabs TTS client + pre-generated phrase cache.
  - Phrase variants for rep counts 1–50 and all standard cue phrases, each 5–8 variants.
  - No-repeat window (min(8, variant_count) of most-recent variants).
  - Audio session handling (`.playAndRecord` + `.mixWithOthers` + `.duckOthers`).
  - STT (Apple Speech framework, on-device where available).
  - VAD (Speech framework + energy-threshold fallback).
- `LLMClient` with Claude integration, versioned prompts, safety filter.
- Between-set conversation working end-to-end.
- Warm post-set summary generation.

### Tests
- `VoiceIOTests`: cache loads all variants; no-repeat window works; audio session transitions correct through call/Siri/headphone events.
- `LLMClientTests`: evals for post-set summary (must reference specific observations, no generic praise), between-set Q&A (20 representative prompts), content safety (must refuse/redirect on unsafe prompts).
- Integration: in-set rep count voiceover starts within 150 ms of rep detection (measured against mocked audio clock).
- North-star demo test, now end-to-end: pose stream → engine → voice → captured audio transcribed → assertions on content and timing.

### Demo
"Live push-up set with AirPods in. Coach counts. Form cue fires when you pike. Slow down — 'one more, push' fires. Ask between sets 'should I add weight?' Coach gives a reasonable answer grounded in the set you just did."

### Exit bar
- In-set cue end-to-end latency measured at < 400 ms on iPhone 13 under realistic load.
- No cue misfires over 3×10 real reps of each exercise.
- North-star demo test passes in CI.

---

## M4 — Onboarding, plan, relational layer (week 7)

### Deliverables
- Conversational onboarding (voice-forward if mic tapped, typed otherwise). 5–7 minutes. Captures goals, injuries, equipment, experience, tone preference.
- 4-week plan generated at onboarding exit.
- Morning readiness check-in with local notification.
- `CoachMemoryNote` creation pipeline (LLM extracts from onboarding, between-set chat, post-session reflection).
- Warm post-session summary.
- History view: per-exercise progression, session-by-session timeline.
- HealthKit read integration (HRV + sleep for morning readiness).
- Personal opening screen ("Welcome back, Fortune. Ready for today's upper workout?").

### Tests
- Onboarding UI test: fresh install → answers captured → plan generated.
- Persistence: plan + session + memory notes round-trip cleanly through schema.
- LLM evals: memory notes are extracted from the right inputs; not hallucinated; properly tagged.
- Integration: on session 5, morning check-in references a specific memory from session 2–4.

### Demo
"Fresh install. Onboard. Today plan shows. Do a live session. Warm summary. Close the app. Next morning: readiness check-in says 'how's that left knee today?' because you mentioned it yesterday."

### Exit bar
- End-to-end cold-install-to-first-real-session flow works without stumbles.
- Memory retrieval surfaces relevant notes ≥ 80% of the time in manual testing.

---

## M5 — Polish, chaos, TestFlight (week 8)

### Deliverables
- Snapshot tests for every screen: light/dark, Dynamic Type XS → AX5, RTL pseudo-locale.
- UI tests for the 3 highest-risk flows: onboarding end-to-end, Live Session happy path, today → Live Session entry.
- Chaos scenarios all pass: incoming call, Siri mid-rep, headphone connect/disconnect, network drop, low-power mode, HealthKit denied, camera revoked mid-session, mic revoked mid-session, background, kill-and-relaunch.
- Performance passes: ≤ 25% battery / 60 min live session on iPhone 13 mini; no thermal throttling within 30 min at 22 °C.
- Accessibility checklist green (VoiceOver labels everywhere, reduced motion, contrast WCAG AA).
- README front-door polish: clone-and-run under 10 minutes.
- TestFlight build shipped to test group.

### Tests
- All suites green.
- Coverage report: CoachingEngine ≥ 85%, app-wide ≥ 60%.
- Every chaos scenario has a test that asserts either correct resume or user-visible explanation.

### Demo
"I hand my phone to a test-group user. They install TestFlight, onboard, do a live session, get a warm summary, and come back tomorrow. I am not in the room."

### Exit bar (this is the MVP Definition of Done)
- TestFlight build installable by me and my test group.
- All chaos scenarios pass.
- 3×10 real-lift smoke test on each exercise — no cue misfires.
- North-star demo test green in CI and reproducible in a live demo.
- Zero compiler warnings, zero force unwraps, no untracked TODOs.

---

## Cross-milestone discipline

- **Small PRs**, one concern each, with tests and a changelog line. Never let `main` go red.
- **No scope pulled forward from Chapter 2+.** If a fourth exercise is tempting, write the ADR first. Default answer: no.
- **No dependency added without an ADR.** Default posture: no third-party outside Apple frameworks, one LLM SDK, one TTS SDK.
- **If a milestone is in trouble, scope moves; quality bar does not.** If M3 slips because the cue catalogue isn't tight, we slip M3 — we do not ship with cue misfires and patch later.
