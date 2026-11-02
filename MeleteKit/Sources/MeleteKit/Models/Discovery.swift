//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

public struct AiAbout: Codable, Sendable {
    /// On once an admin sets an OpenRouter key.
    public let enabled: Bool
}

public struct AiSearchRequest: Codable, Sendable {
    /// `movies` or `series`.
    public let kind: String
    /// What someone is in the mood for, in their own words.
    public let query: String
}

public struct AiSuggestion: Codable, Hashable, Sendable {
    public let title: String
    public let year: Int?
    /// The movie or series here, if it is.
    public let id: Int?
}

public struct AiSearch: Codable, Sendable {
    /// The suggestions in the library, best fit first.
    public let results: [ListItem]
    /// Every suggestion, here or not.
    public let suggested: [AiSuggestion]
}

/// A title from TMDB, marked by where it stands here.
public struct DiscoverItem: Codable, Hashable, Sendable, Identifiable {

    public enum State: String, Codable, Sendable {
        case playable
        case requested
        case requestable
    }

    /// `tmdb:movie:603`, `tmdb:tv:1399`.
    public let id: String
    public let kind: TitleKind
    public let tmdbId: Int
    public let title: String
    public let year: Int?
    public let overview: String?
    public let poster: String?
    public let state: State
    /// The title's id here, when it is playable.
    public let libraryId: Int?
    /// The viewer's own open request for it.
    public let requestId: Int?
}

public struct NewRequest: Codable, Sendable {
    /// `movie` or `series`.
    public let kind: String
    public let tmdbId: Int
    /// One season of a series; nil for all of it.
    public let season: Int?

    public init(kind: TitleKind, tmdbId: Int, season: Int? = nil) {
        self.kind = kind.rawValue
        self.tmdbId = tmdbId
        self.season = season
    }
}

/// How an approved request is getting on.
public struct WantedProgress: Codable, Hashable, Sendable {
    /// `wanted`, `searching`, `downloading`, `transferring`, `importing`,
    /// `in_library` or `failed`.
    public let step: String
    /// How much is downloaded, while downloading.
    public let percent: Double?
    /// The latest word on it, in plain words.
    public let message: String?
    /// While it is being copied home: how far that has got. Nil otherwise,
    /// and from a server older than the field.
    public let copied: Copying?
    /// Where it is coming from: `torrent` or `soulseek`.
    public let source: String?
    /// When the download last changed, in Unix seconds; nil for a step
    /// worked out from the library.
    public let updatedAt: Int?

    public struct Copying: Codable, Hashable, Sendable {
        public let bytes: Int
        public let total: Int
        public let bytesPerSecond: Int?
        public let secondsLeft: Int?
    }
}

public struct MediaRequest: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    /// `movie`, `series`, `artist`, `album` or `song`.
    public let kind: String
    public let tmdbId: Int?
    public let season: Int?
    public let title: String
    public let year: Int?
    public let poster: String?
    /// `requested`, `approved` or `declined`.
    public let state: String
    /// Why it was declined.
    public let reason: String?
    public let createdAt: Int
    public let progress: WantedProgress?
    /// Who asked.
    public let username: String?
    /// For music: the artist.
    public let artist: String?
    /// When it was approved or declined, in Unix seconds.
    public let decidedAt: Int?
    /// Who decided; nil when it was approved as it was made.
    public let decidedBy: String?
    /// For an approved series: each of its seasons and how it is getting on.
    public let seasons: [RequestSeason]?
}

/// A season of an approved series request.
public struct RequestSeason: Codable, Hashable, Sendable {
    /// 0 is specials.
    public let season: Int
    /// Whether it is looked for, whoever asked for it.
    public let monitored: Bool
    /// Episodes TMDB lists that have aired; nil when not known.
    public let episodes: Int?
    /// Episodes in the library.
    public let inLibrary: Int
    /// The same steps as a request's progress.
    public let step: String
    public let percent: Double?
}

/// The season a waiting series request asks for: one, or nil for all of it.
public struct RequestChange: Codable, Sendable {
    public let season: Int?

    public init(season: Int?) {
        self.season = season
    }

    /// Nil is sent as null: Melete needs the key either way.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(season, forKey: .season)
    }
}

public struct RequestPage: Codable, Sendable {
    public let total: Int
    public let items: [MediaRequest]
}
