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

## Features

- **Generic Destinations** -- Define your own destination enum; the router resolves views through your factory.
- **Combine Dispatcher** -- View models send actions; the router subscribes and executes UIKit transitions.
- **Full UIKit Navigation** -- Push, present (sheets, fullscreen, custom detents), pop, dismiss, tab selection.
- **Protocol-Driven** -- Inject `ConduitDispatching`, `ConduitRouting`, and `ConduitViewFactory` for full testability.
- **Presented Stack Management** -- Tracks modally presented navigation controllers for correct resolution.
- **Configurable Tab Bar** -- Generic `ConduitTabBarController` built from `ConduitTabItem` arrays.
- **UIKit-Free Domain** -- Presentation styles, detents, and bar preferences are SDK enums mapped internally.
- **Swift 6 Ready** -- `@MainActor` isolation, `Sendable` conformance, zero concurrency warnings.
- **Zero Dependencies** -- Built entirely on Combine, UIKit, and SwiftUI.

## Architecture

```
Sources/Conduit/
├── Core/
│   ├── ConduitDestination.swift        ← Marker protocol for app destinations
│   ├── ConduitViewFactory.swift        ← Factory protocol: destination → AnyView
│   ├── ConduitDispatching.swift        ← Dispatcher protocol (Combine publisher)
│   ├── ConduitRouting.swift            ← Router protocol (start, changeRoot)
│   └── ConduitTabConfiguring.swift     ← Tab configuration protocol
├── Domain/
│   ├── ConduitAction.swift             ← Generic navigation commands
│   ├── ConduitBarPreferences.swift     ← Nav bar configuration
│   ├── ConduitDetent.swift             ← Sheet presentation detents
│   ├── ConduitPresentationStyle.swift  ← Modal presentation styles
│   └── ConduitTabItem.swift            ← Tab item configuration
└── Infrastructure/
    ├── ConduitDispatcher.swift          ← PassthroughSubject-based dispatcher
    ├── ConduitRouter.swift             ← Core router: actions → UIKit navigation
    ├── ConduitTabBarController.swift   ← Generic configurable tab bar
    ├── UIViewController+Conduit.swift  ← Navigation controller resolution
    └── ConduitWindowUtils.swift        ← Active window lookup
```

## Installation

### Swift Package Manager

Add Conduit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/egzonpllana/conduit-ios.git", from: "1.0.0")
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

```swift
struct AppViewFactory: ConduitViewFactory {
    @MainActor
    func makeView(for destination: AppDestination) -> AnyView {
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

```swift
let dispatcher = ConduitDispatcher<AppDestination>()
let router = ConduitRouter(
    viewFactory: AppViewFactory(),
    dispatcher: dispatcher
)
```

### 4. Start Routing

```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)

    let tabs = [
        ConduitTabItem(title: "Home", icon: homeIcon, rootViewController: homeVC, index: 0),
        ConduitTabItem(title: "Search", icon: searchIcon, rootViewController: searchVC, index: 1),
        ConduitTabItem(title: "Profile", icon: profileIcon, rootViewController: profileVC, index: 2)
    ]
    let tabBar = ConduitTabBarController(tabs: tabs, selectedIndex: 0)

    router.start(in: window, rootViewController: tabBar)
}
```

### 5. Navigate from View Models

```swift
final class ProfileViewModel {
    private let dispatcher: any ConduitDispatching<AppDestination>

    init(dispatcher: any ConduitDispatching<AppDestination>) {
        self.dispatcher = dispatcher
    }

    @MainActor
    func didTapSettings() {
        dispatcher.send(.push(.settings))
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
    router.changeRoot(to: nav)
}
```

### Navigation Actions

| Action | Description |
|--------|-------------|
| `.push(destination)` | Push onto current navigation stack |
| `.present(destination, style:, detents:, ...)` | Present modally with sheet configuration |
| `.pop` | Pop top view controller |
| `.popMultiple(count:)` | Pop multiple view controllers |
| `.popToRoot` | Pop to root of current stack |
| `.dismiss()` | Dismiss top presented modal |
| `.selectTab(index)` | Select a tab bar tab |
| `.popToRootAndSelectTab(tabIndex:)` | Reset all stacks and select tab |

### Bar Preferences

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

## API Reference

### Core Protocols

| Protocol | Description |
|----------|-------------|
| `ConduitDestination` | Marker protocol for app-defined navigation destinations |
| `ConduitViewFactory` | Factory that converts destinations to `AnyView` |
| `ConduitDispatching` | Navigation action publisher and sender |
| `ConduitRouting` | Router lifecycle: start, updateWindow, changeRoot |
| `ConduitTabConfiguring` | Tab bar item definition protocol |

### Domain Models

| Type | Description |
|------|-------------|
| `ConduitAction<Destination>` | Generic navigation command enum |
| `ConduitBarPreferences` | Navigation bar visibility and title configuration |
| `ConduitDetent` | Sheet detents: `.medium`, `.large`, `.custom(CGFloat)`, `.fraction(CGFloat)` |
| `ConduitPresentationStyle` | Modal styles: `.pageSheet`, `.formSheet`, `.fullScreen`, `.overFullScreen` |
| `ConduitLargeTitleDisplayMode` | Title modes: `.automatic`, `.always`, `.never` |
| `ConduitTabItem` | Tab configuration: title, icon, root view controller, index |

### Infrastructure

| Type | Description |
|------|-------------|
| `ConduitDispatcher<Destination>` | Combine-based `@MainActor` dispatcher |
| `ConduitRouter<Factory>` | Core router translating actions to UIKit navigation |
| `ConduitTabBarController` | Generic tab bar built from `ConduitTabItem` arrays |
| `ConduitWindowUtils` | Active key window lookup |

## Requirements

- iOS 16.0+ / macOS 13.0+ (build support)
- Swift 6.0+
- Xcode 16.0+

## License

Conduit is available under the MIT license. See the [LICENSE](LICENSE) file for details.
