//
//  ConduitDispatching.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

import Combine

/// A protocol for dispatching and observing navigation actions.
///
/// View models send actions through a dispatcher, and the router
/// subscribes to the publisher to execute the corresponding
/// UIKit navigation operations.
///
/// ```swift
/// class MyViewModel {
///     let dispatcher: any ConduitDispatching<AppDestination>
///
///     func showProfile(userId: String) {
///         dispatcher.send(.push(.profile(userId: userId)))
///     }
/// }
/// ```
@MainActor
public protocol ConduitDispatching<Destination>: AnyObject {

    /// The destination type used by this dispatcher.
    associatedtype Destination: ConduitDestination

    /// A publisher that emits navigation actions sent through the dispatcher.
    var actionPublisher: AnyPublisher<ConduitAction<Destination>, Never> { get }

    /// Sends a navigation action to interested subscribers.
    ///
    /// - Parameter action: The navigation action to broadcast.
    func send(_ action: ConduitAction<Destination>)
}
