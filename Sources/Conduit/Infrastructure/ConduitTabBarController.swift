//
//  ConduitTabBarController.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

#if canImport(UIKit)
import UIKit

/// A generic, configurable tab bar controller for use with Conduit.
///
/// Creates tabs from an array of ``ConduitTabItem`` values. Each tab gets
/// its own `UINavigationController` wrapping the provided root view controller.
///
/// ```swift
/// let tabs = [
///     ConduitTabItem(title: "Home", icon: homeIcon, rootViewController: homeVC, index: 0),
///     ConduitTabItem(title: "Profile", icon: profileIcon, rootViewController: profileVC, index: 1)
/// ]
/// let tabBar = ConduitTabBarController(tabs: tabs, selectedIndex: 0)
/// ```
@MainActor
public final class ConduitTabBarController: UITabBarController {

    // MARK: - Properties

    private let tabs: [ConduitTabItem]
    private let initialSelectedIndex: Int

    // MARK: - Initialization

    /// Creates a tab bar controller with the given tab items.
    ///
    /// - Parameters:
    ///   - tabs: The tab configurations to display.
    ///   - selectedIndex: The initially selected tab index. Defaults to `0`.
    ///   - tintColor: The tint color for selected tab items. Defaults to system tint.
    public init(
        tabs: [ConduitTabItem],
        selectedIndex: Int = 0,
        tintColor: UIColor? = nil
    ) {
        self.tabs = tabs
        self.initialSelectedIndex = selectedIndex
        super.init(nibName: nil, bundle: nil)
        setupTabs(tintColor: tintColor)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Private

    private func setupTabs(tintColor: UIColor?) {
        let controllers = tabs.map { tab -> UINavigationController in
            let nav = UINavigationController(rootViewController: tab.rootViewController)
            nav.tabBarItem = UITabBarItem(title: tab.title, image: tab.icon, tag: tab.index)
            nav.navigationBar.prefersLargeTitles = tab.prefersLargeTitles
            return nav
        }
        viewControllers = controllers
        selectedIndex = initialSelectedIndex

        if let tintColor {
            tabBar.tintColor = tintColor
        }
    }
}
#endif
