//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

/// A converted copy of a file that a device can download and keep. The
/// server makes it in the background, then serves it once behind a link.
public struct OfflineCopy: Codable, Hashable, Identifiable, Sendable {

    public enum Status: String, Codable, Hashable, Sendable {
        case queued
        case making
        case ready
        case failed
    }

    public let id: Int
    public let fileId: Int
    public let status: Status
    /// How far along making it is, from 0 to 1.
    public let progress: Double
    /// Why it failed, when it did.
    public let error: String?
    /// About how big it will be, worked out when it was asked for.
    public let estimatedBytes: Int
    /// How big it is, once ready.
    public let bytes: Int?
    public let createdAt: Int
    public let readyAt: Int?
    /// When the server deletes it; nil while it waits or is being made.
    public let deleteAt: Int?
    /// The subtitle tracks kept beside it.
    public let subtitles: [String]
}

/// What a copy of a file would take, and whether the server makes copies.
public struct OfflineChoices: Codable, Sendable {

    public struct Choice: Codable, Hashable, Sendable {
        public let maxHeight: Int
        public let estimatedBytes: Int
    }

    /// Off unless the server's admin turned offline copies on.
    public let on: Bool
    /// Each size up to the file's own, tallest first.
    public let choices: [Choice]
    /// The copies the viewer already has of the file.
    public let copies: [OfflineCopy]
}

/// What to make a copy with: the tallest picture, how it is encoded, the
/// sound, and up to ten text subtitle tracks to keep beside it.
public struct OfflineRequest: Codable, Sendable {
    public let maxHeight: Int
    /// `h264`, the server's default, or `hevc`, which keeps HDR10 and HLG.
    public let videoCodec: String?
    public let audioStream: Int?
    /// The most channels to keep; the server keeps no more than the file
    /// has, and makes stereo when this is left out.
    public let audioChannels: Int?
    public let subtitles: [String]

    public init(
        maxHeight: Int,
        videoCodec: String? = nil,
        audioStream: Int? = nil,
        audioChannels: Int? = nil,
        subtitles: [String] = []
    ) {
        self.maxHeight = maxHeight
        self.videoCodec = videoCodec
        self.audioStream = audioStream
        self.audioChannels = audioChannels
        self.subtitles = Array(subtitles.prefix(Self.subtitleLimit))
    }

    public static let subtitleLimit = 10
}

/// Where a ready copy and its subtitles download from: a day long, and the
/// link's own token is the credential, so no header is sent.
public struct OfflineLink: Codable, Sendable {

    public struct Subtitle: Codable, Hashable, Sendable {
        public let track: String
        public let url: String
    }

    /// The seek bar's previews to keep with a copy: the index, and each
    /// sheet in order under the link.
    public struct Previews: Codable, Hashable, Sendable {
        public let index: Trickplay
        public let sheetUrls: [String]
    }

    public let downloadUrl: String
    public let expiresAt: Int
    public let subtitles: [Subtitle]
    /// Nil when the file has none, has changed since the copy was made, or
    /// the server is older than the field.
    public let trickplay: Previews?
}
