//
//  ConduitNavigationTracking.swift
//  Conduit
//

import Foundation
import Combine

/// A service that tracks the user's navigation across pushes, modals, and tabs.
///
/// Implementations observe a `ConduitDispatching` publisher and maintain stack
/// state plus a history log so analytics, deep-link routers, and feature flags
/// can answer "where is the user right now?".
@MainActor
public protocol ConduitNavigationTracking<Destination, Screen>: AnyObject {

    /// Destination type the tracker observes.
    associatedtype Destination: ConduitDestination

    /// Screen type the tracker resolves destinations into.
    associatedtype Screen: ConduitNavigatedScreen

    // MARK: - Publishers

    /// Emits whenever the currently visible screen changes.
    var currentScreenPublisher: AnyPublisher<Screen, Never> { get }

    /// Emits every navigation event the tracker records.
    var navigationEventPublisher: AnyPublisher<ConduitNavigationEvent<Screen>, Never> { get }

    // MARK: - Current State

    /// The currently visible screen.
    var currentScreen: Screen { get }

    /// Context attached to the currently visible screen.
    var currentContext: ConduitNavigationContext { get }

    /// `true` when no modals are presented and the active tab stack is at root.
    var isAtRootScreen: Bool { get }

    /// Currently selected tab index.
    var currentTabIndex: Int { get }

    /// Navigation depth (pushed + presented entries) from the active tab's root.
    var navigationDepth: Int { get }

    // MARK: - History

    /// All recorded entries, keyed by their stringified order.
    var navigationHistory: [String: ConduitNavigationHistoryEntry<Screen>] { get }

    /// The most recent entry, or `nil` if none has been recorded.
    var lastNavigationEntry: ConduitNavigationHistoryEntry<Screen>? { get }

    /// The most recent event, or `nil` if none has been recorded.
    var lastNavigationEvent: ConduitNavigationEvent<Screen>? { get }

    /// Total number of navigation events recorded this session.
    var totalNavigationCount: Int { get }

    /// Clears recorded history without disturbing stack state.
    func clearNavigationHistory()

    // MARK: - Tab Tracking

    /// Records a tab selection. Call this from your tab bar delegate; tab
    /// selections dispatched as `.selectTab` actions are recorded automatically.
    func trackTabSelection(_ tabIndex: Int)

    // MARK: - History Queries

    /// Returns history entries with a matching analytics identifier.
    func navigationEntries(matching analyticsIdentifier: String) -> [ConduitNavigationHistoryEntry<Screen>]

    /// Returns history entries whose resulting screen matches `screen`.
    func navigationEntries(toScreen screen: Screen) -> [ConduitNavigationHistoryEntry<Screen>]
}
