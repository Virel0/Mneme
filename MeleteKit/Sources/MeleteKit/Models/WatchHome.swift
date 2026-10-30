//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

/// The viewer's home in one request: the hero's picks over rows.
public struct WatchHome: Codable, Sendable {
    public let hero: [WatchHomeItem]
    public let rows: [WatchHomeRow]
}

public struct WatchHomeRow: Codable, Sendable, Identifiable {

    public let key: Key
    public let items: [WatchHomeItem]

    public var id: Key { key }

    /// Kept open rather than an enum, so a row a newer server adds is shown
    /// under its key instead of failing the whole home.
    public struct Key: RawRepresentable, Codable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let continueWatching = Key(rawValue: "continue_watching")
        public static let nextUp = Key(rawValue: "next_up")
        public static let favourites = Key(rawValue: "favourites")
        public static let latestShows = Key(rawValue: "latest_shows")
        public static let latestAnime = Key(rawValue: "latest_anime")
        public static let latestMovies = Key(rawValue: "latest_movies")
    }
}

public enum TitleKind: String, Codable, Hashable, Sendable {
    case movie
    case series
}

/// A point in a picture, from 0 to 1 on each axis: where its subject is, to
/// crop around.
public struct Focus: Codable, Hashable, Sendable {
    public let x: Double
    public let y: Double
}

public struct WatchHomeItem: Codable, Hashable, Sendable, Identifiable {

    public let kind: TitleKind
    /// The movie's or series' id; unique only within its kind.
    public let id: Int
    public let title: String
    public let year: Int?
    public let genres: [String]
    /// Movies only.
    public let runtimeMinutes: Int?
    public let overview: String?
    /// Artwork paths, relative to the server.
    public let poster: String?
    public let backdrop: String?
    public let backdropFocus: Focus?
    public let textlessBackdrop: String?
    public let textlessBackdropFocus: Focus?
    public let logo: String?
    public let addedAt: Int?
    /// Series only: episodes on disk not yet watched.
    public let unwatchedEpisodes: Int?
    /// The episode partway through, or the next one; null elsewhere.
    public let episode: Episode?
    public let progress: Progress?

    public struct Episode: Codable, Hashable, Sendable {
        public let fileId: Int
        public let season: Int?
        public let episode: Int?
        public let name: String?
        public let still: String?
    }

    public struct Progress: Codable, Hashable, Sendable {
        public let fileId: Int
        public let positionSeconds: Double
        public let durationSeconds: Double?
        public let watched: Bool
        public let updatedAt: Int
    }
}

public extension MeleteClient {

    func home() async throws(MeleteError) -> WatchHome {
        try await send(Endpoint(.get, "api/v1/home"))
    }
}
