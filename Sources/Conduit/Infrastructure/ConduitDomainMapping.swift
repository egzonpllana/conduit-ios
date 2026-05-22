//
//  ConduitDomainMapping.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

#if canImport(UIKit)
import UIKit

// MARK: - ConduitLargeTitleDisplayMode → UIKit

extension ConduitLargeTitleDisplayMode {

    /// Maps the SDK large title mode to its UIKit equivalent.
    var uiKit: UINavigationItem.LargeTitleDisplayMode {
        switch self {
        case .automatic: return .automatic
        case .always: return .always
        case .never: return .never
        }
    }
}

// MARK: - ConduitPresentationStyle → UIKit

extension ConduitPresentationStyle {

    /// Maps the SDK presentation style to its UIKit equivalent.
    var uiKit: UIModalPresentationStyle {
        switch self {
        case .pageSheet: return .pageSheet
        case .formSheet: return .formSheet
        case .fullScreen: return .fullScreen
        case .overFullScreen: return .overFullScreen
        case .currentContext: return .currentContext
        case .overCurrentContext: return .overCurrentContext
        }
    }
}

// MARK: - ConduitDetent → UIKit

extension ConduitDetent {

    /// Maps the SDK detent to its UIKit sheet detent equivalent.
    ///
    /// `.adaptiveHeight` cannot resolve without measuring its hosting view, so
    /// the mapping here falls back to `.medium()`. `ConduitRouter.handlePresent`
    /// detects `.adaptiveHeight` and substitutes a measured `.custom` detent
    /// before this default is used.
    var uiKit: UISheetPresentationController.Detent {
        switch self {
        case .medium:
            return .medium()
        case .large:
            return .large()
        case .custom(let height):
            return .custom { _ in height }
        case .fraction(let fraction):
            return .custom { context in
                context.maximumDetentValue * fraction
            }
        case .adaptiveHeight:
            return .medium()
        }
    }
}
#endif
