//
//  ConduitBarPreferences.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

/// Configuration for navigation bar appearance when pushing or presenting a view.
///
/// Controls visibility, title display mode, and tab bar hiding behavior
/// for the destination view controller.
public struct ConduitBarPreferences: Sendable {

    // MARK: - Properties

    /// Whether the navigation bar should be hidden.
    public let isHidden: Bool

    /// The large title display mode for the navigation item.
    public let largeTitleDisplayMode: ConduitLargeTitleDisplayMode

    /// Whether the tab bar should be hidden when this view is pushed.
    public let hideTabBar: Bool

    // MARK: - Initialization

    /// Creates navigation bar preferences.
    ///
    /// - Parameters:
    ///   - isHidden: Whether the navigation bar is hidden. Defaults to `true`.
    ///   - largeTitleDisplayMode: The large title mode. Defaults to `.automatic`.
    ///   - hideTabBar: Whether to hide the tab bar. Defaults to `true`.
    public init(
        isHidden: Bool = true,
        largeTitleDisplayMode: ConduitLargeTitleDisplayMode = .automatic,
        hideTabBar: Bool = true
    ) {
        self.isHidden = isHidden
        self.largeTitleDisplayMode = largeTitleDisplayMode
        self.hideTabBar = hideTabBar
    }
}

// MARK: - Large Title Display Mode

/// Large title display mode for the navigation bar.
///
/// Maps to `UINavigationItem.LargeTitleDisplayMode` at the infrastructure layer.
public enum ConduitLargeTitleDisplayMode: Sendable {

    /// Inherit the display mode from the previous view controller.
    case automatic

    /// Always display a large title.
    case always

    /// Never display a large title.
    case never
}
