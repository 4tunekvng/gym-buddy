# ADR-0001: Use SwiftData for persistence

**Date:** 2026-04-19
**Status:** Accepted
**Context window:** PRD §13 item 1, §8 data model

## Context

We need an on-device data store for workout sessions, user profile, plan, cue events, and coach memory notes. Two realistic options: **SwiftData** (Apple's modern ORM on top of Core Data) or **GRDB** (a well-regarded community SQLite wrapper).

## Options considered

### SwiftData
- First-party, ships with iOS 17 (our deployment target).
- Model-driven migrations via `SchemaMigrationPlan`.
- Native `@Model` macros and Swift Observation integration work cleanly with SwiftUI.
- Downsides: young API; some gaps around complex predicates and CloudKit sync behavior when projects grow; harder to unit-test without an in-memory configuration (there is one, and we use it).

### GRDB
- Proven, mature, excellent docs.
- Full control over SQL and schema.
- More manual migration and query plumbing.
- Heavier community dependency; swapping it out later is work.

## Decision

**SwiftData.** Chapter 1's entity set is small and boring (the list in PRD §8). It fits SwiftData's happy path. The SwiftUI ergonomics matter for our UI layer, and we avoid pulling in a third-party dependency for something Apple already ships. If we hit a SwiftData limitation we can't live with, we swap — because our `Persistence` package already exposes a protocol-based repository API that the app uses, not the SwiftData types directly.

## Trade-offs

- **+** No third-party dependency; aligned with our no-dependency-default posture.
- **+** Clean SwiftUI integration, fewer boilerplate glue types.
- **+** Future migration to CloudKit sync (Chapter 11) is supported first-party.
- **−** Less control over SQL-level optimizations. We don't need them in MVP.
- **−** API maturity risk. Mitigated by hiding SwiftData behind our repository protocols so swapping to GRDB later is localized.

## Revisit date

End of M4. If SwiftData has bitten us on migrations or query performance, we swap to GRDB before TestFlight.
