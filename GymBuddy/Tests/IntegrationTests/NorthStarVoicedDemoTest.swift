import XCTest
@testable import CoachingEngine
@testable import VoiceIO

/// Full-pipeline variant of the north-star demo (PRD §2 + §10.3).
///
/// PRD §10.3 explicitly calls for the test to pipe the fixture through
/// `CoachingEngine + VoiceIO with a mock audio output`. This test covers that
/// path: pose stream → SessionOrchestrator → IntentToVoiceMapper →
/// MockVoicePlayer. The mock player records every phrase that *would have*
/// played, with the engine-time timestamp at which it was scheduled.
///
/// Assertions track the original spec:
///   1. Exactly 13 rep-count utterances are scheduled.
///   2. A "one more" phrase (in any of its standard variants) is scheduled
///      during rep 13's concentric window (±200 ms tolerance).
///   3. A "last one" phrase eventually plays (PRD §2's "that's the one you
///      weren't going to do alone" companion line).
///   4. The post-set summary text contains "13".
///   5. No safety phrases play.
final class NorthStarVoicedDemoTest: XCTestCase {

    func testFullPipelineFiresOneMoreDuringRep13Concentric() async throws {
        let config = SessionConfig(
            exerciseId: .pushUp,
            setNumber: 1,
            targetReps: nil,
            tone: .standard
        )
        let context = SessionContext(
            userId: UUID(),
            tone: .standard,
            priorSessionBestReps: [.pushUp: 11],
            activeInjuryNotes: [],
            memoryReferences: []
        )
        let orchestrator = SessionOrchestrator(config: config, context: context)
        let fixture = HeroFixtureV2.build()

        let player = MockVoicePlayer()
        let cache = Self.makeCache()
        let mapper = IntentToVoiceMapper(tone: .standard, cache: cache, voice: player)

        // Track each routed intent with its engine-time timestamp so we can
        // assert phrasing/timing without depending on real-clock ordering.
        var routedAt: [(phraseKind: PhraseID.Kind, engineT: TimeInterval)] = []

        for sample in fixture.samples {
            let intents = orchestrator.observe(sample: sample)
            for intent in intents {
                let phrase = try? await mapper.route(intent)
                if let phrase {
                    let engineT: TimeInterval = {
                        switch intent {
                        case .sayRepCount(_, let t): return t
                        case .encouragement(_, _, let t): return t
                        case .formCue(let cue): return cue.timestamp
                        case .painStop, .setEnded, .startRest, .contextualSpeech:
                            return sample.timestamp
                        }
                    }()
                    routedAt.append((phrase.kind, engineT))
                }
            }
        }

        // 1) Exactly 13 rep counts.
        let repCounts = routedAt.filter { $0.phraseKind == .repCount }
        XCTAssertEqual(repCounts.count, 13, "PRD §10.3: exactly 13 rep-count phrases must play")

        // 2) "one more" within rep 13's concentric window ±200 ms tolerance.
        let oneMoreTimes = routedAt.filter { $0.phraseKind == .encourageOneMore }.map(\.engineT)
        XCTAssertFalse(oneMoreTimes.isEmpty, "Expected an 'one more' phrase to play")
        let firstOneMore = oneMoreTimes[0]
        let lower = fixture.rep13ConcentricStartTimestamp - 0.200
        let upper = fixture.rep13ConcentricEndTimestamp + 0.200
        XCTAssertTrue(
            (lower...upper).contains(firstOneMore),
            "PRD §10.3: 'one more' must occur during rep 13's concentric window. " +
            "Routed at t=\(firstOneMore), window=[\(fixture.rep13ConcentricStartTimestamp), " +
            "\(fixture.rep13ConcentricEndTimestamp)] ±0.2s"
        )

        // 3) "last one" plays (companion phrase from PRD §2).
        let lastOneTimes = routedAt.filter { $0.phraseKind == .encourageLastOne }
        XCTAssertFalse(lastOneTimes.isEmpty, "Expected a 'last one' phrase to play")

        // 4) No safety pain-stop phrases play on a clean set.
        let safetyPlayed = routedAt.contains { $0.phraseKind == .safetyPainStop }
        XCTAssertFalse(safetyPlayed, "No safety phrases should fire on a clean synthetic set")

        // 5) Post-set summary contains "13".
        let obs = orchestrator.buildObservation()
        let summary = SessionSummaryFallback.summary(for: obs)
        XCTAssertTrue(
            summary.contains("13"),
            "PRD §10.3: post-set summary must contain the numeric count '13'. Got: \(summary)"
        )

        // 6) "Transcribed" audio sanity-check: the captured selections include
        //    at least one rep count phrase that names "13" — the user must
        //    audibly hear the final count regardless of which encouragement
        //    variant the cache picked. PRD §2 says assertions are about
        //    *meaning*, not exact wording, so we don't pin the encouragement
        //    text — the EncouragementKind check above already covers that.
        let transcripts = await player.cachedSelections().map { selection in
            SpeechSynthesizerVoicePlayerStub.spokenText(for: selection)
        }
        XCTAssertTrue(
            transcripts.contains { $0.contains("13") },
            "Captured audio should include a rep-count phrase voicing 13. Got: \(transcripts)"
        )
    }

    static func makeCache() -> PhraseCache {
        var variants: [PhraseID: [PhraseCache.Variant]] = [:]
        for tone in CoachingTone.allCases {
            for id in PhraseManifest.required(for: tone) {
                let variantCount = PhraseManifest.minimumVariantsByKind[id.kind] ?? 1
                variants[id] = (0..<variantCount).map {
                    PhraseCache.Variant(index: $0, assetName: "test:\(id.assetName):\($0)")
                }
            }
        }
        return PhraseCache(variants: variants, windowSize: 3)
    }
}

/// Identical fixture math to NorthStarDemoTest, duplicated here so the
/// integration-test suite is self-contained (CoachingEngineTests targets
/// don't expose internal types to integration tests at the package level).
private enum HeroFixtureV2 {
    struct Output {
        let samples: [PoseSample]
        let rep13ConcentricStartTimestamp: TimeInterval
        let rep13ConcentricEndTimestamp: TimeInterval
    }

    static func build() -> Output {
        let concentricByRep: [Double] = [
            1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
            1.05, 1.12, 1.22, 1.30,
            1.50,
            1.80
        ]
        let eccentricSeconds: TimeInterval = 0.8
        let bottomDwellSeconds: TimeInterval = 0.1
        let topDwellSeconds: TimeInterval = 0.1
        let dt = 1.0 / 30.0

        var samples: [PoseSample] = []
        var t: TimeInterval = 0
        var rep13ConcentricStart: TimeInterval = 0
        var rep13ConcentricEnd: TimeInterval = 0

        for _ in 0..<30 {
            samples.append(VoicedPushUpSample.at(elbowDegrees: 170, t: t)); t += dt
        }

        for (idx, concentricSeconds) in concentricByRep.enumerated() {
            let repNumber = idx + 1
            let eccFrames = max(1, Int(eccentricSeconds * 30))
            for i in 0..<eccFrames {
                let phase = Double(i + 1) / Double(eccFrames)
                let angle = 170.0 - 75.0 * phase
                samples.append(VoicedPushUpSample.at(elbowDegrees: angle, t: t)); t += dt
            }
            let bottomFrames = max(1, Int(bottomDwellSeconds * 30))
            for _ in 0..<bottomFrames {
                samples.append(VoicedPushUpSample.at(elbowDegrees: 95, t: t)); t += dt
            }
            if repNumber == 13 { rep13ConcentricStart = t }
            let concFrames = max(1, Int(concentricSeconds * 30))
            for i in 0..<concFrames {
                let phase = Double(i + 1) / Double(concFrames)
                let angle = 95.0 + 75.0 * phase
                samples.append(VoicedPushUpSample.at(elbowDegrees: angle, t: t)); t += dt
            }
            if repNumber == 13 { rep13ConcentricEnd = t }
            let topFrames = max(1, Int(topDwellSeconds * 30))
            for _ in 0..<topFrames {
                samples.append(VoicedPushUpSample.at(elbowDegrees: 170, t: t)); t += dt
            }
        }

        for _ in 0..<(30 * 5) {
            samples.append(VoicedPushUpSample.at(elbowDegrees: 170, t: t)); t += dt
        }

        return Output(
            samples: samples,
            rep13ConcentricStartTimestamp: rep13ConcentricStart,
            rep13ConcentricEndTimestamp: rep13ConcentricEnd
        )
    }
}

private enum VoicedPushUpSample {
    static func at(elbowDegrees: Double, t: TimeInterval) -> PoseSample {
        let shoulderX = 0.3
        let wristX = 0.3
        let wristY = 0.55
        let armSegment = 0.15
        let theta = elbowDegrees * .pi / 180
        let shoulderWristDist = 2 * armSegment * sin(theta / 2)
        let shoulderY = wristY - shoulderWristDist
        let elbowY = (shoulderY + wristY) / 2
        let elbowX = shoulderX + armSegment * cos(theta / 2)
        let ankleY = 0.40
        func yOnLine(atX x: Double) -> Double {
            let r = (x - shoulderX) / (0.90 - shoulderX)
            return shoulderY + r * (ankleY - shoulderY)
        }
        let hipY = yOnLine(atX: 0.60)
        let kneeY = yOnLine(atX: 0.75)
        return PoseSample(timestamp: t, joints: [
            .leftShoulder: Keypoint(x: shoulderX, y: shoulderY, confidence: 0.95),
            .rightShoulder: Keypoint(x: shoulderX + 0.02, y: shoulderY, confidence: 0.95),
            .leftElbow: Keypoint(x: elbowX, y: elbowY, confidence: 0.95),
            .rightElbow: Keypoint(x: elbowX + 0.02, y: elbowY, confidence: 0.95),
            .leftWrist: Keypoint(x: wristX, y: wristY, confidence: 0.95),
            .rightWrist: Keypoint(x: wristX + 0.02, y: wristY, confidence: 0.95),
            .leftHip: Keypoint(x: 0.60, y: hipY, confidence: 0.95),
            .rightHip: Keypoint(x: 0.60, y: hipY + 0.01, confidence: 0.95),
            .leftKnee: Keypoint(x: 0.75, y: kneeY, confidence: 0.9),
            .rightKnee: Keypoint(x: 0.75, y: kneeY + 0.01, confidence: 0.9),
            .leftAnkle: Keypoint(x: 0.90, y: ankleY, confidence: 0.9),
            .rightAnkle: Keypoint(x: 0.90, y: ankleY + 0.01, confidence: 0.9),
            .nose: Keypoint(x: 0.27, y: shoulderY - 0.02, confidence: 0.9)
        ])
    }
}

/// Stand-in mapping from PhraseID → human-readable text. The real iOS-only
/// SpeechSynthesizerVoicePlayer.spokenText is unavailable on macOS targets
/// (it imports AVFoundation). This stub mirrors the same lookup table so
/// "transcribing the captured audio" works in CI on macOS.
private enum SpeechSynthesizerVoicePlayerStub {
    static func spokenText(for selection: PhraseCache.Selection) -> String {
        let phrase = selection.phrase
        let v = selection.variant.index
        switch phrase.kind {
        case .repCount:
            let n = phrase.number ?? 0
            return ["\(n)", "Rep \(n)", "\(n)."][v % 3]
        case .encourageOneMore:
            return ["One more", "Give me one more", "You've got one more", "One clean rep"][v % 4]
        case .encouragePush:
            return ["Push", "Push through", "Drive it up"][v % 3]
        case .encourageDrive:
            return ["Drive", "Drive through", "Finish the rep"][v % 3]
        case .encourageLastOne:
            return ["Last one", "That's the last rep", "Final rep"][v % 3]
        case .encourageSteady:
            return ["Steady", "Stay steady"][v % 2]
        case .encourageValidate:
            return ["There we go", "That's it"][v % 2]
        case .safetyPainStop:
            return "Let's stop there. Sharp pain is a stop signal."
        case .safetyDiagnosisDeflect, .safetyNutritionDeflect, .safetyGenericDeflect:
            return "I can't help with that here."
        }
    }
}
