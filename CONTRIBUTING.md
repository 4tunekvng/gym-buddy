# Contributing — Gym Buddy

Chapter 1 of the arc. Read [PRD.md](PRD.md) §14 first — the rules of engagement are there.

## Working rules

- **Small PRs, one concern each.** Tests in the same PR as the feature. A changelog line. Keep green main.
- **Default to no dependencies.** Adding a third-party import requires an ADR in `docs/decisions/`.
- **`CoachingEngine` is pure Swift.** No imports from `UIKit`, `SwiftUI`, `Vision`, `HealthKit`, `AVFoundation`, or vendor SDKs. The CI lint step fails the build if you do.
- **Write code for the reader.** Names are honest. No cute names.
- **Doc-comment every public type** in `CoachingEngine` with a one-line example.
- **No force unwraps.** No `try!`. No compiler warnings. No untracked `TODO`s.
- **If a milestone is in trouble, scope moves.** The quality bar does not.

## Setting up

1. Install Xcode 15.4+ (full Xcode, not just Command Line Tools).
2. Clone the repo.
3. `cd GymBuddy && swift test` — every test must pass.
4. `open Package.swift` in Xcode to get the SwiftPM workspace.
5. For iOS app development, see `GymBuddy/README.md#app-setup`.

## Secrets

Local dev needs:

- `ANTHROPIC_API_KEY` — Claude.
- `ELEVENLABS_API_KEY` — only needed when regenerating the TTS cache.

Put these in `GymBuddy/.env` (gitignored). They're read by:

- `AppComposition.makeProduction()` at runtime (Info.plist via `xcconfig` is the right move for release builds — to do before TestFlight).
- The TTS build script when regenerating the bundled audio cache (see `scripts/generate-tts-cache.sh` — to be added).

**Never commit keys.** `.gitignore` is configured to ignore `.env`, `*.pem`, `apiKey*.plist`.

## Adding an exercise

You can't in Chapter 1. Adding a 4th MVP exercise requires an ADR argued from the roadmap — default answer is no. See `docs/decisions/0005-rep-fsm-hand-rolled.md` for the shape of those.

## Adding a form cue

1. Define the `CueType` case in `Sources/CoachingEngine/Cues/CueType.swift` and its `applicableExercises`.
2. Add an evaluator conforming to `CueEvaluator` in the relevant file (`PushUpCues.swift`, etc.).
3. Register it in that file's `all` array.
4. Document the biomechanical signal it watches in a one-line doc comment.
5. Add a positive and negative pose fixture in `Tests/CoachingEngineTests/Fixtures/`.
6. Add a test that shows the cue fires on the positive and stays silent on the negative.

## Adding an LLM prompt

1. Add a `render…` method to `Sources/LLMClient/Prompts/Registry.swift`.
2. Version it with an explicit constant — versions never reuse.
3. Add at least one eval in `Tests/LLMClientTests/Evals/`.
4. If the prompt can produce unsafe output, the eval must prove the `ContentSafetyFilter` catches every failure mode.

## Reviewing a PR

The author ran the checklist below before handing the PR over — a reviewer's first job is to verify it.

- [ ] Tests cover the new behavior (happy path + ≥ 1 edge case).
- [ ] `CoachingEngine` still has no platform imports.
- [ ] No force unwraps, no `try!`, no compiler warnings.
- [ ] SwiftLint green.
- [ ] Dependency-direction lint green.
- [ ] North-star demo test still green.
- [ ] Any ADR for the change is filed in `docs/decisions/`.
- [ ] Changelog line added.

## Commit messages

Conventional Commits, kept small:

```
feat(coaching-engine): add knee-valgus left/right cue
test(coaching-engine): positive + negative fixtures for knee valgus
fix(voice-io): no-repeat window now matches manifest size
docs(adr): 0008 — move tempo slowdown ratio to a user-tunable setting
```

## Questions

Log them in `docs/OPEN_QUESTIONS.md` with a proposed resolution — don't silently pick.
