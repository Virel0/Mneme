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
/// With the controls hidden: Select skips the part on offer, plays the next
/// episode while it counts down, or pauses; Left and Right start scrubbing;
/// Menu turns away the next episode, else leaves. With them showing, Left
/// and Right move the scrub point ten seconds at a time over the seek bar's
/// previews, Select jumps there, Down reaches Audio and Subtitles, and Menu
/// puts them away.
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
            remoteCatcher(session)

            if let offer = session.skipOffer, !controlsVisible, !session.isOfferingNext {
                SkipBadge(title: offer.title)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(80)
            }

            if let next = session.next, let left = session.nextCountdown {
                NextUpCard(next: next, secondsLeft: left)
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
                    move: moveOnBar,
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
        .onMoveCommand { direction in
            touch()
            switch direction {
            case .left: scrub(by: -Self.scrubStep)
            case .right: scrub(by: Self.scrubStep)
            default: showControls()
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

    private func moveOnBar(_ direction: MoveCommandDirection) {
        touch()
        switch direction {
        case .left: scrub(by: -Self.scrubStep)
        case .right: scrub(by: Self.scrubStep)
        default: break
        }
    }

    private func scrub(by seconds: Double) {
        guard let session else { return }
        showControls()
        let from = scrubTarget ?? session.position
        scrubTarget = min(max(0, from + seconds), session.duration)
    }

    private func showControls() {
        guard !controlsVisible else { return }
        withAnimation(.easeOut(duration: 0.2)) { controlsVisible = true }
        focus = .bar
    }

    private func hideControls() {
        scrubTarget = nil
        withAnimation(.easeOut(duration: 0.3)) { controlsVisible = false }
        focus = .catcher
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
