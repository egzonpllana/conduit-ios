//
//  ConduitSwipeBack.swift
//  Conduit
//

#if canImport(UIKit)
import SwiftUI
import UIKit

/// Screens that have turned the edge swipe back off, for example while an edit
/// has unsaved changes and leaving must go through a confirmation first.
///
/// Weak entries, so a screen that is gone never blocks anything.
@MainActor
enum ConduitSwipeBack {
    private static let disabled = NSHashTable<UIViewController>.weakObjects()

    static func setDisabled(_ isDisabled: Bool, for viewController: UIViewController) {
        if isDisabled {
            disabled.add(viewController)
        } else {
            disabled.remove(viewController)
        }
    }

    static func isDisabled(for viewController: UIViewController) -> Bool {
        disabled.contains(viewController)
    }
}

public extension View {
    /// Turns the edge swipe back off for the screen showing this view while
    /// `isDisabled` is true.
    ///
    /// Conduit keeps the system swipe back working on every stack it manages,
    /// even with the navigation bar hidden. Use this when leaving a screen needs
    /// a confirmation (unsaved changes) that a swipe would skip. The screen's own
    /// back button keeps working.
    func conduitSwipeBackDisabled(_ isDisabled: Bool = true) -> some View {
        background(ConduitSwipeBackMarker(isDisabled: isDisabled).frame(width: 0, height: 0))
    }
}

/// Finds the screen it is placed in (the child of the navigation controller)
/// and records whether that screen allows the swipe back.
private struct ConduitSwipeBackMarker: UIViewControllerRepresentable {
    let isDisabled: Bool

    func makeUIViewController(context: Context) -> MarkerController {
        MarkerController(isDisabled: isDisabled)
    }

    func updateUIViewController(_ controller: MarkerController, context: Context) {
        controller.isDisabled = isDisabled
    }

    static func dismantleUIViewController(_ controller: MarkerController, coordinator: ()) {
        controller.isDisabled = false
    }

    final class MarkerController: UIViewController {
        var isDisabled: Bool {
            didSet { apply() }
        }

        /// The screen the marker last applied to, so turning it back on or
        /// leaving clears the same screen.
        private weak var screen: UIViewController?

        init(isDisabled: Bool) {
            self.isDisabled = isDisabled
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            nil
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            apply()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            apply()
        }

        private func apply() {
            let current = Self.screen(containing: self)
            if let previous = screen, previous !== current {
                ConduitSwipeBack.setDisabled(false, for: previous)
            }
            screen = current
            if let current {
                ConduitSwipeBack.setDisabled(isDisabled, for: current)
            }
        }

        /// The ancestor whose parent is a navigation controller.
        private static func screen(containing controller: UIViewController) -> UIViewController? {
            var candidate: UIViewController? = controller
            while let current = candidate {
                if current.parent is UINavigationController {
                    return current
                }
                candidate = current.parent
            }
            return nil
        }
    }
}
#endif
