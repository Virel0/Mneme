//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import AetherEngine
import AssRendering
import SwiftUI

/// An ASS/SSA track drawn as it was made, over the picture: signs where
/// they were placed, in their fonts, karaoke and all, by libass.
struct AssSubtitleOverlay: View {

    let renderer: AssRenderer

    @ObservedObject
    var engine: AetherEngine

    @Environment(\.displayScale)
    private var scale

    @State
    private var frame: AssRenderer.Frame?

    /// Often enough for moving signs and karaoke; drawing is skipped while
    /// nothing changes.
    private static let interval: Duration = .milliseconds(33)

    var body: some View {
        GeometryReader { proxy in
            let video = videoRect(in: proxy.size)
            ZStack(alignment: .topLeading) {
                if let frame {
                    Image(decorative: frame.image, scale: scale)
                        .frame(width: frame.rect.width / scale, height: frame.rect.height / scale)
                        .offset(x: video.minX + frame.rect.minX / scale, y: video.minY + frame.rect.minY / scale)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .task(id: video) {
                await draw(into: video)
            }
        }
        .allowsHitTesting(false)
    }

    /// Asks for the moment the picture is at, until the overlay goes or the
    /// picture moves.
    private func draw(into video: CGRect) async {
        let width = Int(video.width * scale), height = Int(video.height * scale)
        guard width > 0, height > 0 else { return }
        let renderer = renderer
        renderer.setFrame(
            width: width,
            height: height,
            videoWidth: Int(presentedSize.width),
            videoHeight: Int(presentedSize.height)
        )
        while !Task.isCancelled {
            let seconds = engine.clock.sourceTime
            let next = await Task.detached(priority: .userInitiated) { renderer.frame(at: seconds) }.value
            if next?.image !== frame?.image {
                frame = next
            }
            try? await Task.sleep(for: Self.interval)
        }
    }

    /// The video's size as shown: its coded size under its pixel aspect.
    private var presentedSize: CGSize {
        CGSize(width: Double(engine.sourceVideoWidth) * engine.sourceVideoPixelAspectRatio, height: Double(engine.sourceVideoHeight))
    }

    /// Where the picture sits on the screen, fitted as the player fits it.
    private func videoRect(in screen: CGSize) -> CGRect {
        let video = presentedSize
        guard video.width > 0, video.height > 0 else { return CGRect(origin: .zero, size: screen) }
        let fit = min(screen.width / video.width, screen.height / video.height)
        let size = CGSize(width: video.width * fit, height: video.height * fit)
        return CGRect(x: (screen.width - size.width) / 2, y: (screen.height - size.height) / 2, width: size.width, height: size.height)
    }
}
