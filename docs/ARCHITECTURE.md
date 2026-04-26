# Gym Buddy — Architecture (C4 module view + package boundaries)

*The architectural contract. Every PR must keep this true.*

---

## Guiding principles

1. **`CoachingEngine` is sacrosanct.** Pure Swift. No UIKit, SwiftUI, Vision, HealthKit, AVFoundation, URLSession, or vendor SDK imports. Ever. This is what makes Chapters 5 (IMU-only) and 10 (Android) additive, not rewrites.
2. **Protocols at every boundary.** Every platform-dependent capability is a protocol owned by the domain layer, with the platform implementation and a test double living in separate packages.
3. **Unidirectional dependencies.** `GymBuddyApp` depends on all packages; `CoachingEngine` depends on nothing but stdlib/Foundation; other packages may depend on `CoachingEngine` only.
4. **No singletons, no service locator.** Constructor-injected protocols, composed at the app root.
5. **Swift Concurrency only.** `async`/`await`, `AsyncSequence`. No Combine in new code. No GCD except wrapped at thin platform seams.

---

## C4 Level 1 — System context

```
                ┌───────────────────────┐
                │        User           │
                │  (iPhone, AirPods)    │
                └────────┬──────────────┘
                         │
                         ▼
                ┌───────────────────────┐
                │     Gym Buddy App     │
                │        (iOS)          │
                └────┬──────┬───────────┘
                     │      │
      (synth. text)  │      │ (nothing — pose stays on device)
                     ▼      ▼
        ┌────────────────────┐   ┌────────────────────┐
        │   TTS vendor       │   │   LLM vendor       │
        │   (ElevenLabs)     │   │   (Claude API)     │
        └────────────────────┘   └────────────────────┘

    HealthKit — local, read-only, on-device.
    No data leaves the device except: TTS request text + LLM prompt text.
```

---

## C4 Level 2 — Container (modules)

```
╔═══════════════════════════════════════════════════════════════╗
║                      GymBuddyApp (iOS target)                 ║
║                   composition root · no logic                 ║
╚═══════════════════════════════════════════════════════════════╝
         │     │    │     │     │       │      │       │
         ▼     ▼    ▼     ▼     ▼       ▼      ▼       ▼
    ┌────────┐ ┌─────────┐ ┌──────┐ ┌─────────┐ ┌──────────────┐
    │ Design │ │  Pose   │ │Voice │ │  LLM    │ │  HealthKit   │
    │ System │ │ Vision  │ │ IO   │ │ Client  │ │   Bridge     │
    │ (iOS)  │ │ (iOS)   │ │(iOS) │ │(cross)  │ │   (iOS)      │
    └────────┘ └────┬────┘ └──┬───┘ └────┬────┘ └──────┬───────┘
                    │         │          │             │
                    ▼         ▼          ▼             ▼
                ╔═══════════════════════════════════════════════╗
                ║            CoachingEngine                     ║
                ║  pure Swift · no platform imports · ever      ║
                ║                                               ║
                ║  - RepDetector (push-up, squat, row FSMs)     ║
                ║  - SetEndDetector                             ║
                ║  - CueEngine (cue catalogue per exercise)     ║
                ║  - TempoTracker (fatigue signal)              ║
                ║  - CoachingIntentEmitter                      ║
                ║  - PlanGenerator (4-week linear progression)  ║
                ║  - CoachMemoryStore (tag+recency retrieval)   ║
                ║  - ReadinessScaler                            ║
                ║  - ContentSafetyFilter                        ║
                ╚═══════════════════════════════════════════════╝
                                      │
                                      ▼
                             ┌──────────────────┐
                             │   Persistence    │
                             │  SwiftData repo  │
                             └──────────────────┘
                                      │
                                      ▼
                             ┌──────────────────┐
                             │    Telemetry     │
                             │ local event log  │
                             └──────────────────┘
```

### Per-module dependency rules (enforced in `Package.swift`)

| Module              | Allowed deps                                   | Forbidden                                  |
|---------------------|------------------------------------------------|--------------------------------------------|
| `CoachingEngine`    | Swift stdlib, Foundation                       | Everything else                            |
| `PoseVision`        | `CoachingEngine`, Vision, CoreML, AVFoundation | SwiftUI, vendor SDKs                       |
| `VoiceIO`           | `CoachingEngine`, AVFoundation, Speech, TTS SDK | SwiftUI                                   |
| `LLMClient`         | `CoachingEngine`, Foundation, Anthropic SDK    | SwiftUI, AVFoundation                      |
| `Persistence`       | `CoachingEngine`, SwiftData                    | SwiftUI, Vision, AVFoundation              |
| `HealthKitBridge`   | `CoachingEngine`, HealthKit                    | SwiftUI, AVFoundation                      |
| `DesignSystem`      | SwiftUI                                        | `CoachingEngine`, vendor SDKs              |
| `Telemetry`         | Foundation                                     | Everything else                            |
| `GymBuddyApp`       | All of the above                               | —                                          |

A GitHub Actions lint step greps every package's `Package.swift` + source for forbidden imports. CI fails red on any violation.

---

## C4 Level 3 — Key collaborations

### The Live Session data flow

```
┌───────────────┐  CMSampleBuffer   ┌──────────────┐  Pose   ┌────────────┐
│  AVCaptureSession  ───────────▶   │  PoseVision  │ ──────▶ │            │
│ (front/rear cam)   ◀─────────     │   (Vision)   │         │  Coaching  │
└───────────────┘   control         └──────────────┘         │   Engine   │
                                                             │   (pure)   │
┌───────────────┐  audio frames                              │            │
│  AVAudioEngine     ◀──────────  (TTS audio stream)         │            │
│   +AVAudioSession ───────────▶   ┌──────────────┐ ◀──────  │            │
│ (ducks, records)    STT stream   │   VoiceIO    │ Intent   │            │
└───────────────┘                  │   (AVF)      │ ──────▶  │            │
                                   └──────┬───────┘          └────┬───────┘
                                          │                       │
                                          │ TTS cache miss?       │ persist
                                          ▼                       ▼
                                   ┌──────────────┐         ┌──────────────┐
                                   │  LLM Client  │         │ Persistence  │
                                   │   (Claude)   │         │ (SwiftData)  │
                                   └──────────────┘         └──────────────┘
```

### The "one more — push" moment (hot path)

```
Pose frame (Vision) ──▶ PoseVision adapter ──▶ CoachingEngine
                                                     │
                                                     ├── RepDetector (FSM) ──▶ rep event
                                                     │
                                                     ├── TempoTracker ──▶ slowdown detected on rep N
                                                     │                          (concentric > 1.4× baseline)
                                                     │
                                                     └── CoachingIntentEmitter
                                                                │
                                                                ▼
                                                       PushIntent("one more", timing: bottomOfRep)
                                                                │
                                                                ▼
                                                       VoiceIO.play(cachedPhrase(.oneMore, variant: next)
                                                                │
                                                                ▼
                                         audio starts within <400ms of slowdown first being visible
```

The entire path from pose-frame-in to audio-starts-playing is synchronous-ish: `CoachingEngine` runs in a dedicated serial `AsyncChannel` consumer, `VoiceIO` plays pre-cached `AVAudioPCMBuffer`s from memory. The only I/O in the hot path is reading a pre-loaded audio buffer and calling `AVAudioPlayerNode.scheduleBuffer`.

### The between-set conversation flow (cold path, < 2.5 s budget)

```
User speaks ──▶ STT (on-device Speech) ──▶ transcribed question
                                                    │
                                                    ▼
                                          CoachingEngine.contextualize(
                                             question, session, memory)
                                                    │
                                                    ▼ (builds prompt)
                                          LLMClient.stream(prompt)
                                                    │
                                                    ▼ (tokens arrive)
                                          ContentSafetyFilter (rolling)
                                                    │
                                                    ▼
                                          VoiceIO.streamTTS(tokens)
                                                    │
                                                    ▼
                                          audio starts at first sentence boundary
```

---

## C4 Level 4 — `CoachingEngine` internals

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           CoachingEngine                                │
│                                                                         │
│  Inputs:                          Outputs:                              │
│   - BodyStateStream (pose or IMU)  - CoachingIntent (cue/rep/end)       │
│   - UserContext (profile/memory)   - PersistableEvents (rep/cue/set)    │
│   - SessionRequest                 - MemoryNotes (to persist)           │
│                                                                         │
│   ┌────────────────────────────────────────────────────────────────┐    │
│   │                       SessionOrchestrator                      │    │
│   │                  (consumes pose frames, emits intents)         │    │
│   └────┬─────────────────┬─────────────────┬─────────────────┬─────┘    │
│        │                 │                 │                 │          │
│        ▼                 ▼                 ▼                 ▼          │
│   ┌─────────┐     ┌──────────────┐   ┌─────────┐     ┌──────────────┐   │
│   │  Rep    │     │  SetEnd      │   │  Tempo  │     │    Cue       │   │
│   │ Detector│     │  Detector    │   │ Tracker │     │   Engine     │   │
│   └─────────┘     └──────────────┘   └─────────┘     └──────────────┘   │
│        │                                                  │             │
│        │                                                  │             │
│        ▼                                                  ▼             │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │                   CoachingIntentEmitter                          │  │
│   │   priority:  safety > rep-count > quality cue > optimization     │  │
│   │              cue > encouragement.                                │  │
│   └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│   Helpers (not in hot path):                                            │
│   - PlanGenerator                - CoachMemoryStore                     │
│   - ReadinessScaler              - ContentSafetyFilter                  │
└─────────────────────────────────────────────────────────────────────────┘
```

### State machine sketch (rep detector — simplified)

```
                  ┌────────────┐
                  │    Idle    │
                  └──────┬─────┘
                         │ body in setup pose
                         ▼
                  ┌────────────┐
        ┌───────▶ │    Top     │──── observe: entering descent ─┐
        │         └────────────┘                                │
        │                                                        ▼
rep_event│                                                 ┌────────────┐
(count++,│                                                 │ Descending │
tempo    │                                                 └──────┬─────┘
record)  │                                                        │
        │                                                         ▼ at/below ROM threshold
        │                                                  ┌────────────┐
        │                                                  │   Bottom   │
        │                                                  └──────┬─────┘
        │                                                         │ begin ascent
        │                                                         ▼
        │                                                  ┌────────────┐
        └────────────────────────────────── full ROM ───── │ Ascending  │
                                                           └────────────┘
```

Push-up, squat, and row all use this 4-state FSM with exercise-specific joint-angle thresholds.

---

## Testability architecture

| Test type                | Where it lives                        | What it protects                                   |
|--------------------------|---------------------------------------|----------------------------------------------------|
| Unit                     | `Tests/<PackageName>Tests`            | Individual classes/functions                       |
| Property-based           | `Tests/CoachingEngineTests/Property`  | Invariants ("no cue without observation", etc.)    |
| Pose fixture             | `Tests/CoachingEngineTests/Fixtures`  | Rep counting + cue firing per exercise             |
| North-star demo          | `Tests/CoachingEngineTests/HeroMoment`| The PRD §2 moment                                  |
| LLM eval                 | `Tests/LLMClientTests/Evals`          | Prompt output properties (tone, no unsafe, etc.)   |
| Snapshot                 | `Tests/AppUITests/Snapshots`          | Visual regressions                                 |
| XCUITest                 | `Tests/AppUITests`                    | High-risk UI flows                                 |
| Integration/chaos        | `Tests/IntegrationTests`              | Permission revoke, backgrounding, network drop, …  |
| Performance              | `Tests/PerformanceTests`              | CPU/GPU/RAM/battery during live session            |

The coaching frontend *is* the pose-fixture → voice-intent pipeline. The XCUITests cover the actual app shell (navigation, onboarding, settings), but the moment-to-moment correctness is guarded by the pose fixtures — which is exactly why they have to be exhaustive.

---

## Directory layout

```
gym-buddy-prd/
├── PRD.md               ← source spec
├── VISION.md
├── ROADMAP.md
├── README.md
├── docs/
│   ├── PRD.md                     ← my restatement
│   ├── ARCHITECTURE.md            ← you are here
│   ├── MILESTONES.md
│   ├── OPEN_QUESTIONS.md
│   ├── Safety.md
│   ├── Privacy.md
│   ├── Telemetry.md
│   └── decisions/
│       └── 0001 – 0007 (one ADR per open decision)
├── GymBuddy/
│   ├── Package.swift              ← root SwiftPM workspace
│   ├── Sources/
│   │   ├── CoachingEngine/        ← pure Swift, domain
│   │   ├── PoseVision/            ← Apple Vision wrapper
│   │   ├── VoiceIO/               ← TTS/STT/VAD/audio session
│   │   ├── LLMClient/             ← LLM abstraction + prompts
│   │   ├── Persistence/           ← SwiftData store
│   │   ├── HealthKitBridge/
│   │   ├── DesignSystem/
│   │   ├── Telemetry/
│   │   └── GymBuddyApp/           ← iOS app composition root
│   └── Tests/
│       ├── CoachingEngineTests/
│       │   ├── Fixtures/          ← JSON pose streams
│       │   ├── Property/          ← invariants
│       │   └── HeroMoment/
│       ├── PoseVisionTests/
│       ├── VoiceIOTests/
│       ├── LLMClientTests/
│       │   └── Evals/             ← golden prompts
│       ├── PersistenceTests/
│       ├── IntegrationTests/
│       └── AppUITests/
└── .github/workflows/ci.yml
```

---

## What stays true across every chapter

- `CoachingEngine`'s public API takes *abstract body state*, not pose keypoints specifically. This is how Chapter 5 (IMU fusion) becomes a new input adapter, not an engine rewrite.
- `VoiceIO` accepts *coaching intents*, not raw strings. The engine says "encourage on rep N bottom"; `VoiceIO` decides which cached variant to play. This is how Chapter 4 (Watch haptic-only mode) becomes a new output adapter.
- `PoseVision` and `VoiceIO` both hide their vendor behind a protocol. Vision → MediaPipe swap and ElevenLabs → OpenAI-TTS swap are package-internal.
- Every persistent type has a schema version and a migration. Never ship a destructive migration without an explicit user-consent flow.

If a future PR needs to break any of these, the discussion is "update the architecture doc first" — not a silent deviation.
