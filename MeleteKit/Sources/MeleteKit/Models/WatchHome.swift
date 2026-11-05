//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
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
    /// For Because You Watched: the finished title the row's titles are
    /// like. Nil on every other row, and from a server older than the field.
    public let seed: Seed?

    public var id: Key {
        key
    }

    public struct Seed: Codable, Hashable, Sendable {
        public let kind: TitleKind
        public let id: Int
        public let title: String
    }

    /// Kept open rather than an enum, so a row a newer server adds is shown
    /// under its key instead of failing the whole home.
    public struct Key: RawRepresentable, Codable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let continueWatching = Key(rawValue: "continue_watching")
        public static let nextUp = Key(rawValue: "next_up")
        /// Shows from Next Up whose next episode came in lately; each is in
        /// this row instead of Next Up, with the episode to play.
        public static let newEpisodes = Key(rawValue: "new_episodes")
        public static let favourites = Key(rawValue: "favourites")
        public static let latestShows = Key(rawValue: "latest_shows")
        public static let latestAnime = Key(rawValue: "latest_anime")
        public static let latestMovies = Key(rawValue: "latest_movies")
        public static let nextInCollection = Key(rawValue: "next_in_collection")
        public static let highlyRated = Key(rawValue: "highly_rated")
        public static let watchAgain = Key(rawValue: "watch_again")
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
    /// On the hero's picks only: a trailer to play muted. Nil when there is
    /// none, and from a server older than the field.
    public let trailer: Trailer?
    /// On the hero's picks only: a clip of the title itself, for when there
    /// is no trailer. Nil when the title has no file, and from a server older
    /// than the field.
    public let clip: Clip?

    public struct Trailer: Codable, Hashable, Sendable {
        public let source: Source
        /// The trailer's file. Optional for servers before 0.5, whose online
        /// trailers had none.
        public let fileId: Int?

        /// The file to play, for the sources this app knows; a source it
        /// doesn't know counts as no trailer, as Melete asks.
        public var playableFile: Int? {
            [Source.folder, .downloaded].contains(source) ? fileId : nil
        }

        /// Kept open like row keys, so a source a newer server adds does not
        /// fail the whole home.
        public struct Source: RawRepresentable, Codable, Hashable, Sendable {
            public let rawValue: String
            public init(rawValue: String) {
                self.rawValue = rawValue
            }

            /// A trailer in the title's folder.
            public static let folder = Source(rawValue: "folder")
            /// One Melete downloaded for the title.
            public static let downloaded = Source(rawValue: "downloaded")
        }
    }

    /// Where in which file a clip of the title starts, and for how long.
    public struct Clip: Codable, Hashable, Sendable {
        public let fileId: Int
        /// Where the viewer left the file, else an eighth of the way in.
        public let startSeconds: Double
        public let durationSeconds: Double
    }

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

/// One Watch page's home, as `/home?kind=` gives it.
public enum HomePage: String, Sendable {
    case movies
    case shows
    case anime
}

public extension MeleteClient {

    /// The whole home, or with `page`, one Watch page's: its hero and every
    /// row kept to that kind. A server older than `kind` ignores it and
    /// answers with the whole home.
    func home(page: HomePage? = nil) async throws(MeleteError) -> WatchHome {
        let query = page.map { [URLQueryItem(name: "kind", value: $0.rawValue)] } ?? []
        return try await send(Endpoint(.get, "api/v1/home", query: query))
    }
}
