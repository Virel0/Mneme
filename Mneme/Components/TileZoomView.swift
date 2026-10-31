//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI

/// A pressed tile's picture growing from where the tile sat to the whole
/// screen, fading as it goes, over the page coming in beneath it.
struct TileZoomView: View {

    let zoom: TileZoom
    let done: () -> Void

    @State
    private var isGrown = false
    @State
    private var isGone = false

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private static let growth: TimeInterval = 0.5

    var body: some View {
        GeometryReader { screen in
            let frame = isGrown ? CGRect(origin: .zero, size: screen.size) : zoom.frame
            ArtworkImage(path: zoom.picture)
                .frame(width: frame.width, height: frame.height)
                .clipShape(RoundedRectangle(cornerRadius: isGrown ? 0 : 12, style: .continuous))
                .position(x: frame.midX, y: frame.midY)
                .opacity(isGone ? 0 : 1)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .task {
            // Nothing to grow from: a tile pressed before it knew its place.
            guard !reduceMotion, zoom.frame != .zero else {
                done()
                return
            }
            withAnimation(.easeInOut(duration: Self.growth)) { isGrown = true }
            withAnimation(.easeIn(duration: Self.growth * 0.6).delay(Self.growth * 0.4)) { isGone = true }
            try? await Task.sleep(for: .seconds(Self.growth))
            done()
        }
    }
}
