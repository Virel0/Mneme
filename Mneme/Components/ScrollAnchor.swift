//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI
import UIKit

/// Puts a view at a set height on the screen by scrolling the page it is in.
///
/// UIKit, because SwiftUI has no way to say "put this view at this height on
/// the screen" for a view inside nested scroll views. Heights are in window
/// points: the page's scroll view starts at the top of the screen on some
/// pages and under the nav strip on others, and a line measured in its own
/// coordinates landed in two different places.
enum ScrollAnchoring {

    /// Scrolls the nearest vertical scroll view above `view` so that the
    /// view's top edge sits at `windowY`, as far as the content allows.
    ///
    /// - Returns: where the view's top edge ends up, in window points — which
    ///   is not `windowY` when the page runs out first, as it does for the
    ///   last row.
    @discardableResult
    static func scroll(_ view: UIView, toWindowY windowY: CGFloat) -> CGFloat? {
        guard view.window != nil, let scrollView = verticalScrollView(above: view) else { return nil }

        let top = view.convert(view.bounds, to: nil).minY
        let delta = top - windowY

        // Already there. Re-scrolling by a few points on every focus change
        // is a page that will not settle.
        guard abs(delta) > 8 else { return top }

        let lowest = -scrollView.adjustedContentInset.top
        let furthest = max(
            lowest,
            scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        )
        let offset = min(max(lowest, scrollView.contentOffset.y + delta), furthest)
        let moved = offset - scrollView.contentOffset.y

        if abs(moved) > 0.5 {
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: offset), animated: true)
        }

        return top - moved
    }

    /// The nearest ancestor that scrolls vertically — a row's own scroll
    /// view is horizontal and skipped.
    static func verticalScrollView(above view: UIView) -> UIScrollView? {
        var current = view.superview

        while let candidate = current {
            if let scrollView = candidate as? UIScrollView,
               scrollView.contentSize.height > scrollView.bounds.height + 1
            {
                return scrollView
            }
            current = candidate.superview
        }

        return nil
    }
}

/// Scrolls the page so this view's top sits at `windowY` each time
/// `isActive` turns on. Put it in a `.background` of the block it anchors.
///
/// With `locksPage`, the page then stays where it was put for as long as
/// focus is inside the block — for a block with scrolling of its own, like
/// the episode picker, where tvOS otherwise scrolls the page as well as the
/// list on every move and the block creeps up the screen.
///
/// The lock puts the page back whenever it moves while focus is inside, and
/// leaves it alone once focus is outside. Turning the page's scrolling off
/// instead held it just as well, but tvOS will not move focus to something
/// off screen in a scroll view that cannot scroll, so focus could never
/// leave the block upwards.
struct ScrollAnchor: UIViewRepresentable {

    let isActive: Bool
    let windowY: CGFloat
    var locksPage = false
    /// Told where the view's top actually landed, in window points — not
    /// `windowY` when the page ran out first.
    var onLanded: ((CGFloat) -> Void)?

    @MainActor
    final class Coordinator {
        var wasActive = false
        var observation: NSKeyValueObservation?
        var lockedOffset: CGFloat?
        var isRestoring = false

        func unlock() {
            observation?.invalidate()
            observation = nil
            lockedOffset = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        let coordinator = context.coordinator
        defer { coordinator.wasActive = isActive }

        if !isActive, coordinator.wasActive {
            coordinator.unlock()
            return
        }

        guard isActive, !coordinator.wasActive else { return }

        // Next runloop turn: the view has its frame by then.
        DispatchQueue.main.async {
            if let landed = ScrollAnchoring.scroll(view, toWindowY: windowY) {
                onLanded?(landed)
            }

            guard locksPage, let scrollView = ScrollAnchoring.verticalScrollView(above: view) else { return }

            // After the scroll above has landed, so the lock holds the page
            // where it was put rather than half way there.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                guard coordinator.wasActive else { return }
                Self.lock(scrollView, to: view, coordinator: coordinator)
            }
        }
    }

    private static func lock(_ scrollView: UIScrollView, to view: UIView, coordinator: Coordinator) {
        coordinator.lockedOffset = scrollView.contentOffset.y
        coordinator.observation = scrollView.observe(\.contentOffset, options: [.new]) { [weak view] scrollView, _ in
            // Hopped to the main actor: the observation is delivered where the
            // offset changed, which for a scroll view is the main thread.
            MainActor.assumeIsolated {
                guard let view,
                      !coordinator.isRestoring,
                      let locked = coordinator.lockedOffset,
                      abs(scrollView.contentOffset.y - locked) > 0.5,
                      isFocusInside(view, scrollView: scrollView)
                else { return }

                coordinator.isRestoring = true
                scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: locked), animated: false)
                coordinator.isRestoring = false
            }
        }
    }

    /// Whether the focused view sits inside the anchored block, compared in
    /// the page's content coordinates, which do not change as it scrolls.
    ///
    /// The focused item is asked for its frame through `UIFocusItem` rather
    /// than cast to a view: SwiftUI's focusable elements are focus items of
    /// their own, not views, so a cast found nothing and the lock never held.
    @MainActor
    private static func isFocusInside(_ view: UIView, scrollView: UIScrollView) -> Bool {
        guard let item = view.window?.windowScene?.focusSystem?.focusedItem,
              let space = item.parentFocusEnvironment?.focusItemContainer?.coordinateSpace
        else { return false }

        let block = view.convert(view.bounds, to: scrollView)
        let frame = space.convert(item.frame, to: scrollView)
        return block.contains(CGPoint(x: frame.midX, y: frame.midY))
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.unlock()
    }
}
