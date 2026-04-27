# How to test Gym Buddy like a real user

Three ways to do this, ordered from easiest to most realistic. Pick the one that matches what you want.

| Option | Realism | Cost | Setup time | What you can test |
|---|---|---|---|---|
| **A. iOS Simulator on your Mac** | Mid | Free | 1 min | All the screens, navigation, persistence, the synthetic-pose hero demo |
| **B. Your real iPhone** | High | Free | 15–30 min one-time | Everything in A, plus a real device (no real camera/Vision yet — that's M2 work) |
| **C. TestFlight (share with friends)** | Highest | $99/year | 1–2 hours one-time | What an actual beta tester sees |

You only need **one** of these to get going. Most people start with A and move to B once they want to feel the app on their actual phone.

---

## Option A — Run on the iOS Simulator (easiest, 1 minute)

This is what you've already seen working in our session. The simulator is an iPhone running on your Mac.

### Once-only setup

1. Make sure Xcode is installed (you have this) and is the active toolchain:
   ```bash
   xcode-select -p
   ```
   It should print `/Applications/Xcode.app/Contents/Developer`. If it prints something with "CommandLineTools" instead, run:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```
2. Install `xcodegen` (a tool that generates the Xcode project from `project.yml`):
   ```bash
   brew install xcodegen
   ```

### Every time you want to run the app

```bash
cd ~/personal_projects/gym-buddy-prd
./scripts/run-simulator.sh
```

That's the whole thing. It:
- Regenerates the Xcode project so it's always in sync with the code.
- Builds the app.
- Boots a simulated iPhone 17 and opens the Simulator window.
- Installs and launches Gym Buddy.

To start fresh (re-do onboarding):
```bash
./scripts/run-simulator.sh --reset
```

To use a different simulated phone:
```bash
./scripts/run-simulator.sh "iPhone 16"
```

### The 60-second smoke test (do this first)

This is the fastest way to confirm the hero loop is working — and the closest thing to "what an actual user feels":

1. **Turn your Mac volume up** — the coach actually speaks now (via `AVSpeechSynthesizer`).
2. `./scripts/run-simulator.sh --reset`
3. Tap **Get started** → type a name → tap **Continue** until you reach **Today**.
4. Tap **Push-up**, then **Start set**.
5. **Listen.** You should hear the coach count "one, two, three…" out loud as the rep counter climbs. Around rep 7–8 you'll hear "one more" / "push" — that's the hero moment from PRD §2.
6. Watch the speaker bubble at the bottom of the live screen — it shows the exact phrase that was just spoken, so you can verify what audio is firing even if the speakers are off.
7. The set ends near rep 10; you'll land on the **Set done** summary.

If you can hear the count and see the bubble matching, the audio + rep loop are wired correctly end-to-end.

### What else to try

- Walk through every onboarding step — the Continue/Back footer is pinned to the bottom and the option list scrolls if it overflows. (Step 2 "Goal" used to clip on smaller phones; this is fixed.)
- Read the warm summary, tap **Back to today**.
- Tap the clock icon (top-left) — you should see the session you just did.
- Tap the gear icon (top-right) — change tone preference, kill the app, relaunch, confirm it stuck.
- The cancel button on the live session setup should bail back to Today without saving.

### Limitations of the Simulator

- **No camera.** The app falls back to a synthetic pose stream (a built-in 10-rep demo) — that's why the rep counter still ticks up. On a real device with the camera, this is what would be driven by your actual movement.
- **No HealthKit data.** The mock health reader is wired up.
- **System TTS only — not the production voice.** The Simulator (and on-device until M3) speaks with `AVSpeechSynthesizer`. The premium ElevenLabs phrase cache that ships in M3 is what real users will hear; this is a strictly better fallback than silence.

For everything else (navigation, persistence, copy, accessibility, the hero flow logic, **and audible coaching**), the simulator is faithful.

---

## Option B — Run on your real iPhone (most realistic, 15–30 min once)

You don't need a paid Apple Developer account. A free Apple ID works — the app will run on your phone for **7 days** before needing to be re-deployed (just rerun the steps).

### Step 1: One-time Xcode setup

1. Open Xcode. (`open -a Xcode` in Terminal, or click it in Applications.)
2. Top-left menu: **Xcode → Settings... → Accounts**.
3. Click the **+** at the bottom-left → **Apple ID** → sign in with your Apple ID. If you don't have one, create one at [appleid.apple.com](https://appleid.apple.com) — takes 2 minutes.
4. Once signed in you'll see your name in the Accounts list with a "Personal Team" listed below.

### Step 2: Open the project in Xcode

```bash
cd ~/personal_projects/gym-buddy-prd/GymBuddy
xcodegen generate --spec project.yml
open GymBuddyApp.xcodeproj
```

In Xcode:
1. In the left sidebar, click the blue **GymBuddyApp** icon at the top.
2. In the middle pane, click the **GymBuddyApp** target (under TARGETS).
3. Click the **Signing & Capabilities** tab.
4. Check **Automatically manage signing**.
5. **Team**: choose your name from the dropdown (it shows "Personal Team").
6. **Bundle Identifier**: change `com.gymbuddy.app` to something unique to you, like `com.fortune.gymbuddy.app`. (Apple requires globally unique IDs even for personal builds.)

### Step 3: Connect your iPhone

1. Plug your iPhone into the Mac with a Lightning or USB-C cable.
2. Unlock the iPhone. If it asks "Trust this computer?" — tap **Trust** and enter your passcode.
3. **First time only**: enable Developer Mode on the phone. On the iPhone go to **Settings → Privacy & Security → Developer Mode → On**, then restart the phone when prompted.

### Step 4: Run

1. In Xcode's top toolbar, find the destination dropdown (says "iPhone 17" or similar). Click it and pick **your iPhone** by name.
2. Press the **▶ Play** button (or `Cmd-R`).
3. Xcode will build the app and install it. First time it can take 1–3 minutes.
4. **First time only**: the iPhone will refuse to launch the app with a popup that says "Untrusted Developer". On the iPhone:
   - **Settings → General → VPN & Device Management** (sometimes called "Profiles & Device Management").
   - You'll see your Apple ID under "Developer App". Tap it → **Trust [your name]** → **Trust** in the confirmation.
5. Go back to Xcode and press **▶ Play** again. The app launches on your phone.

### What you can now test on the real device

- **Camera**: the live session will try to use the front camera. The Vision-based rep detection compiles but hasn't been calibrated against real pose data — it'll work or be jittery; that's the M2 work.
- **HealthKit permission flow**: the app will ask for permission the first time it tries to read HRV/sleep.
- **Microphone permission flow** (between-set Q&A path).
- **Real haptics + audio routing** — TTS speaks through the device speakers (system synth until M3 swaps in ElevenLabs).
- **The actual feel of the app at retina speed.**

After 7 days the app will refuse to launch on the phone. Just rerun **Step 4** above to redeploy.

---

## Option C — Share with friends via TestFlight (paid, 1–2 hours once)

This is what real beta testing looks like. Apple's Developer Program costs **$99/year**. Worth it once you want a dozen friends to try the app for a month per the PRD's quality bar.

### Step 1: Enroll

1. Go to [developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll).
2. Sign in with the same Apple ID you used in Xcode.
3. Pay $99. Approval is usually instant for individuals; can take 1–2 days for the first enrollment.

### Step 2: Create the app record in App Store Connect

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com).
2. **My Apps → +** → **New App**.
3. Fill in:
   - **Platform**: iOS
   - **Name**: Gym Buddy (or your variant if you want)
   - **Primary Language**: English
   - **Bundle ID**: pick the one that matches your Xcode project (the unique one from Option B Step 2.6)
   - **SKU**: anything unique, e.g. `gymbuddy-001`
4. Click Create.

### Step 3: Archive + upload from Xcode

1. In Xcode, top toolbar destination dropdown: pick **Any iOS Device (arm64)** (not a simulator).
2. Top menu: **Product → Archive**. Takes a few minutes.
3. When done the **Organizer** window opens automatically.
4. Click **Distribute App → TestFlight & App Store → Distribute**.
5. Xcode uploads the archive to App Store Connect. Takes 5–15 minutes for processing on Apple's side.

### Step 4: Invite testers

1. Back in App Store Connect → your app → **TestFlight** tab.
2. Wait for the build to finish processing (you'll see it transition from "Processing" to "Ready to Test").
3. Apple needs to approve "missing compliance" (export compliance — it's a checkbox saying you don't use exotic encryption — answer No).
4. **Internal Testing**: add up to 100 of your Apple ID emails. They install via the **TestFlight** app on iOS.
5. **External Testing**: requires Apple Beta Review (1–2 days first time). Then invite by email; testers tap a link, install TestFlight, install the app.

This is a one-time setup — every subsequent build just needs Steps 3 + 4 (a few clicks once Apple knows the app).

---

## Push the code to a GitHub repo

I already verified there are **no secrets** in the code (no API keys committed) and made an initial commit ready to go. You just need to authenticate to GitHub from your machine.

### Step 1: Authenticate (only you can do this)

In Terminal:

```bash
gh auth login
```

You'll be prompted:
- **What account?** → **GitHub.com**
- **Preferred protocol** → **HTTPS** (easiest) or SSH if you've used it before.
- **Authenticate Git with your GitHub credentials?** → **Yes**.
- **How would you like to authenticate?** → **Login with a web browser**.

It prints a one-time code. Press Enter, your browser opens, you paste the code, click authorize. Done.

### Step 2: Create the repo and push

After auth, run this single command:

```bash
cd ~/personal_projects/gym-buddy-prd
gh repo create gym-buddy --private --source=. --remote=origin --push
```

This creates a **private** GitHub repo named `gym-buddy` and pushes everything there in one step. After it finishes, run:

```bash
gh repo view --web
```

…to open it in your browser.

### What gets pushed and what doesn't

Pushed: all source code, tests, docs, the `project.yml`, this guide, scripts.

NOT pushed (because of `.gitignore`):
- `.DS_Store` macOS junk
- `GymBuddy/.build/`, `GymBuddy/.swiftpm/` — build outputs
- `GymBuddy/GymBuddyApp.xcodeproj/` — auto-generated by xcodegen
- `.env`, any `apiKey*.plist`, any `*.pem` — never commit secrets
- `GymBuddy/Resources/TTSCache/` — regenerated from manifest

### Want it public instead?

Change `--private` to `--public` in the command above.

### Want a different name?

Replace `gym-buddy` with your preferred name in the command. Bundle IDs in iOS don't have to match repo names.

---

## Quick reference

```bash
# Run on simulator
./scripts/run-simulator.sh

# Run on simulator with fresh state
./scripts/run-simulator.sh --reset

# Run all unit tests
cd GymBuddy && swift test

# Run the hero demo in the terminal (no UI)
cd GymBuddy && swift run coaching-cli

# Run all UI tests (~3 min)
cd GymBuddy && xcodebuild -project GymBuddyApp.xcodeproj -scheme GymBuddyApp \
  -destination "platform=iOS Simulator,name=iPhone 17" test

# Push to GitHub (one-time, after gh auth login)
gh repo create gym-buddy --private --source=. --remote=origin --push
```

If anything goes sideways, paste the error back into Claude — I'll debug.
