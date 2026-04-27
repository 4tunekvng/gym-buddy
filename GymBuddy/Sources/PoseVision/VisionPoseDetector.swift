import Foundation
import CoachingEngine

#if canImport(Vision) && canImport(AVFoundation) && !os(macOS)
import Vision
import AVFoundation

/// Apple Vision–backed pose detector. Converts `VNHumanBodyPoseObservation` to
/// our abstract `PoseSample` so CoachingEngine stays vendor-pure.
///
/// This file only compiles on iOS — Vision's human-body-pose request and the
/// camera capture session are iOS-specific. macOS test runs use the fixture
/// detector instead.
public final class VisionPoseDetector: NSObject, PoseDetecting, CameraPreviewProviding, @unchecked Sendable {
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "com.gymbuddy.posevision.video", qos: .userInteractive)
    private var continuation: AsyncStream<BodyState>.Continuation?
    private var started = false
    private let cameraPosition: AVCaptureDevice.Position

    public init(cameraPosition: AVCaptureDevice.Position = .front) {
        self.cameraPosition = cameraPosition
    }

    public var previewSession: AVCaptureSession { captureSession }

    public func bodyStateStream() -> BodyStateStream {
        AsyncStream<BodyState> { continuation in
            self.continuation = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.stop() }
            }
        }
    }

    public func start() async throws {
        guard !started else { throw PoseDetectionError.alreadyStarted }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted { throw PoseDetectionError.cameraPermissionDenied }
        default: throw PoseDetectionError.cameraPermissionDenied
        }

        try configureSession()
        captureSession.startRunning()
        started = true
    }

    public func stop() async {
        captureSession.stopRunning()
        continuation?.finish()
        continuation = nil
        started = false
    }

    private func configureSession() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        captureSession.sessionPreset = .hd1920x1080
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) else {
            throw PoseDetectionError.cameraUnavailable
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard captureSession.canAddInput(input) else {
            throw PoseDetectionError.sessionConfigurationFailed(reason: "cannot_add_input")
        }
        captureSession.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        guard captureSession.canAddOutput(videoOutput) else {
            throw PoseDetectionError.sessionConfigurationFailed(reason: "cannot_add_output")
        }
        captureSession.addOutput(videoOutput)

        // Best-effort 30 fps.
        if let connection = videoOutput.connection(with: .video) {
            // iOS 17 deprecated `videoOrientation` in favour of the rotation-
            // angle API. 90° clockwise = portrait. Some older sims still want
            // the legacy property, so we set it under a runtime guard.
            if #available(iOS 17.0, *) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            } else {
                connection.videoOrientation = .portrait
            }
            if connection.isCameraIntrinsicMatrixDeliverySupported {
                connection.isCameraIntrinsicMatrixDeliveryEnabled = false
            }
        }
    }
}

extension VisionPoseDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput,
                              didOutput sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        let request = VNDetectHumanBodyPoseRequest()
        do {
            try handler.perform([request])
            guard let observation = request.results?.first as? VNHumanBodyPoseObservation else { return }
            let timestamp = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            let sample = Self.convert(observation: observation, timestamp: timestamp)
            continuation?.yield(.pose(sample))
        } catch {
            // Observations failing is expected in occluded frames; skip silently.
        }
    }

    private static let jointMap: [VNHumanBodyPoseObservation.JointName: JointName] = [
        .nose: .nose,
        .leftEye: .leftEye, .rightEye: .rightEye,
        .leftEar: .leftEar, .rightEar: .rightEar,
        .leftShoulder: .leftShoulder, .rightShoulder: .rightShoulder,
        .leftElbow: .leftElbow, .rightElbow: .rightElbow,
        .leftWrist: .leftWrist, .rightWrist: .rightWrist,
        .leftHip: .leftHip, .rightHip: .rightHip,
        .leftKnee: .leftKnee, .rightKnee: .rightKnee,
        .leftAnkle: .leftAnkle, .rightAnkle: .rightAnkle
    ]

    static func convert(observation: VNHumanBodyPoseObservation, timestamp: TimeInterval) -> PoseSample {
        var joints: [JointName: Keypoint] = [:]
        for (visionJoint, ourJoint) in jointMap {
            if let point = try? observation.recognizedPoint(visionJoint) {
                // Vision uses normalized image-space with origin at lower-left; our
                // convention is origin at upper-left. Flip y.
                joints[ourJoint] = Keypoint(
                    x: point.location.x,
                    y: 1.0 - point.location.y,
                    confidence: Double(point.confidence)
                )
            }
        }
        return PoseSample(timestamp: timestamp, joints: joints)
    }
}

#endif
