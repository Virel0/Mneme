//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

public enum ListSort: String, Sendable {
    case title
    case year
    case recent
}

public enum AnimeFilter: String, Sendable {
    /// Anime alone.
    case only
    /// Everything but anime, as Watch's Shows lists it.
    case exclude
}

public extension MeleteClient {

    func movies(
        query: String? = nil,
        genre: String? = nil,
        sort: ListSort = .title,
        limit: Int = 100,
        offset: Int = 0
    ) async throws(MeleteError) -> Page<ListItem> {
        try await send(Endpoint(.get, "api/v1/movies", query: listQuery(query, genre, sort, limit, offset)))
    }

    func series(
        query: String? = nil,
        genre: String? = nil,
        anime: AnimeFilter? = nil,
        sort: ListSort = .title,
        limit: Int = 100,
        offset: Int = 0
    ) async throws(MeleteError) -> Page<ListItem> {
        var items = listQuery(query, genre, sort, limit, offset)
        if let anime {
            items.append(URLQueryItem(name: "anime", value: anime.rawValue))
        }
        return try await send(Endpoint(.get, "api/v1/series", query: items))
    }

    /// Every anime series' id, which is what sorts a series into Anime rather
    /// than Shows. Paged through at the most the server gives at once.
    func animeSeriesIDs() async throws(MeleteError) -> Set<Int> {
        var ids: Set<Int> = []
        var offset = 0
        while true {
            let page = try await series(anime: .only, limit: 500, offset: offset)
            ids.formUnion(page.items.map(\.id))
            offset += 500
            if offset >= page.total || page.items.isEmpty {
                return ids
            }
        }
    }

    func movie(_ id: Int) async throws(MeleteError) -> MovieDetail {
        try await send(Endpoint(.get, "api/v1/movies/\(id)"))
    }

    func series(_ id: Int) async throws(MeleteError) -> SeriesDetail {
        try await send(Endpoint(.get, "api/v1/series/\(id)"))
    }

    func season(_ season: Int, ofSeries id: Int) async throws(MeleteError) -> Season {
        try await send(Endpoint(.get, "api/v1/series/\(id)/seasons/\(season)"))
    }

    func artwork(_ kind: TitleKind, _ id: Int) async throws(MeleteError) -> TitleArtwork {
        try await send(Endpoint(.get, "api/v1/\(kind.pathComponent)/\(id)/artwork"))
    }

    func genres() async throws(MeleteError) -> [Genre] {
        try await send(Endpoint(.get, "api/v1/browse/genres"))
    }

    /// Progress on each file of one title.
    func progress(_ kind: TitleKind, _ id: Int) async throws(MeleteError) -> [ProgressEntry] {
        let name = kind == .movie ? "movie_id" : "series_id"
        return try await send(Endpoint(.get, "api/v1/me/progress", query: [URLQueryItem(name: name, value: String(id))]))
    }

    func setWatched(file id: Int, _ watched: Bool) async throws(MeleteError) -> Progress {
        try await send(Endpoint(.put, "api/v1/files/\(id)/watched", json: WatchedRequest(watched: watched)))
    }

    func setWatched(series id: Int, season: Int? = nil, _ watched: Bool) async throws(MeleteError) -> SeriesWatched {
        try await send(Endpoint(
            .put,
            "api/v1/series/\(id)/watched",
            json: SeriesWatchedRequest(watched: watched, season: season)
        ))
    }

    func favourites(kind: TitleKind? = nil, limit: Int = 100, offset: Int = 0) async throws(MeleteError) -> FavouriteList {
        var query = [URLQueryItem(name: "limit", value: String(limit)), URLQueryItem(name: "offset", value: String(offset))]
        if let kind {
            query.append(URLQueryItem(name: "kind", value: kind.rawValue))
        }
        return try await send(Endpoint(.get, "api/v1/me/favourites", query: query))
    }

    func favourite(_ kind: TitleKind, _ id: Int) async throws(MeleteError) -> FavouriteState {
        try await send(Endpoint(.get, "api/v1/me/favourites/\(kind.pathComponent)/\(id)"))
    }

    func setFavourite(_ kind: TitleKind, _ id: Int, _ isFavourite: Bool) async throws(MeleteError) -> FavouriteState {
        try await send(Endpoint(isFavourite ? .put : .delete, "api/v1/me/favourites/\(kind.pathComponent)/\(id)"))
    }

    private func listQuery(_ query: String?, _ genre: String?, _ sort: ListSort, _ limit: Int, _ offset: Int) -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "sort", value: sort.rawValue),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        if let query, query.isEmpty == false {
            items.append(URLQueryItem(name: "q", value: query))
        }
        if let genre {
            items.append(URLQueryItem(name: "genre", value: genre))
        }
        return items
    }
}

public extension TitleKind {
    /// The kind's collection in the API's paths: `movies`, `series`.
    var pathComponent: String {
        switch self {
        case .movie: "movies"
        case .series: "series"
        }
    }
}
