//
//  ConduitTabItem.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

#if canImport(UIKit)
import UIKit
import SwiftUI

/// Configuration for a single tab in the `ConduitTabBarController`.
///
/// Each tab item describes the title, icon, root view, and position
/// of a tab in the tab bar.
@MainActor
public struct ConduitTabItem {

    // MARK: - Properties

    /// The title displayed below the tab icon.
    public let title: String

    /// The icon displayed in the tab bar.
    public let icon: UIImage

    /// The root SwiftUI view for this tab, type-erased.
    public let rootView: AnyView

    /// The zero-based position of this tab.
    public let index: Int

    // MARK: - Initialization

    /// Creates a new tab item configuration.
    ///
    /// - Parameters:
    ///   - title: The title displayed below the tab icon.
    ///   - icon: The icon displayed in the tab bar.
    ///   - rootView: The root SwiftUI view for this tab.
    ///   - index: The zero-based position of this tab.
    public init(title: String, icon: UIImage, rootView: AnyView, index: Int) {
        self.title = title
        self.icon = icon
        self.rootView = rootView
        self.index = index
    }
}
#endif
