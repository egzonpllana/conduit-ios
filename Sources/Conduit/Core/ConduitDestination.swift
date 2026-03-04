//
//  ConduitDestination.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

/// A marker protocol that app-defined destination enums must conform to.
///
/// Conforming types represent all navigable screens in the app.
/// Each case typically carries associated values needed to construct
/// the destination view.
///
/// ```swift
/// enum AppDestination: ConduitDestination {
///     case home
///     case profile(userId: String)
///     case settings
/// }
/// ```
public protocol ConduitDestination: Sendable {}
