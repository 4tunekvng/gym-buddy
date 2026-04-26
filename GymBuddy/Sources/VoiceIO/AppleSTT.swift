import Foundation

#if canImport(Speech) && !os(macOS)
import Speech
import AVFoundation

/// Apple Speech framework wrapper. On-device recognition where supported; falls
/// back to server recognition otherwise. Used for between-set Q&A and the pain
/// detector's input.
///
/// Privacy: see docs/Privacy.md. If `requiresOnDeviceRecognition` is true the
/// user's speech stays on-device.
public final class AppleSTT: @unchecked Sendable {
    public enum RecognitionError: Error, Equatable {
        case authorizationDenied
        case recognizerUnavailable
        case startFailed(String)
    }

    private let recognizer = SFSpeechRecognizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    public init() {}

    public func authorize() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    public func startRecognition(onPartial: @escaping @Sendable (String) -> Void) async throws {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw RecognitionError.recognizerUnavailable
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        try engine.start()

        task = recognizer.recognitionTask(with: request) { result, error in
            if let result {
                onPartial(result.bestTranscription.formattedString)
            }
            if error != nil || (result?.isFinal ?? false) {
                request.endAudio()
            }
        }
    }

    public func stop() {
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
    }
}

#endif
