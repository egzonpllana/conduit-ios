# Conduit

Conduit is a generic, protocol-driven UIKit navigation framework for SwiftUI apps. It uses Combine dispatching, generic destinations, and a centralized router for a type-safe and decoupled navigation API.

> The name **Conduit** comes from engineering — a channel designed to carry something from one point to another with minimal resistance. In your application, Conduit is the pipe through which navigation intent flows: from a view model's decision to a screen appearing on screen. It doesn't decide where to go — it carries the signal, wraps the view, and hands it to UIKit with precision. Like a well-laid conduit in a building's infrastructure, it is invisible when working correctly and indispensable when absent.

![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platform](https://img.shields.io/badge/Platform-iOS%2016%2B%20%7C%20macOS%2013%2B-blue.svg)
![SPM](https://img.shields.io/badge/SPM-Compatible-brightgreen.svg)
![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)

```swift
dispatcher.send(.push(.profile(userId: "123")))
```

## Changelog

| Version | Type | Highlights |
|---------|------|-----------|
| **2.3.0** | Minor | The edge swipe back now works on every stack Conduit manages (tab stacks, the root stack and stacks inside presented modals), even with the navigation bar hidden. UIKit turns `interactivePopGestureRecognizer` off whenever the bar is hidden, and `.push` hides it by default, so apps lost the system back gesture unless they patched each navigation controller. `ConduitNavigationBarCoordinator` now becomes the recognizer's delegate when it attaches and allows the swipe when there is something to pop, no transition is running, and the top screen has not opted out. New: `View.conduitSwipeBackDisabled(_:)` turns it off for one screen, for example while an edit has unsaved changes. |
| **2.2.2** | Patch (docs) | README brought in line with the 2.2.x API: `ConduitRouter(dispatcher:viewFactory:)` argument order, `makeView(_:)`, `ConduitTabItem(rootView:)`, `ConduitTabBarController(configuration:)`, and root setup through `changeRoot(to:in:)` / `setTabController(_:)` — there is no `start(in:)`. New **SwiftUI App Lifecycle** section, documented bar defaults (`.push` hides the navigation bar; `ConduitBarPreferences()` hides the tab bar), full `ConduitPresentationStyle` list, corrected source layout. No code change. |
| 2.2.1 | Patch | The navigation bar now arrives together with the incoming screen: `setNavigationBarHidden` is called directly inside the push/pop transition so UIKit coordinates it, instead of a separate frame animation that slid the bar down from the top. |
| **2.2.0** | Minor | Navigation bar visibility is now resolved **per destination** by `ConduitNavigationBarCoordinator` during the transition, rather than applied stack-wide at push time. Fixes two long-standing bugs: the bar animated separately from the push (the incoming screen laid out bar-less, then jumped when the bar arrived), and it was never restored on pop (a screen that showed the bar left it over the screen underneath, shifting that content down). Pop, `popToRoot`, `popMultiple` and interactive swipe-back — including a *cancelled* swipe-back — now all resolve the incoming destination's own preference. No API change: `ConduitBarPreferences.isHidden` keeps its meaning. Apps that install their own `UINavigationControllerDelegate` keep it and fall back to the previous behaviour. |
| **2.1.0** | Minor | `ConduitRouter` gains an optional `defaultPresentationBackground: Color?` init parameter. When a `.present` action does not specify its own `presentationBackground`, the router falls back to this app-wide default, so every modal gets a consistent host background without supplying it at each call site. Per-action `presentationBackground` still takes precedence. Defaults to `nil` (system background) — fully backward-compatible. |
| **2.0.3** | Patch (docs) | Add **Dependency Injection & Dynamic Casts (iOS 18)** section: resolving `any ConduitDispatching<…>` / `any ConduitNavigationTracking<…>` through an `as?`-based DI container crashes on iOS 18 (parameterized-existential cast returns nil); use a plain app protocol or the concrete type at the DI boundary. |
| **2.0.2** | Patch (docs) | Add **Concurrency & Sendability** section covering the four most common integration sharp edges (off-main dispatch, action-completion isolation, non-Sendable destination closures, app-extension restrictions). |
| 2.0.1 | Patch | Promote `UIViewController.closestNavigationController()` from `internal` to `public` so consumer apps and app extensions can reuse it instead of duplicating the helper. |
| **2.0.0** | Major | Navigation Tracking subsystem (`ConduitNavigationTracker`, events, history, context). New actions: `.openSafari(url)`, `.changeRoot(rootBuilder:, metadata:)`. New detent `.adaptiveHeight` with content measurement. `presentationBackground: Color?` on `.present`. Router walks top-most presenter and defers when mid-transition. `ConduitSheetDetentExpander` utility. **Breaking:** `.present` adds `presentationBackground`; `.popToRootAndSelectTab` adds `reason`. |
| 1.0.3 | Patch | Run main-thread navigation actions synchronously to avoid one-frame push lag. |
| 1.0.2 | Patch | Fix dispatcher binding to init; improve `topViewController` fallback. |
| 1.0.1 | Patch | Fix main actor isolation error in `dismissAllPresentedViewControllers` completion. |
| 1.0.0 | Major | Initial release — generic UIKit navigation framework for SwiftUI apps. |

## Concurrency & Sendability

Conduit leans on Swift 6 strict concurrency. The four things that surprise
consumers most often:

### 1. `ConduitDispatching` is `@MainActor`

`send(_:)` and every method added via extensions on `ConduitDispatching` /
`ConduitDispatcher` inherits `@MainActor` isolation. Calling them from an
`async` function that isn't on the main actor (network interceptors,
WebSocket callbacks, background tasks) crashes at runtime even when it
compiles.

```swift
// Wrong — crashes if logoutUser is called off-main
func logoutUser() async {
    tokenRepository.clear()
    dispatcher.navigateToSignInRoot()
}

// Right
func logoutUser() async {
    tokenRepository.clear()
    await MainActor.run {
        dispatcher.navigateToSignInRoot()
    }
}
```

### 2. Action completions are `@Sendable () -> Void`, not `@MainActor`

`.dismiss(completion:)` and `.popToRootAndSelectTab(completion:)` declare
their completions as `@Sendable () -> Void`. UIKit fires them on the main
thread, but the compiler doesn't see that — so calling `@MainActor` work
inside (a follow-up `.send`, a view-model method) is rejected.

```swift
// Right — assume isolation because UIKit guarantees main-thread firing
dispatcher.send(.dismiss(completion: { [weak self] in
    MainActor.assumeIsolated {
        self?.presentNextScreen()
    }
}))
```

### 3. `ConduitDestination` requires `Sendable`

Real destination enums often carry view-model parameters and SwiftUI
callback closures that aren't `Sendable`. Conform with `@unchecked Sendable`
and document the invariant — the dispatcher is `@MainActor`, so destination
values never traverse actors in practice:

```swift
enum AppDestination: @unchecked Sendable, ConduitDestination {
    case profile(viewModel: ProfileViewModel)
    case confirm(onConfirm: () -> Void)
}
```

### 4. App extensions can't use `UIApplication.shared`

If your `CommonNavigationDispatching` (or similar) helper calls
`UIApplication.shared.open(_:)` or `openSettingsURLString`, the conformance
must live in a **main-target-only** file. Put the protocol definition in a
shared file and the extension implementation in a main-only file
(`extension ConduitDispatcher: @retroactive YourProtocol where Destination == ...`).
Otherwise the share / widget / notification-service target fails to link.

## Dependency Injection & Dynamic Casts (iOS 18)

`ConduitDispatching<Destination>` and `ConduitNavigationTracking<Destination, Screen>`
are *parameterized protocols*. Using them by value or via constructor injection is
safe. **But the Swift runtime on iOS 18 (and earlier) mishandles dynamic casts
(`as?` / `as!`) to a parameterized existential** such as
`any ConduitDispatching<AppDestination>`: the cast returns `nil` even when the value
conforms. The same code works on iOS 26+, which ships a fixed runtime.

This bites type-erased dependency-injection containers, which store instances as
`Any` and cast them back with `as?`. Resolving `any ConduitDispatching<AppDestination>`
that way crashes on iOS 18 — typically as an "unexpectedly found nil" trap inside the
container, at the first resolution during launch.

**Do not** register/resolve `any ConduitDispatching<…>` or
`any ConduitNavigationTracking<…>` through an `as?`-based container.
**Instead**, at the DI boundary use either:

- a **plain (non-parameterized) protocol** your app owns, with a conditional
  conformance on the concrete Conduit type:

  ```swift
  @MainActor
  protocol AppNavigating: AnyObject {
      var actionPublisher: AnyPublisher<ConduitAction<AppDestination>, Never> { get }
      func send(_ action: ConduitAction<AppDestination>)
  }

  extension ConduitDispatcher: AppNavigating where Destination == AppDestination {}
  ```

- or the **concrete type** `ConduitDispatcher<AppDestination>`.

Casts to a plain existential or a concrete class are reliable on all runtimes.

## Components

### Core Protocols
| Component | What it is |
|-----------|------------|
| `ConduitDestination` | Marker protocol your destination enum conforms to. |
| `ConduitDispatching` | Sends and publishes `ConduitAction` values. |
| `ConduitRouting` | Router lifecycle: `changeRoot`, `updateActiveWindow`. |
| `ConduitViewFactory` | Resolves a destination into a SwiftUI view. |
| `ConduitTabConfiguring` | Supplies the tab items for `ConduitTabBarController`. |

### Domain Models (UIKit-free)
| Component | What it is |
|-----------|------------|
| `ConduitAction<Destination>` | Generic navigation command (`.push`, `.present`, `.pop`, `.dismiss`, `.changeRoot`, `.openSafari`, `.selectTab`, ...). |
| `ConduitBarPreferences` | Navigation-bar visibility, large-title mode, tab-bar hiding. |
| `ConduitDetent` | Sheet detents: `.medium`, `.large`, `.custom`, `.fraction`, `.adaptiveHeight`. |
| `ConduitPresentationStyle` | Modal styles mapped to `UIModalPresentationStyle`. |
| `ConduitLargeTitleDisplayMode` | Large-title preference for pushed and presented screens. |
| `ConduitRootChangeMetadata` | Optional metadata attached to `.changeRoot` for tracker consumers. |

### Infrastructure (UIKit)
| Component | What it is |
|-----------|------------|
| `ConduitDispatcher<Destination>` | Combine `PassthroughSubject`-backed dispatcher. |
| `ConduitRouter<Factory>` | Core engine: translates actions into UIKit transitions, walks the top-most presenter, defers when mid-transition. |
| `ConduitNavigationBarCoordinator` | Resolves bar visibility per destination during transitions, and restores it on the way back (added in 2.2.0). |
| `ConduitTabBarController` | Generic `UITabBarController` built from a `ConduitTabConfiguring`. |
| `ConduitTabItem` | Title + icon + root SwiftUI view + index for a tab bar tab. |
| `ConduitSheetDetentExpander` | Promote the top-most sheet to `.large` or pin to a custom height. |
| `ConduitWindowUtils` | Active key-window and top-view-controller lookups. |

### Tracking (added in 2.0.0)
| Component | What it is |
|-----------|------------|
| `ConduitNavigatedScreen` | Marker protocol your trackable screen enum conforms to. |
| `ConduitNavigationContext` | Free-form key/value bag attached to every stack entry. |
| `ConduitNavigationEvent<Screen>` | Generic event enum carrying analytics identifiers. |
| `ConduitNavigationHistoryEntry<Screen>` | Single ordered history record. |
| `ConduitNavigationTracking` | Tracker protocol: stacks, history, publishers. |
| `ConduitNavigationTracker<Destination, Screen>` | Concrete generic tracker observing the dispatcher. |

## Features

- **Generic Destinations** -- Define your own destination enum; the router resolves views through your factory.
- **Combine Dispatcher** -- View models send actions; the router subscribes and executes UIKit transitions.
- **Full UIKit Navigation** -- Push, present (sheets, fullscreen, custom detents), pop, dismiss, tab selection, Safari, root swaps.
- **Protocol-Driven** -- Inject `ConduitDispatching`, `ConduitRouting`, `ConduitViewFactory`, and `ConduitNavigationTracking` for full testability.
- **Top-Most Presenter Resolution** -- Walks the `presentedViewController` chain and defers when a presenter is mid-transition, avoiding UIKit's "already presenting" warnings.
- **Adaptive Sheet Heights** -- `ConduitDetent.adaptiveHeight` measures the SwiftUI content at present time and pins the sheet to it.
- **Configurable Tab Bar** -- Generic `ConduitTabBarController` built from `ConduitTabItem` arrays.
- **Navigation Tracking** -- `ConduitNavigationTracker` observes the dispatcher and maintains per-tab stacks, modal stacks, and an analytics-ready history log.
- **UIKit-Free Domain** -- Presentation styles, detents, and bar preferences are SDK enums mapped internally.
- **Swift 6 Ready** -- `@MainActor` isolation, `Sendable` conformance, zero concurrency warnings.
- **Zero Dependencies** -- Built entirely on Combine, UIKit, SwiftUI, and SafariServices.

## Architecture

![Conduit Architecture Diagram](conduit-architecture-diagram.png)

The diagram illustrates seven navigation flows handled by Conduit's core actors:

| Actor | Role |
|-------|------|
| **SceneDelegate / App** | Entry point that creates the window, router, and tab bar |
| **ConduitRouter** | Central coordinator that subscribes to dispatched actions and executes UIKit transitions |
| **ConduitDispatcher** | Combine-based publisher that view models use to send navigation actions |
| **NavigationController** | UIKit navigation stack resolved by the router for push/pop operations |
| **ConduitViewFactory** | Factory that maps generic destinations to concrete SwiftUI views |
| **UINavigationController** | UIKit host wrapping SwiftUI views via `UIHostingController` |
| **ConduitTabBarController** | Generic tab bar managing multiple navigation stacks and tab selection |
| **ViewModels** | Consumer layer that triggers navigation by sending actions through the dispatcher |

### Flows Covered

| # | Flow | Description |
|---|------|-------------|
| 1 | **App Launch** | Window setup, root installed via `changeRoot` / `setTabController`, tab bar configuration, Combine subscription |
| 2 | **Push Navigation** | Dispatcher sends push action, router resolves nav controller, pushes hosting controller |
| 3 | **Modal Presentation** | Present with sheet style, detents, and drag indicator via `present(_:animated:)` |
| 4 | **Pop and Dismiss** | Pop from navigation stack or dismiss presented modals with stack tracking |
| 5 | **Tab Selection and Pop to Root** | Dismiss all presented controllers, pop all stacks, switch selected tab |
| 6 | **Change Root** | Tear down presented stack, replace `window.rootViewController` (e.g., sign-out) |
| 7 | **Bar Preferences** | Configure navigation bar visibility, large title mode, and tab bar hiding per push |

### Source Layout

```
Sources/Conduit/
├── Core/
│   ├── ConduitDestination.swift        ← Marker protocol for app destinations
│   ├── ConduitViewFactory.swift        ← Factory protocol: destination → AnyView
│   ├── ConduitDispatching.swift        ← Dispatcher protocol (Combine publisher)
│   ├── ConduitRouting.swift            ← Router protocol (changeRoot, updateActiveWindow)
│   └── ConduitTabConfiguring.swift     ← Tab configuration protocol
├── Domain/
│   ├── ConduitAction.swift             ← Generic navigation commands
│   ├── ConduitBarPreferences.swift     ← Nav bar configuration + large-title mode
│   ├── ConduitDetent.swift             ← Sheet presentation detents
│   ├── ConduitPresentationStyle.swift  ← Modal presentation styles
│   └── ConduitRootChangeMetadata.swift ← Metadata for .changeRoot actions
├── Infrastructure/
│   ├── ConduitDispatcher.swift              ← PassthroughSubject-based dispatcher
│   ├── ConduitRouter.swift                 ← Core router: actions → UIKit navigation
│   ├── ConduitNavigationBarCoordinator.swift ← Per-destination bar visibility during transitions
│   ├── ConduitDomainMapping.swift          ← SDK enums → UIKit types
│   ├── ConduitTabBarController.swift       ← Generic configurable tab bar
│   ├── ConduitTabItem.swift                ← Tab item configuration
│   ├── ConduitSheetDetentExpander.swift    ← Promote top sheet to large / custom height
│   ├── UIViewController+Conduit.swift      ← Navigation controller resolution
│   └── ConduitWindowUtils.swift            ← Active window lookup
└── Tracking/
    ├── ConduitNavigatedScreen.swift              ← Marker protocol for trackable screens
    ├── ConduitNavigationContext.swift            ← Free-form key/value context bag
    ├── ConduitNavigationEvent.swift              ← Generic event enum with analytics IDs
    ├── ConduitNavigationHistoryEntry.swift       ← Single history record
    ├── ConduitNavigationTracking.swift           ← Tracker protocol
    └── ConduitNavigationTracker.swift            ← Concrete generic tracker
```

## Installation

### Swift Package Manager

Add Conduit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/egzonpllana/conduit-ios.git", from: "2.2.2")
]
```

Or in Xcode: **File > Add Package Dependencies** and enter:

```
https://github.com/egzonpllana/conduit-ios.git
```

## Usage

### 1. Define Your Destinations

```swift
import Conduit

enum AppDestination: ConduitDestination {
    case profile(userId: String)
    case settings
    case createPocket(members: [Contact])
}
```

### 2. Implement the View Factory

`ConduitViewFactory` is `@MainActor`. `makeIdentifier(_:)` is optional (defaults to
`nil`); return a string to tag the hosting controller, e.g. to avoid duplicate pushes.

```swift
struct AppViewFactory: ConduitViewFactory {
    func makeView(_ destination: AppDestination) -> AnyView {
        switch destination {
        case .profile(let userId):
            AnyView(ProfileView(userId: userId))
        case .settings:
            AnyView(SettingsView())
        case .createPocket(let members):
            AnyView(CreatePocketView(members: members))
        }
    }
}
```

### 3. Create Dispatcher and Router

Create both once, on the main actor, and keep a strong reference to the router for
the app's lifetime (a DI container singleton or a property on your app/scene delegate).
A released router stops listening to the dispatcher.

```swift
let dispatcher = ConduitDispatcher<AppDestination>()
let router = ConduitRouter(
    dispatcher: dispatcher,
    viewFactory: AppViewFactory()
)
```

To give every modal a consistent host background without passing it at each
`.present` call site, supply `defaultPresentationBackground` once. A per-action
`presentationBackground` still overrides it:

```swift
let router = ConduitRouter(
    dispatcher: dispatcher,
    viewFactory: AppViewFactory(),
    defaultPresentationBackground: .appModalBackground
)
```

### 4. Install the Root (UIKit Scene Lifecycle)

Describe the tabs with a `ConduitTabConfiguring`, then hand the root to the router with
`changeRoot(to:in:)`. Passing a `UITabBarController` registers it for `.selectTab` and
`.popToRootAndSelectTab`; passing a `UINavigationController` makes it the push stack;
any other view controller is wrapped in a new `UINavigationController`. The router then
sets the window's root and makes it key.

```swift
struct AppTabConfiguration: ConduitTabConfiguring {
    func tabItems() -> [ConduitTabItem] {
        [
            ConduitTabItem(title: "Home", icon: homeIcon, rootView: AnyView(HomeView()), index: 0),
            ConduitTabItem(title: "Search", icon: searchIcon, rootView: AnyView(SearchView()), index: 1),
            ConduitTabItem(title: "Profile", icon: profileIcon, rootView: AnyView(ProfileView()), index: 2)
        ]
    }
}

func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    self.window = window

    let tabBar = ConduitTabBarController(configuration: AppTabConfiguration())
    router.changeRoot(to: tabBar, in: window)
}
```

Single-stack apps pass a navigation controller instead:

```swift
let home = UIHostingController(rootView: HomeView())
router.changeRoot(to: UINavigationController(rootViewController: home), in: window)
```

### 4b. Install the Root (SwiftUI App Lifecycle)

With `@main struct App`, SwiftUI owns the window. Host the tab bar through a
`UIViewControllerRepresentable` and register it with `setTabController(_:)`; the
router finds the active window and top-most presenter on its own.

```swift
struct ConduitHostView: UIViewControllerRepresentable {
    let router: ConduitRouter<AppViewFactory>

    func makeUIViewController(context: Context) -> ConduitTabBarController {
        let tabBar = ConduitTabBarController(configuration: AppTabConfiguration())
        router.setTabController(tabBar)
        return tabBar
    }

    func updateUIViewController(_ uiViewController: ConduitTabBarController, context: Context) {}
}

@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ConduitHostView(router: appDelegate.router)
                .ignoresSafeArea()
        }
    }
}
```

`AppDelegate` here builds and owns the dispatcher and router (step 3) so both
outlive any view.

### 5. Navigate from View Models

```swift
final class ProfileViewModel {
    private let dispatcher: any ConduitDispatching<AppDestination>

    init(dispatcher: any ConduitDispatching<AppDestination>) {
        self.dispatcher = dispatcher
    }

    @MainActor
    func didTapSettings() {
        dispatcher.send(.push(.settings, barPreferences: .init(isHidden: false, hideTabBar: false)))
    }

    @MainActor
    func didTapContact(userId: String) {
        dispatcher.send(.present(
            .profile(userId: userId),
            style: .formSheet,
            detents: [.medium, .large],
            showDragIndicator: true
        ))
    }

    @MainActor
    func didTapBack() {
        dispatcher.send(.pop)
    }
}
```

### 6. Change Root (Sign Out, Onboarding)

```swift
@MainActor
func signOut(router: any ConduitRouting) {
    let signInVC = UIHostingController(rootView: SignInView())
    let nav = UINavigationController(rootViewController: signInVC)
    router.changeRoot(to: nav, in: nil) // nil = the router's active window
}
```

Through the protocol the `in:` argument is required; only `ConduitRouter` itself
declares the `nil` default. Prefer the `.changeRoot` action (below) when tracker
subscribers should see the swap.

### Navigation Actions

| Action | Description |
|--------|-------------|
| `.push(destination, barPreferences:)` | Push onto current navigation stack |
| `.present(destination, style:, isModalInPresentation:, detents:, preferredHeight:, showDragIndicator:, presentationBackground:, barPreferences:, ...)` | Present modally with sheet configuration and optional background color |
| `.openSafari(url)` | Present `SFSafariViewController` on the top-most presenter |
| `.pop` | Pop top view controller |
| `.popMultiple(count:, animated:)` | Pop multiple view controllers |
| `.popToRoot` | Pop to root of current stack |
| `.dismiss(animated:, completion:)` | Dismiss top presented modal (with top-most-presenter fallback) |
| `.changeRoot(rootBuilder:, metadata:)` | Swap `window.rootViewController`; the closure builds the new root on `MainActor` |
| `.selectTab(index)` | Select a tab bar tab |
| `.popToRootAndSelectTab(tabIndex:, reason:, completion:)` | Reset all stacks and select tab |

### Bar Preferences

Two defaults decide what a screen looks like when you pass nothing:

| Call | Navigation bar | Tab bar |
|------|----------------|---------|
| `.push(dest)` / `.present(dest, style:)` | **hidden** (`barPreferences` defaults to `.init(isHidden: true)`) | hidden |
| `ConduitBarPreferences()` | shown | **hidden** (`hideTabBar` defaults to `true`) |

So a pushed screen that should keep both bars passes
`.init(isHidden: false, hideTabBar: false)`.

```swift
// Show navigation bar with large title, keep tab bar visible
dispatcher.send(.push(
    .settings,
    barPreferences: ConduitBarPreferences(
        isHidden: false,
        largeTitleDisplayMode: .always,
        hideTabBar: false
    )
))
```

`isHidden` describes **that destination**, not the stack. Since 2.2.0 the router
resolves it during the transition and restores the previous value when the
screen is popped, so a root that hides its bar stays hidden after you come back
from a screen that shows one — and the bar animates in with the push instead of
jumping in afterwards.

A destination you never gave preferences to inherits the bar state the stack had
when Conduit first attached, so existing screens are unaffected.

> If your app assigns its own `UINavigationControllerDelegate` to the same
> navigation controller, Conduit will not replace it. Bar preferences are then
> applied directly, as before 2.2.0, which cannot restore them on pop. Prefer
> letting Conduit own that delegate.

### Swipe Back

Since 2.3.0 the edge swipe back works on every pushed screen, whether or not the
navigation bar is hidden. Conduit takes over the stack's
`interactivePopGestureRecognizer` delegate when it first attaches (on the first
push into a stack, or when it presents a modal) and lets the swipe start when
there is a screen to go back to and no transition is running.

A screen that must confirm before leaving turns the swipe off while that is true.
Its own back button keeps working:

```swift
EditStayView(model: model)
    .conduitSwipeBackDisabled(model.hasChanges)
```

### Adaptive Sheet Heights

When a sheet should hug its SwiftUI content (e.g., a short form), pass
`.adaptiveHeight`. The router pre-measures the hosting controller via
`sizeThatFits` and substitutes a `.custom` detent before presenting:

```swift
dispatcher.send(.present(
    .quickEditor,
    style: .pageSheet,
    detents: [.adaptiveHeight],
    showDragIndicator: true
))
```

To grow an already-presented sheet (for example, when a text field gains
focus), call `ConduitSheetDetentExpander`:

```swift
ConduitSheetDetentExpander.expandToLarge()
// or pin to a measured height
ConduitSheetDetentExpander.setCustomHeight(420)
```

### Open Safari

```swift
guard let url = URL(string: "https://example.com") else { return }
dispatcher.send(.openSafari(url))
```

`ConduitRouter` presents `SFSafariViewController` on the top-most presenter so
it stacks correctly on top of any active modal. Dismiss with the standard
`.dismiss()` action.

### Change Root via Action

`changeRoot` is available both as a direct router method (for cases that need
to pass a window explicitly) and as a `ConduitAction` that flows through the
dispatcher. Using the action lets tracker subscribers see the swap:

```swift
dispatcher.send(.changeRoot(
    rootBuilder: {
        let signIn = UIHostingController(rootView: SignInView())
        return UINavigationController(rootViewController: signIn)
    },
    metadata: .init(
        rootName: "sign_in",
        reason: "user_signed_out",
        resetsTabStacks: false
    )
))
```

## Navigation Tracking

`ConduitNavigationTracker` observes the dispatcher and maintains per-tab
navigation stacks, a modal stack, and a chronological history log keyed by
order. Subscribe to its publishers for analytics, deep-link routing, or
"where is the user right now?" decisions.

### 1. Conform Your Screen Enum

```swift
enum AppScreen: String, ConduitNavigatedScreen {
    case home, feed, settings, profile, eventDetails, unknown

    var analyticsIdentifier: String { rawValue }
}
```

### 2. Create the Tracker

```swift
let tracker = ConduitNavigationTracker<AppDestination, AppScreen>(
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
        case .profile: return .profile
        case .eventDetails: return .eventDetails
        default: return .unknown
        }
    },
    resolveContext: { destination in
        switch destination {
        case let .eventDetails(eventId, pocketId):
            return ConduitNavigationContext(values: [
                "eventId": eventId,
                "pocketId": pocketId
            ])
        default:
            return .empty
        }
    },
    analyticsPrefix: "myapp_navigation_"
)
```

### 3. Use the Tracker

```swift
// Forward tab-bar selections from your tab delegate
func tabBarController(_ controller: UITabBarController, didSelect: UIViewController) {
    tracker.trackTabSelection(controller.selectedIndex)
}

// Read current state
let screen = tracker.currentScreen
let depth = tracker.navigationDepth
let isRoot = tracker.isAtRootScreen

// Smart navigation: only push when not already there
if tracker.currentContext["eventId"] != targetEventId {
    dispatcher.send(.push(.eventDetails(eventId: targetEventId, pocketId: pocketId)))
}

// Subscribe to events for analytics
tracker.navigationEventPublisher
    .sink { event in
        analytics.record(name: event.analyticsIdentifier(prefix: "myapp_navigation_"))
    }
    .store(in: &cancellables)

// Query history
let pushes = tracker.navigationEntries(matching: "myapp_navigation_pushed")
let visitsToProfile = tracker.navigationEntries(toScreen: .profile)
```

## API Reference

### Core Protocols

| Protocol | Description |
|----------|-------------|
| `ConduitDestination` | Marker protocol for app-defined navigation destinations |
| `ConduitViewFactory` | Factory that converts destinations to `AnyView` |
| `ConduitDispatching` | Navigation action publisher and sender |
| `ConduitRouting` | Router lifecycle: `changeRoot(to:in:)`, `updateActiveWindow(_:)` |
| `ConduitTabConfiguring` | Tab bar item definition protocol |
| `ConduitNavigatedScreen` | Marker protocol for trackable screen enums |
| `ConduitNavigationTracking` | Tracker protocol: stacks, history, publishers |

### Domain Models

| Type | Description |
|------|-------------|
| `ConduitAction<Destination>` | Generic navigation command enum |
| `ConduitBarPreferences` | Navigation bar visibility and title configuration |
| `ConduitDetent` | Sheet detents: `.medium`, `.large`, `.custom(CGFloat)`, `.fraction(CGFloat)`, `.adaptiveHeight` |
| `ConduitPresentationStyle` | Modal styles: `.pageSheet`, `.formSheet`, `.fullScreen`, `.overFullScreen`, `.currentContext`, `.overCurrentContext` |
| `ConduitLargeTitleDisplayMode` | Title modes: `.automatic`, `.always`, `.never` |
| `ConduitRootChangeMetadata` | Optional metadata attached to `.changeRoot` actions |
| `ConduitTabItem` | Tab configuration: title, icon, root SwiftUI view (`AnyView`), index |

### Infrastructure

| Type | Description |
|------|-------------|
| `ConduitDispatcher<Destination>` | Combine-based `@MainActor` dispatcher |
| `ConduitRouter<Factory>` | Core router translating actions to UIKit navigation |
| `ConduitTabBarController` | Generic tab bar built from `ConduitTabItem` arrays |
| `ConduitSheetDetentExpander` | Promote the top-most sheet to `.large` or a custom height |
| `ConduitWindowUtils` | Active key window lookup |

### Tracking

| Type | Description |
|------|-------------|
| `ConduitNavigationTracker<Destination, Screen>` | Concrete generic tracker observing the dispatcher |
| `ConduitNavigationEvent<Screen>` | Generic event enum (pushed, presented, popped, dismissed, tabSwitched, rootChanged, ...) |
| `ConduitNavigationContext` | Free-form key/value bag attached to each stack entry |
| `ConduitNavigationHistoryEntry<Screen>` | Recorded history row with order, event, timestamp, and analytics ID |

## Requirements

- iOS 16.0+ / macOS 13.0+ (build support)
- Swift 6.0+
- Xcode 16.0+

## License

Conduit is available under the MIT license. See the [LICENSE](LICENSE) file for details.
