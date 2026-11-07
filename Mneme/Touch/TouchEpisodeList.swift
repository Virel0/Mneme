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

/// A series' episodes, one season at a time: the season chosen from a menu
/// above them, and two columns of episodes on a wide iPad. Tapping an
/// episode plays it; a long press marks it watched or not.
struct TouchEpisodeList: View {

    @Environment(\.horizontalSizeClass)
    private var sizeClass
    @Environment(Router.self)
    private var router

    let model: TitleModel

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 20, alignment: .top), count: sizeClass == .regular ? 2 : 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                seasonChoice
                Spacer()
                if let season = model.selectedSeason {
                    seasonOptions(season)
                }
            }
            .padding(.horizontal, TouchLayout.edge)

            if let season = model.selectedSeason {
                if let loaded = model.seasons[season] {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                        ForEach(loaded.episodes.filter { !$0.files.isEmpty }) { episode in
                            row(episode, season: season)
                        }
                    }
                    .padding(.horizontal, TouchLayout.edge)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                }
            }
        }
    }

    // MARK: - Seasons

    /// A menu of the seasons when there is more than one, else the one
    /// season's name as the heading.
    @ViewBuilder
    private var seasonChoice: some View {
        let seasons = model.seasonList
        let current = seasons.first { $0.season == model.selectedSeason }?.displayTitle ?? "Episodes"

        if seasons.count > 1 {
            Menu {
                Picker("Season", selection: Binding(
                    get: { model.selectedSeason },
                    set: { season in Task { await model.select(season: season) } }
                )) {
                    ForEach(seasons) { season in
                        Text(season.displayTitle).tag(Int?.some(season.season))
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(current)
                    Image(systemName: "chevron.down")
                        .font(.subheadline.bold())
                }
                .font(.title3.bold())
                .foregroundStyle(.primary)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Season")
            .accessibilityValue(current)
        } else {
            Text(current)
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func seasonOptions(_ season: Int) -> some View {
        let watched = model.isSeasonWatched(season)
        return Menu {
            Button(
                watched ? "Mark Season Unwatched" : "Mark Season Watched",
                systemImage: watched ? "checkmark.circle.fill" : "checkmark.circle"
            ) {
                Task { await model.setSeasonWatched(season, !watched) }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Season Options")
    }

    // MARK: - Episodes

    private func row(_ episode: Episode, season: Int) -> some View {
        let watched = model.isWatched(episode)
        return Button {
            if let target = model.target(for: episode, season: season) {
                router.play(target)
            }
        } label: {
            TouchEpisodeRow(
                episode: episode,
                season: season,
                isWatched: watched,
                fraction: model.fraction(episode),
                stillWidth: sizeClass == .regular ? 176 : 136
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(watched ? "Mark Unwatched" : "Mark Watched", systemImage: watched ? "circle" : "checkmark.circle") {
                Task { await model.setWatched(episode, !watched) }
            }
        }
        .accessibilityHint("Plays the episode")
        .accessibilityAction(named: watched ? "Mark Unwatched" : "Mark Watched") {
            Task { await model.setWatched(episode, !watched) }
        }
    }
}

/// An episode's still, with how far through and whether it is watched; its
/// code, name and length beside it; its overview under both.
private struct TouchEpisodeRow: View {

    let episode: Episode
    let season: Int
    let isWatched: Bool
    let fraction: Double?
    let stillWidth: CGFloat

    /// "S1:E3 · Name".
    private var heading: String {
        [Format.episodeCode(season: season, episode: episode.episode), episode.name]
            .compactMap(\.self)
            .joined(separator: " · ")
    }

    private var details: String {
        [episode.runtimeMinutes.flatMap(Format.runtime(minutes:)), episode.airDate]
            .compactMap(\.self)
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                still

                VStack(alignment: .leading, spacing: 4) {
                    Text(heading)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    if !details.isEmpty {
                        Text(details)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let overview = episode.overview, !overview.isEmpty {
                Text(overview)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(isWatched ? "Watched" : (fraction == nil ? "" : "Partly watched"))
    }

    private var still: some View {
        ArtworkImage(ArtworkSlot(path: episode.still, kind: .still, width: stillWidth)) {
            ZStack {
                Color(white: 0.12)
                Image(systemName: "film")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: stillWidth, height: stillWidth * 9 / 16)
        .clipped()
        .overlay(alignment: .bottom) {
            if let fraction {
                ProgressView(value: fraction)
                    .tint(Color.mnemeViolet)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 5)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isWatched {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .padding(5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
#endif
