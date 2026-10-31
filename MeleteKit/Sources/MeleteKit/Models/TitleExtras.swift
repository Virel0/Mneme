//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

public struct CastMember: Codable, Hashable, Sendable {
    public let personId: Int
    public let name: String
    public let character: String?
    /// Artwork path (w185).
    public let profile: String?
}

public struct CrewMember: Codable, Hashable, Sendable {
    public let personId: Int
    public let name: String
    public let job: String
    public let profile: String?
}

public struct CollectionRef: Codable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let poster: String?
}

public struct Credits: Codable, Hashable, Sendable {
    public let cast: [CastMember]
    public let crew: [CrewMember]
    /// The film series a movie belongs to; nil for a series or a film alone.
    public let collection: CollectionRef?
}

/// A bonus video in a title's folder: a trailer, a featurette. Plays through
/// the file routes by its id; no progress is kept for it.
public struct Extra: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    /// `trailer`, `featurette`, `behind_the_scenes`, `deleted_scene`,
    /// `interview`, `scene`, `short`, `clip` or `other`.
    public let kind: String
    public let title: String
    public let durationSeconds: Double?
}

public struct MovieCollection: Codable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let poster: String?
    public let backdrop: String?
    /// Whether every film of the collection is in the library.
    public let allFilms: Bool
    public let items: [DiscoverItem]
}

public struct Person: Codable, Hashable, Sendable {

    public struct Title: Codable, Hashable, Sendable {
        public let kind: TitleKind
        public let id: Int
        public let title: String
        public let year: Int?
        public let poster: String?
        public let characters: [String]
        public let jobs: [String]
    }

    public let id: Int
    public let name: String
    public let profile: String?
    /// Their titles in the library.
    public let titles: [Title]
}

/// Titles like one: the AI's picks when Melete has them on, else its own.
public struct SimilarTitles: Codable, Sendable {
    /// `ai`, or why these are Melete's own: `off`, `making`, `limited`,
    /// `busy`.
    public let status: String
    /// `ai` or `library`.
    public let source: String
    public let items: [AiPick]
}

/// A title chosen for the viewer: in the library, or to ask for.
public struct AiPick: Codable, Hashable, Sendable {
    public let kind: TitleKind
    /// The library's id; nil for a title to ask for.
    public let id: Int?
    public let tmdbId: Int?
    public let requestable: Bool
    public let title: String
    public let year: Int?
    public let poster: String?
    public let backdrop: String?
    /// Why, in a few words; text a model wrote, shown as plain text.
    public let reason: String?
}

public extension MeleteClient {

    func credits(_ kind: TitleKind, _ id: Int) async throws(MeleteError) -> Credits {
        try await send(Endpoint(.get, "api/v1/\(kind.pathComponent)/\(id)/credits"))
    }

    func similarTitles(_ kind: TitleKind, _ id: Int) async throws(MeleteError) -> SimilarTitles {
        try await send(Endpoint(.get, "api/v1/\(kind.pathComponent)/\(id)/similar"))
    }

    func extras(_ kind: TitleKind, _ id: Int) async throws(MeleteError) -> [Extra] {
        try await send(Endpoint(.get, "api/v1/\(kind.pathComponent)/\(id)/extras"))
    }

    func collection(_ id: Int) async throws(MeleteError) -> MovieCollection {
        try await send(Endpoint(.get, "api/v1/collections/\(id)"))
    }

    func person(_ id: Int) async throws(MeleteError) -> Person {
        try await send(Endpoint(.get, "api/v1/people/\(id)"))
    }

    /// TMDB's recommendations for a title, by its TMDB id, each marked by
    /// where it stands here. Refused (409) unless discovery is on.
    func similar(_ kind: TitleKind, tmdbId: Int) async throws(MeleteError) -> [DiscoverItem] {
        let chart = kind == .movie ? "movie" : "tv"
        return try await send(Endpoint(.get, "api/v1/discover/similar/tmdb:\(chart):\(tmdbId)"))
    }
}
