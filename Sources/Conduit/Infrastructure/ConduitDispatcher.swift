//
//  ConduitDispatcher.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

import Combine

/// A concrete dispatcher that broadcasts navigation actions via a Combine subject.
///
/// This is the standard implementation of `ConduitDispatching`. Inject it into
/// view models so they can emit navigation actions without knowing about UIKit.
///
/// ```swift
/// let dispatcher = ConduitDispatcher<AppDestination>()
/// dispatcher.send(.push(.home))
/// ```
@MainActor
public final class ConduitDispatcher<Destination: ConduitDestination>: ConduitDispatching, ObservableObject {

    // MARK: - Properties

    private let subject = PassthroughSubject<ConduitAction<Destination>, Never>()

    /// A publisher that emits navigation actions sent through the dispatcher.
    public var actionPublisher: AnyPublisher<ConduitAction<Destination>, Never> {
        subject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    /// Creates a new dispatcher instance.
    public init() {}

    // MARK: - Methods

    /// Sends a navigation action to all subscribers.
    ///
    /// - Parameter action: The navigation action to broadcast.
    public func send(_ action: ConduitAction<Destination>) {
        subject.send(action)
    }
}
