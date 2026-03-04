//
//  ConduitViewFactory.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

import SwiftUI

/// A factory protocol that maps destination values to SwiftUI views.
///
/// Conforming types provide the view-building logic for each destination
/// in the app's navigation graph. The router calls `makeView(_:)` when
/// it needs to push or present a destination.
///
/// ```swift
/// struct AppViewFactory: ConduitViewFactory {
///     func makeView(_ destination: AppDestination) -> AnyView {
///         switch destination {
///         case .home:
///             return AnyView(HomeView())
///         case .profile(let userId):
///             return AnyView(ProfileView(userId: userId))
///         case .settings:
///             return AnyView(SettingsView())
///         }
///     }
///
///     func makeIdentifier(_ destination: AppDestination) -> String? {
///         return nil
///     }
/// }
/// ```
@MainActor
public protocol ConduitViewFactory {

    /// The destination type this factory handles.
    associatedtype Destination: ConduitDestination

    /// Creates a type-erased SwiftUI view for the given destination.
    ///
    /// - Parameter destination: The navigation destination to build a view for.
    /// - Returns: A type-erased `AnyView` representing the destination screen.
    func makeView(_ destination: Destination) -> AnyView

    /// Returns an optional restoration identifier for the given destination.
    ///
    /// Used to tag the `UIHostingController` for later identification
    /// (e.g., preventing duplicate pushes).
    ///
    /// - Parameter destination: The navigation destination.
    /// - Returns: A string identifier, or `nil` if not needed.
    func makeIdentifier(_ destination: Destination) -> String?
}

// MARK: - Default Implementation

public extension ConduitViewFactory {

    /// Default implementation returns `nil` for all destinations.
    func makeIdentifier(_ destination: Destination) -> String? {
        nil
    }
}
