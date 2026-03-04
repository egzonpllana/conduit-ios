//
//  ConduitPresentationStyle.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

import Foundation

/// SDK-owned modal presentation styles, independent of UIKit.
///
/// Maps to `UIModalPresentationStyle` at the infrastructure layer.
/// Keeps the domain layer free of UIKit imports.
public enum ConduitPresentationStyle: Sendable {

    /// A presentation style that partially covers the underlying content.
    case pageSheet

    /// A presentation style that displays the content centered in the screen.
    case formSheet

    /// A presentation style in which the presented view covers the screen.
    case fullScreen

    /// A presentation style where the content is displayed over the current context.
    case overFullScreen

    /// A presentation style where the content is displayed over the current content.
    case currentContext

    /// A presentation style where the content is displayed over the current content,
    /// allowing the underlying content to show through.
    case overCurrentContext
}
