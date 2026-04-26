# Gym Buddy — Vision

*This is the long view. Read this first, then ROADMAP.md, then PRD.md.*

---

## Thesis

The best personal trainers in the world are rare, expensive, and unscalable. They cost $100–200 per hour, you have to match their schedule, and only a tiny fraction of people who would benefit from one will ever work with one. Gym Buddy is a coach that watches, remembers, adapts, and pushes — built so that millions of people who currently train alone (or not at all) get something better than most of them could get from any human trainer they'd realistically hire.

We are not building "a fitness app with AI." We are building the actual coaching relationship — the form eye, the voice in your ear, the memory across months, the adjustment of today's work to yesterday's sleep — rendered in software because software can scale where humans cannot.

---

## The moment we're building toward

It's Tuesday morning. Your watch has been quietly noticing that your HRV is down for three days running and your sleep last night was rough. As you lace your shoes, your AirPods chime:

> "Morning. Before you head in — your recovery's been off this week and your sleep last night was short. I've pulled today's volume back about 15% and cut the tempo work on deadlifts. You'll still hit the main lifts. You just won't be cooked after. Sound good?"

You nod. "Yeah, that's fine."

> "Good. See you there."

Twenty minutes later you're at the rack. No phone out, no screen to squint at between sets, no tapping. The coach speaks through your AirPods and senses your position from your watch and AirPod IMUs, counting quietly as you move. On rep five of your heavy bench set, your bar speed drops 30% — the grind is real and you feel it.

> "Drive — **one more** — push."

Perfectly timed to the sticking point. Not a half-second after. You get the rep. The coach's voice softens:

> "That's the one you weren't going to do alone."

Between sets you say, "left shoulder's a bit cranky." It remembers you said that three weeks ago too.

> "Want to swap overhead press for incline dumbbell? Takes the load off the AC joint. We can come back to OHP next week."

"Yeah."

It adjusts the plan. You finish the session. Walking to the car:

> "Good one. You beat last week's volume by 4% and your bar path on bench was cleaner on the last set than the first — your warmup is working. Same time Thursday?"

That's the product. Not a feature list. A relationship.

---

## Why this is possible now, not five years ago

Four technologies matured at roughly the same time and together make this buildable:

1. **On-device human pose estimation.** Apple's Vision framework and Google's MediaPipe detect 17–33 body keypoints at 30+ fps on a phone without sending anything to a server. Five years ago this was a research problem; today it's a system API.
2. **Multimodal LLMs with long context.** Claude, Gemini, and others can reason about goals, injuries, training history, and today's state in a single conversation — holding context across weeks of sessions in a way no human coach can match at this resolution.
3. **Streaming, human-sounding TTS.** ElevenLabs and OpenAI's voice APIs crossed the uncanny valley in 2024. A coach that sounds like a person — encouraging, pacing, warm, demanding when earned — is now a solved problem, not an aspiration.
4. **Ubiquitous sensor fusion.** iPhone + Apple Watch + AirPods Pro together expose accelerometers, gyroscopes, heart rate, and head orientation — three instrumented points on the body — plus HealthKit's longitudinal record of sleep, HRV, and workouts. No previous device generation gave us this.

Stack them and you get a coach that sees, hears, remembers, adapts, and speaks — at a quality that wasn't possible three years ago and will be table-stakes in five. The window to build the leading product in this category is short.

---

## What we believe

- **Depth of care beats breadth of features.** A coach that knows *you* — your injuries, your goals, your sore spots, your training history, your motivation style — will always beat a coach with a bigger exercise library. Most people do 8–12 movements on repeat anyway.
- **The moat is the athlete model, not the technology.** Apple and Google will match any one feature. What they can't easily copy is the compounding record of your training — the coach knowing, on month six, that your left knee caves under fatigue above 80% 1RM and pre-cueing for it.
- **Hands-free is the north star.** Any interaction that requires tapping a screen mid-set is a compromise. The phone (or Watch, or AirPods) should disappear into the experience.
- **Real-time beats retrospective.** Post-workout analysis is table-stakes — everyone does it. The win is the cue that changes the outcome of the set while you're in it.
- **Safety is non-negotiable.** The coach never pushes through sharp pain, never diagnoses injuries, never prescribes weight cuts or nutrition below medically safe minima, never substitutes for a physician. This is both ethics and moat — trust is hard to earn, easy to lose.
- **Trust is earned through reliability, not claimed through marketing.** A coach that misfires a cue on a 1RM attempt is a coach the user fires.

---

## The horizon (directional, not dated)

See ROADMAP.md for sequencing. Briefly, we build toward:

- **Full lift library** — the 5 MVP exercises grow to cover every serious strength movement with grounded form cues.
- **Apple Watch companion** — HR-guided intensity, haptic tempo cues, silent mode (coach through vibration, no voice needed).
- **Screenless in-ear mode** — pose inferred from AirPods + Watch IMU fusion for a subset of lifts. Phone stays in the pocket. This is the dream experience.
- **Recovery depth** — HRV-driven deload, sleep-informed readiness, perceived-effort journaling.
- **Nutrition** — photo a meal, conversation about it, goal-aligned macro guidance. Never calorie prison, always within medically safe bounds.
- **Goal programs** — user picks a goal (first pull-up, 2× bodyweight squat, 5K time, body recomposition) and the coach builds the multi-week arc.
- **Dual-camera 3D form analysis** — iPhone + iPad for gold-standard form review.
- **Cross-platform** — Android via the portable CoachingEngine.
- **Vetted human-authored programs** — marketplace where real coaches publish, AI delivers.

---

## What this is not

- A video library of exercises.
- A form-check-only app. Form checking is table-stakes in two years; it's not a product on its own.
- A replacement for elite coaching. Human coaches will always be better for the top 1% of athletes. We are building for the 99%.
- A nutrition tracker first. Nutrition is a later chapter; form is chapter one.
- A social network. Privacy is the default; sharing is opt-in and always will be.

---

## The north-star outcome

Measurable, not poetic: an intermediate lifter uses Gym Buddy for twelve weeks instead of their current routine (or their human trainer), is measurably stronger at the end, reports the experience as better than or equal to working with a human coach, and cannot imagine going back to training without it.

Everything we build is in service of that outcome.
