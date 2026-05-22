//
//  ConduitRootChangeMetadata.swift
//  Conduit
//

import Foundation

/// Metadata describing a `.changeRoot` action for tracker consumers.
///
/// The router itself ignores this payload — it is forwarded to subscribers like
/// `ConduitNavigationTracker` so they can record the root swap with analytics
/// context.
public struct ConduitRootChangeMetadata: Sendable {

    /// Human-readable identifier for the new root (e.g. `"tab_bar"`, `"sign_in"`).
    public let rootName: String

    /// Free-form reason for the root swap (e.g. `"user_signed_in"`,
    /// `"session_expired"`).
    public let reason: String

    /// When `true`, the tracker re-populates its tab navigation stacks from the
    /// initial tab screens passed at construction time. When `false`, the tracker
    /// clears all tab stacks (typical for auth-flow transitions).
    public let resetsTabStacks: Bool

    public init(
        rootName: String = "",
        reason: String = "",
        resetsTabStacks: Bool = true
    ) {
        self.rootName = rootName
        self.reason = reason
        self.resetsTabStacks = resetsTabStacks
    }
}
