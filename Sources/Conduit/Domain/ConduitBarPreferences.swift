//
//  ConduitBarPreferences.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

import Foundation

/// Configuration for navigation bar appearance when pushing or presenting a view.
///
/// Controls visibility, large title behavior, and tab bar visibility
/// for the destination view controller.
public struct ConduitBarPreferences: Sendable {

    // MARK: - Properties

    /// Whether the navigation bar is hidden.
    public var isHidden: Bool

    /// The large title display mode for the navigation item.
    public var largeTitleDisplayMode: ConduitLargeTitleDisplayMode

    /// Whether the tab bar is hidden when the view is pushed.
    public var hideTabBar: Bool

    // MARK: - Initialization

    /// Creates a new bar preferences instance.
    ///
    /// - Parameters:
    ///   - isHidden: Whether the navigation bar is hidden. Defaults to `false`.
    ///   - largeTitleDisplayMode: The large title display mode. Defaults to `.automatic`.
    ///   - hideTabBar: Whether to hide the tab bar when pushed. Defaults to `true`.
    public init(
        isHidden: Bool = false,
        largeTitleDisplayMode: ConduitLargeTitleDisplayMode = .automatic,
        hideTabBar: Bool = true
    ) {
        self.isHidden = isHidden
        self.largeTitleDisplayMode = largeTitleDisplayMode
        self.hideTabBar = hideTabBar
    }
}

/// SDK-owned large title display mode, independent of UIKit.
///
/// Maps to `UINavigationItem.LargeTitleDisplayMode` at the infrastructure layer.
public enum ConduitLargeTitleDisplayMode: Sendable {

    /// Inherits the display mode from the previous item on the navigation stack.
    case automatic

    /// Always displays a large title.
    case always

    /// Never displays a large title.
    case never
}
