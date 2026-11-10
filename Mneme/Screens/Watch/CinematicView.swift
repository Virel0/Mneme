//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import AetherEngine
import MeleteKit
import SwiftUI

/// Home left alone: the hero's picks take the whole screen one at a time,
/// each with its trailer or a clip of it, its logo and facts low in the
/// corner, crossfading to the next after 40 seconds, or once its trailer has
/// played to the end: nobody is busy with anything else. After eight it rests on
/// the last picture, with nothing playing, so the Apple TV's own screensaver
/// can come.
struct CinematicView: View {

    @Environment(Library.self)
    private var library

    let picks: [TitleSummary]

    @State
    private var index = 0
    @State
    private var clip = PreviewClip()

    private static let each: Duration = .seconds(40)
    private static let most = 8

    private var pick: TitleSummary? {
        picks.isEmpty ? nil : picks[index % picks.count]
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.mnemePageBackground

            if let pick {
                FocusedBackdrop(path: pick.backdrop, focus: pick.backdropFocus)
                    .modifier(SlowDrift(focus: pick.backdropFocus))
                    .overlay {
                        if let engine = clip.engine, clip.isPlaying {
                            AetherPlayerSurface(engine: engine)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.8), value: clip.isPlaying)
                    .overlay {
                        LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .init(x: 0.5, y: 0.55), endPoint: .bottom)
                    }
                    .id(pick.ref)
                    .transition(.opacity)

                VStack(alignment: .leading, spacing: 14) {
                    TitleLogo(entry: pick, maxWidth: 560, maxHeight: 170, fontSize: 64)
                    Text(pick.facts)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.leading, RowLayout.edge)
                .padding(.bottom, 90)
                .id(pick.ref)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 1.2), value: index)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .task {
            for shown in 0 ..< Self.most {
                guard !Task.isCancelled, let pick else { return }
                clip.start(
                    for: pick,
                    client: library.client,
                    trailerFile: Self.trailerFile(of: pick, library: library),
                    wholeTrailer: true
                )
                try? await Task.sleep(for: Self.each)
                // The clip stops itself at its end.
                while clip.isPlaying, !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                }
                guard !Task.isCancelled else { return }
                clip.stop()
                if shown < Self.most - 1 {
                    index += 1
                }
            }
        }
        .onDisappear {
            clip.stop()
        }
    }

    private static func trailerFile(of pick: TitleSummary, library: Library) -> Int? {
        guard library.heroTrailers else { return nil }
        return pick.trailer?.playableFile
    }
}
