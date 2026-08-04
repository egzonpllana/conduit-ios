//
//  ConduitNavigationBarCoordinator.swift
//  Conduit
//

#if canImport(UIKit)
import UIKit

/// Owns navigation bar visibility per view controller instead of per action.
///
/// `UINavigationController.setNavigationBarHidden(_:animated:)` is stack-wide
/// state, but `ConduitBarPreferences.isHidden` describes a single destination.
/// Applying it at push time therefore had two failure modes:
///
/// 1. **The bar animated separately from the push.** Setting it and pushing in
///    the same breath starts two unrelated animations, so the incoming screen
///    laid out without a bar and was then shoved down when the bar arrived.
/// 2. **Nothing restored it.** Popping back left the pushed screen's bar state
///    applied to the screen underneath, which had never asked for it.
///
/// Routing everything through `navigationController(_:willShow:animated:)`
/// fixes both: the change rides the transition coordinator so it moves with the
/// content, and *every* transition — push, pop, `popToRoot`, `popMultiple`, and
/// the interactive swipe-back — resolves the incoming controller's own
/// preference. A controller with no recorded preference falls back to the
/// baseline captured when Conduit first attached, so a root the app configured
/// itself keeps whatever it set.
@MainActor
final class ConduitNavigationBarCoordinator: NSObject, UINavigationControllerDelegate {

    /// Per-controller preference. Weak keys so entries die with their screens.
    private let preferences = NSMapTable<UIViewController, NSNumber>.weakToStrongObjects()

    /// Bar state each stack had before Conduit touched it.
    private let baselines = NSMapTable<UINavigationController, NSNumber>.weakToStrongObjects()

    /// Becomes the stack's delegate so transitions can be observed.
    ///
    /// - Returns: `false` when the stack already has a delegate that is not
    ///   this coordinator. Conduit never steals an app's own delegate; the
    ///   caller falls back to applying the preference directly, which is the
    ///   pre-existing behaviour.
    @discardableResult
    func attach(to navigationController: UINavigationController) -> Bool {
        if navigationController.delegate === self { return true }

        guard navigationController.delegate == nil else {
            #if DEBUG
            print(
                "[Conduit] Error: Navigation bar coordination disabled — this "
                    + "UINavigationController already has a delegate. Conduit will apply bar "
                    + "preferences directly, which cannot restore them on pop."
            )
            #endif
            return false
        }

        baselines.setObject(
            NSNumber(value: navigationController.isNavigationBarHidden),
            forKey: navigationController
        )
        navigationController.delegate = self
        return true
    }

    /// Records the bar state `viewController` wants while it is on top.
    func setBarHidden(_ isHidden: Bool, for viewController: UIViewController) {
        preferences.setObject(NSNumber(value: isHidden), forKey: viewController)
    }

    // MARK: - UINavigationControllerDelegate

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        apply(
            resolvedIsHidden(for: viewController, in: navigationController),
            in: navigationController,
            animated: animated
        )

        // An interactive pop the user abandons slides the previous controller
        // back out without a second `willShow`, so the bar would be left in the
        // state the aborted destination wanted.
        navigationController.transitionCoordinator?.notifyWhenInteractionChanges { [weak self] context in
            guard context.isCancelled,
                  let self,
                  let from = context.viewController(forKey: .from) else { return }

            self.apply(
                self.resolvedIsHidden(for: from, in: navigationController),
                in: navigationController,
                animated: animated
            )
        }
    }

    // MARK: - Resolution

    private func resolvedIsHidden(
        for viewController: UIViewController,
        in navigationController: UINavigationController
    ) -> Bool {
        if let recorded = preferences.object(forKey: viewController) {
            return recorded.boolValue
        }
        if let baseline = baselines.object(forKey: navigationController) {
            return baseline.boolValue
        }
        return navigationController.isNavigationBarHidden
    }

    private func apply(
        _ isHidden: Bool,
        in navigationController: UINavigationController,
        animated: Bool
    ) {
        guard navigationController.isNavigationBarHidden != isHidden else { return }

        // `willShow` already runs inside the transition, so UIKit's own bar
        // animation is coordinated with the push or pop. Do not wrap this in
        // `transitionCoordinator.animate(alongsideTransition:)`: that replaces
        // the coordinated transition with a plain frame animation, and the bar
        // visibly slides down from the top instead of arriving with the screen.
        navigationController.setNavigationBarHidden(isHidden, animated: animated)
    }
}
#endif
