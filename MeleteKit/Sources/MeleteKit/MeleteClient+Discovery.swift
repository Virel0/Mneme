//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

public extension MeleteClient {

    /// Whether AI features are on: only once an admin sets an OpenRouter key
    /// on the server.
    func ai() async throws(MeleteError) -> AiAbout {
        try await send(Endpoint(.get, "api/v1/ai"))
    }

    /// Titles found by describing them. Only the description leaves the
    /// server; 30 an hour each.
    func aiSearch(_ query: String, kind: TitleKind) async throws(MeleteError) -> AiSearch {
        try await send(Endpoint(
            .post,
            "api/v1/ai/search",
            json: AiSearchRequest(kind: kind == .movie ? "movies" : "series", query: query)
        ))
    }

    /// TMDB's first page of movies or series for the words, each marked
    /// playable, requested or requestable. Needs only a TMDB key on the
    /// server. Anime is among the series and movies: TMDB has no kind of its
    /// own for it.
    func discoverSearch(_ query: String, kind: TitleKind) async throws(MeleteError) -> [DiscoverItem] {
        try await send(Endpoint(.get, "api/v1/discover/search", query: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "kind", value: kind.rawValue),
        ]))
    }

    /// The movies or series trending on TMDB. Refused (409) unless the
    /// server has discovery turned on.
    func trending(kind: TitleKind) async throws(MeleteError) -> [DiscoverItem] {
        try await send(Endpoint(.get, "api/v1/discover/trending", query: [URLQueryItem(name: "kind", value: kind.rawValue)]))
    }

    func request(_ request: NewRequest) async throws(MeleteError) -> MediaRequest {
        try await send(Endpoint(.post, "api/v1/requests", json: request))
    }

    /// Takes back a request still waiting for a decision.
    func takeBack(request id: Int) async throws(MeleteError) {
        _ = try await send(Endpoint<NoContent>(.delete, "api/v1/requests/\(id)"))
    }

    /// Changes the season a waiting series request asks for; nil for all.
    func changeRequest(_ id: Int, season: Int?) async throws(MeleteError) -> MediaRequest {
        try await send(Endpoint(.put, "api/v1/requests/\(id)", json: RequestChange(season: season)))
    }

    /// The viewer's own requests, newest first.
    func requests(limit: Int = 50) async throws(MeleteError) -> RequestPage {
        try await send(Endpoint(.get, "api/v1/requests", query: [URLQueryItem(name: "limit", value: String(limit))]))
    }
}
