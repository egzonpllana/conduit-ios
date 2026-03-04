//
//  ConduitRouting.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

#if canImport(UIKit)
import UIKit

/// A protocol defining the router's public interface for app-level navigation.
///
/// The router listens to dispatcher actions and translates them into
/// UIKit push/present/pop/dismiss operations. The `changeRoot` method
/// is intentionally not an action — it takes a `UIViewController` which
/// is not `Sendable`.
@MainActor
public protocol ConduitRouting: AnyObject {

    /// Replaces the window's root view controller.
    ///
    /// Use this for root-level transitions (e.g., sign-in to main app).
    /// This is a direct method rather than an action because `UIViewController`
    /// is not `Sendable`.
    ///
    /// - Parameters:
    ///   - viewController: The new root view controller.
    ///   - window: The window to update. If `nil`, the router uses its active window.
    func changeRoot(to viewController: UIViewController, in window: UIWindow?)

    /// Updates the currently active window used by the router.
    ///
    /// - Parameter window: The new `UIWindow` instance to track.
    func updateActiveWindow(_ window: UIWindow)
}
#endif
