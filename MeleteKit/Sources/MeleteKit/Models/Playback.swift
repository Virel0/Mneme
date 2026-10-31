//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

/// A stretch of a file worth skipping, or the start of its credits.
public struct Segment: Codable, Hashable, Sendable {
    public let startSeconds: Double
    public let endSeconds: Double
    /// How it was found: `chapter`, `audio` or `ending`.
    public let source: String
}

public struct FileSegments: Codable, Hashable, Sendable {
    /// Whether the file as it is now has been looked at.
    public let scanned: Bool
    public let intro: Segment?
    public let credits: Segment?
    public let recap: Segment?
    public let preview: Segment?
}

/// The tracks Melete chose for this viewer and this file.
public struct TrackPick: Codable, Hashable, Sendable {
    /// The audio stream's index in the file; nil for a file without audio.
    public let audio: Int?
    public let audioReason: String
    /// The track as the subtitle list names it (`s3`, `x1a2b3c4d`); nil for
    /// none.
    public let subtitle: String?
    public let subtitleReason: String
}

public struct PlayResponse: Codable, Hashable, Sendable {
    /// Hand to the player as it is: it carries its own token for this file,
    /// for 24 hours.
    public let streamUrl: String
    public let expiresAt: Int
    /// Where to start; 0 for the beginning.
    public let resumeSeconds: Double
    public let durationSeconds: Double?
    public let watched: Bool
    public let segments: FileSegments
    /// The most bits per second a stream may take on this way in, or nil.
    public let maxBitrate: Int?
    /// Nil until the file has been probed as it is now.
    public let tracks: TrackPick?
}

public struct ProgressReport: Codable, Sendable {
    public let positionSeconds: Double
    public let durationSeconds: Double?
    /// The viewer chose to start over, so a position near the start replaces
    /// a later saved one.
    public let restart: Bool

    public init(positionSeconds: Double, durationSeconds: Double?, restart: Bool) {
        self.positionSeconds = positionSeconds
        self.durationSeconds = durationSeconds
        self.restart = restart
    }
}

public struct SubtitleTrack: Codable, Hashable, Sendable, Identifiable {
    /// `s{index}` for an embedded stream, `x` and 8 hex digits for a file
    /// beside the video, `o` and 8 hex digits for one fetched from
    /// OpenSubtitles.
    public let track: String
    /// `embedded`, `external` or `opensubtitles`.
    public let source: String
    public let codec: String
    public let language: String?
    public let title: String?
    public let `default`: Bool
    public let forced: Bool
    public let hearingImpaired: Bool
    /// Only text tracks can be fetched as WebVTT.
    public let text: Bool
    public let file: String?
    public let encoding: String?

    public var id: String {
        track
    }

    /// The stream index of an embedded track.
    public var embeddedIndex: Int? {
        guard track.hasPrefix("s") else { return nil }
        return Int(track.dropFirst())
    }
}

public struct TrackChoice: Codable, Sendable {

    public struct Subtitle: Codable, Sendable {
        public let language: String?
        public let forced: Bool
        public let hearingImpaired: Bool

        public init(language: String?, forced: Bool, hearingImpaired: Bool) {
            self.language = language
            self.forced = forced
            self.hearingImpaired = hearingImpaired
        }
    }

    public let audioLanguage: String?
    /// Nil when subtitles were turned off.
    public let subtitle: Subtitle?

    public init(audioLanguage: String?, subtitle: Subtitle?) {
        self.audioLanguage = audioLanguage
        self.subtitle = subtitle
    }

    // Both keys are required by the contract, null included, so they are
    // always written.
    enum CodingKeys: String, CodingKey {
        case audioLanguage
        case subtitle
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(audioLanguage, forKey: .audioLanguage)
        try container.encode(subtitle, forKey: .subtitle)
    }
}

public struct Trickplay: Codable, Hashable, Sendable {
    /// Each picture's size in pixels.
    public let width: Int
    public let height: Int
    /// Pictures across and down one sheet.
    public let columns: Int
    public let rows: Int
    public let sheets: Int
    /// Each picture's time in seconds, in order.
    public let times: [Double]
}

public struct DiagnosticsReport: Codable, Sendable {
    public let app: String
    public let appVersion: String?
    public let platform: String?
    /// `info`, `warning` or `error`.
    public let level: String
    /// What happened, in a line.
    public let summary: String
    public let details: [String: [String]]

    public init(app: String, appVersion: String?, platform: String?, level: String, summary: String, details: [String: [String]]) {
        self.app = app
        self.appVersion = appVersion
        self.platform = platform
        self.level = level
        self.summary = summary
        self.details = details
    }
}

public struct DiagnosticsKept: Codable, Sendable {
    public let id: Int
}

/// The viewer's playback choices, kept by Melete for every device they use.
public struct PlaybackSettings: Codable, Sendable {
    public let autoplayNext: Bool
    public let countdownSeconds: Int
    public let heroTrailers: HeroTrailers

    /// Where the home's hero plays its picks' trailers. Kept open, so a
    /// choice a newer server adds does not fail the request.
    public struct HeroTrailers: RawRepresentable, Codable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let off = HeroTrailers(rawValue: "off")
        public static let largeScreens = HeroTrailers(rawValue: "large_screens")
        public static let everywhere = HeroTrailers(rawValue: "everywhere")
    }
}
