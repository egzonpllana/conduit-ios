//
//  UIViewController+Conduit.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

#if canImport(UIKit)
import UIKit

extension UIViewController {

    /// Walks the entire presentation chain and finds the topmost visible `UINavigationController`.
    ///
    /// Traverses presented view controllers, tab bar controllers, and child
    /// view controllers to locate the closest navigation controller in the hierarchy.
    ///
    /// - Returns: The topmost `UINavigationController`, or `nil` if none is found.
    func closestNavigationController() -> UINavigationController? {
        var current: UIViewController? = self

        while let presented = current?.presentedViewController {
            current = presented
        }

        if let navigationController = current as? UINavigationController {
            return navigationController
        }

        if let navigationController = current?.navigationController {
            return navigationController
        }

        if let tabBarController = current as? UITabBarController,
           let selected = tabBarController.selectedViewController {
            return selected.closestNavigationController()
        }

        for child in current?.children ?? [] {
            if let navigationController = child.closestNavigationController() {
                return navigationController
            }
        }

        return nil
    }
}
#endif
