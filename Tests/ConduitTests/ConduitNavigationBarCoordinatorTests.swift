//
//  ConduitNavigationBarCoordinatorTests.swift
//  Conduit
//

#if canImport(UIKit)
import Testing
import UIKit

@testable import Conduit

@MainActor
@Suite("ConduitNavigationBarCoordinator Tests")
struct ConduitNavigationBarCoordinatorTests {

    /// A stack whose bar starts hidden, mirroring an app that hides it at launch.
    private func makeStack(barHidden: Bool) -> UINavigationController {
        let navigationController = UINavigationController(rootViewController: UIViewController())
        navigationController.setNavigationBarHidden(barHidden, animated: false)
        return navigationController
    }

    @Test("Attaching takes the delegate and records the current bar state")
    func attachRecordsBaseline() {
        let coordinator = ConduitNavigationBarCoordinator()
        let stack = makeStack(barHidden: true)

        #expect(coordinator.attach(to: stack))
        #expect(stack.delegate === coordinator)
    }

    @Test("Attaching twice is idempotent")
    func attachIsIdempotent() {
        let coordinator = ConduitNavigationBarCoordinator()
        let stack = makeStack(barHidden: true)

        #expect(coordinator.attach(to: stack))
        #expect(coordinator.attach(to: stack))
    }

    @Test("An app's own delegate is never replaced")
    func foreignDelegateIsPreserved() {
        final class ForeignDelegate: NSObject, UINavigationControllerDelegate {}

        let coordinator = ConduitNavigationBarCoordinator()
        let stack = makeStack(barHidden: true)
        let foreign = ForeignDelegate()
        stack.delegate = foreign

        #expect(coordinator.attach(to: stack) == false)
        #expect(stack.delegate === foreign)
    }

    @Test("Showing a destination applies the bar state it asked for")
    func appliesRecordedPreference() {
        let coordinator = ConduitNavigationBarCoordinator()
        let stack = makeStack(barHidden: true)
        coordinator.attach(to: stack)

        let pushed = UIViewController()
        coordinator.setBarHidden(false, for: pushed)
        coordinator.navigationController(stack, willShow: pushed, animated: false)

        #expect(stack.isNavigationBarHidden == false)
    }

    /// The regression this type exists for: a pushed screen that shows the bar
    /// used to leave it visible over the screen underneath, shifting content
    /// down. Going back must restore the stack's original state.
    @Test("Returning to a destination with no preference restores the baseline")
    func restoresBaselineOnPop() {
        let coordinator = ConduitNavigationBarCoordinator()
        let stack = makeStack(barHidden: true)
        coordinator.attach(to: stack)
        let root = stack.viewControllers[0]

        let pushed = UIViewController()
        coordinator.setBarHidden(false, for: pushed)
        coordinator.navigationController(stack, willShow: pushed, animated: false)
        #expect(stack.isNavigationBarHidden == false)

        coordinator.navigationController(stack, willShow: root, animated: false)
        #expect(stack.isNavigationBarHidden)
    }

    @Test("Each destination keeps its own preference across transitions")
    func preferencesArePerDestination() {
        let coordinator = ConduitNavigationBarCoordinator()
        let stack = makeStack(barHidden: true)
        coordinator.attach(to: stack)

        let showsBar = UIViewController()
        let hidesBar = UIViewController()
        coordinator.setBarHidden(false, for: showsBar)
        coordinator.setBarHidden(true, for: hidesBar)

        coordinator.navigationController(stack, willShow: showsBar, animated: false)
        #expect(stack.isNavigationBarHidden == false)

        coordinator.navigationController(stack, willShow: hidesBar, animated: false)
        #expect(stack.isNavigationBarHidden)

        coordinator.navigationController(stack, willShow: showsBar, animated: false)
        #expect(stack.isNavigationBarHidden == false)
    }

    // MARK: - Swipe back

    @Test("Attaching takes over the swipe-back recognizer")
    func attachInstallsSwipeBack() {
        let coordinator = ConduitNavigationBarCoordinator()
        let stack = makeStack(barHidden: true)

        coordinator.attach(to: stack)

        #expect(stack.interactivePopGestureRecognizer?.delegate === coordinator)
    }

    @Test("Swipe back is off on a stack's root")
    func swipeBackOffAtRoot() throws {
        let coordinator = ConduitNavigationBarCoordinator()
        let stack = makeStack(barHidden: true)
        coordinator.attach(to: stack)
        let recognizer = try #require(stack.interactivePopGestureRecognizer)

        #expect(coordinator.gestureRecognizerShouldBegin(recognizer) == false)
    }

    @Test("Swipe back works on a pushed screen with the bar hidden")
    func swipeBackOnPushedScreen() throws {
        let coordinator = ConduitNavigationBarCoordinator()
        let stack = makeStack(barHidden: true)
        coordinator.attach(to: stack)
        stack.setViewControllers([UIViewController(), UIViewController()], animated: false)
        let recognizer = try #require(stack.interactivePopGestureRecognizer)

        #expect(coordinator.gestureRecognizerShouldBegin(recognizer))
    }

    @Test("A screen that turned swipe back off blocks it until it turns it on")
    func swipeBackDisabledPerScreen() throws {
        let coordinator = ConduitNavigationBarCoordinator()
        let stack = makeStack(barHidden: true)
        coordinator.attach(to: stack)
        let top = UIViewController()
        stack.setViewControllers([UIViewController(), top], animated: false)
        let recognizer = try #require(stack.interactivePopGestureRecognizer)

        ConduitSwipeBack.setDisabled(true, for: top)
        #expect(coordinator.gestureRecognizerShouldBegin(recognizer) == false)

        ConduitSwipeBack.setDisabled(false, for: top)
        #expect(coordinator.gestureRecognizerShouldBegin(recognizer))
    }

    @Test("A recognizer from a stack the coordinator doesn't own never starts")
    func foreignRecognizerNeverBegins() {
        let coordinator = ConduitNavigationBarCoordinator()

        #expect(coordinator.gestureRecognizerShouldBegin(UIPanGestureRecognizer()) == false)
    }
}
#endif
