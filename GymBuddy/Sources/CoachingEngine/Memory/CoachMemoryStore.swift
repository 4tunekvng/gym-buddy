import Foundation

/// Protocol for coach memory persistence. The in-memory implementation in this
/// module is used by tests and by the in-process session flow; the Persistence
/// package provides a SwiftData-backed implementation for the real app.
public protocol CoachMemoryStoreProtocol: AnyObject, Sendable {
    func add(_ note: CoachMemoryNote) async
    func recent(matching tags: Set<String>, limit: Int) async -> [CoachMemoryNote]
    func all() async -> [CoachMemoryNote]
    func remove(_ id: UUID) async
}

/// Simple in-memory implementation. Deterministic, fast, used in tests and when
/// SwiftData isn't available (CLI harness, macOS test target).
public actor InMemoryCoachMemoryStore: CoachMemoryStoreProtocol {
    private var notes: [CoachMemoryNote] = []

    public init(seed: [CoachMemoryNote] = []) {
        self.notes = seed
    }

    public func add(_ note: CoachMemoryNote) {
        notes.append(note)
    }

    public func recent(matching tags: Set<String>, limit: Int) -> [CoachMemoryNote] {
        if tags.isEmpty {
            return notes.sorted(by: { $0.createdAt > $1.createdAt }).prefix(limit).map { $0 }
        }
        return notes
            .filter { !$0.tags.isDisjoint(with: tags) }
            .sorted(by: { $0.createdAt > $1.createdAt })
            .prefix(limit)
            .map { $0 }
    }

    public func all() -> [CoachMemoryNote] { notes }

    public func remove(_ id: UUID) {
        notes.removeAll { $0.id == id }
    }
}
