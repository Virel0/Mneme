//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit
import SwiftUI

struct HomeView: View {

    @State
    var model: HomeModel

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView()
            case let .failed(error):
                FailureView(error: error) {
                    Task { await model.load() }
                }
            case let .loaded(home):
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 56) {
                        if let pick = home.hero.first {
                            HeroView(item: pick)
                        }
                        ForEach(home.rows) { row in
                            HomeRowView(row: row)
                        }
                    }
                    .padding(.bottom, 80)
                }
                .scrollClipDisabled()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .environment(\.melete, model.client)
        .task { await model.load() }
    }
}

private struct HeroView: View {

    let item: WatchHomeItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkImage(path: item.textlessBackdrop ?? item.backdrop)
                .frame(height: 760)
                .clipped()
                .overlay {
                    LinearGradient(colors: [.clear, .black], startPoint: .center, endPoint: .bottom)
                }

            VStack(alignment: .leading, spacing: 20) {
                if item.logo != nil {
                    ArtworkImage(path: item.logo, contentMode: .fit)
                        .frame(maxWidth: 560, maxHeight: 200, alignment: .bottomLeading)
                } else {
                    Text(item.title)
                        .font(.largeTitle.bold())
                }

                Text(facts)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if let overview = item.overview {
                    Text(overview)
                        .lineLimit(2)
                        .frame(maxWidth: 900, alignment: .leading)
                }
            }
            .padding(.horizontal, 80)
            .padding(.bottom, 40)
        }
        .focusable()
    }

    private var facts: String {
        var parts: [String] = [item.kind == .movie ? "Movie" : "Series"]
        if let year = item.year { parts.append(String(year)) }
        parts.append(contentsOf: item.genres.prefix(3))
        if let minutes = item.runtimeMinutes {
            parts.append(minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min")
        }
        return parts.joined(separator: " · ")
    }
}

private struct HomeRowView: View {

    let row: WatchHomeRow

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(row.key.title)
                .font(.title3.bold())
                .padding(.horizontal, 80)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 40) {
                    ForEach(row.items) { item in
                        Button {} label: {
                            TileView(item: item, isLandscape: row.key.isLandscape)
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(.horizontal, 80)
                .padding(.vertical, 20)
            }
            .scrollClipDisabled()
        }
    }
}

private struct TileView: View {

    let item: WatchHomeItem
    let isLandscape: Bool

    var body: some View {
        if isLandscape {
            ZStack(alignment: .bottomLeading) {
                ArtworkImage(path: item.episode?.still ?? item.textlessBackdrop ?? item.backdrop)
                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.callout.bold())
                    if let episode = item.episode, let season = episode.season, let number = episode.episode {
                        Text("S\(season):E\(number)" + (episode.name.map { " · \($0)" } ?? ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let progress = item.progress, let duration = progress.durationSeconds, duration > 0 {
                        ProgressView(value: min(progress.positionSeconds / duration, 1))
                            .tint(.white)
                    }
                }
                .lineLimit(1)
                .padding(16)
            }
            .frame(width: 420, height: 236)
        } else {
            ArtworkImage(path: item.poster)
                .frame(width: 220, height: 330)
        }
    }
}

private struct FailureView: View {

    let error: MeleteError
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Couldn't load Home")
                .font(.title2)
            Text(error.localizedDescription)
                .foregroundStyle(.secondary)
            Button("Try Again", action: retry)
        }
    }
}
