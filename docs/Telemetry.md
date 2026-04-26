# Telemetry — event schema

*Local-only ring buffer in MVP. See ADR-0007 for the policy rationale.*

---

## Event envelope

```swift
public struct TelemetryEvent: Codable, Equatable {
    public let id: UUID
    public let kind: EventKind
    public let payload: EventPayload
    public let timestamp: Date
    public let sessionIdRef: UUID?     // if attached to a session
    public let schemaVersion: Int      // increments per migration
}
```

## Kinds (complete list)

### Session lifecycle
- `session.started { exerciseId, setNumber, plannedReps }`
- `session.ended { exerciseId, setNumber, actualReps, duration_s, endReason }`
  `endReason ∈ { autoDetected, userTapped, userVoice, interruptedCall, backgrounded, paused }`

### Coaching signal
- `rep.detected { exerciseId, repNumber, concentric_ms, eccentric_ms, romScore }`
- `cue.fired { exerciseId, cueType, severity, latency_ms }`
- `tempo.slowdownDetected { exerciseId, repNumber, ratioToBaseline }`
- `intent.emitted { intentKind, priority }`

### Voice IO
- `voice.played { tier, phraseId, variantIndex, latency_ms }`
- `voice.cacheMiss { phraseId }`
- `voice.ttsError { vendorErrorCode }`
- `stt.transcribed { duration_ms, onDevice: Bool }`
- `vad.speechDetected { duration_ms }`

### LLM
- `llm.called { promptId, promptVersion, tokensIn, tokensOut, latency_ms }`
- `llm.streamFirstToken { latency_ms }`
- `llm.safetySubstitution { category }`
- `llm.error { httpStatus, errorCode }` (no body content)

### Permissions + chaos
- `permission.requested { kind }` / `permission.granted { kind }` / `permission.denied { kind }`
- `permission.revoked { kind, midSession: Bool }`
- `system.interruption { kind }` `kind ∈ { call, siri, route, lowPower, background }`
- `network.changed { reachable: Bool }`

### App lifecycle
- `app.launched { coldStart: Bool, launchToFirstPaint_ms }`
- `app.backgrounded` / `app.foregrounded`
- `crash.logged { stackHash }` (hash, not stack)

### Safety
- `safety.painDetected { source: stt | userTap }`
- `safety.sessionPaused { reason }`

## Privacy rules for every event

- **No body metrics** (weight, body fat, specific HealthKit values).
- **No user speech content** (STT events log duration, not transcript).
- **No coach text** (LLM events log token counts, not text).
- **No PII** (no name, no email, nothing identifying).
- **No raw error messages** (we log codes and hashes).

## Storage

- SQLite table `telemetry_event` in a separate file from `persistence.sqlite`.
- Ring buffer: drop oldest when count exceeds 10,000 rows OR age exceeds 7 days.
- Schema versioned; migrations ship with the app update.

## Export

Settings → "Share diagnostics with developer" opens a share sheet with the compressed event log (JSONL). User-initiated only. No automatic export in MVP.

## What we *will* use this for

- Debugging reported issues ("my rep count was off on session 4 at 7:23 pm" — we look at `rep.detected` stream for that session).
- Measuring cue latency distributions in the field (histogram of `cue.fired.latency_ms`).
- Finding crash patterns (`crash.logged` stackHash aggregation).

## What we *won't* use this for (in MVP)

- Funnel analysis, A/B tests, retention tracking. No vendor, no analytics pipeline.
- Behavior modeling. Not interesting at this scale.
