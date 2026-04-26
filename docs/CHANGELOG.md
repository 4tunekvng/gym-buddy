# Changelog

Notes for the next developer working on this repo. Dates + whys, not every file touched — `git log` has those.

---

## 2026-04-20 (evening) — Defence-in-depth pass: test the things UI tests can't see, kill the silent bugs

Second pass on the same day, extreme-QA mindset. Everything passes at the view level, so now we hunt for issues that XCUITest can't catch on its own.

### Silent bugs found and fixed

- **LiveSessionView Cancel button wasn't rendering.** I put it in `.toolbar { ToolbarItem(placement: .topBarTrailing) { … } }`, but toolbar items need a `NavigationStack` ancestor to render. There's none — RootView doesn't wrap anything in a navigation container. So any user who changed their mind at the setup overlay had no way to back out. Replaced with an inline top-right button in a `VStack` at the top of the live session ZStack. Added `CancelAndMultiSessionUITest.testCancelFromSetupReturnsToTodayWithoutPersisting` so this can't silently break again.

- **`SessionSummaryFallback.qualitativeNote`: the personal-best note was unreachable.** Order was fatigue → safety → clean → PB. A set that crushes the prior best with no fatigue and no partial reps would hit the "Clean through the whole set." branch and never mention the PB. Reordered so safety → PB → fatigue → clean. Per OQ-009, the summary must reference something specific; PB delta is more specific than "clean", so it takes precedence.

- **`ContentSafetyFilter.detectsDiagnosis` only matched literal substrings.** `"sounds like a tear"` matches `"sounds like a tear"` exactly, but LLM drift typically adds a body part: `"sounds like a rotator cuff tear"`, `"sounds like a meniscus tear"`. The literal match missed every one of these. Expanded to a two-part check: (a) literal phrase list, then (b) "diagnostic leaders" (`sounds like a`, `looks like a`, `must be a`, `probably a`) followed within ~6 words by diagnostic nouns (`tear`, `strain`, `sprain`, `rupture`, `injury`). Covered by `PainAndSafetyFlowTests.testSafetySubstitutionProducesFallbackText`.

### Extractions that moved logic under test coverage

- **`PostSessionSummaryView.specificFallback` → `CoachingEngine.SessionSummaryFallback`.** The view-layer version was unreachable from Swift Package tests. Moved the entire fallback to the domain, gave it a proper priority model (lead fact → qualitative note → rest hint), and added 9 tests. Covers 0-rep sets, partial-rep sets, fatigue reps, safety cues, PB beats, and the generic-praise ban from OQ-009.

- **`TodayView.pickTodayPlanDay` → `CoachingEngine.PlanDayPicker`.** The old version pulled `Date()` and `Calendar.current` directly, which made the day-of-week logic untestable. Extracted to a pure function that takes a weekday index; the iOS caller converts `Date()` to Monday-first via a second helper. 6 tests: exact match, fallback, nil plan, no non-rest days, clamping out-of-range input, and the Calendar→Monday-first conversion.

### Accessibility

- **`RepCounterHUD`** — added `accessibilityLabel("5 reps")` with correct pluralization; `accessibilityValue("full rep" / "partial rep")` as the dynamic value; `accessibilityAddTraits(.updatesFrequently)` so VoiceOver doesn't spam every update; `minimumScaleFactor(0.5)` and `lineLimit(1)` so the 180pt digit still fits at AX sizes. Hid the "partial" capsule from VoiceOver since its meaning is already encoded in the accessibilityValue.
- **`DS.Font.displayLarge` / `.repCounter`** — now carry `.leading(.tight)` so multi-line layouts tighten instead of overflowing at larger Dynamic Type scales.

### Code quality

- **No more `try!` in non-test code.** The two uses in `AppComposition` (production + preview container opens) were replaced with `try?` + descriptive `fatalError` messages. Same crash-on-catastrophic-failure behaviour, but with a line the next developer can actually read.

### Tests added

- **`CoachingEngineTests.SessionSummaryFallbackTests`** (9 tests).
- **`CoachingEngineTests.PlanDayPickerTests`** (6 tests).
- **`CoachingEngineTests.CueDisplayTextExpectationsTests`** — exhaustive switch on every CueType so adding a new one forces a compile-time decision (no silent mapping to "Hold the form").
- **`IntegrationTests.PainAndSafetyFlowTests`** — pain-keyword STT → session end flow; LLM diagnostic drift → safety substitution → specific fallback text.
- **`GymBuddyAppUITests.CancelAndMultiSessionUITest`** — Cancel-from-setup returns to Today without persisting; two consecutive sessions both complete and appear in History.

### Test counts

- **157 unit tests** (was 139).
- **12 UI tests** (was 10).

### Still in the backlog

- Rotating the device during a live set — currently portrait-locked via Info.plist, but no explicit regression test.
- Snapshot tests per screen × dark/light × AX5 × RTL (tooling-heavy; deferred).
- Telemetry SQLite-backed store (MVP is in-memory).
- TTS audio assets (ADR-0002).
- Real Anthropic LLM wiring (MockLLMClient is still the default in `makeProduction`).

---

## 2026-04-20 — Live session + persistence loop closed; the hero flow actually runs in the Simulator

This is the pass that took the "stub" out of the hero flow. Before today, tapping a push-up on Today took you to a Live Session that stared back at you — the view used a placeholder detector, placeholder voice player, and an empty phrase cache. Post-session summary showed hardcoded copy. History was permanently empty. Settings changes evaporated.

After today, the full hero loop runs end-to-end in the iOS Simulator and is covered by XCUITest.

### Bugs fixed (load-bearing)

- **`FixturePoseDetector` start/subscribe race.** `start()` captured `self.continuation` by *value* in its task closure. When the consumer called `bodyStateStream()` later, it set `self.continuation` — but the running task had already snapshotted nil. Every pose sample was silently dropped. The detector now resolves the continuation at runtime through `self.continuation?.yield(...)` and supports both `start`-then-`subscribe` and `subscribe`-then-`start` orderings. Regression test: `IntegrationTests.SessionPipelineTests.testStartBeforeSubscribeStillDelivers`.

- **`SetEndDetector` stillness window never crossed the threshold.** The old implementation maintained a rolling buffer pruned to the most recent `stillnessSeconds`. The prune ran *before* the check, so the buffer span was always `<= stillnessSeconds` and the `>= stillnessSeconds` condition was one floating-point rounding away from ever firing. Rewrote as a simple "streak" model: track `streakStart`, `streakMin`, `streakMax`; break the streak when a new sample pushes max-min past the displacement tolerance. Fires when the streak has lasted long enough. Tested by `IntegrationTests.SessionPipelineTests.testFixtureDrivenSetProducesObservationAndRecord`.

- **`LiveSessionView` bottom bar overlapped the SetupOverlay's Start button** in the ZStack, and the Cancel button was laid on top. Taps aimed at Start hit Cancel, which navigated to Today — the user never saw the session actually run. Fix: the bottom action bar only renders once `viewModel.isSetupComplete`; pre-setup cancellation moved to a top-trailing toolbar item that doesn't overlap anything.

- **SetupOverlay started with all four checks failing**, which means the "Start set" button was disabled, which means the onConfirm action never ran, which means `completeSetupAndStart()` never flipped the checks to green. A classic chicken-and-egg. For MVP the checks start green (real framing detection is an M2 deliverable); the disabled guard remains for the future real-pose path.

- **`AppComposition` tried to use `VisionPoseDetector` in the iOS Simulator.** The Simulator has no camera, so `AVCaptureDevice.requestAccess(for: .video)` pops a permission dialog that never gets answered from within a test harness — the session blocks indefinitely. Fix: `#if targetEnvironment(simulator)` branch uses a synthetic 10-rep push-up `FixturePoseDetector` with a 3× realtime frame interval. On-device still uses Vision.

### New wiring (things that now work)

- **Session hand-off.** `AppRouter` carries a `lastSessionObservation`. `LiveSessionView.onFinish(observation)` calls `router.goToPostSessionSummary(with:)`, which stashes the observation for `PostSessionSummaryView` to read. `goToToday()` clears it. Consumers never look at each other directly.

- **Persistence loop.** `LiveSessionViewModel.completeLifecycle` builds a `WorkoutSessionRecord` from the `SessionObservation` and writes it via `composition.sessionRepo.record(_:)`. `HistoryView` reads from the same repo and renders the list. Verified by `HistoryPersistenceUITest.testCompletedSessionShowsInHistory`.

- **Post-session summary uses the real observation.** Stats rows (Reps / Tempo baseline / Fatigue began / Cues) come from `SessionObservation`. The warm paragraph comes from `LLMClient.complete` with `PromptRegistry.renderPostSetSummary`; safety substitutions fall back to `specificFallback(for:)` so we never ship generic praise (per OQ-009).

- **Settings tone picker persists.** `.onChange(of: tone)` writes the updated `UserProfile` back to `userProfileRepo`. `hasLoaded` flag prevents the initial `load()` from triggering a no-op save. Verified by `SettingsPersistsUITest.testTonePickerPersistsAcrossRelaunch`.

- **Onboarded state persists across app relaunch.** `RootView.task` checks `userProfileRepo.load()` on first appearance; if a profile exists, the router jumps directly to `.today` and the welcome/onboarding flow is skipped.

- **`Today` view shows prescribed sets × reps**, not just exercise names. Uses `PlannedExercise.sets` to render "3 × 10" / "AMRAP" / mixed-rep shorthand. Picks the plan day matching today's weekday first, falling back to the first non-rest day.

- **Phrase cache bootstraps at composition time** via `AppComposition.bootstrapPhraseCache()`, which registers one placeholder variant for every `PhraseID` in the manifest for every tone. The mock voice player logs them; once Tier-1 audio assets ship (ADR-0002) these placeholder names become the asset names.

### Tests added

- `IntegrationTests.SessionPipelineTests` — 3 tests covering fixture → orchestrator → observation → persistence, stream-based detection, and the start/subscribe ordering regression.
- `GymBuddyAppUITests.ChaosUITest` — 4 tests covering rapid taps, immediate End-set, rapid navigation loops, and app backgrounding mid-session.
- `GymBuddyAppUITests.HistoryPersistenceUITest` — closes the session-to-history loop end-to-end.
- `GymBuddyAppUITests.SettingsPersistsUITest` — verifies tone persists across terminate/relaunch.
- `GymBuddyAppUITests.UITestSupport` — shared helper that makes tests robust to carried-over SwiftData state (fresh install onboards, carryover skips to Today; post-condition is always "we're on Today").
- Screenshot tour expanded to include live-setup, live-midset, and post-session screens.

### Test counts

- **139 unit tests** (was 136) — all green.
- **10 UI tests** — all green.

### Known follow-ups (not in scope for this pass)

- Real pose-driven SetupOverlay checks (M2).
- Real ElevenLabs audio assets (ADR-0002).
- Real Anthropic LLM wiring (MockLLMClient is still the default in makeProduction).
- Accessibility sweep beyond basic identifiers: VoiceOver rotor order, Dynamic Type scales, reduced-motion variants.
- Snapshot tests per screen × dark/light × XS→AX5 × RTL.
- Telemetry store wired to a local SQLite file (currently in-memory only).
