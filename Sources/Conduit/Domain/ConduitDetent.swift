//
//  ConduitDetent.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

import Foundation

/// Represents a sheet presentation detent for modal presentations.
///
/// Maps to `UISheetPresentationController.Detent` at the infrastructure layer.
public enum ConduitDetent: Sendable {

    /// The medium detent (approximately half screen).
    case medium

    /// The large detent (full screen).
    case large

    /// A custom detent with an exact height in points.
    case custom(CGFloat)

    /// A fractional detent relative to the maximum available height.
    case fraction(CGFloat)
}
