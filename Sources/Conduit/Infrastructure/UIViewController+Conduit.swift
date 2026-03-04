//
//  UIViewController+Conduit.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

#if canImport(UIKit)
import UIKit

extension UIViewController {

    /// Walks the presentation chain and child hierarchy to find the nearest `UINavigationController`.
    ///
    /// Checks presented view controllers first, then falls back to
    /// the navigation controller property, tab bar children, and container children.
    ///
    /// - Returns: The closest `UINavigationController`, or `nil` if none is found.
    func conduit_closestNavigationController() -> UINavigationController? {
        var current: UIViewController? = self

        while let presented = current?.presentedViewController {
            current = presented
        }

        if let nav = current as? UINavigationController {
            return nav
        }

        if let nav = current?.navigationController {
            return nav
        }

        if let tabBar = current as? UITabBarController,
           let selected = tabBar.selectedViewController {
            return selected.conduit_closestNavigationController()
        }

        for child in current?.children ?? [] {
            if let nav = child.conduit_closestNavigationController() {
                return nav
            }
        }

        return nil
    }
}
#endif
