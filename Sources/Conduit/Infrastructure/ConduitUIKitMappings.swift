//
//  ConduitUIKitMappings.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

#if canImport(UIKit)
import UIKit

// MARK: - ConduitLargeTitleDisplayMode

extension ConduitLargeTitleDisplayMode {
    var uiKit: UINavigationItem.LargeTitleDisplayMode {
        switch self {
        case .automatic: .automatic
        case .always: .always
        case .never: .never
        }
    }
}

// MARK: - ConduitDetent

extension ConduitDetent {
    var uiKit: UISheetPresentationController.Detent {
        switch self {
        case .medium:
            .medium()
        case .large:
            .large()
        case .custom(let height):
            .custom { _ in height }
        case .fraction(let fraction):
            .custom { context in context.maximumDetentValue * fraction }
        }
    }
}

// MARK: - ConduitPresentationStyle

extension ConduitPresentationStyle {
    var uiKit: UIModalPresentationStyle {
        switch self {
        case .pageSheet: .pageSheet
        case .formSheet: .formSheet
        case .fullScreen: .fullScreen
        case .overFullScreen: .overFullScreen
        case .overCurrentContext: .overCurrentContext
        }
    }
}
#endif
