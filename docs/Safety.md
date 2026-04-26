# Safety — refusal hierarchy and enforcement

*Source: PRD §10.8. This document makes the rules concrete.*

---

## What Gym Buddy will never do

1. **Diagnose** any injury or medical condition. Maximum response is: *"That sounds like something a physician or PT should look at."*
2. **Prescribe** specific weights/macros/calories below medically safe minima, a specific weight-cut target, or a body-fat-percentage target.
3. **Shame** the user. Not sarcastically. Not "tough love." Not "intense" mode. Shame is out of bounds regardless of tone preference.
4. **Push through** sharp-pain signals. If the user says *"hurts," "sharp," "something popped," "pinched," "shooting pain,"* we stop the set.
5. **Substitute for** a physician, PT, psychologist, or registered dietitian.

## Enforcement — three layers

### Layer 1: LLM system prompt

Every LLM call includes a safety preamble:

```
You are Gym Buddy, a strength coach for an intermediate lifter.
You will never: diagnose injuries, recommend specific calorie targets
below 1,500 kcal/day or weight-cut plans, shame the user, or push
through sharp pain signals. If the user describes sharp pain, advise
stopping and consulting a physician or physical therapist.
You will defer to a physician for any sign of injury beyond muscle
soreness.
```

### Layer 2: Post-LLM content filter

Every LLM response passes through `ContentSafetyFilter` in `CoachingEngine` (keeping safety decisions in the pure domain layer). Pattern categories:

- **Diagnosis patterns:** "you have [condition]", "sounds like [medical term]", etc. → replace with the safe-response "medical consultation" line.
- **Calorie floors:** any numeric recommendation below 1,500 kcal/day or any "weight cut to X lbs" phrasing → replaced.
- **Shame patterns:** condescension detectors, "pathetic", "weak", etc. (these shouldn't appear — belt-and-suspenders) → replaced.
- **Push-through-pain:** if LLM output contains language that pushes through after user mentioned pain → replaced with the pain-stop response.

Every substitution logs a `safety.substitution` telemetry event with the category and the offending regex match hash (not the raw text — privacy).

### Layer 3: Pre-recorded safe-response library

A small library of pre-recorded TTS audio for the safety fallbacks, so we never have to trust the LLM's wording in a safety moment. Played directly from cache when a safety substitution is triggered:

- `safety.pain.stop`: *"Let's stop there. Sharp pain is a stop signal. I'm logging the set. If it keeps hurting, please check in with a physician or PT."*
- `safety.diagnosis.deflect`: *"I can't diagnose that — it sounds like something a physician should look at. How are you feeling right now?"*
- `safety.nutrition.deflect`: *"I can help with training. For specific calorie or weight-cut numbers, I'd want you to talk to a registered dietitian."*
- `safety.generic.deflect`: *"That's outside what I can help with. Let's get back to the set."*

## Sharp-pain pipeline

```
STT transcript ─▶ [pain-keyword matcher] ─▶ match? ──▶ suppress cue engine,
                                                        pause rep counting,
                                                        set session.painFlag = true,
                                                        play safety.pain.stop audio,
                                                        show on-screen
                                                        "Paused — take care of yourself"
                                                        with actions:
                                                          "End session"
                                                          "Continue (you're sure)"
                                        │
                                        ▼
                                    no match ──▶ normal LLM flow
```

The keyword matcher runs **before** the LLM call so it's deterministic and offline-safe:

```swift
private let painPhrases: Set<String> = [
    "hurts", "hurting", "sharp pain", "something popped",
    "pinched", "pinching", "shooting pain", "tweaked",
    "pulled something", "stabbing",
]
```

(Matching is case-insensitive, word-boundary, and includes the keyword in a set of negated contexts like *"doesn't hurt"* which are allowed through.)

## Testing

Every layer has tests in `Tests/CoachingEngineTests/Safety/`:

- Unit: every pain phrase triggers `SafetyAction.stopSet`.
- Unit: every forbidden output pattern triggers a substitution.
- Negative: common non-pain phrases (*"it's a grind"*, *"that was tough"*) do **not** trigger a pain response.
- LLM eval: 30 prompts that try to get the LLM to diagnose / shame / prescribe unsafe cuts; 100% must route through a substitution.
- Integration: a full live session with a scripted pain utterance → verify set pauses, audio plays, telemetry event fires.

## Escalation

If a user triggers three pain events within 7 days, the app surfaces a banner: *"You've had several pain signals lately. Consider checking in with a professional before your next session."* Not blocking, not nagging — one quiet surfacing.

## What's explicitly NOT a safety trigger

- *"This is hard"*, *"I'm dying"* (colloquial), *"my legs are burning"* (muscle burn), *"I'm cooked"*. These are normal training vocabulary. Do not false-positive them.
- The fatigue-slowdown signal from the TempoTracker is **not** a safety signal — it's the intended trigger for the "one more" moment.
