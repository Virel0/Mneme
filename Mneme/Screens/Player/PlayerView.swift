//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import AetherEngine
import SwiftUI

/// The full-screen player and what the remote does in it.
///
/// A click on the remote's left or right edge jumps ten seconds at once; a
/// swipe across its surface scrubs, with the seek bar's previews, and Select
/// jumps to where the swipe stopped. Select otherwise presses the Skip or
/// Next Episode on offer, or pauses. Down reaches Audio and Subtitles. Menu
/// backs out one layer at a time.
struct PlayerView: View {

    @Environment(Library.self)
    private var library
    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.scenePhase)
    private var scenePhase

    @State
    private var session: PlayerSession?
    @State
    private var previews: TrickplayPreviews?
    @State
    private var controlsVisible = false
    /// Where Select will jump to, while scrubbing.
    @State
    private var scrubTarget: Double?
    /// Where a swipe started scrubbing from.
    @State
    private var swipeStart: Double?
    @State
    private var picker: TrackPicker.Kind?
    @State
    private var lastInput = Date.now

    @FocusState
    private var focus: PlayerFocus?

    let target: PlayTarget

    /// How long the controls stay up without a press, while playing.
    private static let controlsTimeout: TimeInterval = 5
    private static let scrubStep: Double = 10

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let session {
                content(session)
            }
        }
        .task {
            let session = PlayerSession(target: target, library: library)
            self.session = session
            focus = .catcher
            await session.start()
        }
        .task(id: session?.trickplay) {
            guard let session, let trickplay = session.trickplay, let play = session.play,
                  let url = library.client.url(for: play.streamUrl)
            else { return }
            previews = TrickplayPreviews(trickplay: trickplay, stream: url, client: library.client)
        }
        .task(id: controlsVisible) {
            await hideControlsWhenIdle()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: session?.enterBackground()
            case .active: Task { await session?.enterForeground() }
            default: break
            }
        }
        // An offer takes focus when it appears, so Select presses it, and
        // gives it back when it goes.
        .onChange(of: session?.isOfferingNext) { _, offering in
            if offering == true {
                if controlsVisible {
                    hideControls()
                }
                moveFocus(to: .nextUp)
            } else if focus == .nextUp {
                moveFocus(to: .catcher)
            }
        }
        .onChange(of: session?.skipOffer != nil) { _, offered in
            if offered, !controlsVisible, session?.isOfferingNext == false {
                moveFocus(to: .skip)
            } else if !offered, focus == .skip {
                moveFocus(to: .catcher)
            }
        }
        .onChange(of: session?.phase) { _, phase in
            if phase == .finished {
                leave()
            }
        }
        // On the whole player rather than the catcher, which is switched off
        // while the controls are up. The track picker answers Menu first.
        .onPlayPauseCommand {
            touch()
            session?.togglePause()
        }
        .onExitCommand(perform: exit)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func content(_ session: PlayerSession) -> some View {
        if let engine = session.engine {
            AetherPlayerSurface(engine: engine)
                .ignoresSafeArea()
            SubtitleOverlay(engine: engine)
                .ignoresSafeArea()
            ActivitySpinner(engine: engine)
        }

        if case let .failed(message) = session.phase {
            PlaybackFailure(message: message, leave: leave)
        } else {
            RemoteInput(
                onClick: click,
                onSwipeBegan: beginSwipe,
                onSwipeChanged: swipe,
                onSwipeEnded: { swipeStart = nil }
            )
            .allowsHitTesting(false)

            remoteCatcher(session)

            if let offer = session.skipOffer, !controlsVisible, !session.isOfferingNext {
                SkipButton(title: offer.title) {
                    touch()
                    session.skip(offer)
                }
                .focused($focus, equals: .skip)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(80)
            }

            if let next = session.next, let left = session.nextCountdown {
                NextUpButton(next: next, secondsLeft: left) {
                    touch()
                    session.playNext()
                }
                .focused($focus, equals: .nextUp)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(80)
            }

            if controlsVisible {
                PlayerControls(
                    session: session,
                    previews: previews,
                    scrubTarget: scrubTarget,
                    focus: $focus,
                    select: selectOnBar,
                    openPicker: { picker = $0 }
                )
                .transition(.opacity)
            }

            if let picker {
                TrackPicker(kind: picker, session: session) {
                    self.picker = nil
                    focus = .bar
                }
            }
        }
    }

    // MARK: - Remote

    /// Something focusable to receive the remote while the controls are
    /// hidden: the whole screen.
    @ViewBuilder
    private func remoteCatcher(_ session: PlayerSession) -> some View {
        Button {
            touch()
            if session.isOfferingNext {
                session.playNext()
            } else if let offer = session.skipOffer {
                session.skip(offer)
            } else {
                session.togglePause()
                showControls()
            }
        } label: {
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(BareButtonStyle())
        .focused($focus, equals: .catcher)
        .disabled(controlsVisible || picker != nil)
        // Left and Right are `RemoteInput`'s: a click jumps, a swipe scrubs.
        .onMoveCommand { direction in
            touch()
            if direction == .up || direction == .down {
                showControls()
            }
        }
    }

    /// Menu backs out one layer at a time: the scrub, then the controls,
    /// then the next-episode offer, then the player.
    private func exit() {
        if scrubTarget != nil {
            scrubTarget = nil
        } else if controlsVisible {
            hideControls()
        } else if session?.isOfferingNext == true {
            session?.dismissNext()
        } else {
            leave()
        }
    }

    private func selectOnBar() {
        touch()
        guard let session else { return }
        if let target = scrubTarget {
            session.seek(to: target)
            scrubTarget = nil
        } else {
            session.togglePause()
        }
    }

    // MARK: - Clicks and swipes

    /// A click jumps ten seconds at once; while scrubbing it nudges the scrub
    /// point instead. Ignored while focus is on the buttons under the bar,
    /// where Left and Right move between them.
    private func click(_ edge: RemoteInput.Edge) {
        guard let session, picker == nil, focus.allowsJumping else { return }
        touch()
        let step = edge == .left ? -Self.scrubStep : Self.scrubStep
        if let target = scrubTarget {
            scrubTarget = min(max(0, target + step), session.duration)
        } else {
            session.jump(by: step)
            showControls()
        }
    }

    private func beginSwipe() {
        guard let session, picker == nil, focus.allowsJumping else { return }
        touch()
        swipeStart = scrubTarget ?? session.shownPosition
        showControls()
    }

    /// A thumb across the whole surface moves a fifth of the film, between
    /// three and twenty minutes, so a long film and a short episode both
    /// scrub at a speed that can be followed.
    private func swipe(_ fraction: CGFloat) {
        guard let session, let start = swipeStart else { return }
        touch()
        let span = min(max(session.duration * 0.2, 180), 1200)
        scrubTarget = min(max(0, start + Double(fraction) * span), session.duration)
    }

    private func showControls() {
        guard !controlsVisible else { return }
        withAnimation(.easeOut(duration: 0.2)) { controlsVisible = true }
        moveFocus(to: .bar)
    }

    private func hideControls() {
        scrubTarget = nil
        withAnimation(.easeOut(duration: 0.3)) { controlsVisible = false }
        let offering = session?.isOfferingNext == true
        moveFocus(to: offering ? .nextUp : (session?.skipOffer != nil ? .skip : .catcher))
    }

    /// Moves focus a moment later, once what it moves to is on screen and
    /// switched on. Set in the same instant, tvOS can drop the move and leave
    /// nothing focused, and then Select does nothing at all.
    private func moveFocus(to target: PlayerFocus) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            focus = target
        }
    }

    private func touch() {
        lastInput = .now
    }

    private func hideControlsWhenIdle() async {
        while controlsVisible, !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            let isIdle = Date.now.timeIntervalSince(lastInput) > Self.controlsTimeout
            if isIdle, scrubTarget == nil, picker == nil, session?.isPaused == false {
                hideControls()
            }
        }
    }

    private func leave() {
        let session = session
        Task {
            await session?.stop()
            dismiss()
        }
    }
}

enum PlayerFocus: Hashable {
    case catcher
    case bar
    case audio
    case subtitles
    case skip
    case nextUp
}

extension PlayerFocus? {

    /// Where Left and Right jump and scrub, rather than move between buttons.
    var allowsJumping: Bool {
        switch self {
        case .catcher, .bar, .skip, .nextUp: true
        default: false
        }
    }
}

/// A spinner for as long as the engine has no picture to give: opening a 4K
/// file over Wi-Fi is seconds of black, and a frozen frame with nothing on it
/// reads as a crash.
private struct ActivitySpinner: View {

    @ObservedObject
    var engine: AetherEngine

    var body: some View {
        switch engine.playbackPhase {
        case .loading, .rebuffering, .stalled:
            ProgressView()
                .scaleEffect(2)
                .tint(.white)
        default:
            EmptyView()
        }
    }
}

private struct PlaybackFailure: View {

    let message: String
    let leave: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
            Text("This can't be played")
                .font(.title2)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 900)
            Button("Back", action: leave)
        }
    }
}
