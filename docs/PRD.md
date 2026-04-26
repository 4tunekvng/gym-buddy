# Gym Buddy MVP — Restatement (Chapter 1)

*My (Claude Code's) restatement of the PRD in my own words, so we can verify alignment before I touch feature code. If anything below contradicts `../PRD.md`, the source document wins and I've misunderstood; flag it and I'll fix.*

---

## The one-sentence product

Gym Buddy is an iOS app that watches you lift through your phone's camera, counts your reps, catches your form breakdowns, and pushes you through the last rep you wouldn't have hit alone — in a voice that sounds like a real coach, not a synthesizer.

## The one moment that ships or the MVP doesn't ship

A user does push-ups. The coach counts. Around rep 9 the user's tempo slows visibly — concentric phase >40% longer than earlier reps. At the bottom of that rep, the coach says *"one more — push"* timed to the start of the next concentric (not half a second late). User grinds it out. Coach says *"that's the one you weren't going to do alone."* Set auto-ends when user stands. Coach delivers a one-paragraph warm summary naming at least one specific thing observed.

Every scope decision in this MVP is measured against: does it serve that 30-second moment? If not, it gets cut.

## Scope (kept intentionally narrow)

**Three exercises, done perfectly**: push-up, goblet squat, dumbbell row. Not four. Not even "plus a bodyweight squat." Three.

**Hero flow**: pick today's workout → prop phone → setup overlay confirms framing → coach sees, counts, cues, pushes → auto-detected set end → warm summary → suggested next-set load → rest timer with between-set voice Q&A.

**Supporting flows that make it feel like a coach, not a tracker**:
- Conversational onboarding (5–7 min), voice-forward.
- 4-week linear-progression plan.
- Morning readiness check-in, short and warm, references prior session detail.
- Automatic workout logging when camera was used; manual entry path for off-camera sets.
- Per-session post-summary paragraph, spoken and shown.
- History view — per-exercise progression, session notes. No 1RM, no form-score charts, no velocity graphs.
- **The Relational Layer** (coach memory, tone preference, personal opening screen) — first-class.

**Explicit cuts**: Android, Watch, in-ear screenless mode, barbell, nutrition, social, adaptive re-planning, 1RM/velocity/form-score graphs, cloud sync, payments.

## The quality bar

"Would a dozen tech-savvy friends train with it for four weeks and come away convinced?" Not "passes a 1000-person QA gauntlet" — that's later. The real bar is *no embarrassing bugs, no unsafe advice, no jank that breaks the illusion of a real coach*, for four weeks across a dozen real users.

Smaller and flawless beats broader and shaky.

## The architectural discipline that makes Chapters 2–12 reachable

`CoachingEngine` is pure Swift. No `UIKit`, `SwiftUI`, `Vision`, `HealthKit`, `AVFoundation`, no network, no vendor SDKs. It takes body-state streams + user state in, emits coaching intents out. Every other module is an adapter around a protocol — swappable without touching the engine.

This is why later chapters (Android port, AirPods+Watch IMU-only mode, Vision→MediaPipe swap, Claude→OpenAI swap) don't become rewrites. The moment the engine depends on one of those vendors, the product has a short half-life.

## Voice strategy (two tiers, one principle)

**Principle**: no unpredictable latency in the hot loop. Not "no LLM ever."

- **Tier 1 — in-set phrases**. Rep counts 1–50, common motivational phrases (*"one more," "push," "drive," "last one," "hold the form"*), each with 5–8 variants. Pre-generated via premium TTS (ElevenLabs), cached on-device, chosen at runtime with a no-repeat window. Effectively zero latency. Offline-capable. Deterministic.
- **Tier 2 — contextual phrases**. Post-set summary, between-set conversation, morning check-in, post-session summary, onboarding. LLM-generated with streaming TTS. No latency budget problem because there's rest time.

## Latency budget

- In-set form/encouragement cue end-to-end (deviation visible → voice starts): **< 400 ms** on iPhone 13+.
- Rep count voiceover: **< 150 ms** after rep detected.
- Between-set conversation: **< 2.5 s** from end-of-user-speech to start-of-voice.

## Privacy promises that are load-bearing, not marketing

- **Pose frames never leave the device.** Ever.
- Only synthesized *text* of what the coach says goes to the TTS vendor. Never user audio, video, or pose data.
- HealthKit is read-only in MVP.
- Offline-first: the full live session loop (rep counting, cues, voice) works in airplane mode. LLM features degrade to deterministic canned paths when offline.

## Safety posture

Gym Buddy will never diagnose injury, recommend unsafe caloric restriction, shame the user, or push through sharp-pain signals. This is enforced at three layers: LLM system-prompt guardrails, a post-LLM content filter (deny-list + pattern matching), and a pre-written safe-response fallback library. Every refusal path is tested.

## What "done" looks like for the MVP

- TestFlight build ~10 friends can install.
- CoachingEngine ≥ 85% line coverage; app-wide ≥ 60%.
- North-star demo test green in CI.
- Every chaos scenario from PRD §10.7 passes.
- 3×10 manual real-lift smoke test on each exercise: no cue misfires.
- Zero compiler warnings, zero force unwraps, no untracked TODOs.
- README gets a clone-and-run-in-under-10-minutes section.

---

## Where I exercised judgment (resolved in ADRs)

Each of the seven open decisions in PRD §13 got an ADR in `decisions/`. The defaults the PRD suggests are the ones I chose unless numbers forced otherwise — I'd rather ship the PRD's implied default than invent a novel answer:

1. **Persistence** → SwiftData (ADR-0001). Modern Swift, first-party, and the entity set is simple enough that GRDB's power isn't needed in Chapter 1.
2. **TTS vendor + generation timing** → ElevenLabs, generated at build time into bundled audio assets (ADR-0002). Hardest latency constraint; bundled variants fully eliminate it.
3. **LLM vendor** → Anthropic Claude (ADR-0003). Best tone for the warm-but-demanding coach voice; strong safety posture.
4. **Pose detection** → Apple Vision (ADR-0004). Default per PRD; MediaPipe evaluated as fallback with documented methodology when per-exercise accuracy requires it.
5. **FSM library** → hand-rolled (ADR-0005). Domain is small; library dependency not worth it.
6. **Coach memory retrieval** → tag + recency, not vector search (ADR-0006). Defer vector until memory set is large enough to justify.
7. **Telemetry** → local-only event log in MVP (ADR-0007). No vendor until we know what we actually need to measure.

## Where I hit ambiguity (logged in OPEN_QUESTIONS)

See `OPEN_QUESTIONS.md`. The big ones:
- How aggressive should "fatigue detection" be? Tempo-slowdown threshold is tunable; I've proposed a starting ratio but need your sign-off.
- Does "the user can't trick us with weak reps to end a set" (PRD §4 job 4) mean we should refuse to count reps with incomplete ROM, or just not use incomplete ROM as the fatigue signal? I've proposed the latter.
- What does "the coach never sounds looped" mean quantitatively? I've set a no-repeat window of min(8, variant_count) most-recent variants — flagging for confirmation.

---

*End of restatement. If this matches, I'll proceed to feature code per `MILESTONES.md`.*
