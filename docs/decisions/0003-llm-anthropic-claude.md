# ADR-0003: LLM vendor = Anthropic (Claude)

**Date:** 2026-04-19
**Status:** Accepted
**Context window:** PRD §7.6, §13 item 3

## Context

LLM is used for onboarding synthesis, plan generation, between-set conversation, post-set summary, morning readiness interpretation, coach memory note extraction. Not used for rep counting, cue firing, or set-end detection.

## Evaluated

Claude, GPT-4/5, Gemini, on four axes:
1. **Reasoning quality** for structured coaching tasks (plan generation, memory extraction).
2. **Tone** — the MVP coach is warm, honest, demanding, never sycophantic.
3. **Safety posture** — we need a model that refuses medical diagnosis cleanly.
4. **Latency + streaming** — the between-set budget is 2.5 s.

## Decision

**Claude** (via the Anthropic SDK), with the specific model chosen at runtime via a model-id constant in `LLMClient.Configuration`.

**Model selection rationale:**
- Tone: Claude's default register is closer to the coach we want than GPT's default "cheerful assistant" tone. Less prompt work to get there.
- Safety: Constitutional-AI training + Anthropic's strong stance on refusing medical diagnosis aligns with our §10.8 safety requirements.
- Reasoning: Claude Opus 4.x handles the "generate a 4-week plan given goals + injuries + equipment" task reliably in evals.
- Streaming: Anthropic's streaming API has competitive TTFB for the between-set use case.

**Tradeoff accepted:** Our best model on Anthropic is more expensive per token than some alternatives. At our expected token volume (a few hundred tokens per session, a dozen sessions per user per month), per-user monthly cost is negligible. Not the axis to optimize on in Chapter 1.

## Implementation notes

- Model id stored in `LLMClient/Configuration.swift` — changeable via a single constant without code surgery.
- Prompts versioned in `LLMClient/Prompts/`, one markdown file per prompt, with a `@version` tag.
- Every prompt has an eval suite in `Tests/LLMClientTests/Evals/`.
- Every LLM response passes through `ContentSafetyFilter` (in `CoachingEngine`, so the safety filter stays pure Swift and doesn't depend on the vendor).

## Revisit date

End of M3. If eval results reveal a specific task where another vendor is markedly better, spin up a per-task routing layer — Chapter 2+ work.
