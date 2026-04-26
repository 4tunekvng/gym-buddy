#!/usr/bin/env bash
# scripts/run-simulator.sh — one-command "open the app on the iOS Simulator".
#
# Walks through:
#   1. Regenerate the Xcode project from project.yml (so it's always fresh).
#   2. Build the app for the iPhone 17 Simulator.
#   3. Boot the simulator (and open the Simulator window so you can see it).
#   4. Install + launch the app on it.
#
# Usage:
#   ./scripts/run-simulator.sh                 # uses iPhone 17
#   ./scripts/run-simulator.sh "iPhone 16"     # any device name from `xcrun simctl list devices available`
#   ./scripts/run-simulator.sh --reset         # also wipes any previous install (fresh-onboarding)
#
# What you should see:
#   - Simulator app opens and shows an iPhone.
#   - Welcome screen → tap "Get started" → walk through onboarding → "Today" → tap a push-up.

set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="iPhone 17"
RESET=0
for arg in "$@"; do
  case "$arg" in
    --reset) RESET=1 ;;
    *)        DEVICE="$arg" ;;
  esac
done

# --- preflight ---------------------------------------------------------------
command -v xcodegen >/dev/null 2>&1 || {
  echo "xcodegen is missing. Install it once with:"
  echo "  brew install xcodegen"
  exit 1
}
command -v xcodebuild >/dev/null 2>&1 || {
  echo "Xcode is not installed (or 'xcode-select -p' points at Command Line Tools only)."
  echo "Install Xcode from the App Store, then run:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
}

cd GymBuddy

# --- regenerate the Xcode project --------------------------------------------
echo "==> Regenerating GymBuddyApp.xcodeproj from project.yml"
xcodegen generate --spec project.yml >/dev/null

# --- build for the simulator -------------------------------------------------
DERIVED=/tmp/gym-app-derived
echo "==> Building for $DEVICE (this is fast on a warm cache)"
xcodebuild -project GymBuddyApp.xcodeproj \
           -scheme GymBuddyApp \
           -destination "platform=iOS Simulator,name=$DEVICE" \
           -derivedDataPath "$DERIVED" \
           -quiet \
           build

APP_PATH=$(find "$DERIVED" -name "GymBuddyApp.app" -type d | head -1)
if [ -z "$APP_PATH" ]; then
  echo "Build succeeded but the app bundle wasn't found under $DERIVED."
  exit 1
fi

# --- boot + open simulator ---------------------------------------------------
echo "==> Booting $DEVICE"
SIM_ID=$(xcrun simctl list devices available | grep "$DEVICE " | head -1 | grep -oE '[A-F0-9-]{36}')
if [ -z "$SIM_ID" ]; then
  echo "No available simulator named '$DEVICE'. Try one of:"
  xcrun simctl list devices available | grep -E "iPhone|iPad" | head -5
  exit 1
fi
xcrun simctl boot "$SIM_ID" 2>/dev/null || true
open -a Simulator

# --- install + launch --------------------------------------------------------
if [ "$RESET" = "1" ]; then
  echo "==> Wiping previous install (--reset)"
  xcrun simctl terminate "$SIM_ID" com.gymbuddy.app 2>/dev/null || true
  xcrun simctl uninstall "$SIM_ID" com.gymbuddy.app 2>/dev/null || true
fi

echo "==> Installing"
xcrun simctl install "$SIM_ID" "$APP_PATH"

echo "==> Launching"
xcrun simctl launch "$SIM_ID" com.gymbuddy.app >/dev/null

echo ""
echo "Done. The Simulator window should now show Gym Buddy."
echo "If you don't see it, click the Simulator icon in your Dock."
echo ""
echo "Tip: run with --reset to wipe your previous data and see the onboarding from scratch."
