//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

#if os(iOS)
import MeleteKit
import SwiftUI

/// A titled row of tiles to swipe along, a little of the next one showing at
/// the edge.
struct TouchTileRow: View {

    @Environment(\.horizontalSizeClass)
    private var sizeClass

    let title: String
    let items: [TitleSummary]
    let shape: TileShape
    let open: (TitleSummary) -> Void
    /// For a row whose tiles play: opens the title instead, from the tile's
    /// long-press menu.
    var goToTitle: ((TitleSummary) -> Void)?
    /// After the last title, the first again, for as far as anybody swipes.
    var loops = false

    /// How many times over the titles are laid out; one more is added as
    /// the last comes into view, so the end is never reached.
    @State
    private var rounds = 2
    @State
    private var rowWidth: CGFloat = 0

    /// About one and a half wide tiles to a phone's width, or three posters
    /// and a bit; more of each on an iPad.
    private var tileWidth: CGFloat {
        switch (shape, sizeClass) {
        case (.landscape, .regular): 300
        case (.landscape, _): 240
        case (.portrait, .regular): 150
        case (.portrait, _): 112
        }
    }

    /// Only a row longer than the screen goes round: a shorter one would
    /// show the same titles side by side.
    private var places: [(place: RowPlace, item: TitleSummary)] {
        let fits = rowWidth / (tileWidth + 10)
        let goesRound = loops && CGFloat(items.count) > fits
        return items.inRounds(goesRound ? rounds : 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.bold())
                .padding(.horizontal, TouchLayout.edge)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 10) {
                    ForEach(places, id: \.place) { place, item in
                        tile(item)
                            .onAppear {
                                if place.round == rounds - 1 {
                                    rounds += 1
                                }
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, TouchLayout.edge, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
        }
    }

    @ViewBuilder
    private func tile(_ item: TitleSummary) -> some View {
        let button = Button {
            open(item)
        } label: {
            TouchTile(summary: item, shape: shape, width: tileWidth)
        }
        .buttonStyle(.plain)

        if let goToTitle {
            button.contextMenu {
                Button("Go to \(item.kind == .series ? "Show" : "Movie")", systemImage: "info.circle") {
                    goToTitle(item)
                }
            }
        } else {
            button
        }
    }
}

/// A title's picture, with its badge, and on a wide tile how far through and
/// a caption under it.
struct TouchTile: View {

    @Environment(Library.self)
    private var library

    let summary: TitleSummary
    let shape: TileShape
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            picture
            if shape == .landscape {
                caption
            }
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var picture: some View {
        let size = shape.size(forWidth: width)
        return ArtworkImage(TitleTile.picture(of: summary, in: .grid(shape, width: width))) {
            ZStack {
                Color(white: 0.12)
                Text(summary.title)
                    .font(.caption.bold())
                    .multilineTextAlignment(.center)
                    .padding(8)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .overlay(alignment: .bottom) {
            if shape == .landscape, let progress = summary.progress {
                ProgressLine(progress: progress)
            }
        }
        .overlay(alignment: .topLeading) {
            if let badge = summary.badge(isWatching: library.watching.contains(summary.ref), compact: shape == .portrait) {
                BadgeChip(kind: badge.0, title: badge.1)
                    .padding(6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(summary.title)
                .font(.subheadline.weight(.semibold))
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
    }

    /// "S2:E4 · The Long Night", or the year for a movie.
    private var subtitle: String? {
        if let episode = summary.episode {
            return [Format.episodeCode(season: episode.season, episode: episode.episode), episode.name]
                .compactMap(\.self)
                .joined(separator: " · ")
        }
        return summary.year.map(String.init)
    }
}

/// How far through, as a thin bar along the bottom of a wide tile.
private struct ProgressLine: View {

    let progress: WatchHomeItem.Progress

    private var fraction: Double {
        guard let duration = progress.durationSeconds, duration > 0 else { return 0 }
        return min(max(progress.positionSeconds / duration, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(.white.opacity(0.3))
                Rectangle().fill(Color.mnemeViolet).frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 4)
        .accessibilityLabel(progress.timeLeft ?? "Partly watched")
    }
}
#endif
