//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit

/// The hero's picks and the rows of one Watch page, from the home.
///
/// Shows, Anime and Movies each have their own home from Melete, its hero and
/// rows kept to their kind. Each is still narrowed here, for a server that
/// answers every page with the whole home: a movie is a movie, and a series
/// is anime when the anime list has it.
struct WatchSections {

    struct Row: Identifiable {
        let key: WatchHomeRow.Key
        let title: String
        let items: [TitleSummary]
        /// For Because You Watched, which comes once for each title it is
        /// like: that title.
        var seed: WatchHomeRow.Seed?

        var id: String {
            seed.map { "\(key.rawValue):\($0.kind.rawValue):\($0.id)" } ?? key.rawValue
        }

        var shape: TileShape {
            key.isLandscape ? .landscape : .portrait
        }
    }

    let picks: [TitleSummary]
    let rows: [Row]

    /// As many picks as the home's hero has.
    private static let heroCount = 8

    init(
        home: WatchHome,
        kind: WatchKind,
        kindOf: (TitleRef) -> WatchKind,
        becauseYouWatched: (title: String, items: [TitleSummary])? = nil
    ) {
        guard kind != .home else {
            picks = home.hero.map(TitleSummary.init)
            var rows = home.rows
                .filter { !$0.items.isEmpty }
                .map { Row(key: $0.key, title: $0.title, items: $0.items.map(TitleSummary.init), seed: $0.seed) }
            // Mneme's own, from a server that doesn't send any: after what is
            // being watched, before what is new.
            if let because = becauseYouWatched, !rows.contains(where: { $0.key == .becauseYouWatched }) {
                let after = rows.lastIndex { $0.key.isWatching }.map { $0 + 1 } ?? 0
                rows.insert(Row(key: .becauseYouWatched, title: "Because You Watched \(because.title)", items: because.items), at: after)
            }
            self.rows = rows
            return
        }

        func mine(_ key: WatchHomeRow.Key, in row: WatchHomeRow? = nil) -> [TitleSummary] {
            ((row ?? home.rows.first { $0.key == key })?.items ?? [])
                .map(TitleSummary.init)
                .filter { kindOf($0.ref) == kind }
        }

        let latest = kind.latestRow
        var seen: Set<TitleRef> = []
        picks = (home.hero.map(TitleSummary.init).filter { kindOf($0.ref) == kind } + mine(latest))
            .filter { seen.insert($0.ref).inserted }
            .prefix(Self.heroCount)
            .map(\.self)

        rows = home.rows
            // A Because You Watched row for a title of another kind holds
            // nothing of this one.
                .filter { row in row.seed.map { kindOf(TitleRef(kind: $0.kind, id: $0.id)) == kind } ?? true }
                .map { row in
                    Row(
                        key: row.key,
                        title: row.key == .favourites ? "On My List" : row.title,
                        items: mine(row.key, in: row),
                        seed: row.seed
                    )
                }
                .filter { !$0.items.isEmpty }
    }
}

extension WatchKind {

    var latestRow: WatchHomeRow.Key {
        switch self {
        case .home, .shows: .latestShows
        case .anime: .latestAnime
        case .movies: .latestMovies
        }
    }
}

extension WatchHomeRow {

    var title: String {
        if key == .becauseYouWatched, let seed {
            return "Because You Watched \(seed.title)"
        }
        return key.title
    }
}

extension WatchHomeRow.Key {

    /// Melete's, once for each finished title; Mneme makes its own for a
    /// server that doesn't send it.
    static let becauseYouWatched = WatchHomeRow.Key(rawValue: "because_you_watched")
    /// The AI's picks, when an admin has them on.
    static let featuredForYou = WatchHomeRow.Key(rawValue: "featured_for_you")

    var title: String {
        switch self {
        case .continueWatching: "Continue Watching"
        case .nextUp: "Next Up"
        case .favourites: "My List"
        case .latestShows: "Latest Shows"
        case .latestAnime: "Latest Anime"
        case .latestMovies: "Latest Movies"
        case .newEpisodes: "New Episodes"
        case .featuredForYou: "Featured for You"
        case .becauseYouWatched: "Because You Watched"
        case .nextInCollection: "Next in the Collection"
        case .highlyRated: "Highly Rated, Not Seen Yet"
        case .watchAgain: "Watch Again"
        default: rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Rows of things to play now show wide tiles; rows of titles to open
    /// show posters.
    var isLandscape: Bool {
        isWatching
    }

    /// The rows of what is being watched, each entry with the episode or
    /// point to play from. New Episodes holds shows taken out of Next Up.
    var isWatching: Bool {
        self == .continueWatching || self == .nextUp || self == .newEpisodes
    }
}

extension WatchKind {

    /// The page's own home from Melete; nil for the whole home.
    var homePage: HomePage? {
        switch self {
        case .home: nil
        case .shows: .shows
        case .anime: .anime
        case .movies: .movies
        }
    }
}
