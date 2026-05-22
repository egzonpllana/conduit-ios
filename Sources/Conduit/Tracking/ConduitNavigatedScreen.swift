//
//  ConduitNavigatedScreen.swift
//  Conduit
//

import Foundation

/// Marker protocol that app-defined screen enums conform to for tracker support.
///
/// Conforming types describe trackable screens. The tracker uses
/// `analyticsIdentifier` to log events, group history queries, and emit
/// analytics breadcrumbs.
///
/// ```swift
/// enum AppScreen: String, ConduitNavigatedScreen {
///     case home, profile, settings, unknown
///     var analyticsIdentifier: String { rawValue }
/// }
/// ```
public protocol ConduitNavigatedScreen: Hashable, Sendable {

    /// String identifier emitted in analytics events for this screen.
    var analyticsIdentifier: String { get }
}
