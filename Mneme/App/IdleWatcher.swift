//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI
import UIKit

/// Notices every press and swipe on the remote, and every move of focus,
/// without taking any of them: recognisers on the window that never cancel
/// what they see, as the player's remote input does. With `catchesMenu`, it
/// also takes Menu, so a press meant to wake the screen doesn't leave the app.
struct IdleWatcher: UIViewRepresentable {

    let catchesMenu: Bool
    let onActivity: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = WatcherView()
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.onActivity = onActivity
        context.coordinator.menu?.isEnabled = catchesMenu
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onActivity: () -> Void = {}
        var menu: UITapGestureRecognizer?
        private var recognizers: [UIGestureRecognizer] = []
        private var focusObserver: NSObjectProtocol?

        func attach(to window: UIWindow) {
            guard recognizers.isEmpty else { return }
            let presses = UITapGestureRecognizer(target: self, action: #selector(noticed))
            presses.allowedPressTypes = [UIPress.PressType.select, .playPause, .upArrow, .downArrow, .leftArrow, .rightArrow]
                .map { NSNumber(value: $0.rawValue) }
            let swipes = UIPanGestureRecognizer(target: self, action: #selector(noticed))
            let menu = UITapGestureRecognizer(target: self, action: #selector(noticed))
            menu.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
            menu.isEnabled = false
            for recognizer in [presses, swipes] {
                recognizer.cancelsTouchesInView = false
                recognizer.delaysTouchesBegan = false
                recognizer.delegate = self
            }
            for recognizer in [presses, swipes, menu] {
                window.addGestureRecognizer(recognizer)
            }
            self.menu = menu
            recognizers = [presses, swipes, menu]
            focusObserver = NotificationCenter.default
                .addObserver(forName: UIFocusSystem.didUpdateNotification, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.onActivity() }
                }
        }

        func detach() {
            for recognizer in recognizers {
                recognizer.view?.removeGestureRecognizer(recognizer)
            }
            recognizers = []
            if let focusObserver {
                NotificationCenter.default.removeObserver(focusObserver)
            }
        }

        @objc
        private func noticed() {
            onActivity()
        }

        func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool {
            true
        }
    }

    private final class WatcherView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let window {
                coordinator?.attach(to: window)
            }
        }
    }
}
