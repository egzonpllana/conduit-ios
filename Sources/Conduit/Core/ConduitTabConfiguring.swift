//
//  ConduitTabConfiguring.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

#if canImport(UIKit)
import UIKit

/// A protocol for providing tab bar configuration to the router.
///
/// Conforming types supply the list of tab items that the
/// `ConduitTabBarController` uses to build its tabs.
///
/// ```swift
/// struct AppTabConfig: ConduitTabConfiguring {
///     func tabItems() -> [ConduitTabItem] {
///         [
///             ConduitTabItem(title: "Home", icon: UIImage(systemName: "house")!, rootView: AnyView(HomeView()), index: 0),
///             ConduitTabItem(title: "Settings", icon: UIImage(systemName: "gear")!, rootView: AnyView(SettingsView()), index: 1)
///         ]
///     }
/// }
/// ```
@MainActor
public protocol ConduitTabConfiguring {

    /// Returns the ordered list of tab items for the tab bar.
    ///
    /// - Returns: An array of `ConduitTabItem` describing each tab.
    func tabItems() -> [ConduitTabItem]
}
#endif
