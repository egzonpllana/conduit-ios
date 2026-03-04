//
//  ConduitAction.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

import Foundation

/// Represents navigation commands dispatched through the Conduit framework.
///
/// Each case maps to a UIKit navigation operation. The `Destination` generic
/// parameter is the app-defined destination enum conforming to `ConduitDestination`.
///
/// ```swift
/// dispatcher.send(.push(.profile(userId: "123")))
/// dispatcher.send(.present(.settings, style: .pageSheet, detents: [.medium, .large]))
/// dispatcher.send(.pop)
/// ```
public enum ConduitAction<Destination: ConduitDestination>: Sendable {

    /// Pushes a destination onto the navigation stack.
    ///
    /// - Parameters:
    ///   - destination: The screen to navigate to.
    ///   - barPreferences: Navigation bar configuration for the pushed view.
    case push(
        Destination,
        barPreferences: ConduitBarPreferences = .init(isHidden: true)
    )

    /// Presents a destination modally.
    ///
    /// - Parameters:
    ///   - destination: The screen to present.
    ///   - style: The modal presentation style.
    ///   - isModalInPresentation: Whether the modal can be dismissed interactively.
    ///   - detents: Sheet detent sizes for page/form sheet styles.
    ///   - preferredHeight: Fallback fixed height when detents are not provided.
    ///   - showDragIndicator: Whether to show the sheet grabber.
    ///   - barPreferences: Navigation bar configuration for the presented view.
    ///   - animated: Whether the presentation is animated.
    case present(
        Destination,
        style: ConduitPresentationStyle,
        isModalInPresentation: Bool = false,
        detents: [ConduitDetent]? = nil,
        preferredHeight: CGFloat? = nil,
        showDragIndicator: Bool = false,
        barPreferences: ConduitBarPreferences = .init(isHidden: true),
        animated: Bool = true
    )

    /// Pops the top view controller from the navigation stack.
    case pop

    /// Pops multiple view controllers from the navigation stack.
    ///
    /// - Parameters:
    ///   - count: Number of view controllers to pop.
    ///   - animated: Whether the last pop is animated.
    case popMultiple(count: Int, animated: Bool = true)

    /// Pops all view controllers back to the root.
    case popToRoot

    /// Dismisses the currently presented modal.
    ///
    /// - Parameters:
    ///   - animated: Whether the dismissal is animated.
    ///   - completion: Closure called after the dismissal completes.
    case dismiss(animated: Bool = true, completion: (@Sendable () -> Void)? = nil)

    /// Selects a specific tab in the tab bar controller.
    ///
    /// - Parameter tabIndex: The zero-based index of the tab to select.
    case selectTab(Int)

    /// Pops all navigation stacks to root and selects a specific tab.
    ///
    /// Dismisses any presented modals, pops all pushed view controllers
    /// to their root, and selects the specified tab.
    ///
    /// - Parameters:
    ///   - tabIndex: The zero-based index of the tab to select.
    ///   - completion: Optional closure called after navigation completes.
    case popToRootAndSelectTab(tabIndex: Int, completion: (@Sendable () -> Void)? = nil)
}
