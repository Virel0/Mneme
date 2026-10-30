//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit
import SwiftUI

/// A series' seasons down the left and the chosen season's episodes on the
/// right, as one block the height of the screen.
///
/// While focus is inside, the page is held still with the block at the top
/// of the screen: both lists scroll on their own, and without the hold tvOS
/// scrolled the page as well as the list on every move and the block crept
/// up the screen.
struct EpisodePicker: View {

    @Environment(Router.self)
    private var router

    let model: TitleModel

    fileprivate enum Focus: Hashable {
        case season(Int)
        case markSeason
        case episode(Int)
    }

    @FocusState
    private var focus: Focus?

    private static let height = UIScreen.main.bounds.height - 75

    var body: some View {
        HStack(alignment: .top, spacing: 48) {
            seasons
                .frame(width: 360)

            episodes
        }
        .padding(.horizontal, RowLayout.edge)
        .frame(height: Self.height, alignment: .top)
        .background {
            ScrollAnchor(isActive: focus != nil, windowY: 0, locksPage: true)
        }
        // A season is chosen by resting on it, as a tab is.
        .onChange(of: focus) { previous, current in
            guard case let .season(season) = current, season != model.selectedSeason else { return }

            // Arriving from the episodes lands on the season they belong to,
            // not whichever one happens to sit level with the episode.
            if let selected = model.selectedSeason, !previous.isSeason {
                focus = .season(selected)
                return
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                guard focus == .season(season) else { return }
                await model.select(season: season)
            }
        }
    }

    // MARK: - Seasons

    @ViewBuilder
    private var seasons: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(model.seasonList) { season in
                    Button {
                        Task { await model.select(season: season.season) }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(season.displayTitle)
                                .font(.headline)
                            Text(season.available == season
                                .episodes ? "\(season.episodes) episodes" : "\(season.available) of \(season.episodes) episodes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(SeasonButtonStyle(isSelected: model.selectedSeason == season.season))
                    .focused($focus, equals: .season(season.season))
                }
            }
            .padding(.vertical, 20)
        }
        .scrollClipDisabled()
        .focusSection()
    }

    // MARK: - Episodes

    @ViewBuilder
    private var episodes: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 28) {
                if let season = model.selectedSeason {
                    markSeasonButton(season)

                    ForEach(model.seasons[season]?.episodes.filter { !$0.files.isEmpty } ?? []) { episode in
                        EpisodeRow(
                            episode: episode,
                            season: season,
                            isWatched: model.isWatched(episode),
                            fraction: model.fraction(episode)
                        ) {
                            if let target = model.target(for: episode, season: season) {
                                router.play(target)
                            }
                        }
                        .focused($focus, equals: .episode(episode.episode))
                        .contextMenu {
                            Button(model.isWatched(episode) ? "Mark Unwatched" : "Mark Watched") {
                                Task { await model.setWatched(episode, !model.isWatched(episode)) }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .scrollClipDisabled()
        .focusSection()
    }

    @ViewBuilder
    private func markSeasonButton(_ season: Int) -> some View {
        let watched = model.isSeasonWatched(season)
        HeroActionButton(
            title: watched ? "Mark Season Unwatched" : "Mark Season Watched",
            systemImage: watched ? "checkmark.circle.fill" : "checkmark.circle",
            isProminent: false
        ) {
            Task { await model.setSeasonWatched(season, !watched) }
        }
        .focused($focus, equals: .markSeason)
    }
}

private extension EpisodePicker.Focus? {

    var isSeason: Bool {
        if case .season = self {
            return true
        }
        return false
    }
}

private struct EpisodeRow: View {

    @FocusState
    private var isFocused: Bool

    let episode: Episode
    let season: Int
    let isWatched: Bool
    let fraction: Double?
    let action: () -> Void

    private static let still = CGSize(width: 384, height: 216)

    private var details: String {
        [episode.runtimeMinutes.flatMap(Format.runtime(minutes:)), episode.airDate]
            .compactMap(\.self)
            .joined(separator: " · ")
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 32) {
                still

                VStack(alignment: .leading, spacing: 8) {
                    Text([Format.episodeCode(season: season, episode: episode.episode), episode.name].compactMap(\.self)
                        .joined(separator: " · "))
                        .font(.headline)
                        .lineLimit(1)
                    if !details.isEmpty {
                        Text(details)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let overview = episode.overview {
                        Text(overview)
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(.white.opacity(isFocused ? 0.12 : 0), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(BareButtonStyle())
        .focused($isFocused)
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    @ViewBuilder
    private var still: some View {
        ArtworkImage(path: episode.still) {
            ZStack {
                Color(white: 0.12)
                Image(systemName: "film").font(.title).foregroundStyle(.secondary)
            }
        }
        .frame(width: Self.still.width, height: Self.still.height)
        .clipped()
        .overlay(alignment: .bottom) {
            if let fraction {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(.white.opacity(0.3))
                        Rectangle().fill(.white).frame(width: proxy.size.width * fraction)
                    }
                }
                .frame(height: 6)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isWatched {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .padding(10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(isFocused ? 0.9 : 0), lineWidth: 4)
        }
    }
}

private struct SeasonButtonStyle: ButtonStyle {

    @Environment(\.isFocused)
    private var isFocused

    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isFocused ? .black : .white)
            .background(
                isFocused ? Color.white : (isSelected ? Color.white.opacity(0.18) : Color.clear),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}
