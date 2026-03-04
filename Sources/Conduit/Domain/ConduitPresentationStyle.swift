//
//  ConduitPresentationStyle.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

/// Represents the modal presentation style for presented view controllers.
///
/// Maps to `UIModalPresentationStyle` at the infrastructure layer.
public enum ConduitPresentationStyle: Sendable {

    /// A page sheet presentation.
    case pageSheet

    /// A form sheet presentation.
    case formSheet

    /// Full screen presentation.
    case fullScreen

    /// Over full screen (previous content remains visible underneath).
    case overFullScreen

    /// Over current context.
    case overCurrentContext
}
