//
//  ConduitAction.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

import Foundation

/// Represents a navigation command dispatched through the Conduit system.
///
/// Each case corresponds to a UIKit navigation operation. Actions are
/// generic over the application's destination type.
public enum ConduitAction<Destination: ConduitDestination>: @unchecked Sendable {

    /// Pushes a destination onto the current navigation stack.
    case push(
        Destination,
        barPreferences: ConduitBarPreferences = .init()
    )

    /// Presents a destination modally.
    case present(
        Destination,
        style: ConduitPresentationStyle = .pageSheet,
        isModalInPresentation: Bool = false,
        detents: [ConduitDetent]? = nil,
        preferredHeight: CGFloat? = nil,
        showDragIndicator: Bool = false,
        barPreferences: ConduitBarPreferences = .init(),
        animated: Bool = true
    )

    /// Pops the top view controller from the navigation stack.
    case pop

    /// Pops multiple view controllers from the navigation stack.
    case popMultiple(count: Int, animated: Bool = true)

    /// Pops all view controllers to the root of the current stack.
    case popToRoot

    /// Dismisses the currently presented modal.
    case dismiss(animated: Bool = true, completion: (() -> Void)? = nil)

    /// Selects a tab at the given index.
    case selectTab(Int)

    /// Pops all stacks to root, dismisses modals, and selects a tab.
    case popToRootAndSelectTab(tabIndex: Int, completion: (() -> Void)? = nil)
}
