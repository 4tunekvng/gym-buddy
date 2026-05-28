#!/usr/bin/env bash
# Generate Tier-1 TTS audio assets per the PhraseManifest. See ADR-0002.
#
# The resulting mp3 files land under GymBuddy/Resources/TTSCache/<tone>/<phrase>/<variant>.mp3
# and are bundled into the app (.ipa) at build time. They are .gitignored because
# regenerating them is cheap given an API key and deterministic.
#
# Requires:
#   - ELEVENLABS_API_KEY in env
#   - jq, curl
#
# Usage:
#   scripts/generate-tts-cache.sh [--tone standard|quiet|intense] [--only-missing]

set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -z "${ELEVENLABS_API_KEY:-}" ]]; then
  echo "ERROR: ELEVENLABS_API_KEY not set." >&2
  exit 1
fi

TONE="standard"
ONLY_MISSING=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tone)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "ERROR: --tone requires a value (standard|quiet|intense)" >&2
        exit 1
      fi
      TONE="$2"
      shift 2
      ;;
    --only-missing)
      ONLY_MISSING=1
      shift
      ;;
    *)
      echo "ERROR: Unknown argument '$1'" >&2
      exit 1
      ;;
  esac
done

if [[ ! "$TONE" =~ ^(standard|quiet|intense)$ ]]; then
  echo "ERROR: Invalid tone '$TONE'. Must be one of: standard, quiet, intense" >&2
  exit 1
fi
OUT="GymBuddy/Resources/TTSCache/$TONE"
mkdir -p "$OUT"

echo "Generating Tier-1 cache for tone=$TONE into $OUT"
echo "(This is a stub — full implementation ships in M3. See ADR-0002 for the plan.)"
