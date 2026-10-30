//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation
import MeleteKit
import Observation

/// What Search shows: before typing, the viewer's requests and what is
/// trending; while typing, titles in the library and on TMDB; on asking,
/// what the AI picked for a description.
@MainActor
@Observable
final class SearchModel {

    struct Results {
        var movies: [TitleSummary] = []
        var shows: [TitleSummary] = []
        /// From TMDB, and not playable here.
        var elsewhere: [DiscoverItem] = []
    }

    struct AiResults {
        let query: String
        let movies: [TitleSummary]
        let shows: [TitleSummary]
    }

    private let client: MeleteClient

    private(set) var results = Results()
    private(set) var isSearching = false
    private(set) var ai: AiResults?
    private(set) var isAsking = false
    private(set) var aiError: String?
    /// Whether the server has AI features on.
    private(set) var aiEnabled = false

    private(set) var requests: [MediaRequest] = []
    /// Nil until asked; empty when the server has discovery off.
    private(set) var trending: [DiscoverItem]?

    init(client: MeleteClient) {
        self.client = client
    }

    /// What does not depend on the query.
    func loadStart() async {
        async let ai = try? client.ai()
        async let requests = try? client.requests()
        async let trending = try? client.trending()

        aiEnabled = await ai?.enabled ?? false
        self.requests = await requests?.items ?? []
        // Refused unless discovery is on in Melete; then the row is left out.
        self.trending = await (trending ?? []).filter { $0.state != .playable }
    }

    /// Searches as the viewer types. Called with every change; waits out a
    /// beat so a word typed letter by letter is one search, not five.
    func search(_ query: String) async {
        let query = query.trimmingCharacters(in: .whitespaces)
        ai = nil
        aiError = nil
        guard !query.isEmpty else {
            results = Results()
            return
        }

        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }

        isSearching = true
        defer { isSearching = false }

        async let movies = try? client.movies(query: query, limit: 30)
        async let shows = try? client.series(query: query, limit: 30)
        async let elsewhere = try? client.discoverSearch(query)

        let found = await Results(
            movies: (movies?.items ?? []).map { TitleSummary($0, kind: .movie) },
            shows: (shows?.items ?? []).map { TitleSummary($0, kind: .series) },
            elsewhere: (elsewhere ?? []).filter { $0.state != .playable }
        )
        guard !Task.isCancelled else { return }
        results = found
    }

    /// Asks the AI for titles matching a description, movies and series
    /// both. Only the description leaves the server.
    func ask(_ query: String) async {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isAsking = true
        aiError = nil
        defer { isAsking = false }

        async let movies = client.aiSearch(query, kind: .movie)
        async let shows = client.aiSearch(query, kind: .series)
        do {
            let (movies, shows) = try await (movies, shows)
            ai = AiResults(
                query: query,
                movies: movies.results.map { TitleSummary($0, kind: .movie) },
                shows: shows.results.map { TitleSummary($0, kind: .series) }
            )
        } catch let error as MeleteError {
            aiError = if case .tooManyRequests = error {
                "That's the AI's limit for the hour. Try again later."
            } else {
                error.localizedDescription
            }
        } catch {
            aiError = error.localizedDescription
        }
    }

    /// Asks for a title; the answer replaces it wherever it is listed.
    func request(_ item: DiscoverItem) async throws(MeleteError) -> MediaRequest {
        let made = try await client.request(NewRequest(kind: item.kind, tmdbId: item.tmdbId))
        requests.insert(made, at: 0)
        return made
    }
}
