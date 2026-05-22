//
//  ConduitNavigationEvent.swift
//  Conduit
//

import Foundation

/// A navigation event recorded by `ConduitNavigationTracker`.
///
/// Each case captures forward navigation, backward navigation, tab navigation,
/// or root changes with enough context for analytics and runtime queries.
public enum ConduitNavigationEvent<Screen: ConduitNavigatedScreen>: Sendable {

    // MARK: - App Lifecycle

    /// App launched and landed on its initial screen.
    case appLaunched(initialScreen: Screen, tabIndex: Int)

    // MARK: - Forward Navigation

    /// A screen was pushed onto the navigation stack.
    case pushed(screen: Screen, fromScreen: Screen, tabIndex: Int)

    /// A screen was presented modally.
    case presented(screen: Screen, fromScreen: Screen, style: ConduitPresentationStyle)

    // MARK: - Backward Navigation

    /// A screen was popped from the navigation stack.
    case popped(screen: Screen, toScreen: Screen, tabIndex: Int)

    /// Multiple screens were popped from the navigation stack.
    case poppedMultiple(count: Int, toScreen: Screen, tabIndex: Int)

    /// Navigation stack was popped to root.
    case poppedToRoot(fromScreen: Screen, rootScreen: Screen, tabIndex: Int)

    /// A modal screen was dismissed.
    case dismissed(screen: Screen, toScreen: Screen)

    // MARK: - Tab Navigation

    /// User switched tabs.
    case tabSwitched(fromTabIndex: Int, toTabIndex: Int, toScreen: Screen)

    // MARK: - Root Changes

    /// App root was changed.
    case rootChanged(rootName: String, reason: String, resultingScreen: Screen)

    /// All modals were dismissed and all tabs popped to root.
    case resetToRootAndTabSelected(toTabIndex: Int, reason: String, toScreen: Screen)

    // MARK: - Computed Properties

    /// The screen visible after this event.
    public var resultingScreen: Screen {
        switch self {
        case let .appLaunched(initialScreen, _):
            return initialScreen
        case let .pushed(screen, _, _):
            return screen
        case let .presented(screen, _, _):
            return screen
        case let .popped(_, toScreen, _):
            return toScreen
        case let .poppedMultiple(_, toScreen, _):
            return toScreen
        case let .poppedToRoot(_, rootScreen, _):
            return rootScreen
        case let .dismissed(_, toScreen):
            return toScreen
        case let .tabSwitched(_, _, toScreen):
            return toScreen
        case let .rootChanged(_, _, resultingScreen):
            return resultingScreen
        case let .resetToRootAndTabSelected(_, _, toScreen):
            return toScreen
        }
    }

    /// Returns the analytics identifier for this event, prefixed by the
    /// tracker's configured `analyticsPrefix`.
    public func analyticsIdentifier(prefix: String) -> String {
        let suffix: String
        switch self {
        case .appLaunched:
            suffix = "app_launched"
        case .pushed:
            suffix = "pushed"
        case .presented:
            suffix = "presented"
        case .popped:
            suffix = "popped"
        case .poppedMultiple:
            suffix = "popped_multiple"
        case .poppedToRoot:
            suffix = "popped_to_root"
        case .dismissed:
            suffix = "dismissed"
        case .tabSwitched:
            suffix = "tab_switched"
        case .rootChanged:
            suffix = "root_changed"
        case .resetToRootAndTabSelected:
            suffix = "reset_to_root"
        }
        return prefix + suffix
    }
}
