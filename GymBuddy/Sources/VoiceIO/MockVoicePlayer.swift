import Foundation
import CoachingEngine

/// An in-memory voice player that records what would have played. Used in
/// tests to assert "the coach said N" without any audio hardware. The
/// north-star demo test relies on this.
public actor MockVoicePlayer: VoicePlaying {
    public struct Played: Equatable, Sendable {
        public enum Kind: Equatable, Sendable {
            case cached(PhraseCache.Selection)
            case stream(text: String, tone: CoachingTone)
        }
        public let kind: Kind
        public let timestamp: Date
    }

    private(set) public var history: [Played] = []
    private var streamBuffer: String = ""

    public init() {}

    public func playCached(_ selection: PhraseCache.Selection) async throws {
        history.append(Played(kind: .cached(selection), timestamp: Date()))
    }

    public func speakStreaming(
        text: AsyncStream<String>,
        tone: CoachingTone
    ) async throws {
        var assembled = ""
        for await chunk in text {
            assembled += chunk
        }
        history.append(Played(kind: .stream(text: assembled, tone: tone), timestamp: Date()))
    }

    public func stop() async {
        streamBuffer = ""
    }

    public func cachedHistory() -> [PhraseID] {
        history.compactMap {
            if case .cached(let selection) = $0.kind { return selection.phrase } else { return nil }
        }
    }

    public func cachedSelections() -> [PhraseCache.Selection] {
        history.compactMap {
            if case .cached(let selection) = $0.kind { return selection } else { return nil }
        }
    }

    public func streamHistory() -> [(text: String, tone: CoachingTone)] {
        history.compactMap {
            if case .stream(let t, let tone) = $0.kind { return (t, tone) } else { return nil }
        }
    }

    public func reset() {
        history.removeAll()
        streamBuffer = ""
    }
}
