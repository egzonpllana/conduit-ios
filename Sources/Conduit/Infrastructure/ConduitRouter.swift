//
//  ConduitRouter.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

#if canImport(UIKit)
import UIKit
import SwiftUI
import Combine

#if canImport(SafariServices)
import SafariServices
#endif

/// The core navigation router that translates `ConduitAction` values into UIKit operations.
///
/// `ConduitRouter` subscribes to a dispatcher's action publisher and performs
/// the corresponding push, present, pop, dismiss, or tab selection on
/// the active `UINavigationController`.
///
/// ```swift
/// let dispatcher = ConduitDispatcher<AppDestination>()
/// let factory = AppViewFactory()
/// let router = ConduitRouter(dispatcher: dispatcher, viewFactory: factory)
/// router.updateActiveWindow(window)
/// ```
@MainActor
public final class ConduitRouter<Factory: ConduitViewFactory>: ConduitRouting {

    // MARK: - Properties

    private let dispatcher: any ConduitDispatching<Factory.Destination>
    private let viewFactory: Factory
    private var cancellables = Set<AnyCancellable>()
    private var activeWindow: UIWindow?
    private var tabController: UITabBarController?
    private var rootNavigationController: UINavigationController?
    private var presentedNavStack: [UINavigationController] = []

    // MARK: - Initialization

    /// Creates a new router bound to a dispatcher and view factory.
    ///
    /// - Parameters:
    ///   - dispatcher: The dispatcher to subscribe to for navigation actions.
    ///   - viewFactory: The factory that builds views for each destination.
    public init(
        dispatcher: any ConduitDispatching<Factory.Destination>,
        viewFactory: Factory
    ) {
        self.dispatcher = dispatcher
        self.viewFactory = viewFactory
        self.rootNavigationController = UINavigationController()
        bindDispatcher()
    }

    // MARK: - ConduitRouting

    /// Replaces the window's root view controller.
    ///
    /// - Parameters:
    ///   - viewController: The new root view controller.
    ///   - window: The window to update. If `nil`, uses the active window.
    public func changeRoot(to viewController: UIViewController, in window: UIWindow? = nil) {
        let targetWindow = window ?? activeWindow
        presentedNavStack.removeAll()

        if let oldRoot = targetWindow?.rootViewController {
            oldRoot.dismiss(animated: false)
            if let nav = oldRoot as? UINavigationController {
                nav.setViewControllers([], animated: false)
            }
        }

        if let nav = viewController as? UINavigationController {
            rootNavigationController = nav
        } else if let tab = viewController as? UITabBarController {
            tabController = tab
            rootNavigationController = nil
        } else {
            let nav = UINavigationController(rootViewController: viewController)
            rootNavigationController = nav
            targetWindow?.rootViewController = nav
            targetWindow?.makeKeyAndVisible()
            return
        }

        targetWindow?.rootViewController = viewController
        targetWindow?.makeKeyAndVisible()
    }

    /// Updates the currently active window used by the router.
    ///
    /// - Parameter window: The new `UIWindow` instance to track.
    public func updateActiveWindow(_ window: UIWindow) {
        self.activeWindow = window
    }

    /// Assigns a tab bar controller for tab-based navigation.
    ///
    /// - Parameter tabBarController: The tab bar controller to manage.
    public func setTabController(_ tabBarController: UITabBarController) {
        self.tabController = tabBarController
    }
}

// MARK: - Dispatcher Binding

private extension ConduitRouter {
    func bindDispatcher() {
        dispatcher.actionPublisher
            .sink { [weak self] action in
                // Run synchronously when already on the main thread so the
                // navigation animation can start in the same run-loop tick as
                // the tap. Background-thread callers (Combine sinks, async
                // tasks) still hop to main for UIKit safety.
                if Thread.isMainThread {
                    MainActor.assumeIsolated {
                        self?.dispatchOnMain(action)
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.dispatchOnMain(action)
                    }
                }
            }
            .store(in: &cancellables)
    }

    func dispatchOnMain(_ action: ConduitAction<Factory.Destination>) {
        switch action {
        case let .push(destination, barPreferences):
            guard let navController = resolveActiveNavigationController() else {
                logConduitError("No active UINavigationController to perform push.")
                return
            }
            handlePush(destination, using: navController, preferences: barPreferences)

        case let .present(
            destination,
            style,
            isModalInPresentation,
            detents,
            preferredHeight,
            showDragIndicator,
            presentationBackground,
            barPreferences,
            animated
        ):
            handlePresent(
                destination,
                style: style,
                isModalInPresentation: isModalInPresentation,
                detents: detents,
                preferredHeight: preferredHeight,
                showDragIndicator: showDragIndicator,
                presentationBackground: presentationBackground,
                preferences: barPreferences,
                animated: animated
            )

        #if canImport(SafariServices)
        case let .openSafari(url):
            handleOpenSafari(url: url)
        #endif

        case .pop:
            guard let navController = resolveActiveNavigationController() else {
                logConduitError("No active UINavigationController to perform pop.")
                return
            }
            navController.popViewController(animated: true)

        case let .popMultiple(count, animated):
            guard let navController = resolveActiveNavigationController() else {
                logConduitError("No active UINavigationController to perform popMultiple.")
                return
            }
            let viewControllers = navController.viewControllers
            guard count > 0, count < viewControllers.count else { return }
            let targetIndex = viewControllers.count - count - 1
            navController.popToViewController(viewControllers[targetIndex], animated: animated)

        case .popToRoot:
            guard let navController = resolveActiveNavigationController() else {
                logConduitError("No active UINavigationController to perform popToRoot.")
                return
            }
            navController.popToRootViewController(animated: true)

        case let .dismiss(animated, completion):
            handleDismiss(animated: animated, completion: completion)

        case let .changeRoot(rootBuilder, _):
            handleChangeRoot(builder: rootBuilder)

        case let .selectTab(tabIndex):
            handleSelectTab(tabIndex)

        case let .popToRootAndSelectTab(tabIndex, _, completion):
            handlePopToRootAndSelectTab(tabIndex: tabIndex, completion: completion)
        }
    }
}

// MARK: - Navigation Helpers

private extension ConduitRouter {

    /// Walks the `presentedViewController` chain to find the top-most VC that
    /// can issue a `present(_:animated:)` call. Without this, UIKit logs
    /// "Attempt to present <X> on <Y> which is already presenting <Z>" and the
    /// new modal never appears.
    func topMostPresenter(from root: UIViewController) -> UIViewController {
        var current = root
        while let next = current.presentedViewController {
            current = next
        }
        return current
    }

    /// Returns `true` when the top-most presenter is mid-transition and a
    /// `present`/`dismiss` issued right now would be dropped by UIKit.
    func isPresenterTransitioning(_ presenter: UIViewController) -> Bool {
        presenter.isBeingPresented
            || presenter.isBeingDismissed
            || presenter.transitionCoordinator != nil
    }

    /// Resolves the active navigation controller used as the base for push/pop.
    /// Walks any orphaned entries off `presentedNavStack` whose view is no
    /// longer in the window hierarchy.
    func resolveActiveNavigationController() -> UINavigationController? {
        while let top = presentedNavStack.last {
            if top.view.window != nil {
                return top
            } else {
                presentedNavStack.removeLast()
            }
        }

        guard let rootVC = activeWindow?.rootViewController ?? tabController else {
            logConduitError("No root view controller set.")
            return nil
        }

        // If a native modal (e.g. SwiftUI `.sheet`) is on top of the tab/root
        // and contains a navigation controller, push into that one so we don't
        // break the user's modal context.
        let resolvedTop = topMostPresenter(from: rootVC)
        if let nav = resolvedTop as? UINavigationController {
            return nav
        }
        if let nav = resolvedTop.closestNavigationController() {
            return nav
        }

        if let tabBar = rootVC as? UITabBarController,
           let nav = tabBar.selectedViewController as? UINavigationController {
            return nav
        }

        return rootVC.closestNavigationController()
    }

    func handlePush(
        _ destination: Factory.Destination,
        using navController: UINavigationController,
        preferences: ConduitBarPreferences
    ) {
        let view = viewFactory.makeView(destination)
        let hostingController = UIHostingController(rootView: view)
        hostingController.navigationItem.largeTitleDisplayMode = preferences.largeTitleDisplayMode.uiKit
        hostingController.hidesBottomBarWhenPushed = preferences.hideTabBar
        hostingController.restorationIdentifier = viewFactory.makeIdentifier(destination)
        navController.setNavigationBarHidden(preferences.isHidden, animated: true)
        navController.pushViewController(hostingController, animated: true)
    }

    func handlePresent(
        _ destination: Factory.Destination,
        style: ConduitPresentationStyle,
        isModalInPresentation: Bool,
        detents: [ConduitDetent]?,
        preferredHeight: CGFloat?,
        showDragIndicator: Bool,
        presentationBackground: Color?,
        preferences: ConduitBarPreferences,
        animated: Bool
    ) {
        guard let rootVC = activeWindow?.rootViewController else {
            logConduitError("No root view controller — cannot present.")
            return
        }

        let presenter = topMostPresenter(from: rootVC)

        // If the presenter is mid-transition, requeue on the next run-loop tick.
        if isPresenterTransitioning(presenter) {
            DispatchQueue.main.async { [weak self] in
                self?.handlePresent(
                    destination,
                    style: style,
                    isModalInPresentation: isModalInPresentation,
                    detents: detents,
                    preferredHeight: preferredHeight,
                    showDragIndicator: showDragIndicator,
                    presentationBackground: presentationBackground,
                    preferences: preferences,
                    animated: animated
                )
            }
            return
        }

        let view = viewFactory.makeView(destination)
        let hostingController = UIHostingController(rootView: view)
        hostingController.navigationItem.largeTitleDisplayMode = preferences.largeTitleDisplayMode.uiKit
        hostingController.restorationIdentifier = viewFactory.makeIdentifier(destination)

        if let backgroundColor = presentationBackground.flatMap({ UIColor($0) }) {
            hostingController.view.backgroundColor = backgroundColor
        }

        let wrappedNav = UINavigationController(rootViewController: hostingController)
        wrappedNav.modalPresentationStyle = style.uiKit
        wrappedNav.isModalInPresentation = isModalInPresentation
        wrappedNav.setNavigationBarHidden(preferences.isHidden, animated: false)

        if let backgroundColor = presentationBackground.flatMap({ UIColor($0) }) {
            wrappedNav.view.backgroundColor = backgroundColor
        }

        configureSheetIfNeeded(
            wrappedNav: wrappedNav,
            hostingController: hostingController,
            detents: detents,
            preferredHeight: preferredHeight,
            showDragIndicator: showDragIndicator
        )

        presenter.present(wrappedNav, animated: animated)
        presentedNavStack.append(wrappedNav)
    }

    func configureSheetIfNeeded(
        wrappedNav: UINavigationController,
        hostingController: UIHostingController<AnyView>,
        detents: [ConduitDetent]?,
        preferredHeight: CGFloat?,
        showDragIndicator: Bool
    ) {
        guard let sheet = wrappedNav.sheetPresentationController else { return }

        if let detents, !detents.isEmpty {
            let containsAdaptive = detents.contains { detent in
                if case .adaptiveHeight = detent { return true } else { return false }
            }
            if containsAdaptive {
                let targetWidth = activeWindow?.bounds.width ?? UIScreen.main.bounds.width
                let measured = hostingController.sizeThatFits(
                    in: CGSize(width: targetWidth, height: .greatestFiniteMagnitude)
                )
                let resolvedHeight = max(measured.height, 1)
                sheet.detents = detents.map { detent in
                    switch detent {
                    case .adaptiveHeight:
                        return .custom { _ in resolvedHeight }
                    default:
                        return detent.uiKit
                    }
                }
            } else {
                sheet.detents = detents.map { $0.uiKit }
            }
        } else if let height = preferredHeight {
            sheet.detents = [.custom { _ in height }]
        }

        sheet.prefersGrabberVisible = showDragIndicator
    }

    #if canImport(SafariServices)
    func handleOpenSafari(url: URL) {
        guard let rootVC = activeWindow?.rootViewController else {
            logConduitError("No root view controller — cannot present Safari.")
            return
        }

        let presenter = topMostPresenter(from: rootVC)
        if isPresenterTransitioning(presenter) {
            DispatchQueue.main.async { [weak self] in
                self?.handleOpenSafari(url: url)
            }
            return
        }

        let safariVC = SFSafariViewController(url: url)
        safariVC.modalPresentationStyle = .pageSheet
        presenter.present(safariVC, animated: true)
    }
    #endif

    func handleDismiss(animated: Bool, completion: (@Sendable () -> Void)?) {
        // Prefer the tracked modal nav stack so dismiss order stays predictable.
        if let topPresented = presentedNavStack.last {
            topPresented.dismiss(animated: animated) { [weak self] in
                if let self, !self.presentedNavStack.isEmpty {
                    self.presentedNavStack.removeLast()
                }
                completion?()
            }
            return
        }

        // Fallback: dismiss whatever is on top (e.g. Safari, system pickers
        // that bypass `presentedNavStack`).
        guard let rootVC = activeWindow?.rootViewController else {
            completion?()
            return
        }
        let presenter = topMostPresenter(from: rootVC)
        if presenter === rootVC {
            completion?()
            return
        }
        presenter.dismiss(animated: animated, completion: completion)
    }

    func handleChangeRoot(builder: @MainActor @Sendable () -> UIViewController) {
        // Dismiss every tracked modal before swapping the root.
        if let oldRoot = activeWindow?.rootViewController {
            oldRoot.dismiss(animated: false)
        }
        presentedNavStack.removeAll()
        tabController = nil
        rootNavigationController?.setViewControllers([], animated: false)
        rootNavigationController = nil

        let newRoot = builder()
        changeRoot(to: newRoot, in: activeWindow)
    }

    func handleSelectTab(_ tabIndex: Int) {
        guard let tabBar = tabController else {
            logConduitError("No tab controller available for tab selection.")
            return
        }
        guard tabIndex >= 0, tabIndex < (tabBar.viewControllers?.count ?? 0) else {
            logConduitError("Invalid tab index: \(tabIndex)")
            return
        }
        tabBar.selectedIndex = tabIndex
    }

    func handlePopToRootAndSelectTab(tabIndex: Int, completion: (@Sendable () -> Void)?) {
        dismissAllPresentedViewControllers { [weak self] in
            guard let self else {
                completion?()
                return
            }
            self.popAllNavigationStacksToRoot()
            self.handleSelectTab(tabIndex)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                completion?()
            }
        }
    }

    func dismissAllPresentedViewControllers(completion: @escaping @MainActor () -> Void) {
        guard !presentedNavStack.isEmpty else {
            completion()
            return
        }

        func dismissNext() {
            guard let topPresented = presentedNavStack.last else {
                completion()
                return
            }
            topPresented.dismiss(animated: false) { [weak self] in
                self?.presentedNavStack.removeLast()
                dismissNext()
            }
        }

        dismissNext()
    }

    func popAllNavigationStacksToRoot() {
        guard let tabBar = tabController,
              let viewControllers = tabBar.viewControllers else {
            return
        }
        for viewController in viewControllers {
            if let navController = viewController as? UINavigationController {
                navController.popToRootViewController(animated: false)
            }
        }
    }

    func logConduitError(_ message: String) {
        #if DEBUG
        print("[Conduit] Error: \(message)")
        #endif
    }
}
#endif
