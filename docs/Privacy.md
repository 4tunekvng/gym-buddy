# Privacy — data flow, on-device guarantees

*Source: PRD §9. This document is the data-flow table the rest of the team (and any auditor) can read without reading the code.*

---

## What stays on the device, always

| Data                           | Storage                                       | Ever leaves device? |
|--------------------------------|-----------------------------------------------|---------------------|
| Raw camera frames              | Never persisted                               | **No.** Ever.       |
| Pose keypoints (derived)       | Per-session summary in SwiftData              | **No.**             |
| STT audio (user speech)        | Processed on-device where supported           | See below           |
| HealthKit data (HRV, sleep)    | Read on-device via HealthKit                  | **No.**             |
| Coach memory notes             | SwiftData                                     | **No.**             |
| Session logs                   | SwiftData                                     | **No.**             |
| Telemetry event log            | Separate SQLite ring buffer                   | **No.** (user can export via share sheet) |

## What leaves the device, when, to whom

| Data                                | Destination            | When                                           | User consent           |
|-------------------------------------|------------------------|------------------------------------------------|------------------------|
| Coach phrase text (synthesized)     | ElevenLabs             | Tier 2 streaming TTS (between-set, summaries)  | Implicit via app install + settings acknowledgement |
| Prompt text (LLM)                   | Anthropic              | LLM reasoning calls                            | Implicit, with on-boarding disclosure                |
| Transcribed user speech             | Anthropic (in prompt)  | Between-set Q&A (only what the user said; their voice audio does **not** leave) | Clear on-screen "Processing…" indicator during Q&A |

No user audio. No video. No pose data. No HealthKit data. Only the text of what the coach is about to say, and the text of what the user asked.

## STT (user's voice)

Apple Speech framework is used. On supported iPhones (13 Pro and newer for on-device dictation), we pass `requiresOnDeviceRecognition = true`. If the user is on an older device, STT falls back to Apple's server-side recognizer — this is Apple's system path, their privacy terms apply, and we disclose it in Settings → Privacy. The user can disable server-side STT in Settings, at the cost of mic-input features on those devices.

## HealthKit

Read-only. Scope: `heartRate`, `heartRateVariabilitySDNN`, `sleepAnalysis`, `bodyMass` (optional, user-toggleable). We write nothing back in MVP.

Full authorization string surfaced at first morning-readiness check-in. User can deny and the feature degrades to "unadjusted plan" mode.

## Analytics / telemetry

Local ring buffer only. See ADR-0007. The "Share anonymous diagnostics" toggle in Settings is UI-present but a no-op in MVP, with explicit disclosure text.

## Crash reporting

Apple's native crash reports via Xcode Organizer. No third-party crash SDK. No user-identifying payloads attached.

## Data deletion

Settings → "Erase all data" performs: drop both SQLite databases, clear the TTS cache, clear the memory-note store. On confirmation, the app returns to its blank-install state.

## User-visible disclosures

On-install onboarding screen: *"Gym Buddy processes pose and audio on your phone. The only thing we send to a server is the text our coach is about to say out loud, and questions you ask the coach between sets. Your video and voice recordings stay on this phone."*

Settings → Privacy: restates the above with links to ElevenLabs' and Anthropic's privacy policies.

## Load-bearing promises

- **Pose frames never leave the device.** Verified in CI via a lint step that grep-fails on any `URLSession` or networking import in `PoseVision`.
- **HealthKit is read-only.** Verified in CI: `HealthKitBridge` does not call any write-side HealthKit API.
- **No crash reporter sees user data.** Verified: no third-party crash SDK in the project.
- **The "Share diagnostics" toggle is a no-op in MVP.** Verified: the toggle binding points to a property with a visible `// no-op in MVP` comment and is covered by a test that asserts no network call is made when toggled.
