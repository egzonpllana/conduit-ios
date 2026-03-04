//
//  ConduitWindowUtils.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

#if canImport(UIKit)
import UIKit

/// Utility for accessing the currently active key window.
///
/// Provides static helpers for resolving the active window and
/// finding the topmost view controller in the hierarchy.
public enum ConduitWindowUtils {

    /// Returns the currently active key window of the application.
    ///
    /// - Returns: The key `UIWindow`, or `nil` if no window is active.
    public static func getActiveWindow() -> UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    /// Returns the topmost visible view controller in the window hierarchy.
    ///
    /// Recursively traverses presented view controllers, navigation controllers,
    /// and tab bar controllers to find the currently visible controller.
    ///
    /// - Returns: The topmost `UIViewController`, or `nil` if no root exists.
    public static func getTopViewController() -> UIViewController? {
        guard let window = getActiveWindow() else { return nil }
        guard let rootViewController = window.rootViewController else { return nil }
        return findTopViewController(from: rootViewController)
    }

    // MARK: - Private

    private static func findTopViewController(from viewController: UIViewController) -> UIViewController {
        if let presentedViewController = viewController.presentedViewController {
            return findTopViewController(from: presentedViewController)
        }

        if let navigationController = viewController as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return findTopViewController(from: visibleViewController)
        }

        if let tabBarController = viewController as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return findTopViewController(from: selectedViewController)
        }

        return viewController
    }
}
#endif
