import Foundation

/// An asynchronous sequence of body-state observations.
///
/// The engine consumes one of these; the platform adapter produces it.
/// `AsyncStream<BodyState>` is the concrete type used in practice; this typealias
/// documents the contract at the module boundary.
public typealias BodyStateStream = AsyncStream<BodyState>
