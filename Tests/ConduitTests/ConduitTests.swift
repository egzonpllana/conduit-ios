//
//  ConduitTests.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

import Testing
import Combine

@testable import Conduit

// MARK: - Test Helpers

enum TestDestination: ConduitDestination {
    case screenA
    case screenB(value: String)
    case screenC
}

// MARK: - ConduitAction Tests

@Suite("ConduitAction Tests")
struct ConduitActionTests {

    @Test("Push action carries destination and default preferences")
    func pushActionDefaults() {
        let action = ConduitAction<TestDestination>.push(.screenA)
        if case let .push(_, barPreferences) = action {
            #expect(barPreferences.isHidden == true)
            #expect(barPreferences.hideTabBar == true)
        } else {
            Issue.record("Expected push action")
        }
    }

    @Test("Present action carries all parameters")
    func presentActionParameters() {
        let action = ConduitAction<TestDestination>.present(
            .screenB(value: "test"),
            style: .formSheet,
            isModalInPresentation: true,
            detents: [.medium, .large],
            showDragIndicator: true
        )
        if case let .present(_, style, isModal, detents, _, showDrag, _, _) = action {
            #expect(style == .formSheet)
            #expect(isModal == true)
            #expect(detents?.count == 2)
            #expect(showDrag == true)
        } else {
            Issue.record("Expected present action")
        }
    }

    @Test("Pop actions exist")
    func popActionsExist() {
        let pop = ConduitAction<TestDestination>.pop
        let popMultiple = ConduitAction<TestDestination>.popMultiple(count: 3)
        let popToRoot = ConduitAction<TestDestination>.popToRoot

        if case .pop = pop {} else { Issue.record("Expected pop") }
        if case let .popMultiple(count, _) = popMultiple {
            #expect(count == 3)
        } else {
            Issue.record("Expected popMultiple")
        }
        if case .popToRoot = popToRoot {} else { Issue.record("Expected popToRoot") }
    }

    @Test("Dismiss with defaults")
    func dismissDefaults() {
        let action = ConduitAction<TestDestination>.dismiss()
        if case let .dismiss(animated, _) = action {
            #expect(animated == true)
        } else {
            Issue.record("Expected dismiss")
        }
    }

    @Test("Tab selection actions")
    func tabSelectionActions() {
        let selectTab = ConduitAction<TestDestination>.selectTab(2)
        let popAndSelect = ConduitAction<TestDestination>.popToRootAndSelectTab(tabIndex: 1)

        if case let .selectTab(index) = selectTab {
            #expect(index == 2)
        } else {
            Issue.record("Expected selectTab")
        }

        if case let .popToRootAndSelectTab(tabIndex, _) = popAndSelect {
            #expect(tabIndex == 1)
        } else {
            Issue.record("Expected popToRootAndSelectTab")
        }
    }
}

// MARK: - ConduitBarPreferences Tests

@Suite("ConduitBarPreferences Tests")
struct ConduitBarPreferencesTests {

    @Test("Default preferences")
    func defaultPreferences() {
        let preferences = ConduitBarPreferences()
        #expect(preferences.isHidden == false)
        #expect(preferences.hideTabBar == true)
        #expect(preferences.largeTitleDisplayMode == .automatic)
    }

    @Test("Custom preferences")
    func customPreferences() {
        let preferences = ConduitBarPreferences(
            isHidden: false,
            largeTitleDisplayMode: .always,
            hideTabBar: false
        )
        #expect(preferences.isHidden == false)
        #expect(preferences.hideTabBar == false)
        #expect(preferences.largeTitleDisplayMode == .always)
    }
}

// MARK: - ConduitDetent Tests

@Suite("ConduitDetent Tests")
struct ConduitDetentTests {

    @Test("All detent cases exist")
    func allDetentCasesExist() {
        let detents: [ConduitDetent] = [.medium, .large, .custom(300), .fraction(0.5)]
        #expect(detents.count == 4)
    }
}

// MARK: - ConduitPresentationStyle Tests

@Suite("ConduitPresentationStyle Tests")
struct ConduitPresentationStyleTests {

    @Test("All presentation styles exist")
    func allStylesExist() {
        let styles: [ConduitPresentationStyle] = [
            .pageSheet, .formSheet, .fullScreen, .overFullScreen, .currentContext, .overCurrentContext
        ]
        #expect(styles.count == 6)
    }
}

// MARK: - ConduitLargeTitleDisplayMode Tests

@Suite("ConduitLargeTitleDisplayMode Tests")
struct ConduitLargeTitleDisplayModeTests {

    @Test("All display modes exist")
    func allModesExist() {
        let modes: [ConduitLargeTitleDisplayMode] = [.automatic, .always, .never]
        #expect(modes.count == 3)
    }
}

// MARK: - ConduitDispatcher Tests

@Suite("ConduitDispatcher Tests")
struct ConduitDispatcherTests {

    @Test("Send publishes action to subscriber")
    @MainActor
    func sendPublishesAction() async {
        let dispatcher = ConduitDispatcher<TestDestination>()
        var receivedCount = 0
        let cancellable = dispatcher.actionPublisher
            .sink { _ in receivedCount += 1 }

        dispatcher.send(.push(.screenA))
        dispatcher.send(.pop)

        // Give Combine a tick to deliver
        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(receivedCount == 2)
        _ = cancellable
    }

    @Test("Multiple subscribers receive same action")
    @MainActor
    func multipleSubscribers() async {
        let dispatcher = ConduitDispatcher<TestDestination>()
        var countA = 0
        var countB = 0

        let cancelA = dispatcher.actionPublisher.sink { _ in countA += 1 }
        let cancelB = dispatcher.actionPublisher.sink { _ in countB += 1 }

        dispatcher.send(.push(.screenC))

        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(countA == 1)
        #expect(countB == 1)
        _ = cancelA
        _ = cancelB
    }

    @Test("No action emitted before send")
    @MainActor
    func noActionBeforeSend() async {
        let dispatcher = ConduitDispatcher<TestDestination>()
        var receivedCount = 0

        let cancellable = dispatcher.actionPublisher
            .sink { _ in receivedCount += 1 }

        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(receivedCount == 0)
        _ = cancellable
    }
}
