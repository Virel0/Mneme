//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
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

    /// TMDB's first page for the words, each marked playable, requested or
    /// requestable. Needs only a TMDB key on the server.
    func discoverSearch(_ query: String) async throws(MeleteError) -> [DiscoverItem] {
        try await send(Endpoint(.get, "api/v1/discover/search", query: [URLQueryItem(name: "q", value: query)]))
    }

    /// What is trending on TMDB. Refused (409) unless the server has
    /// discovery turned on.
    func trending() async throws(MeleteError) -> [DiscoverItem] {
        try await send(Endpoint(.get, "api/v1/discover/trending"))
    }

    func request(_ request: NewRequest) async throws(MeleteError) -> MediaRequest {
        try await send(Endpoint(.post, "api/v1/requests", json: request))
    }

    /// The viewer's own requests, newest first.
    func requests(limit: Int = 50) async throws(MeleteError) -> RequestPage {
        try await send(Endpoint(.get, "api/v1/requests", query: [URLQueryItem(name: "limit", value: String(limit))]))
    }
}
