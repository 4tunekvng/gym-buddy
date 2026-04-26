# ADR-0005: Rep/set state machine — hand-rolled

**Date:** 2026-04-19
**Status:** Accepted
**Context window:** PRD §13 item 5

## Context

We need state machines for: rep detection per exercise, set-end detection, session lifecycle. Options: hand-rolled `enum`-based FSM, or a library like Swift StateKit / Stateful.

## Decision

**Hand-rolled.** Per-exercise rep FSMs are simple (4 states: top / descending / bottom / ascending). Session FSM is also small. Library overhead (API learning, extra dependency, generic-heavy type gymnastics) is not worth it for this shape of problem.

## Shape of the hand-rolled FSM

```swift
enum RepPhase: Equatable {
    case top, descending, bottom, ascending
}

protocol ExerciseRepModel {
    associatedtype Observation
    mutating func observe(_ sample: PoseSample) -> RepEvent?
    var phase: RepPhase { get }
    var tempoSamples: [RepTempoSample] { get }
}
```

One concrete `RepModel` per exercise. `CoachingEngine` owns a dictionary from `ExerciseID` to current `RepModel`. Zero third-party types crossing module boundaries.

## Trade-offs

- **+** Zero dependency, easiest to understand.
- **+** Tailoring the FSM per exercise is trivial (state semantics differ between push-up and row).
- **+** Testable with plain `XCTest`, no library-specific tooling.
- **−** If we end up wanting a hierarchical state machine (Chapter 5 might), we'll add that complexity ourselves. Fine — we'd rather grow it than import an abstraction now.

## Revisit date

If we end up with > 6 nested states or need cross-state side-effect handling that's getting awkward, revisit.
