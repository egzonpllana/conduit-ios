//
//  ConduitSheetDetentExpander.swift
//  Conduit
//

#if canImport(UIKit)
import UIKit

/// Programmatically promotes the top-most presented sheet to its largest detent.
///
/// Needed when a `.medium` sheet hosts a text input — iOS does not auto-grow
/// the sheet to accommodate the keyboard, so a focus event must trigger the
/// expansion explicitly.
@MainActor
public enum ConduitSheetDetentExpander {

    /// Expands the top-most sheet to the system `.large` detent.
    ///
    /// - Parameter animated: When `true`, runs the change inside the sheet's
    ///   animation block.
    public static func expandToLarge(animated: Bool = true) {
        guard let sheet = topPresentedSheet() else { return }
        let apply = {
            sheet.selectedDetentIdentifier = .large
        }
        if animated {
            sheet.animateChanges(apply)
        } else {
            apply()
        }
    }

    /// Replaces the top-most sheet's detents with a single custom detent
    /// matching `height`.
    ///
    /// Use for UIKit-presented sheets that want to hug their SwiftUI content
    /// (the SwiftUI `.presentationDetents` modifier is ignored when the sheet
    /// is presented through a wrapping `UINavigationController`).
    ///
    /// - Parameters:
    ///   - height: The target height in points. Ignored when `<= 0`.
    ///   - animated: When `true`, runs the change inside the sheet's animation
    ///     block.
    public static func setCustomHeight(_ height: CGFloat, animated: Bool = true) {
        guard let sheet = topPresentedSheet(), height > 0 else { return }
        let identifier = UISheetPresentationController.Detent.Identifier("conduit-adaptive-\(Int(height))")
        let detent = UISheetPresentationController.Detent.custom(identifier: identifier) { _ in height }
        let apply = {
            sheet.detents = [detent]
            sheet.selectedDetentIdentifier = identifier
        }
        if animated {
            sheet.animateChanges(apply)
        } else {
            apply()
        }
    }

    // MARK: - Private

    private static func topPresentedSheet() -> UISheetPresentationController? {
        guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        var top = window.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top?.sheetPresentationController
    }
}
#endif
