//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation
import MeleteKit

/// A movie or a series, by kind and id: Melete's ids are unique only within
/// a kind.
struct TitleRef: Hashable, Sendable {
    let kind: TitleKind
    let id: Int
}

/// What a tile, the hero and the spotlight know about a title, whichever
/// answer it came from.
///
/// The home's items say everything; a list's items say little more than the
/// name and the poster, and the rest is fetched when one is looked at.
struct TitleSummary: Hashable, Identifiable, Sendable {

    let ref: TitleRef
    let title: String
    let year: Int?
    let genres: [String]
    let runtimeMinutes: Int?
    let overview: String?
    let poster: String?
    let backdrop: String?
    let backdropFocus: Focus?
    let logo: String?
    let addedAt: Int?
    let unwatchedEpisodes: Int?
    /// The episode partway through, or the next one.
    let episode: WatchHomeItem.Episode?
    let progress: WatchHomeItem.Progress?
    /// Whether this came with its full facts, or is a list entry the
    /// spotlight still has to look up.
    let isComplete: Bool

    var id: TitleRef {
        ref
    }

    var kind: TitleKind {
        ref.kind
    }
}

extension TitleSummary {

    init(_ item: WatchHomeItem) {
        ref = TitleRef(kind: item.kind, id: item.id)
        title = item.title
        year = item.year
        genres = item.genres
        runtimeMinutes = item.runtimeMinutes
        overview = item.overview
        poster = item.poster
        // The textless backdrop first: a picture with the title painted on it
        // fights the logo set over it.
        backdrop = item.textlessBackdrop ?? item.backdrop
        backdropFocus = item.textlessBackdrop != nil ? item.textlessBackdropFocus : item.backdropFocus
        logo = item.logo
        addedAt = item.addedAt
        unwatchedEpisodes = item.unwatchedEpisodes
        episode = item.episode
        progress = item.progress
        isComplete = true
    }

    init(_ item: ListItem, kind: TitleKind) {
        ref = TitleRef(kind: kind, id: item.id)
        title = item.title
        year = item.year
        genres = []
        runtimeMinutes = nil
        overview = nil
        poster = item.poster
        backdrop = nil
        backdropFocus = nil
        logo = nil
        addedAt = item.addedAt
        unwatchedEpisodes = item.unwatchedEpisodes
        episode = nil
        progress = nil
        isComplete = false
    }

    init(_ item: Favourite) {
        ref = TitleRef(kind: item.kind, id: item.id)
        title = item.title
        year = item.year
        genres = []
        runtimeMinutes = nil
        overview = nil
        poster = item.poster
        backdrop = nil
        backdropFocus = nil
        logo = nil
        addedAt = nil
        unwatchedEpisodes = nil
        episode = nil
        progress = nil
        isComplete = false
    }

    /// A list entry with the facts its page answered filled in.
    func completed(with movie: MovieDetail) -> TitleSummary {
        completed(
            year: movie.year,
            genres: movie.genres,
            runtimeMinutes: movie.runtimeMinutes,
            overview: movie.overview,
            backdrop: movie.textlessBackdrop ?? movie.backdrop,
            focus: movie.textlessBackdrop != nil ? movie.textlessBackdropFocus : movie.backdropFocus,
            logo: movie.logo
        )
    }

    func completed(with series: SeriesDetail) -> TitleSummary {
        completed(
            year: series.year,
            genres: series.genres,
            runtimeMinutes: nil,
            overview: series.overview,
            backdrop: series.textlessBackdrop ?? series.backdrop,
            focus: series.textlessBackdrop != nil ? series.textlessBackdropFocus : series.backdropFocus,
            logo: series.logo
        )
    }

    private func completed(
        year: Int?,
        genres: [String],
        runtimeMinutes: Int?,
        overview: String?,
        backdrop: String?,
        focus: Focus?,
        logo: String?
    ) -> TitleSummary {
        TitleSummary(
            ref: ref,
            title: title,
            year: year ?? self.year,
            genres: genres,
            runtimeMinutes: runtimeMinutes,
            overview: overview,
            poster: poster,
            backdrop: backdrop,
            backdropFocus: focus,
            logo: logo,
            addedAt: addedAt,
            unwatchedEpisodes: unwatchedEpisodes,
            episode: episode,
            progress: progress,
            isComplete: true
        )
    }
}

// MARK: - Words

extension TitleSummary {

    /// "Movie · 2007 · Action · Adventure · 1 h 57 min".
    var facts: String {
        var parts: [String] = [kind == .movie ? "Movie" : "Series"]
        if let year {
            parts.append(String(year))
        }
        parts.append(contentsOf: genres.prefix(3))
        if let runtimeMinutes, let length = Format.runtime(minutes: runtimeMinutes) {
            parts.append(length)
        }
        return parts.joined(separator: " · ")
    }

    /// The one badge a tile wears, as Melete's web tiles choose it: episodes
    /// waiting on a series being watched, else "New" for two weeks after the
    /// title came in, unless it has been watched. Every series has episodes
    /// nobody has watched, so the count means something only for one in
    /// progress.
    ///
    /// `compact` for a poster, which has room for the number and no more.
    func badge(isWatching: Bool, compact: Bool = false) -> (BadgeChip.Kind, String)? {
        if kind == .series, isWatching, let unwatched = unwatchedEpisodes, unwatched > 0 {
            return (.unwatched, compact ? "\(unwatched)" : "\(unwatched) Unwatched")
        }
        if let addedAt, Date.now.timeIntervalSince1970 - TimeInterval(addedAt) < 14 * 24 * 3600, progress?.watched != true {
            return (.new, "New")
        }
        return nil
    }
}

enum Format {

    /// "1 h 52 min", "48 min".
    static func runtime(minutes: Int) -> String? {
        guard minutes > 0 else { return nil }
        return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }

    /// "S2:E4", or "Special 3" for season 0.
    static func episodeCode(season: Int?, episode: Int?) -> String? {
        guard let season, let episode else { return nil }
        return season == 0 ? "Special \(episode)" : "S\(season):E\(episode)"
    }

    /// "23m left", "1h 12m left".
    static func timeLeft(position: Double, duration: Double?, watched: Bool) -> String? {
        guard let duration, duration > 0, !watched else { return nil }
        let minutes = max(1, Int(((duration - position) / 60).rounded()))
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m left" : "\(minutes)m left"
    }
}
