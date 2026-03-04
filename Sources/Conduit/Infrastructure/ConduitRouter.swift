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

/// The core navigation router that translates ``ConduitAction`` values into UIKit navigation operations.
///
/// `ConduitRouter` subscribes to a ``ConduitDispatching`` publisher and performs
/// push, present, pop, dismiss, and tab selection operations on UIKit navigation controllers.
/// It wraps SwiftUI views in `UIHostingController` using the injected view factory.
///
/// ```swift
/// let router = ConduitRouter(
///     viewFactory: AppViewFactory(),
///     dispatcher: dispatcher
/// )
/// router.start(in: window, rootViewController: tabBarController)
/// ```
@MainActor
public final class ConduitRouter<Factory: ConduitViewFactory>: ConduitRouting {

    // MARK: - Properties

    private let viewFactory: Factory
    private let dispatcher: any ConduitDispatching<Factory.Destination>
    private var cancellables = Set<AnyCancellable>()
    private var presentedNavStack: [UINavigationController] = []
    private weak var activeWindow: UIWindow?
    private weak var tabController: UITabBarController?
    private var rootNavigationController: UINavigationController?
    private var isBound = false

    // MARK: - Initialization

    /// Creates a router with a view factory and dispatcher.
    ///
    /// - Parameters:
    ///   - viewFactory: The factory that creates SwiftUI views from destinations.
    ///   - dispatcher: The dispatcher that publishes navigation actions.
    public init(
        viewFactory: Factory,
        dispatcher: any ConduitDispatching<Factory.Destination>
    ) {
        self.viewFactory = viewFactory
        self.dispatcher = dispatcher
    }

    // MARK: - ConduitRouting

    public func start(in window: UIWindow, rootViewController: UIViewController) {
        self.activeWindow = window
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()

        if let tabBar = rootViewController as? UITabBarController {
            self.tabController = tabBar
        } else if let nav = rootViewController as? UINavigationController {
            self.rootNavigationController = nav
        }

        bindDispatcher()
    }

    public func updateActiveWindow(_ window: UIWindow) {
        self.activeWindow = window
    }

    public func changeRoot(to viewController: UIViewController) {
        presentedNavStack.removeAll()
        rootNavigationController?.popToRootViewController(animated: false)
        rootNavigationController?.setViewControllers([], animated: false)

        if let tabBar = viewController as? UITabBarController {
            self.tabController = tabBar
            self.rootNavigationController = nil
        } else if let nav = viewController as? UINavigationController {
            self.rootNavigationController = nav
            self.tabController = nil
        } else {
            let nav = UINavigationController(rootViewController: viewController)
            self.rootNavigationController = nav
            self.tabController = nil
        }

        activeWindow?.rootViewController = viewController
        activeWindow?.makeKeyAndVisible()
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
                self.handle(action)
            }
            .store(in: &cancellables)
    }

    func handle(_ action: ConduitAction<Factory.Destination>) {
        guard let navController = resolveActiveNavigationController() else {
            logDebug("No active UINavigationController to perform navigation.")
            return
        }

        switch action {
        case let .push(destination, barPreferences):
            handlePush(destination, using: navController, preferences: barPreferences)

        case let .present(destination, style, isModalInPresentation, detents,
                          preferredHeight, showDragIndicator, barPreferences, animated):
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
            handleDismiss(animated: animated, completion: completion)

        case let .selectTab(tabIndex):
            handleSelectTab(tabIndex)

        case let .popToRootAndSelectTab(tabIndex, completion):
            handlePopToRootAndSelectTab(tabIndex: tabIndex, completion: completion)
        }
    }
}

// MARK: - Navigation Handlers

private extension ConduitRouter {

    func handlePush(
        _ destination: Factory.Destination,
        using navController: UINavigationController,
        preferences: ConduitBarPreferences
    ) {
        let view = viewFactory.makeView(for: destination)
        let hostingController = UIHostingController(rootView: view)
        hostingController.navigationItem.largeTitleDisplayMode = preferences.largeTitleDisplayMode.uiKit
        hostingController.hidesBottomBarWhenPushed = preferences.hideTabBar
        hostingController.restorationIdentifier = viewFactory.makeIdentifier(for: destination)
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
        let view = viewFactory.makeView(for: destination)
        let hostingController = UIHostingController(rootView: view)
        hostingController.navigationItem.largeTitleDisplayMode = preferences.largeTitleDisplayMode.uiKit
        hostingController.restorationIdentifier = viewFactory.makeIdentifier(for: destination)

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

    func handleDismiss(animated: Bool, completion: (() -> Void)?) {
        guard let topPresented = presentedNavStack.last else { return }
        topPresented.dismiss(animated: animated) { [weak self] in
            if let self, !self.presentedNavStack.isEmpty {
                self.presentedNavStack.removeLast()
            }
            completion?()
        }
    }

    func handleSelectTab(_ tabIndex: Int) {
        guard let tabBar = tabController else {
            logDebug("No tab controller available for tab selection.")
            return
        }
        guard tabIndex >= 0, tabIndex < (tabBar.viewControllers?.count ?? 0) else {
            logDebug("Invalid tab index: \(tabIndex)")
            return
        }
        tabBar.selectedIndex = tabIndex
    }

    func handlePopToRootAndSelectTab(tabIndex: Int, completion: (() -> Void)?) {
        dismissAllPresented { [weak self] in
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
}

// MARK: - Stack Management

private extension ConduitRouter {

    func dismissAllPresented(completion: @escaping () -> Void) {
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
              let viewControllers = tabBar.viewControllers else { return }
        for viewController in viewControllers {
            if let nav = viewController as? UINavigationController {
                nav.popToRootViewController(animated: false)
            }
        }
    }

    func resolveActiveNavigationController() -> UINavigationController? {
        while let top = presentedNavStack.last {
            if top.view.window != nil {
                return top
            } else {
                presentedNavStack.removeLast()
            }
        }

        guard let rootVC = activeWindow?.rootViewController else {
            logDebug("No root view controller set.")
            return nil
        }

        if let tabBar = rootVC as? UITabBarController,
           let nav = tabBar.selectedViewController as? UINavigationController {
            return nav
        }

        return rootVC.conduit_closestNavigationController()
    }

    func logDebug(_ message: String) {
        #if DEBUG
        print("[Conduit] \(message)")
        #endif
    }
}
#endif
