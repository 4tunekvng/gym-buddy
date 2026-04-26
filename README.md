# Gym Buddy — Product & Build Docs

An iPhone app that aims to replace — and eventually surpass — the experience of working with an elite personal trainer. This folder is the planning package for Chapter 1 (the MVP), the vision arc that follows, and the implementation.

---

## Reading order

Pick the one that matches who you are right now:

### If you're me (or a future collaborator) orienting from scratch

1. **[VISION.md](VISION.md)** — the thesis, the moment we're building toward, why this is possible now, what we believe.
2. **[ROADMAP.md](ROADMAP.md)** — 12 chapters sequenced by dependency (no dates). Chapter 1 is the MVP; Chapter 5 (screenless in-ear mode) is the dream.
3. **[PRD.md](PRD.md)** — the Chapter 1 build contract. Tight scope: 3 exercises, tempo-aware voice coach, relational layer, 6–8 weeks.
4. **[docs/PRD.md](docs/PRD.md)** — my (Claude Code's) restatement of the PRD for alignment verification.
5. **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — C4 module view + package boundaries + testability architecture.
6. **[docs/MILESTONES.md](docs/MILESTONES.md)** — demo-able milestones M0 → M5.
7. **[docs/OPEN_QUESTIONS.md](docs/OPEN_QUESTIONS.md)** — open questions with proposed resolutions.
8. **[docs/decisions/](docs/decisions/)** — ADRs for the seven open decisions in PRD §13.
9. **[VISION_NARRATIVE.md](VISION_NARRATIVE.md)** — a 2-minute script for a video or readaloud.

### If you're a friend I'm pitching

- **Tech-savvy, skeptical:** read [VISION.md](VISION.md) first, then skim [ROADMAP.md](ROADMAP.md) for the "is the plan real" check, then glance at [PRD.md](PRD.md) §7 (architecture) and §10 (quality bar) to see this isn't hand-waving.
- **Casual:** watch or read the [VISION_NARRATIVE.md](VISION_NARRATIVE.md) script. That's the fastest way to feel the product.

### If you're here to look at the code

- **[GymBuddy/](GymBuddy/)** — the Swift workspace. `GymBuddy/README.md` has clone-and-run instructions.
- **[GymBuddy/Sources/CoachingEngine/](GymBuddy/Sources/CoachingEngine/)** — the sacrosanct domain layer.
- **[GymBuddy/Tests/CoachingEngineTests/HeroMoment/](GymBuddy/Tests/CoachingEngineTests/HeroMoment/)** — the north-star demo test.
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — the rules of engagement.

---

## What's in each doc, one-liner

| Doc | What it is | For whom |
|---|---|---|
| [VISION.md](VISION.md) | The long-form written vision. Thesis, the moment, why now, beliefs, horizon. | Humans (friends, future collaborators, future-me) |
| [ROADMAP.md](ROADMAP.md) | 12-chapter arc from MVP to full vision. Sequence + dependencies, no dates. | Humans + Claude Code (for architectural context) |
| [PRD.md](PRD.md) | Chapter 1 build contract. Scope, architecture, quality bar, milestones, ADRs. | Claude Code primarily |
| [VISION_NARRATIVE.md](VISION_NARRATIVE.md) | 2-min scene-by-scene script for a video or readaloud. Plus 30-sec cutdown. | Friends, pitches, storytelling |
| [docs/](docs/) | Implementation-time docs: restatement, architecture, ADRs, milestones, safety, privacy, telemetry, open questions. | Contributors |
| [GymBuddy/](GymBuddy/) | Swift implementation — 8 packages + iOS app target + full test suite. | Contributors |

---

## The three load-bearing ideas

If you only take three things from this package, take these:

1. **The north-star demo moment (PRD §2) is the product.** Everything else serves the 30-second "one more — push" moment. Cut anything that doesn't. The moment is guarded in CI by `Tests/CoachingEngineTests/HeroMoment/NorthStarDemoTest.swift` — if it breaks, main goes red.
2. **`CoachingEngine` stays pure.** The domain layer never imports `UIKit`, `SwiftUI`, `Vision`, `HealthKit`, or vendor SDKs. This discipline is what makes the roadmap reachable without rewrites. Enforced by both package dependencies and a grep-based CI lint step.
3. **Depth of care, not breadth of features.** 3 exercises done perfectly + a coach that remembers you > 20 exercises done shallowly. Both skeptical and casual users are won by depth, just in different registers.

---

## Status

**Chapter 1 foundation implemented.** Swift packages compile-ready; unit + property + integration + chaos + hero-moment + LLM-eval test suites in place; iOS app SwiftUI views implemented; ADRs recorded for all seven open decisions.

**Still to do before TestFlight (per `docs/MILESTONES.md`):**
- Xcode project scaffolding (`App/GymBuddyApp.xcodeproj` — to be generated via Tuist or XcodeGen) and wiring the iOS target against the SwiftPM libraries.
- TTS cache generation pipeline (M3): produce the Tier-1 phrase variants and commit the audio assets.
- Real pose-fixture corpus recorded from devices (M2 exit bar).
- On-device latency benchmark harness for the in-set cue path.
- Snapshot tests for every screen across Dynamic Type / dark-light / RTL.
- TestFlight signing configuration and first build.
