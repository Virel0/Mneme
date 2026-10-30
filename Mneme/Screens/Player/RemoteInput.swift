//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI
import UIKit

/// Tells a click on the remote's edge from a swipe across its surface.
///
/// SwiftUI's `onMoveCommand` reports both as the same discrete step, so a
/// swipe across the surface became a single ten-second jump: scrubbing that
/// stuttered instead of following the thumb. Clicks are presses of the arrow
/// types; a swipe is a pan of indirect touches. Both recognisers sit on the
/// window, so they hear the remote wherever focus is, and leave the touches
/// to the focus engine too.
struct RemoteInput: UIViewRepresentable {

    var onClick: (Edge) -> Void
    var onSwipeBegan: () -> Void
    /// The horizontal distance moved since the swipe began, as a fraction of
    /// the surface: about 1 for a thumb across its whole width.
    var onSwipeChanged: (CGFloat) -> Void
    var onSwipeEnded: () -> Void

    enum Edge {
        case left
        case right
    }

    func makeUIView(context: Context) -> InputView {
        InputView()
    }

    func updateUIView(_ view: InputView, context: Context) {
        view.input = self
    }

    final class InputView: UIView {

        var input: RemoteInput?
        private var recognizers: [UIGestureRecognizer] = []

        /// The width of the surface in the pan's own units: indirect touches
        /// are reported on a virtual surface about this wide.
        private static let surfaceWidth: CGFloat = 1000

        override func didMoveToWindow() {
            super.didMoveToWindow()
            for recognizer in recognizers {
                recognizer.view?.removeGestureRecognizer(recognizer)
            }
            recognizers = []
            guard let window else { return }

            let left = UITapGestureRecognizer(target: self, action: #selector(clickLeft))
            left.allowedPressTypes = [NSNumber(value: UIPress.PressType.leftArrow.rawValue)]
            let right = UITapGestureRecognizer(target: self, action: #selector(clickRight))
            right.allowedPressTypes = [NSNumber(value: UIPress.PressType.rightArrow.rawValue)]

            // Presses still reach the focus engine, so Left and Right move
            // between buttons where there are buttons to move between.
            left.cancelsTouchesInView = false
            right.cancelsTouchesInView = false

            let pan = UIPanGestureRecognizer(target: self, action: #selector(swipe(_:)))
            pan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
            pan.cancelsTouchesInView = false

            recognizers = [left, right, pan]
            for recognizer in recognizers {
                window.addGestureRecognizer(recognizer)
            }
        }

        @objc
        private func clickLeft() {
            input?.onClick(.left)
        }

        @objc
        private func clickRight() {
            input?.onClick(.right)
        }

        @objc
        private func swipe(_ pan: UIPanGestureRecognizer) {
            let translation = pan.translation(in: pan.view)
            switch pan.state {
            case .began:
                input?.onSwipeBegan()
            case .changed:
                // Mostly sideways only: an up or down swipe moves focus.
                guard abs(translation.x) > abs(translation.y) else { return }
                input?.onSwipeChanged(translation.x / Self.surfaceWidth)
            case .ended, .cancelled, .failed:
                input?.onSwipeEnded()
            default:
                break
            }
        }
    }
}
