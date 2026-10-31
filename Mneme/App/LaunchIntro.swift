//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import AVFoundation
import SwiftUI

/// The opening ident: a rendered clip, played once per launch over
/// everything while the app loads behind it, and gone when it ends or at any
/// press of the remote. With Reduce Motion on, the wordmark is shown still
/// for a moment instead.
struct LaunchIntro: View {

    /// Called once, when the intro is over.
    let onComplete: () -> Void

    @State
    private var player: AVPlayer?
    @State
    private var didComplete = false

    @FocusState
    private var isFocused: Bool

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private static let clip = Bundle.main.url(forResource: "Intro", withExtension: "mp4")

    /// A little past the clip's 8 seconds, so it ends on its own notification;
    /// the ceiling is only for an item that stalls and would otherwise leave
    /// the app hidden behind it.
    private static let ceiling: Duration = .seconds(8.5)

    /// Below full: it plays unasked, at whatever volume the television is
    /// already set to for films.
    private static let volume: Float = 0.8

    var body: some View {
        // A button the size of the screen holds focus, so every press lands
        // here and skips the intro rather than reaching the page behind it.
        Button(action: finish) {
            ZStack {
                Color.black

                if let player {
                    VideoLayer(player: player, gravity: .resizeAspect)
                } else if reduceMotion || Self.clip == nil {
                    Image("MnemeWordmark")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 900)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(LabelOnly())
        .ignoresSafeArea()
        .focused($isFocused)
        .onMoveCommand { _ in finish() }
        .onPlayPauseCommand(perform: finish)
        .onExitCommand(perform: finish)
        .task {
            isFocused = true
            await run()
        }
    }

    private func run() async {
        guard !reduceMotion, let clip = Self.clip else {
            try? await Task.sleep(for: .seconds(1.4))
            finish()
            return
        }

        let item = AVPlayerItem(url: clip)
        let player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .pause
        player.volume = Self.volume
        self.player = player
        player.play()

        // Whichever comes first: the end of the clip, or the ceiling, which
        // stops the wait.
        let ends = NotificationCenter.default.notifications(named: AVPlayerItem.didPlayToEndTimeNotification, object: item)
        let ended = Task {
            for await _ in ends {
                break
            }
        }
        let ceiling = Task {
            try? await Task.sleep(for: Self.ceiling)
            ended.cancel()
        }
        await ended.value
        ceiling.cancel()

        finish()
    }

    private func finish() {
        guard !didComplete else { return }
        didComplete = true
        player?.pause()
        onComplete()
    }
}

/// The label and nothing else: no focus lift or press shrink on a button that
/// is the whole screen.
private struct LabelOnly: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
