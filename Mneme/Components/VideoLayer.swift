//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import AVFoundation
import SwiftUI

/// A bare video layer. AVKit's player view brings transport controls and
/// focus of its own, which the app's own clips have no use for.
struct VideoLayer: UIViewRepresentable {

    let player: AVPlayer
    let gravity: AVLayerVideoGravity

    func makeUIView(context: Context) -> LayerView {
        let view = LayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = gravity
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: LayerView, context: Context) {}

    final class LayerView: UIView {

        override static var layerClass: AnyClass {
            AVPlayerLayer.self
        }

        var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }
    }
}

/// A short silent clip from the bundle, played over and over behind a page.
/// With Reduce Motion on, nothing is shown.
struct LoopingVideo: View {

    /// The clip's name in the bundle, an `.mp4` with no sound.
    let resource: String

    @State
    private var player: AVQueuePlayer?
    @State
    private var looper: AVPlayerLooper?

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        ZStack {
            if let player {
                VideoLayer(player: player, gravity: .resizeAspectFill)
            }
        }
        .task {
            guard !reduceMotion, let url = Bundle.main.url(forResource: resource, withExtension: "mp4") else { return }
            let player = AVQueuePlayer()
            player.isMuted = true
            // A background, not something being watched: the screen may
            // still dim and sleep over it.
            player.preventsDisplaySleepDuringVideoPlayback = false
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            self.player = player
            player.play()
        }
        .onDisappear {
            player?.pause()
        }
    }
}
