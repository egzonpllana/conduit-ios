//
//  ConduitNavigationTracker.swift
//  Conduit
//

#if canImport(UIKit)
import Foundation
import Combine
import UIKit

/// Concrete `ConduitNavigationTracking` implementation.
///
/// Observes a `ConduitDispatching` publisher and maintains per-tab navigation
/// stacks plus a modal stack. Reacts to every dispatched action so apps do not
/// need manual `onAppear` tracking.
///
/// ```swift
/// let tracker = ConduitNavigationTracker(
///     dispatcher: dispatcher,
///     initialTabScreens: [0: .home, 1: .feed, 2: .settings],
///     defaultSelectedTabIndex: 0,
///     unknownScreen: .unknown,
///     resolveScreen: AppScreen.from,
///     resolveContext: AppContext.from,
///     analyticsPrefix: "myapp_navigation_"
/// )
/// ```
@MainActor
public final class ConduitNavigationTracker<
    Destination: ConduitDestination,
    Screen: ConduitNavigatedScreen
>: ConduitNavigationTracking {

    // MARK: - Stack Entry

    private struct StackEntry {
        let screen: Screen
        let context: ConduitNavigationContext
    }

    // MARK: - Dependencies

    private let dispatcher: any ConduitDispatching<Destination>
    private let resolveScreen: @Sendable (Destination) -> Screen
    private let resolveContext: @Sendable (Destination) -> ConduitNavigationContext
    private let analyticsPrefix: String
    private let unknownScreen: Screen
    private let initialTabScreens: [Int: Screen]
    private let defaultSelectedTabIndex: Int

    // MARK: - State

    private let currentScreenSubject: CurrentValueSubject<Screen, Never>
    private let navigationEventSubject = PassthroughSubject<ConduitNavigationEvent<Screen>, Never>()
    private var cancellables = Set<AnyCancellable>()

    private var tabNavigationStacks: [Int: [StackEntry]]
    private var modalStack: [StackEntry] = []
    private var selectedTabIndex: Int
    private var historyStorage: [String: ConduitNavigationHistoryEntry<Screen>] = [:]
    private var currentOrderCounter: Int = 0
    private var currentContextValue: ConduitNavigationContext = .empty

    // MARK: - Initialization

    /// Creates a tracker bound to a dispatcher.
    ///
    /// - Parameters:
    ///   - dispatcher: The dispatcher to observe.
    ///   - initialTabScreens: Map of tab index → initial root screen for each tab.
    ///   - defaultSelectedTabIndex: The tab index selected at app launch.
    ///   - unknownScreen: Fallback screen used when the tracker cannot resolve a
    ///     destination or recover stack state.
    ///   - resolveScreen: Closure mapping a destination to its trackable screen.
    ///   - resolveContext: Closure mapping a destination to its context. Defaults
    ///     to returning `.empty`.
    ///   - analyticsPrefix: Prefix prepended to every event's analytics
    ///     identifier (e.g. `"myapp_navigation_"`).
    public init(
        dispatcher: any ConduitDispatching<Destination>,
        initialTabScreens: [Int: Screen],
        defaultSelectedTabIndex: Int,
        unknownScreen: Screen,
        resolveScreen: @escaping @Sendable (Destination) -> Screen,
        resolveContext: @escaping @Sendable (Destination) -> ConduitNavigationContext = { _ in .empty },
        analyticsPrefix: String = "conduit_navigation_"
    ) {
        self.dispatcher = dispatcher
        self.initialTabScreens = initialTabScreens
        self.defaultSelectedTabIndex = defaultSelectedTabIndex
        self.unknownScreen = unknownScreen
        self.resolveScreen = resolveScreen
        self.resolveContext = resolveContext
        self.analyticsPrefix = analyticsPrefix
        self.selectedTabIndex = defaultSelectedTabIndex

        var stacks: [Int: [StackEntry]] = [:]
        for (index, screen) in initialTabScreens {
            stacks[index] = [StackEntry(screen: screen, context: .empty)]
        }
        self.tabNavigationStacks = stacks

        let initialScreen = initialTabScreens[defaultSelectedTabIndex] ?? unknownScreen
        self.currentScreenSubject = CurrentValueSubject(initialScreen)

        observeDispatcher()
        recordInitialState()
    }

    // MARK: - ConduitNavigationTracking

    public var currentScreenPublisher: AnyPublisher<Screen, Never> {
        currentScreenSubject.eraseToAnyPublisher()
    }

    public var navigationEventPublisher: AnyPublisher<ConduitNavigationEvent<Screen>, Never> {
        navigationEventSubject.eraseToAnyPublisher()
    }

    public var currentScreen: Screen {
        currentScreenSubject.value
    }

    public var currentContext: ConduitNavigationContext {
        currentContextValue
    }

    public var isAtRootScreen: Bool {
        modalStack.isEmpty && currentNavigationStack.count <= 1
    }

    public var currentTabIndex: Int {
        selectedTabIndex
    }

    public var navigationDepth: Int {
        max(currentNavigationStack.count - 1, 0) + modalStack.count
    }

    public var navigationHistory: [String: ConduitNavigationHistoryEntry<Screen>] {
        historyStorage
    }

    public var lastNavigationEntry: ConduitNavigationHistoryEntry<Screen>? {
        guard currentOrderCounter > 0 else { return nil }
        return historyStorage["\(currentOrderCounter - 1)"]
    }

    public var lastNavigationEvent: ConduitNavigationEvent<Screen>? {
        lastNavigationEntry?.event
    }

    public var totalNavigationCount: Int {
        currentOrderCounter
    }

    public func clearNavigationHistory() {
        historyStorage.removeAll()
        currentOrderCounter = 0
    }

    public func trackTabSelection(_ tabIndex: Int) {
        guard tabNavigationStacks[tabIndex] != nil else { return }
        guard tabIndex != selectedTabIndex else { return }

        let previousTab = selectedTabIndex
        selectedTabIndex = tabIndex

        let toScreen = tabNavigationStacks[tabIndex]?.last?.screen
            ?? initialTabScreens[tabIndex]
            ?? unknownScreen

        let event = ConduitNavigationEvent<Screen>.tabSwitched(
            fromTabIndex: previousTab,
            toTabIndex: tabIndex,
            toScreen: toScreen
        )

        updateContext()
        recordNavigationEvent(event)
        updateCurrentScreen()
    }

    public func navigationEntries(
        matching analyticsIdentifier: String
    ) -> [ConduitNavigationHistoryEntry<Screen>] {
        historyStorage.values
            .filter { $0.analyticsIdentifier == analyticsIdentifier }
            .sorted { $0.order < $1.order }
    }

    public func navigationEntries(toScreen screen: Screen) -> [ConduitNavigationHistoryEntry<Screen>] {
        historyStorage.values
            .filter { $0.resultingScreen == screen }
            .sorted { $0.order < $1.order }
    }

    // MARK: - Private

    private var currentNavigationStack: [StackEntry] {
        tabNavigationStacks[selectedTabIndex] ?? []
    }

    private func observeDispatcher() {
        dispatcher.actionPublisher
            .sink { [weak self] action in
                self?.handle(action)
            }
            .store(in: &cancellables)
    }

    private func recordInitialState() {
        let event = ConduitNavigationEvent<Screen>.appLaunched(
            initialScreen: currentScreen,
            tabIndex: selectedTabIndex
        )
        recordNavigationEvent(event)
    }

    private func handle(_ action: ConduitAction<Destination>) {
        switch action {
        case let .push(destination, _):
            handlePush(destination)

        case let .present(destination, style, _, _, _, _, _, _, _):
            handlePresent(destination, style: style)

        #if canImport(SafariServices)
        case .openSafari:
            // Safari is a system VC outside the navigation stack — no tracking.
            break
        #endif

        case .pop:
            handlePop()

        case let .popMultiple(count, _):
            handlePopMultiple(count)

        case .popToRoot:
            handlePopToRoot()

        case .dismiss:
            handleDismiss()

        case let .changeRoot(_, metadata):
            handleChangeRoot(metadata: metadata)

        case let .selectTab(tabIndex):
            trackTabSelection(tabIndex)

        case let .popToRootAndSelectTab(tabIndex, reason, _):
            handlePopToRootAndSelectTab(tabIndex: tabIndex, reason: reason)
        }
    }

    private func handlePush(_ destination: Destination) {
        let fromScreen = currentScreen
        let screen = resolveScreen(destination)
        let context = resolveContext(destination)
        let entry = StackEntry(screen: screen, context: context)
        tabNavigationStacks[selectedTabIndex, default: []].append(entry)

        let event = ConduitNavigationEvent<Screen>.pushed(
            screen: screen,
            fromScreen: fromScreen,
            tabIndex: selectedTabIndex
        )

        updateContext()
        recordNavigationEvent(event)
        updateCurrentScreen()
    }

    private func handlePresent(_ destination: Destination, style: ConduitPresentationStyle) {
        let fromScreen = currentScreen
        let screen = resolveScreen(destination)
        let context = resolveContext(destination)
        modalStack.append(StackEntry(screen: screen, context: context))

        let event = ConduitNavigationEvent<Screen>.presented(
            screen: screen,
            fromScreen: fromScreen,
            style: style
        )

        updateContext()
        recordNavigationEvent(event)
        updateCurrentScreen()
    }

    private func handlePop() {
        guard var stack = tabNavigationStacks[selectedTabIndex], stack.count > 1 else { return }

        let poppedEntry = stack.removeLast()
        tabNavigationStacks[selectedTabIndex] = stack

        let toScreen = stack.last?.screen ?? unknownScreen
        let event = ConduitNavigationEvent<Screen>.popped(
            screen: poppedEntry.screen,
            toScreen: toScreen,
            tabIndex: selectedTabIndex
        )

        updateContext()
        recordNavigationEvent(event)
        updateCurrentScreen()
    }

    private func handlePopMultiple(_ count: Int) {
        guard var stack = tabNavigationStacks[selectedTabIndex] else { return }

        let actualCount = min(count, stack.count - 1)
        guard actualCount > 0 else { return }

        stack.removeLast(actualCount)
        tabNavigationStacks[selectedTabIndex] = stack

        let toScreen = stack.last?.screen ?? unknownScreen
        let event = ConduitNavigationEvent<Screen>.poppedMultiple(
            count: actualCount,
            toScreen: toScreen,
            tabIndex: selectedTabIndex
        )

        updateContext()
        recordNavigationEvent(event)
        updateCurrentScreen()
    }

    private func handlePopToRoot() {
        guard var stack = tabNavigationStacks[selectedTabIndex],
              let rootEntry = stack.first else {
            return
        }

        let fromScreen = currentScreen
        stack = [rootEntry]
        tabNavigationStacks[selectedTabIndex] = stack

        let event = ConduitNavigationEvent<Screen>.poppedToRoot(
            fromScreen: fromScreen,
            rootScreen: rootEntry.screen,
            tabIndex: selectedTabIndex
        )

        updateContext()
        recordNavigationEvent(event)
        updateCurrentScreen()
    }

    private func handleDismiss() {
        guard !modalStack.isEmpty else { return }

        let dismissedEntry = modalStack.removeLast()
        let toScreen = modalStack.last?.screen
            ?? currentNavigationStack.last?.screen
            ?? unknownScreen

        let event = ConduitNavigationEvent<Screen>.dismissed(
            screen: dismissedEntry.screen,
            toScreen: toScreen
        )

        updateContext()
        recordNavigationEvent(event)
        updateCurrentScreen()
    }

    private func handleChangeRoot(metadata: ConduitRootChangeMetadata) {
        modalStack.removeAll()

        if metadata.resetsTabStacks {
            var stacks: [Int: [StackEntry]] = [:]
            for (index, screen) in initialTabScreens {
                stacks[index] = [StackEntry(screen: screen, context: .empty)]
            }
            tabNavigationStacks = stacks
            selectedTabIndex = defaultSelectedTabIndex
        } else {
            tabNavigationStacks.removeAll()
        }

        updateContext()

        let resultingScreen: Screen
        if metadata.resetsTabStacks {
            resultingScreen = initialTabScreens[defaultSelectedTabIndex] ?? unknownScreen
        } else {
            resultingScreen = unknownScreen
        }

        let event = ConduitNavigationEvent<Screen>.rootChanged(
            rootName: metadata.rootName,
            reason: metadata.reason,
            resultingScreen: resultingScreen
        )

        recordNavigationEvent(event)
        updateCurrentScreen()
    }

    private func handlePopToRootAndSelectTab(tabIndex: Int, reason: String) {
        modalStack.removeAll()

        for (tab, _) in tabNavigationStacks {
            if let rootEntry = tabNavigationStacks[tab]?.first {
                tabNavigationStacks[tab] = [rootEntry]
            }
        }

        selectedTabIndex = tabIndex

        let toScreen = tabNavigationStacks[tabIndex]?.first?.screen
            ?? initialTabScreens[tabIndex]
            ?? unknownScreen

        updateContext()

        let event = ConduitNavigationEvent<Screen>.resetToRootAndTabSelected(
            toTabIndex: tabIndex,
            reason: reason,
            toScreen: toScreen
        )

        recordNavigationEvent(event)
        updateCurrentScreen()
    }

    private func recordNavigationEvent(_ event: ConduitNavigationEvent<Screen>) {
        let entry = ConduitNavigationHistoryEntry<Screen>(
            order: currentOrderCounter,
            event: event,
            analyticsPrefix: analyticsPrefix
        )
        historyStorage[entry.dictionaryKey] = entry
        currentOrderCounter += 1
        navigationEventSubject.send(event)
    }

    private func updateCurrentScreen() {
        let newScreen: Screen
        if let topModal = modalStack.last {
            newScreen = topModal.screen
        } else if let topPushed = currentNavigationStack.last {
            newScreen = topPushed.screen
        } else {
            newScreen = initialTabScreens[selectedTabIndex] ?? unknownScreen
        }

        guard newScreen != currentScreenSubject.value else { return }
        currentScreenSubject.send(newScreen)
    }

    private func updateContext() {
        if let topModal = modalStack.last {
            currentContextValue = topModal.context
        } else if let topPushed = currentNavigationStack.last {
            currentContextValue = topPushed.context
        } else {
            currentContextValue = .empty
        }
    }
}
#endif
