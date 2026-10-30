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
}

public struct RequestPage: Codable, Sendable {
    public let total: Int
    public let items: [MediaRequest]
}
