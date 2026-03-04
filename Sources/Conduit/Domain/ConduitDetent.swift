//
//  ConduitDetent.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

import Foundation

/// Defines sheet detent sizes for modal presentations.
///
/// Each case maps to a `UISheetPresentationController.Detent` at the
/// infrastructure layer. The domain layer remains UIKit-free.
public enum ConduitDetent: Sendable {

    /// The system medium detent (approximately half screen).
    case medium

    /// The system large detent (full height).
    case large

    /// A custom fixed-height detent.
    ///
    /// - Parameter height: The height in points.
    case custom(CGFloat)

    /// A fractional detent relative to the maximum detent value.
    ///
    /// - Parameter fraction: A value between 0 and 1 representing the fraction.
    case fraction(CGFloat)
}
