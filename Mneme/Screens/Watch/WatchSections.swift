//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit

/// The hero's picks and the rows of one Watch page, from the home.
///
/// The home is one answer for everything; Shows, Anime and Movies are that
/// answer narrowed to their kind, as Melete's web pages narrow it. A movie
/// is a movie, and a series is anime when the anime list has it.
struct WatchSections {

    struct Row: Identifiable {
        let key: WatchHomeRow.Key
        let title: String
        let items: [TitleSummary]

        var id: WatchHomeRow.Key {
            key
        }

        var shape: TileShape {
            key.isLandscape ? .landscape : .portrait
        }
    }

    let picks: [TitleSummary]
    let rows: [Row]

    /// As many picks as the home's hero has.
    private static let heroCount = 8

    init(home: WatchHome, kind: WatchKind, kindOf: (TitleRef) -> WatchKind) {
        guard kind != .home else {
            picks = home.hero.map(TitleSummary.init)
            rows = home.rows
                .filter { !$0.items.isEmpty }
                .map { Row(key: $0.key, title: $0.key.title, items: $0.items.map(TitleSummary.init)) }
            return
        }

        func mine(_ key: WatchHomeRow.Key) -> [TitleSummary] {
            (home.rows.first { $0.key == key }?.items ?? [])
                .map(TitleSummary.init)
                .filter { kindOf($0.ref) == kind }
        }

        let latest = kind.latestRow
        var seen: Set<TitleRef> = []
        picks = (home.hero.map(TitleSummary.init).filter { kindOf($0.ref) == kind } + mine(latest))
            .filter { seen.insert($0.ref).inserted }
            .prefix(Self.heroCount)
            .map(\.self)

        rows = [
            Row(key: .continueWatching, title: "Continue Watching", items: mine(.continueWatching)),
            Row(key: .nextUp, title: "Next Up", items: mine(.nextUp)),
            Row(key: .favourites, title: "On My List", items: mine(.favourites)),
            Row(key: latest, title: latest.title, items: mine(latest)),
        ]
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

extension WatchHomeRow.Key {

    var title: String {
        switch self {
        case .continueWatching: "Continue Watching"
        case .nextUp: "Next Up"
        case .favourites: "My List"
        case .latestShows: "Latest Shows"
        case .latestAnime: "Latest Anime"
        case .latestMovies: "Latest Movies"
        default: rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Rows of things to play now show wide tiles; rows of titles to open
    /// show posters.
    var isLandscape: Bool {
        self == .continueWatching || self == .nextUp
    }
}
