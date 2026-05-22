//
//  ConduitNavigationHistoryEntry.swift
//  Conduit
//

import Foundation

/// A single entry in the navigation history captured by the tracker.
public struct ConduitNavigationHistoryEntry<Screen: ConduitNavigatedScreen>: Sendable {

    /// Sequential order of this navigation action in the current session (0-based).
    public let order: Int

    /// The navigation event that occurred.
    public let event: ConduitNavigationEvent<Screen>

    /// Wall-clock timestamp when the navigation occurred.
    public let timestamp: Date

    /// The screen visible after this navigation.
    public let resultingScreen: Screen

    /// Analytics identifier for this entry, using the tracker's configured prefix.
    public let analyticsIdentifier: String

    public init(
        order: Int,
        event: ConduitNavigationEvent<Screen>,
        analyticsPrefix: String,
        timestamp: Date = Date()
    ) {
        self.order = order
        self.event = event
        self.timestamp = timestamp
        self.resultingScreen = event.resultingScreen
        self.analyticsIdentifier = event.analyticsIdentifier(prefix: analyticsPrefix)
    }

    /// Stable key for storing this entry in a dictionary.
    public var dictionaryKey: String {
        "\(order)"
    }
}
