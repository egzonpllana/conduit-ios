//
//  ConduitWindowUtils.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

#if canImport(UIKit)
import UIKit

/// Utility for accessing the currently active key window.
public enum ConduitWindowUtils {

    /// Returns the currently active key window of the application.
    ///
    /// Searches all connected `UIWindowScene` instances for the key window.
    ///
    /// - Returns: The active key window, or `nil` if no key window exists.
    @MainActor
    public static func activeWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
#endif
