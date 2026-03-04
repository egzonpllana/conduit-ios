//
//  ConduitTabItem.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

#if canImport(UIKit)
import UIKit

/// Configuration for a single tab in the tab bar controller.
///
/// Used by ``ConduitTabBarController`` to build tabs from an array of items.
public struct ConduitTabItem: @unchecked Sendable {

    // MARK: - Properties

    /// The display title for the tab.
    public let title: String

    /// The icon image for the tab.
    public let icon: UIImage

    /// The root view controller for this tab's navigation stack.
    public let rootViewController: UIViewController

    /// The zero-based index of this tab.
    public let index: Int

    /// Whether the navigation bar should use large titles.
    public let prefersLargeTitles: Bool

    // MARK: - Initialization

    /// Creates a tab item configuration.
    ///
    /// - Parameters:
    ///   - title: The tab title.
    ///   - icon: The tab icon.
    ///   - rootViewController: The root view controller for the tab's navigation stack.
    ///   - index: The zero-based tab index.
    ///   - prefersLargeTitles: Whether to use large titles. Defaults to `true`.
    public init(
        title: String,
        icon: UIImage,
        rootViewController: UIViewController,
        index: Int,
        prefersLargeTitles: Bool = true
    ) {
        self.title = title
        self.icon = icon
        self.rootViewController = rootViewController
        self.index = index
        self.prefersLargeTitles = prefersLargeTitles
    }
}
#endif
