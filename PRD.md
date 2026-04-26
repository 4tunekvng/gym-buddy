# Gym Buddy — MVP Product Requirements & Claude Code Build Contract

**Chapter 1 of the arc described in `VISION.md` and `ROADMAP.md`. Read those first.**

MVP v0.1 · iOS · Target: TestFlight build in 6–8 weeks of focused work

---

## 0. How Claude Code should use this document

You (Claude Code) are being asked to build the MVP for an iOS app called **Gym Buddy**. This document is both the product spec and your build contract. Read `VISION.md`, `ROADMAP.md`, and this PRD end-to-end before writing a single line of code.

**The framing that matters most:** this MVP is **Chapter 1** of a longer arc. Every architectural decision must preserve optionality for Chapters 2–12 (see `ROADMAP.md`). You are not being asked to build the full vision — you are being asked to build the foundation that makes the full vision reachable without rewrites.

Where I've made a decision, stick to it unless you can articulate a clearly better alternative in a new ADR (Architectural Decision Record) for me to approve first. Where I've left a decision open, exercise senior-engineer judgment and write a short ADR into `docs/decisions/` before implementing.

**Quality bar:** "Would a group of skeptical, tech-savvy friends try this for a month and come away convinced?" Not "withstands 1000 QA testers on day one" — that's aspirational and not a real target for an MVP. The real target is: a dozen real users train with it for four weeks without hitting embarrassing bugs, unsafe advice, or jank that breaks the illusion of a real coach. A smaller, flawless MVP beats a broader shaky one every time.

**Before writing any feature code, produce and commit:**

- `docs/PRD.md` — your own restatement of this spec in your own words, so I can verify we're aligned.
- `docs/ARCHITECTURE.md` — a C4-style module diagram plus the package boundaries you'll enforce.
- `docs/decisions/` — one ADR per open decision you resolve (numbered, dated, trade-offs considered).
- `docs/MILESTONES.md` — the demo-able milestones you'll deliver with tests and demo criteria per milestone.
- `docs/OPEN_QUESTIONS.md` — running list of ambiguities you hit, with your proposed resolution and a request for my sign-off.

Do not begin feature work until those are committed and I've reviewed them.

---

## 1. Product vision (one paragraph summary — see VISION.md for full)

Gym Buddy is an iPhone app that replaces — and ultimately surpasses — the experience of working with an elite personal trainer. It watches you lift through your phone's camera, understands what your body is doing, and coaches you through each set in real time with a voice that sounds human, warm, 
and demanding when earned. It knows your goals, your schedule, your history, your injuries, and today's readiness. Between sessions it plans, adapts, and checks in. Every workout compounds into a deeper model of the athlete than any human coach could maintain at this resolution.

---

## 2. The North-Star Demo Moment (the hero)

Every architectural decision in this MVP answers one question: **does this serve the north-star demo moment?**

### The moment, defined concretely

> A user performs a set of push-ups, phone propped on the floor in front of them. The coach counts reps in a human-sounding voice (ElevenLabs or equivalent, not `AVSpeechSynthesizer`). On rep N (around rep 8–12 for an intermediate user), the user's rep tempo visibly slows — the concentric phase takes 40%+ longer than previous reps. At the bottom of that rep, the coach says *"one more — push"* — timed precisely to the start of the next concentric, not a half-second after. The user grinds out the rep. The coach says *"that's the one you weren't going to do alone."* The set auto-ends when the user stands up. The coach says *"solid 13. That last one was everything. Rest 90 seconds, then we go again."*

### Why this moment

- It is **visceral**. A friend watching this happen for someone else feels the punch immediately.
- It is **impossible to fake** — tempo detection, timing, and voice quality all have to actually work for the moment to land.
- It is the **densest expression** of what makes Gym Buddy different from every existing fitness app: form tracking apps don't push, push-based apps don't see, and none of them have a voice that sounds real.

### The implication

If any feature in this MVP conflicts with nailing this 30-second moment, the feature loses. This moment ships perfect or the MVP does not ship.

It must be reproducible in a recorded automated test: a deterministic pose-stream fixture piped through the CoachingEngine, with captured audio transcribed and asserted against expected phrasing and timing windows. Do not hardcode phrasing ofcourse. Assertion is more what is expected to be said in terms of meaning
and if something was said at all, not the exact string. 

---

## 3. MVP scope

### 3.1 Hero flow — Live Session

The user opens the app, selects today's workout, props the phone up, and starts a set. Gym Buddy sees them via the front or rear camera, tracks body pose on-device, counts reps audibly and on-screen, calls out at most one form cue per rep when warranted, 
and escalates encouragement as the user's rep tempo slows toward failure. When the set ends (auto-detected), Gym Buddy summarizes it in one sentence, suggests the load for the next set, and runs a rest timer with optional conversational check-ins.

### 3.2 Supporting flows

- **Conversational onboarding** (5–7 min): voice-assisted if user taps the mic, typed otherwise. Captures goals, injuries, equipment, experience, coaching-tone preference.
- **4-week plan** generated at end of onboarding. Simple linear progression — no adaptive re-planning algorithm in MVP.
- **Morning readiness check-in**: optional, under 30 seconds, warm-toned, references something specific from past data ("how's that left knee feeling today?").
- **Workout logging**: automatic when camera was on, manual entry otherwise.
- **Per-session warm summary**: one paragraph, references specific observations from the session, celebrates wins.
- **History view**: per-exercise progression (sets × reps × load), session notes, session-by-session timeline. No 1RM estimation, no form-score charts, no velocity metrics. Keep it simple.
- **The Relational Layer** (§6) — the thing that makes this feel like a coach, not an app.

### 3.3 Exercises in scope — exactly 3, nailed

1. **Push-up** (horizontal push, bodyweight)
2. **Goblet squat** (lower-body squat pattern, single dumbbell or kettlebell)
3. **Dumbbell row** (horizontal pull, single-arm bent-over)

Rationale:
- Covers the three primary movement patterns (push, pull, squat).
- No barbell → no bar-detection ML model needed → pose-only is sufficient.
- Minimal equipment (two dumbbells total).
- All three have well-studied form cues grounded in biomechanics literature.
- All three work in a home or gym setting with a phone propped at 6–10 feet.

Adding a fourth exercise requires an ADR with a clear argument that Chapter 2 should move up. The default answer is no.

### 3.4 Non-goals for the MVP — explicit cuts

- Android (domain layer must be portable, but we ship iOS only)
- Apple Watch app
- In-ear / screenless mode (Chapter 5)
- Barbell lifts (Chapter 3)
- Nutrition (Chapter 7)
- Adaptive re-planning algorithms — use a simple linear progression
- 1RM estimation, velocity-based training metrics, form score charts
- Social, sharing, feeds — private by default, no sharing in MVP
- Video replay, highlights, exports
- Trainer marketplace or community features
- Payments or paywall
- Cloud sync across devices — local-only; an export/import flow is v2

---

## 4. Users & jobs-to-be-done

### Primary persona

**Intermediate lifter who wants a trainer but can't afford or tolerate one.** Lifts 3–5× a week, has tried Strong / Hevy / Fitbod, knows the basics but loses form under fatigue and doesn't push hard alone. Wants a partner that notices, pushes, adapts.

### Secondary persona

**Non-technical friend who goes to the gym inconsistently.** Less interested in metrics, more interested in feeling supported and knowing what to do today. MVP must feel warm and personal to this user — the Relational Layer (§6) is non-negotiable for them.

### Tertiary — must not alienate

**True beginner** who needs form built from scratch. MVP must not crash, condescend, or mislead a beginner, but polish is optimized for the intermediate.

### The five jobs

1. **Know me by the end of onboarding** — goals, injuries, schedule, equipment, experience, how I like to be coached.
2. **Give me today's workout** with the right volume and substitutions for my injuries.
3. **Watch me during a set** and tell me something I couldn't have known alone.
4. **Push me to one honest rep more** than I would have done alone. We need to make sure we are able to make sure the user can't trick us here by artificially doing a weak rep when they still have more in them. 
5. **Remember every session** and reference it naturally in future sessions. A coach that treats every session as its first is not a coach.

---

## 5. Hero feature deep-dive — Live Session

### 5.1 End-to-end experience

1. Tap **Start Workout** → today's plan summary (e.g., "Upper — Push-up 3×AMRAP, DB Row 3×10, Goblet Squat 3×8").
2. Tap the first exercise → camera view opens with a **Setup overlay**: angle guide, distance guide, lighting check, full-body-in-frame check. The session cannot start until all four are green.
3. Coach confirms: *"I can see you clearly. When you're ready, start."*
4. User begins repping. Coach:
   - Counts reps audibly ("one … two … three …") and on-screen (large, dim, non-distracting, always visible without tapping).
   - Tracks joint angles, range of motion, and rep tempo via on-device pose estimation.
   - Surfaces **at most one** form cue per rep, prioritized: *safety > quality > optimization*.
   - Increases encouragement density as rep tempo slows — matching coach voice intensity to athlete exertion.
   - Auto-detects end of set (≥ 3 s still + athlete stance change, or explicit tap/voice command).
5. After the set: one plain-English summary in a warm tone (*"solid six. Your depth was clean; left knee caved slightly on rep 5 — reset the stance before the next set."*), set logged, rest timer starts.
6. Between sets: the user can ask things ("should I add weight?") and get a response grounded in today's performance + their stated goal + their history. Response time under 2.5s from end-of-speech to start-of-voice.

### 5.2 Form cue catalogue — MUST be exhaustive per lift

Each cue must be grounded in an observable pose-estimation signal with a tunable threshold, and documented with the S&C-literature reference that justifies it. The full catalogue lives in `CoachingEngine/Docs/Cues/` with one markdown file per exercise. At minimum:

- **Push-up:** hip sag (shoulder-hip-ankle line deviation), hip pike, elbow flare past shoulder plane, incomplete ROM at bottom (elbow angle threshold), incomplete lockout at top, head position (neck extension/flexion).
- **Goblet squat:** depth below parallel (hip crease below knee), knee valgus (left/right independently, via knee-to-ankle-line deviation), forward torso lean past threshold, heel lift (inferred from ankle dorsiflexion change), dumbbell drift from sternum.
- **Dumbbell row:** lumbar extension (flat back) vs flexion, elbow path (driving back vs flaring out), torso stability (hip sway on each rep), full ROM (elbow angle at top), tempo (explosive concentric, controlled eccentric).

Every cue ships with at least one **positive** pose fixture (cue should fire) and one **negative** fixture (cue should not fire) in the automated test suite.

### 5.3 Voice experience

- **Persona:** warm, technically fluent, honest, demanding when earned, never condescending, never sycophantic. No pet names, no gym-bro language unless the user explicitly selects an "intense" tone.
- **Tempo awareness:** silent under load on the concentric phase; speaks on the eccentric or at lockout. Never talks over the hard part of a rep.
- **Volume:** ducks the user's music via `AVAudioSession` mixing; does not interrupt incoming phone calls.
- **Density:** increases as rep tempo slows (athlete fatiguing). Decreases on clean, fast reps.
- **Tone preference:** selected in onboarding — *quiet / standard / intense*. Same content, different delivery. Implemented via different voice prompts + different SSML prosody hints.

**Voice examples (illustrative, not prescriptive):**

- Standard tone, clean rep 3 of 10: *"three."*
- Standard tone, slowing rep 8 of 10: *"eight — good. push through."*
- Standard tone, grinding rep 10 of 10: *"one more — drive — YES. That's the set."*
- Intense tone, same grinding rep: *"UP — push through — LAST ONE — yes."*
- Quiet tone, same grinding rep: *"you've got one more. push."*

**Two-tier voice strategy:**

- **Tier 1 — in-set phrases** (rep counts, common motivational cues like *"one more," "push," "drive," "last one"*): pre-generated via TTS with **multiple variants per phrase** (5–8 variants each), cached on-device, selected at runtime with a no-repeat window so the coach doesn't sound looped. Instant, offline, deterministic.
- **Tier 2 — contextual phrases** (post-set summary, between-set conversation, morning check-in, post-session summary, onboarding): LLM-generated with streaming TTS. No latency constraint — there's rest time to work with. This is where personalization lives (references to today's session, past injuries, goals, memory).

The real rule is **"no unpredictable latency in the hot loop"**, not *"no LLM ever."* Tier 1 keeps in-set timing tight; Tier 2 keeps the coach feeling personal. Variants prevent Tier 1 from ever feeling like a loop.

### 5.4 Latency targets

- **In-set form/encouragement cue** (from moment a pose deviation is visible to moment coach voice starts speaking): **< 400 ms end-to-end** on an iPhone 13 or newer.
- **Between-set conversation** (from end of user speech to start of coach voice): **< 2.5 s**.
- **Rep count voiceover**: spoken within 150 ms of the rep being detected.

Achieve the in-set target via:
- **Pre-cached TTS library with variants** (rep counts 1–50, plus ~8–10 common cue phrases each with 5–8 variations). Generated once via TTS, cached on-device. Runtime selection uses a no-repeat window. Effectively zero latency, works offline.
- **Streaming TTS** (ElevenLabs or equivalent) used between sets, for post-set summaries, and for the morning check-in — where LLM generation + TTS streaming comfortably fits the time available.

If you cannot hit < 400 ms, file an ADR explaining why and what the fallback is (on-screen cue only, or cue delayed to between-rep).

---

## 6. The Relational Layer (first-class feature, not a polish pass)

This is what makes a minimal-scope MVP feel *complete* to both tech-savvy and casual users. It is not optional.

### 6.1 Coach memory

Beyond the structured workout log, the coach maintains a separate **qualitative memory store** — things the user said, injury mentions, stated preferences, patterns observed. Examples:

- *"left knee clicks on deep squats — mentioned session 4 and 7"*
- *"hates tempo work, loves AMRAP sets"*
- *"lifts at 7pm on weekdays, weekends flexible"*
- *"mentioned work was stressful on Tuesday"*

Implementation: a `CoachMemoryNote` entity separate from workout data, tagged by type (injury, preference, mood, context), created by the LLM during onboarding / between-set convos / post-session summaries. Retrieved via a simple tag-filter + recency ranking — no vector DB needed for MVP (that's an ADR-worthy choice if you disagree).

These notes are surfaced in coach prompts to make interactions feel continuous. Example: on session 5, morning check-in says *"morning. how's that left knee — still clicking on deep squats?"* rather than a generic greeting.

### 6.2 Morning readiness check-in

Delivered via local notification at user's preferred time (set in onboarding). User can dismiss or open.

If opened: < 30-second flow. Voice-forward if user taps the mic, typed otherwise. Asks one or two things (soreness, energy, sleep), references HealthKit HRV/sleep if available and permission granted, surfaces something from memory ("how's that left knee?"). Outputs: today's plan, unchanged or auto-scaled (load ±10%, volume ± one set, intensity de-load option).

If never opened, today's plan is the un-adjusted plan.

### 6.3 Warm post-session summary

One paragraph in the coach voice, shown on-screen and spoken aloud if AirPods still connected. References **specific** things from the session:

- *"Solid session. You hit 11 on your last push-up set — that's two more than last week. Your form held all the way through, even that last grinding rep. Your left knee was quiet on goblet squats today, which is a good sign. Rest up; I'll see you Thursday."*

Generic encouragement ("good job today!") is explicitly forbidden. If the summary cannot reference something specific, something went wrong in observation and we log it rather than shipping a generic line.

### 6.4 Coaching-tone preference

User selects in onboarding: *quiet / standard / intense*. Changeable in settings. Affects voice prompt selection and LLM system prompt — never the content of the coaching itself, only its delivery.

### 6.5 Opening the app

On app open, the first screen says something personal, not a dashboard. Example: *"Welcome back, Fortune. Ready for today's upper workout? We're going heavier on rows than last week."* If it's a rest day: *"Rest day. I'll see you tomorrow. If you want to move anyway, I can put together something easy."*

---

## 7. Technical architecture

### 7.1 Platform

iOS 17+, Swift 5.10+, SwiftUI first, UIKit only where SwiftUI is weak (camera preview, specific text interactions). Xcode 15+.

### 7.2 Module structure (enforced via local SwiftPM packages)

| Module | Purpose | Allowed dependencies |
|---|---|---|
| `GymBuddyApp` | App target, composition root only. No business logic. | All packages below |
| `CoachingEngine` | **Domain.** Rep/set state machine, cue engine, plan generation, memory retrieval logic. Pure Swift. | Swift stdlib, Foundation only |
| `PoseVision` | Apple Vision / Core ML wrapper. Pluggable via protocol. | Vision, CoreML, AVFoundation |
| `VoiceIO` | TTS + STT + VAD. Pluggable. Includes the TTS cache. | AVFoundation, Speech, vendor SDK (ElevenLabs/OpenAI SDK) |
| `LLMClient` | LLM abstraction + versioned prompts + eval harness. | URLSession, vendor SDK |
| `Persistence` | Local store + migrations. Workout data + memory notes. | SwiftData or GRDB (ADR) |
| `HealthKitBridge` | Read-only HealthKit. | HealthKit |
| `DesignSystem` | Tokens, components, typography. | SwiftUI only |
| `Telemetry` | Privacy-preserving local event log. No network in MVP. | None |

### 7.3 The CoachingEngine contract (load-bearing)

`CoachingEngine` is **sacrosanct**. It must not import `UIKit`, `SwiftUI`, `Vision`, `HealthKit`, `AVFoundation`, networking, or any vendor SDK. It takes pose frames + user state + session context in, and emits *coaching intents* out (cue events, rep events, set-end events, between-set responses when LLM is asked to reason).

This is how we guarantee the long-term durability of the codebase:
- We can swap Apple Vision for MediaPipe without touching the engine.
- We can swap Claude for another LLM without touching the engine.
- We can port to Android (Chapter 10) without rewriting the engine.
- We can add IMU fusion (Chapter 5) by adding a new input adapter, not by rewriting the engine.
- We can replay the engine in CI against synthetic pose streams, which is how we build the chaos test suite cheaply.

**If you ever feel tempted to import a vendor SDK into `CoachingEngine`, stop and write an ADR.** The default answer is no.

### 7.4 Concurrency

Swift Concurrency (`async`/`await`, `AsyncSequence`). No Combine in new code. No GCD except at thin platform seams, always wrapped.

### 7.5 Dependency injection

Protocol-based, constructor-injected. No service locator. No singletons in domain code.

### 7.6 LLM usage boundaries

**LLM is used for:** onboarding synthesis, plan generation, between-set conversation, post-set summary, morning readiness interpretation, coach memory note extraction.

**LLM is NOT used for:** rep counting, cue firing, set-end detection. These are deterministic state machines inside `CoachingEngine`.

**In-set voice phrases** come from the pre-cached TTS library with variants (see §5.3). The guiding principle is *"no unpredictable latency in the hot loop"* — not a blanket ban on LLMs. Contextual, personal phrases live in Tier 2 (between-set, summary, check-in), which is where they matter most anyway.

Prompts are versioned in `LLMClient/Prompts/` with eval fixtures in `Tests/LLMClientTests/Evals/`. Every prompt change runs the full eval suite in CI. Every LLM call goes through a content-safety post-filter (§10.7).

### 7.7 Pose detection

**Default: Apple Vision's `VNDetectHumanBodyPoseRequest`** for latency, privacy, and frame-rate consistency.

Evaluate **MediaPipe** as a fallback only if per-exercise accuracy on the 3 MVP exercises falls below thresholds defined in `docs/decisions/pose-vendor.md`. Document the benchmark methodology and numbers in that ADR.

Frames are processed on-device only. **They must never leave the device. This is a load-bearing promise of the product.**

### 7.8 Voice stack (explicit choices)

- **TTS:** ElevenLabs streaming API (or OpenAI TTS if ADR chooses otherwise). `AVSpeechSynthesizer` is **not acceptable** for the MVP's hero demo — the voice quality is a core part of the product experience, not a polish-phase upgrade.
- **TTS cache:** pre-generate audio for the fixed phrase library (rep counts 1–50, all standard cues, all encouragement phrases per tone preference). Ship these as bundled audio assets. This eliminates in-set TTS latency.
- **STT:** Apple Speech framework, on-device where available.
- **VAD:** Apple Speech framework + simple energy-threshold fallback for environments where ML VAD is flaky.
- **Audio session:** category `.playAndRecord`, options `[.mixWithOthers, .duckOthers]` so the user's music ducks but doesn't stop, and incoming calls interrupt cleanly.

---

## 8. Data model

Persistence via SwiftData unless an ADR chooses GRDB. Entities (fields to be filled in by Claude Code during the alignment phase):

- `UserProfile` (1)
- `Goal` (n, prioritized)
- `Injury` (n, with affected movements)
- `EquipmentItem` (n)
- `Plan` → `PlanWeek` → `PlanDay` → `PlannedExercise` → `PlannedSet`
- `WorkoutSession` → `PerformedExercise` → `PerformedSet` → `RepEvent` (with pose summary)
- `CueEvent` (attached to `PerformedSet`, severity + timestamp + type)
- `ReadinessCheck` (daily)
- `HealthMetricSnapshot` (from HealthKit)
- `CoachMemoryNote` (type, content, created_at, optional linked_session_id)

**Migrations:** every schema change ships with a migration and a migration test. Zero-downtime migration is the bar. Never ship a destructive migration without explicit user consent flow.

---

## 9. Privacy & data handling

- **Pose frames never leave the device. Ever.** Load-bearing promise.
- If premium TTS is used, only the **synthesized text** (the phrase the coach is saying) leaves the device — never user audio, never video, never pose data.
- User's voice captured via STT for between-set conversation is processed on-device where possible; if cloud STT is used for accuracy, document which calls go where in `docs/Privacy.md`.
- HealthKit is read-only in MVP. The app writes nothing back.
- Analytics are opt-in, privacy-preserving, no PII, no body metrics. Full event schema in `docs/Telemetry.md`.
- Crash reporting: no user-identifiable payloads.
- **Offline-first**: the full Live Session (rep counting, in-set cues, voice) must work in airplane mode. Between-set LLM conversation degrades gracefully to deterministic canned responses when offline.

---

## 10. Quality bar & testing strategy

### 10.1 Unit tests

`CoachingEngine` has ≥ 85% line coverage. Rep detector, set-end detector, cue engine, plan generator, memory retrieval all covered by property-based tests (Swift Testing + custom generators) for invariants such as *"no cue ever fires without an underlying pose observation."*

### 10.2 Pose fixture tests

Record or synthesize pose-stream JSON fixtures for each of the 3 exercises: good reps, bad reps (one per cue type), edge cases (partial frames, occlusion, camera shake). These run in CI against `CoachingEngine` and `PoseVision` with no camera required.

**Every cue in the catalogue has at least one positive fixture (cue should fire) and one negative fixture (cue should not fire).**

### 10.3 The north-star demo test

The demo moment from §2 is a **required, automated test**: a scripted pose stream fixture representing a set of push-ups with reps 1–7 at normal tempo and reps 8–13 progressively slowing. The test pipes the fixture through `CoachingEngine + VoiceIO` with a mock audio output, transcribes the captured audio, and asserts:
- Exactly 13 reps counted.
- The phrase *"one more"* occurs during rep 13's concentric window (±200 ms).
- The post-set summary contains the numeric count *"13"*.
- No cue misfires.

This test guards the hero moment. If it breaks, main goes red.

### 10.4 Snapshot tests

Every screen: light and dark, accessibility sizes XS → AX5, Dynamic Type, right-to-left pseudo-locale.

### 10.5 UI tests

The three highest-risk flows: onboarding end-to-end, Live Session happy path (mocked pose + mocked audio), today-view → Live Session entry.

### 10.6 Performance tests

CPU, GPU, RAM, battery during a 30-minute live session on iPhone 13 mini (worst hardware in scope). Realistic budget: **≤ 25% battery drain per 60 minutes** of active Live Session on a fresh phone, no thermal throttling within 30 minutes at 22 °C. (Tighter targets are aspirational; these are the ones we commit to for Chapter 1.)

### 10.7 Chaos tests

Every scenario below must either resume correctly or fail with a clear user-visible explanation:

- Incoming call mid-set
- Siri triggered mid-rep
- Headphones connect / disconnect mid-set
- Network drop
- Low-power mode toggled on/off
- HealthKit permission denied
- Camera permission revoked mid-session
- Microphone permission revoked mid-session
- App backgrounded during a set
- App killed and relaunched with an active session (session resume or clean-exit flow)

### 10.8 Content safety

Gym Buddy will **never**:
- Diagnose an injury or medical condition.
- Recommend specific weight cuts, calorie targets, or macros below medically safe minima.
- Shame the user for any reason.
- Push through sharp pain signals (user says "hurts" / "sharp pain" / "something popped" → stop, acknowledge, recommend rest or medical consultation).

Enforced via:
1. LLM system-prompt guardrails.
2. A **post-LLM content filter** with explicit deny-list patterns and a regex + keyword safety layer. Any LLM output matching refusal patterns is replaced with a pre-written safe response.
3. Refusal hierarchy documented in `docs/Safety.md` with test cases for every category.

### 10.9 Accessibility

VoiceOver, Dynamic Type, reduced motion, reduced transparency, contrast ≥ WCAG AA. An accessibility checklist lives in the repo and must be green before every tag.

### 10.10 LLM evals

Golden prompts with expected properties (format, tone, no unsafe advice, no invented injury diagnoses, correct memory reference when applicable). Eval runner runs in CI on every LLM prompt change. Evals cover:
- Onboarding synthesis (plan correctness given stated goals + equipment + injuries)
- Morning readiness interpretation
- Between-set responses to 20 representative questions
- Post-session summary (must reference specific session observations, must not contain generic praise)
- Content safety (must refuse or redirect on unsafe prompts, must not fabricate medical advice)

---

## 11. Non-functional requirements

- Cold start to camera preview: **< 2.0 s** on iPhone 13.
- Live session: **30 fps pose inference, 60 fps UI, ≤ 1 dropped frame per second sustained.**
- Live cue latency: **< 400 ms** (see §5.4).
- Battery: **≤ 25% drain per 60-minute live session** on a fresh phone.
- Fully offline capable, minus LLM reasoning features (which degrade gracefully).
- App survives any permission being revoked mid-session without crashing.
- All user-visible strings localizable; MVP ships en-US with the localization pipeline complete.

---

## 12. Milestones (deliver demo-ably — do not try to ship this in one shot)

### M0 — Skeleton (week 1)
Xcode project, SwiftPM modules, CI (GitHub Actions), lint (SwiftLint + SwiftFormat), test runner, crash-free launch, design system tokens in place. **Demo:** app launches on a real device, shows a styled welcome screen, CI green.

### M1 — Offline coaching engine (weeks 2–3)
`CoachingEngine` with full rep detection, set-end detection, cue engine for all 3 exercises, driven by pose fixtures. Zero camera yet. **Demo:** CLI harness pipes pose fixture JSON into the engine; correct rep counts and cue events printed for each exercise. The north-star demo test passes against synthetic fixtures.

### M2 — Live on-device (weeks 4–5)
Camera + Vision integrated, engine reads real pose, on-screen rep counter, on-screen text cues. **Demo:** do a live set of push-ups in the office; rep count and at least one cue fire correctly.

### M3 — Voice coach (week 6)
ElevenLabs TTS wired (with pre-cached library), STT wired, voice cues, audio session handling, between-set LLM conversation working. **Demo:** do a live push-up set with AirPods in; the coach counts and cues audibly; you can ask *"should I add weight?"* between sets and get a reasonable answer.

### M4 — Onboarding, plan, relational layer (week 7)
Conversational onboarding, plan generation, morning readiness check-in, coach memory, warm post-session summary, history view, HealthKit read. **Demo:** fresh install → onboard → today's plan → live session → warm summary → history updated → next morning the coach references something specific from the prior session.

### M5 — Polish, chaos, TestFlight (week 8)
Snapshot/UI tests green, chaos scenarios pass, performance targets met, accessibility checklist green, TestFlight build shipped to test group. **Demo:** a test-group user installs from TestFlight, completes their first session without me in the room, and reports back.

Each milestone includes: updated `README.md`, updated `ARCHITECTURE.md`, demo script, known-issues list, coverage delta.

---

## 13. Open decisions — ADR required before implementation

For each, write an ADR in `docs/decisions/` covering context, options considered, decision, trade-offs, revisit date.

1. **SwiftData vs GRDB** for persistence.
2. **TTS strategy + vendor**: pick a vendor (ElevenLabs vs OpenAI TTS vs another based on latency, voice quality, cost, API reliability) and define when Tier 1 variants are generated (at build time, on first run, or on-demand with permanent caching).
3. **LLM vendor**: Claude vs OpenAI vs Gemini — justify on reasoning quality for the specific tasks (plan gen, memory extraction, summaries, conversation), latency, cost, safety posture.
4. **Apple Vision vs MediaPipe** for pose detection — benchmark both on the 3 MVP exercises with recorded fixtures, make the call with numbers.
5. **FSM for set/rep state**: hand-rolled vs a library (e.g., Swift StateKit). Default: hand-rolled, justify if library.
6. **Coach memory retrieval**: tag + recency vs vector search. Default: tag + recency for MVP; defer vector search to when it's clearly needed.
7. **Telemetry vendor**: default is no vendor in MVP, local-only event log.

---

## 14. Rules of engagement for Claude Code

- Work in **small PRs**. Each PR has a single concern, a summary, tests, and a changelog line.
- **Never let `main` go red.** If a test is flaky, fix or quarantine it — don't ignore it.
- Before adding a dependency, open an ADR. **Default posture: no third-party dependencies outside Apple frameworks, one LLM SDK, one TTS SDK.**
- Commit messages follow Conventional Commits.
- Write code for the reader, not the writer. Name things honestly. No cute names.
- Every public type in `CoachingEngine` has a doc comment with an example.
- **No force unwraps. No `try!`. No compiler warnings. No `TODO` without a tracking issue link.**
- If you ever feel pressured to skip tests to hit a milestone — **stop and raise it.** The milestone moves; the quality bar does not.
- When you hit ambiguity in this PRD, do not silently choose. Either file an ADR with your proposed resolution, or log it in `docs/OPEN_QUESTIONS.md` and ask.
- You are building **Chapter 1 of a larger arc.** When in doubt about an architectural decision, ask: "would this survive Chapter 5 (in-ear screenless mode) without a rewrite?" If not, rethink.

---

## 15. Definition of Done for the MVP

- TestFlight build installable by me and my test group (≈ 10 friends, mixed tech-savviness).
- All milestones M0–M5 merged and green in CI.
- `CoachingEngine` ≥ 85% line coverage; app-wide ≥ 60%.
- All chaos scenarios in §10.7 pass.
- All 3 exercises pass a manual "real lift" smoke test with no cue misfires over a 3×10 workout each.
- **The north-star demo test (§2, §10.3) passes in CI and is reproducible in a live demo.**
- `README.md` reads like a front door — a new engineer can clone and run on a real device in under 10 minutes.
- `ARCHITECTURE.md` is current.
- Zero compiler warnings, zero force unwraps, no untracked `TODO`s.

---

## 16. One final framing note for Claude Code

You have been given three documents: `VISION.md`, `ROADMAP.md`, and this PRD. They are intentionally structured so that the vision is ambitious, the roadmap is long, and the MVP is tight. **Do not try to pull scope forward from the roadmap into the MVP.** The discipline of holding the line is the discipline that lets the vision actually ship.

The goal of Chapter 1 is not to impress — it is to build the foundation on which every later chapter can compound. If the MVP is small and the foundation is right, the vision becomes inevitable. If the MVP is big and the foundation is rushed, the vision dies in a refactor.

Build Chapter 1. Build it perfect. Then we write Chapter 2.

---

*End of document. When you're ready, reply with your drafts of `docs/PRD.md`, `docs/ARCHITECTURE.md`, `docs/MILESTONES.md`, and the initial ADR set for my review.*
