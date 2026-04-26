# ADR-0007: Telemetry = local-only event log (no vendor in MVP)

**Date:** 2026-04-19
**Status:** Accepted
**Context window:** PRD §9, §13 item 7

## Context

We need some form of telemetry to debug field issues and measure product quality. PRD forbids sending PII/body metrics to a vendor and defaults to "no vendor in MVP."

## Decision

**Local-only event log, ring buffer of 7 days, no cloud egress in MVP.**

## Shape

- `Telemetry` package, no network dependencies.
- Events are structured: `TelemetryEvent(id, kind, payload, timestamp)`.
- Stored in a separate SQLite file from the main persistence store (so wiping telemetry can't touch user data).
- Ring buffer drops oldest events when the table exceeds `N` rows or the age exceeds 7 days (whichever comes first).
- A Settings screen exposes a "Send diagnostics to developer" action — when tapped, the user gets a native iOS share sheet with the log as a compressed attachment. **Nothing leaves the device without explicit user action.**
- An opt-in toggle is present ("Share anonymous diagnostics") but wired to a no-op in MVP. Text under the toggle: *"Currently stored on this device only. Future versions may offer optional cloud-side sharing — you'll be asked again before any change."*

## Events we log (complete schema in `docs/Telemetry.md`)

- `session.started` / `session.ended`
- `rep.detected { exercise, count, tempo_ms }`
- `cue.fired { exercise, cue_type, severity, latency_ms }`
- `voice.played { tier, phrase_id, latency_ms }`
- `llm.called { prompt_id, tokens_in, tokens_out, latency_ms, safety_triggered }`
- `error.caught { domain, code, stack_hash }` (stack hash, not the stack — privacy)
- `permission.revoked { kind, mid_session: Bool }`

No body metrics. No session pose data. No user speech content.

## Trade-offs

- **+** Keeps our privacy promise unconditionally.
- **+** Zero vendor dependency; nothing to swap if the vendor is later acquired/shut down.
- **−** We can't see field issues in real time. Mitigation: the user-initiated share-sheet export is enough for the scale of our test group (~10).

## Revisit date

Post-TestFlight. If the test group volume makes user-initiated export impractical, design a proper anonymized telemetry pipeline with clear consent — Chapter 2 work.
