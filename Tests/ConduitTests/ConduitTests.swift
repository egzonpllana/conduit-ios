//
//  ConduitTests.swift
//  Conduit
//
//  Created by Egzon Pllana on 4.3.26.
//

import Testing
import Combine
import SwiftUI

@testable import Conduit

// MARK: - Test Helpers

enum TestDestination: ConduitDestination {
    case screenA
    case screenB(value: String)
    case screenC
}

enum TestScreen: String, ConduitNavigatedScreen {
    case home
    case feed
    case settings
    case detail
    case modal
    case unknown

    var analyticsIdentifier: String { rawValue }
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
        if case let .present(_, style, isModal, detents, _, showDrag, background, _, _) = action {
            #expect(style == .formSheet)
            #expect(isModal == true)
            #expect(detents?.count == 2)
            #expect(showDrag == true)
            #expect(background == nil)
        } else {
            Issue.record("Expected present action")
        }
    }

    @Test("Present action carries presentation background")
    func presentActionBackground() {
        let action = ConduitAction<TestDestination>.present(
            .screenA,
            style: .pageSheet,
            presentationBackground: .red
        )
        if case let .present(_, _, _, _, _, _, background, _, _) = action {
            #expect(background == .red)
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
        let popAndSelect = ConduitAction<TestDestination>.popToRootAndSelectTab(
            tabIndex: 1,
            reason: "notification_tap"
        )

        if case let .selectTab(index) = selectTab {
            #expect(index == 2)
        } else {
            Issue.record("Expected selectTab")
        }

        if case let .popToRootAndSelectTab(tabIndex, reason, _) = popAndSelect {
            #expect(tabIndex == 1)
            #expect(reason == "notification_tap")
        } else {
            Issue.record("Expected popToRootAndSelectTab")
        }
    }

    #if canImport(SafariServices)
    @Test("Open Safari action")
    func openSafariAction() throws {
        let url = try #require(URL(string: "https://example.com"))
        let action = ConduitAction<TestDestination>.openSafari(url)
        if case let .openSafari(captured) = action {
            #expect(captured == url)
        } else {
            Issue.record("Expected openSafari")
        }
    }
    #endif

    #if canImport(UIKit)
    @Test("Change root action carries metadata")
    @MainActor
    func changeRootAction() {
        let action = ConduitAction<TestDestination>.changeRoot(
            rootBuilder: { UIViewController() },
            metadata: .init(rootName: "tab_bar", reason: "user_signed_in", resetsTabStacks: true)
        )
        if case let .changeRoot(_, metadata) = action {
            #expect(metadata.rootName == "tab_bar")
            #expect(metadata.reason == "user_signed_in")
            #expect(metadata.resetsTabStacks == true)
        } else {
            Issue.record("Expected changeRoot")
        }
    }
    #endif
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
        let detents: [ConduitDetent] = [.medium, .large, .custom(300), .fraction(0.5), .adaptiveHeight]
        #expect(detents.count == 5)
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

// MARK: - ConduitRootChangeMetadata Tests

@Suite("ConduitRootChangeMetadata Tests")
struct ConduitRootChangeMetadataTests {

    @Test("Default metadata is empty and resets stacks")
    func defaultMetadata() {
        let metadata = ConduitRootChangeMetadata()
        #expect(metadata.rootName.isEmpty)
        #expect(metadata.reason.isEmpty)
        #expect(metadata.resetsTabStacks == true)
    }

    @Test("Custom metadata carries values")
    func customMetadata() {
        let metadata = ConduitRootChangeMetadata(
            rootName: "sign_in",
            reason: "user_signed_out",
            resetsTabStacks: false
        )
        #expect(metadata.rootName == "sign_in")
        #expect(metadata.reason == "user_signed_out")
        #expect(metadata.resetsTabStacks == false)
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

// MARK: - ConduitNavigationContext Tests

@Suite("ConduitNavigationContext Tests")
struct ConduitNavigationContextTests {

    @Test("Empty context")
    func emptyContext() {
        let context = ConduitNavigationContext.empty
        #expect(context.isEmpty)
        #expect(context["anything"] == nil)
    }

    @Test("Stored values are retrievable")
    func storedValues() {
        let context = ConduitNavigationContext(values: ["pocketId": "abc", "eventId": "xyz"])
        #expect(context["pocketId"] == "abc")
        #expect(context["eventId"] == "xyz")
        #expect(context["assetId"] == nil)
        #expect(context.isEmpty == false)
    }
}

// MARK: - ConduitNavigationTracker Tests

#if canImport(UIKit)
@Suite("ConduitNavigationTracker Tests")
@MainActor
struct ConduitNavigationTrackerTests {

    private func makeTracker(
        dispatcher: ConduitDispatcher<TestDestination>
    ) -> ConduitNavigationTracker<TestDestination, TestScreen> {
        ConduitNavigationTracker<TestDestination, TestScreen>(
            dispatcher: dispatcher,
            initialTabScreens: [
                0: .home,
                1: .feed,
                2: .settings
            ],
            defaultSelectedTabIndex: 1,
            unknownScreen: .unknown,
            resolveScreen: { destination in
                switch destination {
                case .screenA: return .detail
                case .screenB: return .modal
                case .screenC: return .home
                }
            },
            resolveContext: { destination in
                switch destination {
                case let .screenB(value):
                    return ConduitNavigationContext(values: ["value": value])
                default:
                    return .empty
                }
            },
            analyticsPrefix: "test_"
        )
    }

    @Test("Tracker starts at default tab's root screen")
    func tracksInitialState() async {
        let dispatcher = ConduitDispatcher<TestDestination>()
        let tracker = makeTracker(dispatcher: dispatcher)

        #expect(tracker.currentScreen == .feed)
        #expect(tracker.currentTabIndex == 1)
        #expect(tracker.isAtRootScreen)
        #expect(tracker.navigationDepth == 0)
        #expect(tracker.totalNavigationCount == 1)
        #expect(tracker.lastNavigationEvent != nil)
    }

    @Test("Push updates current screen and stack depth")
    func pushUpdatesState() async {
        let dispatcher = ConduitDispatcher<TestDestination>()
        let tracker = makeTracker(dispatcher: dispatcher)

        dispatcher.send(.push(.screenA))
        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(tracker.currentScreen == .detail)
        #expect(tracker.navigationDepth == 1)
        #expect(tracker.isAtRootScreen == false)
    }

    @Test("Modal present and dismiss")
    func presentAndDismiss() async {
        let dispatcher = ConduitDispatcher<TestDestination>()
        let tracker = makeTracker(dispatcher: dispatcher)

        dispatcher.send(.present(.screenB(value: "abc"), style: .pageSheet))
        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(tracker.currentScreen == .modal)
        #expect(tracker.currentContext["value"] == "abc")

        dispatcher.send(.dismiss())
        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(tracker.currentScreen == .feed)
        #expect(tracker.currentContext.isEmpty)
    }

    @Test("Tab switch updates selected tab and screen")
    func tabSwitch() async {
        let dispatcher = ConduitDispatcher<TestDestination>()
        let tracker = makeTracker(dispatcher: dispatcher)

        dispatcher.send(.selectTab(0))
        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(tracker.currentTabIndex == 0)
        #expect(tracker.currentScreen == .home)
    }

    @Test("PopToRootAndSelectTab clears modal stack and resets tabs")
    func popToRootAndSelectTab() async {
        let dispatcher = ConduitDispatcher<TestDestination>()
        let tracker = makeTracker(dispatcher: dispatcher)

        dispatcher.send(.push(.screenA))
        dispatcher.send(.present(.screenB(value: "x"), style: .pageSheet))
        try? await Task.sleep(nanoseconds: 10_000_000)

        dispatcher.send(.popToRootAndSelectTab(tabIndex: 2, reason: "notification_tap"))
        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(tracker.currentTabIndex == 2)
        #expect(tracker.currentScreen == .settings)
        #expect(tracker.isAtRootScreen)
    }

    @Test("History query by analytics identifier")
    func historyByAnalyticsIdentifier() async {
        let dispatcher = ConduitDispatcher<TestDestination>()
        let tracker = makeTracker(dispatcher: dispatcher)

        dispatcher.send(.push(.screenA))
        dispatcher.send(.push(.screenC))
        try? await Task.sleep(nanoseconds: 10_000_000)

        let pushed = tracker.navigationEntries(matching: "test_pushed")
        #expect(pushed.count == 2)
    }

    @Test("History query by resulting screen")
    func historyByScreen() async {
        let dispatcher = ConduitDispatcher<TestDestination>()
        let tracker = makeTracker(dispatcher: dispatcher)

        dispatcher.send(.push(.screenA))
        try? await Task.sleep(nanoseconds: 10_000_000)

        let entries = tracker.navigationEntries(toScreen: .detail)
        #expect(entries.count == 1)
    }

    @Test("Change root with reset repopulates tab stacks")
    func changeRootResetsTabs() async {
        let dispatcher = ConduitDispatcher<TestDestination>()
        let tracker = makeTracker(dispatcher: dispatcher)

        dispatcher.send(.push(.screenA))
        try? await Task.sleep(nanoseconds: 10_000_000)
        #expect(tracker.isAtRootScreen == false)

        dispatcher.send(.changeRoot(
            rootBuilder: { UIViewController() },
            metadata: .init(rootName: "tab_bar", reason: "user_signed_in", resetsTabStacks: true)
        ))
        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(tracker.isAtRootScreen)
        #expect(tracker.currentTabIndex == 1)
        #expect(tracker.currentScreen == .feed)
    }

    @Test("Clear navigation history resets counter and storage")
    func clearHistory() async {
        let dispatcher = ConduitDispatcher<TestDestination>()
        let tracker = makeTracker(dispatcher: dispatcher)

        dispatcher.send(.push(.screenA))
        try? await Task.sleep(nanoseconds: 10_000_000)

        tracker.clearNavigationHistory()
        #expect(tracker.totalNavigationCount == 0)
        #expect(tracker.navigationHistory.isEmpty)
        #expect(tracker.lastNavigationEvent == nil)
    }
}
#endif
