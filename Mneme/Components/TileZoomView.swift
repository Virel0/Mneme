//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI

/// A pressed tile's picture growing from where the tile sat to the whole
/// screen, over the page coming in beneath it. As it grows it turns into the
/// page's own backdrop, and fades only once it is that, so it hands over to
/// the same picture in the same place. Fading the tile's picture itself, a
/// poster stretched to the screen showed through the page as it came in.
struct TileZoomView: View {

    let zoom: TileZoom
    let done: () -> Void

    @State
    private var isGrown = false
    @State
    private var isTurned = false
    @State
    private var isGone = false

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private static let growth: TimeInterval = 0.5
    private static let fade: TimeInterval = 0.3

    var body: some View {
        GeometryReader { screen in
            let frame = isGrown ? CGRect(origin: .zero, size: screen.size) : zoom.frame
            // The tile's picture over the backdrop, not beside it in a stack:
            // a poster filling the screen is taller than it, and a stack grew
            // to the poster and the backdrop with it.
            FocusedBackdrop(path: zoom.backdrop, focus: zoom.backdropFocus)
                .overlay {
                    ArtworkImage(zoom.picture)
                        .opacity(isTurned ? 0 : 1)
                }
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
            withAnimation(.easeInOut(duration: Self.growth * 0.6)) { isTurned = true }
            withAnimation(.easeOut(duration: Self.fade).delay(Self.growth)) { isGone = true }
            try? await Task.sleep(for: .seconds(Self.growth + Self.fade))
            done()
        }
    }
}
