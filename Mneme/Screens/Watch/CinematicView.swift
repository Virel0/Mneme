//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import AetherEngine
import MeleteKit
import SwiftUI

/// Home left alone: the hero's picks take the whole screen one at a time,
/// each with its trailer or a clip of it, its logo and facts low in the
/// corner, crossfading to the next every 40 seconds. After eight it rests on
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
                clip.start(for: pick, client: library.client, trailerFile: Self.trailerFile(of: pick, library: library))
                try? await Task.sleep(for: Self.each)
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
        guard library.heroTrailers, let trailer = pick.trailer, trailer.source == .folder else { return nil }
        return trailer.fileId
    }
}
