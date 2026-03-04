//
//  ConduitTabBarController.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

#if canImport(UIKit)
import UIKit
import SwiftUI

/// A generic, configurable `UITabBarController` driven by `ConduitTabItem` values.
///
/// Apps provide tab configuration through the `ConduitTabConfiguring` protocol.
/// The controller builds each tab by wrapping the SwiftUI root view in a
/// `UIHostingController` inside a `UINavigationController`.
///
/// ```swift
/// let config = AppTabConfig()
/// let tabBar = ConduitTabBarController(configuration: config)
/// ```
@MainActor
public final class ConduitTabBarController: UITabBarController {

    // MARK: - Properties

    private let configuration: any ConduitTabConfiguring

    // MARK: - Initialization

    /// Creates a new tab bar controller with the given configuration.
    ///
    /// - Parameter configuration: The tab configuration provider.
    public init(configuration: any ConduitTabConfiguring) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
        setupTabs()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupTabs() {
        let items = configuration.tabItems()
        let controllers = items.map { item in
            makeTab(item: item)
        }
        self.viewControllers = controllers
    }

    private func makeTab(item: ConduitTabItem) -> UINavigationController {
        let rootVC = UIHostingController(rootView: item.rootView)
        rootVC.title = item.title

        let navController = UINavigationController(rootViewController: rootVC)
        navController.tabBarItem = UITabBarItem(title: item.title, image: item.icon, tag: item.index)
        navController.navigationBar.prefersLargeTitles = true

        return navController
    }
}
#endif
