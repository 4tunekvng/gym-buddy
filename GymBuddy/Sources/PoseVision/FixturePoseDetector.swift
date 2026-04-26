import Foundation
import CoachingEngine

/// A pose detector backed by a pre-recorded fixture.
///
/// Used everywhere a camera isn't available or deterministic behavior is needed:
///   - The CoachingCLI harness
///   - Unit and integration tests
///   - The north-star demo test
///   - Simulator demo flow (the app's composition uses this when there's no camera)
///
/// Lifecycle contract with callers: you MUST call `bodyStateStream()` first
/// to set up the continuation, then call `start()` to begin pumping frames.
/// If `start()` is called first we still work — we park the emit task until
/// a consumer subscribes. That way the iOS app's consume-then-start order
/// and unit tests' start-then-consume order both function.
///
/// Fixtures are plain arrays of `PoseSample`. Decoders for JSON fixture files
/// live alongside in `PoseFixtureLoader`.
public final class FixturePoseDetector: PoseDetecting, @unchecked Sendable {
    private let samples: [PoseSample]
    private let frameInterval: TimeInterval
    private var task: Task<Void, Never>?
    private var continuation: AsyncStream<BodyState>.Continuation?
    // Signals that a consumer has subscribed so the emit loop can proceed.
    private var subscribed = false
    private var pendingStart = false

    /// - Parameters:
    ///   - samples: pose samples to emit in order.
    ///   - frameInterval: delay between emissions. Zero means emit as fast as possible,
    ///     which is what tests want; production-style replay uses 1/30s.
    public init(samples: [PoseSample], frameInterval: TimeInterval = 0) {
        self.samples = samples
        self.frameInterval = frameInterval
    }

    public func bodyStateStream() -> BodyStateStream {
        AsyncStream<BodyState> { continuation in
            self.continuation = continuation
            self.subscribed = true
            continuation.onTermination = { _ in
                self.task?.cancel()
            }
            if self.pendingStart {
                // start() was called before the consumer subscribed; launch now.
                self.pendingStart = false
                self.launchEmitTask()
            }
        }
    }

    public func start() async throws {
        guard task == nil && !pendingStart else { throw PoseDetectionError.alreadyStarted }
        if subscribed {
            launchEmitTask()
        } else {
            pendingStart = true
        }
    }

    public func stop() async {
        task?.cancel()
        task = nil
        continuation?.finish()
        continuation = nil
        subscribed = false
        pendingStart = false
    }

    // MARK: - Internal

    private func launchEmitTask() {
        task = Task { [weak self] in
            guard let self else { return }
            for sample in self.samples {
                if Task.isCancelled { break }
                self.continuation?.yield(.pose(sample))
                if self.frameInterval > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(self.frameInterval * 1_000_000_000))
                }
            }
            self.continuation?.finish()
        }
    }

    /// Convenience: build a list of body states directly, no async plumbing.
    /// Handy for pure-engine unit tests that don't need a live stream.
    public static func synchronousReplay(samples: [PoseSample]) -> [BodyState] {
        samples.map { .pose($0) }
    }
}
