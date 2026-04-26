# ADR-0002: TTS vendor = ElevenLabs; Tier 1 cache generated at build time

**Date:** 2026-04-19
**Status:** Accepted
**Context window:** PRD §5.3, §7.8, §13 item 2

## Context

Two coupled decisions:
1. Which TTS vendor?
2. When is the Tier 1 (in-set) phrase cache generated — build time, first run, or on demand with permanent caching?

## Options for vendor

| Vendor        | Voice quality | Streaming API | Latency (streaming) | Cost        | Notes                                                    |
|---------------|---------------|---------------|---------------------|-------------|----------------------------------------------------------|
| ElevenLabs    | Highest       | Yes           | ~250 ms TTFB        | Pay/char    | Best at the warm-but-demanding coach voice; SSML support |
| OpenAI TTS    | High          | Yes           | ~400 ms TTFB        | Pay/char    | Good, a bit flatter; cheaper                             |
| Apple `AVSpeechSynthesizer` | Low  | N/A           | Instant             | Free        | **PRD explicitly rejects for the hero demo** (§7.8)      |

ElevenLabs wins on voice quality, which is the core MVP experience — PRD §7.8 calls the voice "a core part of the product experience, not a polish-phase upgrade."

## Options for cache timing

- **Build time:** TTS pre-generated during a CI step; audio assets bundled in the `.ipa`.
- **First run:** App downloads the cache on first launch from our CDN.
- **On demand:** Phrases are TTS'd on first use and cached forever.

## Decision

**ElevenLabs, build-time cache.**

- Build-time generation is the only option that lets the hero loop run offline on day one. First-run download makes "install the app on airplane mode, do a push-up set" fail.
- We maintain a `TTSCacheManifest.json` listing every Tier 1 phrase and variant, with checksums. Build step runs a Swift script that reads the manifest, checks the repo cache of generated MP3s, and regenerates any missing/checksum-mismatched variants. Generated assets are committed under `GymBuddy/Resources/TTSCache/` so non-network builds work.
- Tier 2 (between-set, summaries, conversation) uses ElevenLabs streaming at runtime — no cache needed because there's rest time to work with.

## Bundle-size budget

Estimated cache:
- Rep counts 1–50 × 3 tones × 7 variants = 1,050 phrases
- ~25 motivational phrases × 3 tones × 7 variants = 525 phrases
- ~18 form-cue phrases × 3 tones × 5 variants = 270 phrases
- Total ≈ 1,850 phrases × ~45 KB each (MP3, low-overhead mono) ≈ 80–90 MB raw

That's too big. Mitigation:
- Ship **two tones** only in the base install (standard + one other picked at onboarding). The third is downloaded on demand and cached permanently. Saves ~30 MB typical.
- Use HE-AAC at 48 kbps mono instead of MP3. Voice quality remains transparent; file size drops ~40%.
- Only ship 5 variants per phrase in initial build; variants 6–8 are background-downloaded and spliced in. No-repeat window handles the gap during the download.

Revised estimate: ~25–35 MB in the base install. Acceptable.

## Trade-offs

- **+** Zero in-set TTS latency, offline-capable, deterministic.
- **+** Strong voice quality; matches the PRD bar.
- **−** Vendor lock-in to ElevenLabs (mitigated: `VoiceIO` hides them behind a protocol).
- **−** Install size up by ~25–35 MB. Acceptable for a fitness app users install once.
- **−** Build pipeline needs API access to ElevenLabs during TTS generation steps. Documented in `CONTRIBUTING.md`.

## Revisit date

End of M3. If voice quality doesn't hold up in user testing, or if the bundle-size approach is worse than expected, reopen.
