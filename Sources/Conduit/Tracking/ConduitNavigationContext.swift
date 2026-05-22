//
//  ConduitNavigationContext.swift
//  Conduit
//

import Foundation

/// Holds free-form key/value context about the current navigation state.
///
/// The tracker stores the context attached to each navigation stack entry so
/// subscribers can answer "is the user already in the right place?" without
/// re-walking the destination payloads.
///
/// The SDK does not assign meaning to specific keys — apps define their own.
/// A common pattern is to extend `ConduitNavigationContext` with typed accessors:
///
/// ```swift
/// extension ConduitNavigationContext {
///     var pocketId: String? { values["pocketId"] }
///     var eventId: String? { values["eventId"] }
///     func isInPocket(_ id: String) -> Bool { pocketId == id }
/// }
/// ```
public struct ConduitNavigationContext: Equatable, Sendable {

    /// The raw key/value bag stored for this context.
    public let values: [String: String]

    public init(values: [String: String] = [:]) {
        self.values = values
    }

    /// An empty context with no stored values.
    public static let empty = ConduitNavigationContext()

    /// Returns the value stored for the given key, or `nil` if absent.
    public subscript(key: String) -> String? {
        values[key]
    }

    /// Returns `true` when no values are stored.
    public var isEmpty: Bool {
        values.isEmpty
    }
}
