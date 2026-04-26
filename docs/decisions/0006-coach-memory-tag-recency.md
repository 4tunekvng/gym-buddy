# ADR-0006: Coach memory retrieval = tag + recency, not vector search

**Date:** 2026-04-19
**Status:** Accepted
**Context window:** PRD §6.1, §13 item 6

## Context

Coach memory notes (e.g., *"left knee clicks on deep squats"*, *"hates tempo work"*) need to be retrievable by the LLM at prompt time so between-set responses and morning check-ins feel continuous. Options:

- **Tag + recency:** each note has tags (`injury`, `preference`, `mood`, `context`, `equipment`, `body-part:knee`) and a timestamp. Retrieval is "give me all notes matching tag-filter X, sorted by recency, top N."
- **Vector search:** embed notes, embed query, cosine similarity, top K.

## Decision

**Tag + recency for MVP.** Defer vector search to when we see a concrete failure mode that tags can't solve.

## Reasoning

- The note corpus for a single user in Chapter 1 is small — an upper bound of maybe 200 notes after 6 months of use. Scan cost is negligible.
- Tag-based retrieval is deterministic, auditable, and trivially testable — the opposite of vector retrieval's "why did it surface this one?" debugging.
- Tag categories map naturally to the things the coach needs to reference (body parts, injuries, preferences, recent moods). The LLM tags a note at write time; retrieval just queries tag indexes.
- Vector retrieval adds: an embedding model (local or remote — local adds binary size and battery cost, remote violates our privacy posture), an embedding index, a similarity threshold to tune, and a failure mode where unrelated-but-similar notes surface.

## When we'd reopen

- Tag catalog grows past ~40 tags and the LLM can't pick the right one reliably.
- Users write free-form notes we can't tag cleanly.
- We need "semantic" recall — *"what's that thing the user said about gym timing?"* when the note wasn't tagged `schedule`.

In Chapter 1, none of those is true.

## Implementation

- `CoachMemoryNote(id, content, tags: Set<String>, createdAt, linkedSessionId?)`.
- Retrieval API: `memoryStore.recent(matching: [String], limit: Int) -> [CoachMemoryNote]`.
- LLM includes up to 6 retrieved notes in its context before generating a between-set response or morning greeting.
- Note creation happens via a post-hoc LLM pass on onboarding output, between-set chat transcripts, and post-session user voice reflections (opt-in).

## Trade-offs

- **+** Deterministic, auditable, trivially fast, zero extra dependencies.
- **−** Cannot do semantic recall across off-tag vocabulary.

## Revisit date

End of Chapter 2 or when we see the first concrete miss that tags can't solve.
