# Open Questions — running log

*Ambiguities I hit in the PRD. Each has my proposed resolution and a flag for your sign-off. Items move to closed once resolved.*

---

## OQ-001 — Tempo-slowdown threshold for "push" intent

**Context:** PRD §2 says "On rep N (around rep 8–12 for an intermediate user), the user's rep tempo visibly slows — the concentric phase takes 40%+ longer than previous reps." This implies a 1.4× concentric-duration ratio vs. the per-set baseline. But what's the baseline? The first clean rep? A rolling window?

**Proposed resolution:** Baseline = median concentric duration of reps 2–4 (skip rep 1 because first-rep tempo is often atypical from setup). Slowdown threshold = 1.35× baseline for the first "push" intent, 1.5× for the "last one, drive" intent. Thresholds live in `CoachingEngine/Tuning/ExerciseTuning.swift` and are per-exercise tunable. Hysteresis: once a push intent fires, suppress for 3 seconds to avoid double-firing.

**Needs sign-off.** Reasonable default; easy to tune if it feels wrong in real use.

---

## OQ-002 — What counts as a "rep" when ROM is partial?

**Context:** PRD §4 job 4: "Push me to one honest rep more than I would have done alone. We need to make sure we are able to make sure the user can't trick us here by artificially doing a weak rep when they still have more in them." Two interpretations:
1. Hard: if ROM < threshold, do not count the rep at all.
2. Soft: count the rep but mark it as partial; don't use partial reps in fatigue detection (so the user can't game the slowdown signal by faking incomplete reps).

**Proposed resolution:** Soft interpretation, with an on-screen marker. Partial reps are counted but rendered with a different HUD color ("5 … 6 … 7 *partial* … 8") and the post-set summary references them: *"Six full reps, then two partial. Focus on finishing the range of motion on the last couple next set."* Partial reps are excluded from the tempo baseline and from the fatigue signal used for "push" timing. Rationale: hard refusal to count feels punitive and will make users feel the app is fighting them; soft counting keeps them engaged while still being honest in the summary.

**Needs sign-off.** This is a design call with product implications; flag it if you disagree.

---

## OQ-003 — Quantifying "the coach never sounds looped"

**Context:** PRD §5.3 requires 5–8 variants per in-set phrase and "no-repeat" runtime selection. But "no repeat" can mean many things.

**Proposed resolution:** No-repeat window = `min(variantCount - 1, 8)` most-recently-played variants. Variant selection: weighted random over un-windowed variants, where weight is inverse-proportional to total play count within the session. This keeps variety fresh and discourages collapsing to a few favorites.

**Needs sign-off.** Minor knob; sensible default.

---

## OQ-004 — ElevenLabs voice ID + tone implementation

**Context:** PRD §6.4 says tone preference (quiet / standard / intense) "affects voice prompt selection and LLM system prompt — never the content of the coaching itself, only its delivery."

**Proposed resolution:**
- Single ElevenLabs voice ID (not three separate voices — same coach, different register).
- Three separate TTS generation passes at build time with different SSML prosody hints (`<prosody volume="soft">` for quiet, default for standard, `<prosody rate="105%" pitch="+2st">` for intense).
- Three audio-asset bundles in the app; the current tone preference selects which bundle to load.
- LLM system prompt has a tone line appended: `{tone: quiet}` | `{tone: standard}` | `{tone: intense}`, each with a few examples of expected phrasing.

**Needs sign-off.** Bigger assumption because it locks us to a single voice actor; easy to undo if we want three voices.

---

## OQ-005 — Storage + privacy for session video

**Context:** PRD §3 doesn't explicitly say video is saved. §9 says "pose frames never leave the device." But what about frames locally? The user might want to review a session.

**Proposed resolution:** No video is saved in MVP, anywhere, ever. Only derived pose sequences are persisted (as compact keypoint arrays per frame, enough to regenerate a skeleton visualization later). This is both a privacy win and a storage win. Video replay is explicitly deferred to Chapter 9. If a user wants to record, they can use iOS screen recording — that's a user-initiated action that routes around our flow and stays on their device.

**Needs sign-off.** Pretty sure this is what you want; flagging to make sure.

---

## OQ-006 — Telemetry opt-in mechanism

**Context:** PRD §9 says "analytics are opt-in, privacy-preserving, no PII, no body metrics." §13 says "telemetry vendor: default is no vendor in MVP, local-only event log."

**Proposed resolution:** MVP logs events locally only, to a rolling 7-day SQLite table inside the Persistence module. No cloud egress. An opt-in toggle in Settings ("Share anonymous diagnostics with Gym Buddy") is present but non-functional in MVP — wiring it to a vendor is Chapter 2+. This keeps the promise honest ("we don't send anything") while the UI affordance exists for later. I'll put a visible "local only in MVP" subtext under the toggle.

**Needs sign-off.** Minor; flagging the UI string.

---

## OQ-007 — Handling "sharp pain" detection in voice

**Context:** PRD §10.8: *user says "hurts" / "sharp pain" / "something popped" → stop, acknowledge, recommend rest or medical consultation.*

**Proposed resolution:** Two-layer detection:
1. Local keyword match on STT output for the pain phrases — fires immediately, does not wait for LLM. Deterministic, no network, no latency.
2. LLM system prompt reinforces the same behavior for edge-case phrasings.

Action on detection: session pauses (rep counting stops, cue suppression on). Coach voice says (from pre-recorded safe-response library): *"Let's stop there. Sharp pain is a stop signal. I'm logging the set. If it keeps hurting, please check in with a physician or physical therapist."* The set is saved as-is; a `pain` flag is attached to the session. Next session, the coach references it ("you mentioned pain in the last session — how are you feeling today?").

**Needs sign-off.** I've picked safe defaults; wording is tunable.

---

## OQ-008 — Plan generation: who picks the workout for day 1?

**Context:** PRD §3 says "4-week plan generated at end of onboarding" with "simple linear progression — no adaptive re-planning algorithm in MVP." §3.1 hero flow opens with "select today's workout," implying the plan gives the user a workout each day.

**Proposed resolution:** Plan is a weekly template (e.g., M/W/F upper-lower-full or push/pull/legs), selected from a small library (3–4 templates) matched to user's stated frequency + equipment + goal. Each plan day has a concrete prescribed workout (3 exercises × sets × target reps). Day N loads N% over day 1 baseline via a fixed linear progression. User can tap "substitute" on any exercise to swap for an in-scope alternative (e.g., goblet squat ↔ lunge — but lunge is out of scope in MVP, so the substitute library is effectively a no-op for now; documented as a Chapter 2 enabler).

**Needs sign-off.** Clean and narrow; flagging that substitution is mostly decorative in MVP.

---

## OQ-009 — "Warm summary must reference something specific — what if nothing notable happened?"

**Context:** PRD §6.3: "Generic encouragement ('good job today!') is explicitly forbidden. If the summary cannot reference something specific, something went wrong in observation and we log it rather than shipping a generic line."

**Proposed resolution:** The summary generator takes as input a structured session observation bundle (rep counts, tempo deltas per rep, cue events, prior-session deltas, memory-note refs). Summary is required to include at least one quantitative fact AND one qualitative observation. If the observation bundle is empty (no cues fired, tempo flat, no prior-session data), we fall back to a *numeric* fact plus a memory-note reference: *"Solid session. Nine clean push-ups, nine clean squats. Left knee was quiet today — good sign."* If memory-note references are also empty (very early user), fall back to: *"Three exercises done, thirty reps total. Clean start. I'll build the baseline from here."* (Explicitly numeric, not generic.) An error is telemetry-logged if the summary ever tries to ship without at least one quantitative fact.

**Needs sign-off.** Keeps the promise honest even for the edge case.

---

## OQ-010 — Build-time vs first-launch TTS cache generation

**Context:** PRD §13 item 2 asks when Tier 1 variants are generated.

**Proposed resolution:** **Build time.** See ADR-0002. The audio assets ship in the `.ipa`. First-launch download would require the network on first run, which violates the "offline-first" promise for the hero loop. Downside: the binary is ~15–25 MB larger (estimate: 50 phrases × 7 variants × ~50 KB each = ~17 MB). Acceptable for Chapter 1.

**Closed.** Documented in ADR-0002.

---

## OQ-011 — Microphone always-on during between-set?

**Context:** PRD §5.1 step 6 implies the user can ask things between sets. Is the mic always hot between sets, or push-to-talk?

**Proposed resolution:** Mic is off by default. A large, always-visible "Talk to coach" button on the rest screen activates the mic for the duration of the user's question + response. After response, mic goes cold again. Push-to-talk is more honest about privacy, more battery-friendly, and avoids the "coach heard me say something to my friend" failure mode. The hot-mic mode is a Chapter 5+ feature (when headphones are always in and privacy expectations are different).

**Needs sign-off.** I think this is the right call for MVP; flag if you want hot-mic from day one.

---

## OQ-012 — What voice does the coach have during onboarding, before tone preference is set?

**Proposed resolution:** Standard tone until the user picks. The question "how do you like to be coached?" is asked late in onboarding (after we've heard them talk a bit, which avoids the cold-open pressure of answering that question first). Post-selection, all subsequent audio uses the selected tone bundle.

**Needs sign-off.**

---

*End of open questions at build start. I'll append new ones here as they arise during implementation.*
