# Gym Buddy — iOS (Chapter 1 MVP)

**Status:** Chapter 1 (MVP) — foundation complete, TestFlight work in progress.

Read the front-door docs first if you haven't:
- [PRD](../PRD.md) — the build contract.
- [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) — module boundaries.
- [docs/MILESTONES.md](../docs/MILESTONES.md) — what ships when.

This directory (`GymBuddy/`) is the Swift Package workspace + the iOS app target.

---

## Clone and run in under 10 minutes

1. **Requirements**: macOS with Xcode 16+ (verified on Xcode 26.4 / iOS 17 SDK). `xcodegen` for regenerating the iOS app project — `brew install xcodegen` once.
2. **Clone** this repo, then `cd GymBuddy`.
3. **Run the full test suite** (pure-Swift packages, no Xcode project needed):

    ```bash
    swift test                        # 161 tests, ~0.1s runtime
    swift test --filter NorthStarDemoTest
    swift run coaching-cli            # prints the full hero moment
    ```

   The CLI prints 13 rep events with the "one more — push" encouragement firing on rep 10 and "last one — drive" firing on rep 11, exactly as PRD §2 specifies.

4. **Regenerate the iOS app project** from `project.yml`:

    ```bash
    xcodegen generate --spec project.yml
    ```

5. **Build + run in the iOS simulator**:

    ```bash
    xcodebuild -project GymBuddyApp.xcodeproj \
      -scheme GymBuddyApp \
      -destination "platform=iOS Simulator,name=iPhone 17" \
      build

    # Install + launch:
    xcrun simctl boot "iPhone 17"
    xcrun simctl install booted /path/to/GymBuddyApp.app
    xcrun simctl launch booted com.gymbuddy.app
    ```

6. **Run the UI test suite** (onboarding end-to-end + screenshot tour):

    ```bash
    xcodebuild -project GymBuddyApp.xcodeproj -scheme GymBuddyApp \
      -destination "platform=iOS Simulator,name=iPhone 17" test
    ```

   The screenshot tour drops one PNG per screen into `/tmp/gym-tour/` so you can scan the whole flow after a run.

---

## Workspace layout

```
GymBuddy/
├── Package.swift              ← root SwiftPM manifest
├── Sources/
│   ├── CoachingEngine/        ← pure-Swift domain (sacrosanct — no platform imports)
│   ├── PoseVision/            ← Apple Vision wrapper + fixture adapter
│   ├── VoiceIO/               ← TTS cache, STT, audio session, intent mapper
│   ├── LLMClient/             ← Claude client + versioned prompts + safety wrapper
│   ├── Persistence/           ← SwiftData store + repositories
│   ├── HealthKitBridge/       ← read-only HealthKit
│   ├── DesignSystem/          ← tokens + components
│   ├── Telemetry/             ← local event log
│   └── CoachingCLI/           ← dev harness for M1 demo
├── Tests/
│   ├── CoachingEngineTests/   ← unit + property + hero-moment tests
│   ├── PoseVisionTests/
│   ├── VoiceIOTests/
│   ├── LLMClientTests/        ← prompt tests + evals
│   ├── PersistenceTests/
│   ├── TelemetryTests/
│   ├── IntegrationTests/      ← end-to-end pipeline
│   └── DependencyDirectionTests/
└── App/
    ├── GymBuddyApp/           ← iOS app SwiftUI sources + Info.plist
    └── GymBuddyAppUITests/    ← XCUITest suite
```

---

## The north-star demo test

Lives at `Tests/CoachingEngineTests/HeroMoment/NorthStarDemoTest.swift`. Run:

```bash
swift test --filter NorthStarDemoTest
```

It synthesizes a 13-rep push-up stream with a fatigue ramp, pipes it through the full coaching pipeline, and asserts:

- Exactly 13 reps counted.
- The "one more — push" encouragement fires during the first fatigue ratio (~rep 8).
- The "last one — drive" encouragement fires during the second (~rep 13).
- No safety-cue misfires on a clean form stream.
- A set-ended intent surfaces.
- A `SessionObservation` is buildable with the numeric rep count for the summary prompt.

**If this test goes red, main goes red.** It is the canonical protection of the PRD §2 moment.

---

## App setup

The SwiftPM workspace produces *library* modules and the CLI executable, but cannot produce an iOS app — that requires an Xcode project. To wire the app target:

1. In Xcode, create a new **iOS App** target at `GymBuddy/App/GymBuddyApp.xcodeproj`.
2. Delete the stock `ContentView.swift` / `<AppName>App.swift` and add the existing sources under `App/GymBuddyApp/` to the target.
3. Set **Info.plist path** to `App/GymBuddyApp/Info.plist`.
4. In target dependencies, add every SwiftPM library from the workspace: `CoachingEngine`, `PoseVision`, `VoiceIO`, `LLMClient`, `Persistence`, `HealthKitBridge`, `DesignSystem`, `Telemetry`.
5. Add the `App/GymBuddyAppUITests/` folder as a UI Test target and link it back to the app.
6. Build to a simulator or device.

A future chore will add a Tuist/XcodeGen config so this is one command.

---

## Known limits / known work

- **Voice cache assets** are not yet committed — Tier 1 TTS generation is a build-time step that needs an ElevenLabs key (see ADR-0002 and `docs/Privacy.md`). Until then the app uses the system speech synthesizer, but now rotates phrase variants and reflects the selected coaching tone more clearly.
- **Full Xcode is required** for iOS builds. The Command Line Tools Swift toolchain alone cannot currently build SwiftPM manifests on macOS 15/26 due to a known linker issue; CI must use the full Xcode.
- **LLM calls are live only when configured.** Set `ANTHROPIC_API_KEY` (or `GYMBUDDY_ANTHROPIC_API_KEY`) to enable the real Anthropic client; otherwise the app stays on the deterministic fallback path and says so in the UI.
- **UI tests now force scripted demo mode intentionally.** They set `GYMBUDDY_POSE_MODE=demo`, `GYMBUDDY_LLM_MODE=mock`, `GYMBUDDY_VOICE_MODE=mock`, and `GYMBUDDY_SCRIPTED_DEMO_PLAYBACK_RATE=3.0` so the end-to-end app tests remain deterministic without pretending the live camera path is under test or dragging the hero flow out unnecessarily.

---

## Quality gates

- `swift test` — every suite must pass.
- `swiftlint` — zero violations.
- Dependency-direction lint — `CoachingEngine` must never import platform frameworks or vendor SDKs.
- North-star demo test — must pass in CI.
- Chaos suite (`Tests/IntegrationTests/ChaosScenarioTests.swift`) — every scenario passes.
- LLM evals (`Tests/LLMClientTests/Evals/`) — every eval case passes.

See [docs/MILESTONES.md](../docs/MILESTONES.md) for per-milestone exit bars.
