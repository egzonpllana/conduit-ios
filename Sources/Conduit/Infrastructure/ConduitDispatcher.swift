//
//  ConduitDispatcher.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

import Combine

/// A Combine-based implementation of the navigation dispatcher.
///
/// Uses a `PassthroughSubject` to broadcast navigation actions to all subscribers.
/// Thread-safe via `@MainActor` isolation.
///
/// ```swift
/// let dispatcher = ConduitDispatcher<AppDestination>()
/// dispatcher.send(.push(.profile(userId: "123")))
/// ```
@MainActor
public final class ConduitDispatcher<Destination: ConduitDestination>: ConduitDispatching {

    // MARK: - Properties

    private let subject = PassthroughSubject<ConduitAction<Destination>, Never>()
    nonisolated(unsafe) private var _actionPublisher: AnyPublisher<ConduitAction<Destination>, Never>?

    // MARK: - ConduitDispatching

    nonisolated public var actionPublisher: AnyPublisher<ConduitAction<Destination>, Never> {
        guard let publisher = _actionPublisher else {
            fatalError("[Conduit] Dispatcher accessed before initialization.")
        }
        return publisher
    }

    // MARK: - Initialization

    /// Creates a new navigation dispatcher.
    public init() {
        _actionPublisher = subject.eraseToAnyPublisher()
    }

    // MARK: - Methods

    /// Sends a navigation action to all subscribers.
    ///
    /// - Parameter action: The navigation action to dispatch.
    public func send(_ action: ConduitAction<Destination>) {
        subject.send(action)
    }
}
