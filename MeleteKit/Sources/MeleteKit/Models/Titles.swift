//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

/// A video file of a movie or an episode.
public struct MediaFile: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let path: String
    public let size: Int
    public let modifiedAt: Int
}

public struct MovieDetail: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let library: String
    public let title: String
    public let originalTitle: String?
    public let year: Int?
    public let overview: String?
    public let runtimeMinutes: Int?
    public let genres: [String]
    public let tmdbId: Int?
    public let imdbId: String?
    public let poster: String?
    public let backdrop: String?
    public let textlessBackdrop: String?
    public let logo: String?
    public let backdropFocus: Focus?
    public let textlessBackdropFocus: Focus?
    /// `matched`, `unmatched`, `ambiguous`, or nil until matching has run.
    public let matchStatus: String?
    public let files: [MediaFile]
}

public struct SeriesDetail: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let library: String
    public let title: String
    public let originalTitle: String?
    public let year: Int?
    public let overview: String?
    public let status: String?
    public let genres: [String]
    public let tmdbId: Int?
    public let tvdbId: Int?
    public let imdbId: String?
    public let poster: String?
    public let backdrop: String?
    public let textlessBackdrop: String?
    public let logo: String?
    public let backdropFocus: Focus?
    public let textlessBackdropFocus: Focus?
    public let matchStatus: String?
    public let seasons: [SeasonSummary]
    /// Files in the series' folder whose season and episode could not be read.
    public let unparsedFiles: [MediaFile]
}

public struct SeasonSummary: Codable, Hashable, Sendable, Identifiable {
    /// 0 is Specials.
    public let season: Int
    public let episodes: Int
    /// Episodes with a file on disk.
    public let available: Int

    public var id: Int {
        season
    }
}

public struct Season: Codable, Hashable, Sendable {
    public let season: Int
    public let episodes: [Episode]
}

public struct Episode: Codable, Hashable, Sendable, Identifiable {
    public let episode: Int
    public let name: String?
    public let overview: String?
    public let airDate: String?
    public let runtimeMinutes: Int?
    public let still: String?
    public let files: [MediaFile]

    public var id: Int {
        episode
    }
}

public struct TitleArtwork: Codable, Hashable, Sendable {
    public let poster: String?
    public let backdrop: String?
    public let backdropFocus: Focus?
    public let textlessBackdrop: String?
    public let textlessBackdropFocus: Focus?
    public let logo: String?
}

/// One title in a movie or series list.
public struct ListItem: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let title: String
    public let year: Int?
    public let poster: String?
    public let matched: Bool
    public let addedAt: Int?
    public let unwatchedEpisodes: Int?
}

public struct Page<Item: Codable & Hashable & Sendable>: Codable, Hashable, Sendable {
    public let total: Int
    public let items: [Item]
}

public struct Genre: Codable, Hashable, Sendable {
    public let name: String
    public let movies: Int
    public let series: Int
}

public struct ProgressEntry: Codable, Hashable, Sendable {
    public let fileId: Int
    public let positionSeconds: Double
    public let durationSeconds: Double?
    public let watched: Bool
    public let playCount: Int
    public let updatedAt: Int
}

public struct Progress: Codable, Hashable, Sendable {
    /// 0 once watched, so the next play starts over.
    public let positionSeconds: Double
    public let durationSeconds: Double?
    public let watched: Bool
    public let playCount: Int
}

public struct WatchedRequest: Codable, Sendable {
    public let watched: Bool
}

public struct SeriesWatchedRequest: Codable, Sendable {
    public let watched: Bool
    /// Only this season (0 for Specials); nil for the whole series.
    public let season: Int?
}

public struct SeriesWatched: Codable, Sendable {
    /// How many files this changed.
    public let changed: Int
}

public struct Favourite: Codable, Hashable, Sendable {
    public let kind: TitleKind
    public let id: Int
    public let addedAt: Int
    public let title: String
    public let year: Int?
    public let poster: String?
    public let matched: Bool
    /// Whether the title is in the library now.
    public let present: Bool
}

public struct FavouriteList: Codable, Hashable, Sendable {
    public let total: Int
    public let version: Int
    public let items: [Favourite]
}

public struct FavouriteState: Codable, Hashable, Sendable {
    public let favourite: Bool
    public let addedAt: Int?
}
