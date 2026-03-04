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
    private var isBound = false

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
            bindDispatcher()
            return
        }

        targetWindow?.rootViewController = viewController
        targetWindow?.makeKeyAndVisible()
        bindDispatcher()
    }

    /// Updates the currently active window used by the router.
    ///
    /// - Parameter window: The new `UIWindow` instance to track.
    public func updateActiveWindow(_ window: UIWindow) {
        self.activeWindow = window
        bindDispatcher()
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
        guard isBound == false else { return }
        isBound = true

        dispatcher.actionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] action in
                guard let self else { return }
                guard let navController = self.resolveActiveNavigationController() else {
                    self.logConduitError("No active UINavigationController to perform navigation.")
                    return
                }
                self.handle(action, using: navController)
            }
            .store(in: &cancellables)
    }

    func handle(_ action: ConduitAction<Factory.Destination>, using navController: UINavigationController) {
        switch action {
        case let .push(destination, barPreferences):
            handlePush(destination, using: navController, preferences: barPreferences)

        case let .present(destination, style, isModalInPresentation, detents, preferredHeight, showDragIndicator, barPreferences, animated):
            handlePresent(
                destination,
                using: navController,
                style: style,
                isModalInPresentation: isModalInPresentation,
                detents: detents,
                preferredHeight: preferredHeight,
                showDragIndicator: showDragIndicator,
                preferences: barPreferences,
                animated: animated
            )

        case .pop:
            navController.popViewController(animated: true)

        case let .popMultiple(count, animated):
            let viewControllers = navController.viewControllers
            guard count > 0, count < viewControllers.count else { break }
            let targetIndex = viewControllers.count - count - 1
            navController.popToViewController(viewControllers[targetIndex], animated: animated)

        case .popToRoot:
            navController.popToRootViewController(animated: true)

        case let .dismiss(animated, completion):
            if let topPresented = presentedNavStack.last {
                topPresented.dismiss(animated: animated) { [weak self] in
                    if let self, !self.presentedNavStack.isEmpty {
                        self.presentedNavStack.removeLast()
                    }
                    completion?()
                }
            }

        case let .selectTab(tabIndex):
            handleSelectTab(tabIndex)

        case let .popToRootAndSelectTab(tabIndex, completion):
            handlePopToRootAndSelectTab(tabIndex: tabIndex, completion: completion)
        }
    }
}

// MARK: - Navigation Helpers

private extension ConduitRouter {
    func resolveActiveNavigationController() -> UINavigationController? {
        while let top = presentedNavStack.last {
            if top.view.window != nil {
                return top
            } else {
                presentedNavStack.removeLast()
            }
        }

        guard let rootVC = activeWindow?.rootViewController else {
            logConduitError("No root view controller set.")
            return nil
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
        using navController: UINavigationController,
        style: ConduitPresentationStyle,
        isModalInPresentation: Bool,
        detents: [ConduitDetent]?,
        preferredHeight: CGFloat?,
        showDragIndicator: Bool,
        preferences: ConduitBarPreferences,
        animated: Bool
    ) {
        let view = viewFactory.makeView(destination)
        let hostingController = UIHostingController(rootView: view)
        hostingController.navigationItem.largeTitleDisplayMode = preferences.largeTitleDisplayMode.uiKit
        hostingController.restorationIdentifier = viewFactory.makeIdentifier(destination)

        let wrappedNav = UINavigationController(rootViewController: hostingController)
        wrappedNav.modalPresentationStyle = style.uiKit
        wrappedNav.isModalInPresentation = isModalInPresentation
        wrappedNav.setNavigationBarHidden(preferences.isHidden, animated: false)

        if let sheet = wrappedNav.sheetPresentationController {
            if let detents, !detents.isEmpty {
                sheet.detents = detents.map { $0.uiKit }
            } else if let height = preferredHeight {
                sheet.detents = [.custom { _ in height }]
            }
            sheet.prefersGrabberVisible = showDragIndicator
        }

        navController.present(wrappedNav, animated: animated)
        presentedNavStack.append(wrappedNav)
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

    func dismissAllPresentedViewControllers(completion: @escaping @Sendable () -> Void) {
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
