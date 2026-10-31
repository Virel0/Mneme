//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

public struct VideoStream: Codable, Hashable, Sendable {
    public let index: Int
    public let codec: String
    public let profile: String?
    public let width: Int?
    public let height: Int?
    public let pixelFormat: String?
    public let frameRate: Double?
    /// `Dolby Vision`, `HDR10`, `HLG`, or nil for SDR.
    public let hdr: String?
}

public struct AudioStream: Codable, Hashable, Sendable {
    public let index: Int
    public let codec: String
    public let profile: String?
    public let channels: Int?
    public let channelLayout: String?
    public let language: String?
    public let title: String?
    public let `default`: Bool
}

public struct MediaInfo: Codable, Hashable, Sendable {
    /// ffprobe's format name, e.g. `matroska,webm`.
    public let container: String?
    public let durationSeconds: Double?
    /// Bits per second, the whole file.
    public let bitRate: Int?
    public let video: [VideoStream]
    public let audio: [AudioStream]
}

public struct Chapter: Codable, Hashable, Sendable {
    public let startSeconds: Double
    public let endSeconds: Double
    public let title: String?
}

/// A file and what is in it.
public struct FileInfo: Codable, Hashable, Sendable {
    public let id: Int
    public let path: String
    public let size: Int
    /// Nil when the file could not be read as a video.
    public let media: MediaInfo?
    /// The most bits per second a video may take on this way in, or nil.
    public let maxBitrate: Int?
    public let chapters: [Chapter]
    /// Whether Melete brought the file in from a download and it is unchanged
    /// since. Nil from a server older than the field.
    public let imported: Bool?
}

public struct TranscodeRequest: Codable, Sendable {
    /// Scale down to this height; never up.
    public let maxHeight: Int?
    /// Video bits per second.
    public let maxBitrate: Int?
    /// An index from the file's audio streams.
    public let audioStream: Int?
    /// `h264` (plays everywhere, HDR tone-mapped), `hevc` (keeps HDR), or
    /// `copy`.
    public let videoCodec: String?

    public init(maxHeight: Int? = nil, maxBitrate: Int? = nil, audioStream: Int? = nil, videoCodec: String? = nil) {
        self.maxHeight = maxHeight
        self.maxBitrate = maxBitrate
        self.audioStream = audioStream
        self.videoCodec = videoCodec
    }
}

public struct TranscodeResponse: Codable, Sendable {
    /// An HLS playlist of the whole file; carries its own token.
    public let playlistUrl: String
    public let expiresAt: Int
    public let durationSeconds: Double?
    public let resumeSeconds: Double
    public let watched: Bool
    public let segments: FileSegments
    public let maxBitrate: Int?
}

public struct Languages: Codable, Hashable, Sendable {
    /// Most wanted first.
    public var audioLanguages: [String]
    /// Most wanted first. Audio in one of these counts as understood.
    public var subtitleLanguages: [String]
    /// `off`, `forced`, `foreign` or `always`.
    public var subtitleMode: String

    public init(audioLanguages: [String], subtitleLanguages: [String], subtitleMode: String) {
        self.audioLanguages = audioLanguages
        self.subtitleLanguages = subtitleLanguages
        self.subtitleMode = subtitleMode
    }
}

public struct QuickConnectApproveRequest: Codable, Sendable {
    public let code: String
}

public struct QuickConnectLookup: Codable, Sendable {
    public let deviceName: String
    public let address: String
    public let ageSeconds: Int
    public let expiresIn: Int
}

public struct QuickConnectApproved: Codable, Sendable {
    public let deviceName: String
}

public extension MeleteClient {

    /// What is in a file. Probes it on the spot if Melete has not yet.
    func fileInfo(_ id: Int) async throws(MeleteError) -> FileInfo {
        try await send(Endpoint(.get, "api/v1/files/\(id)"))
    }

    /// An HLS playlist of the file converted for this device, for when it
    /// cannot be played as it is, or is over the way in's limit.
    func transcode(file id: Int, _ request: TranscodeRequest) async throws(MeleteError) -> TranscodeResponse {
        try await send(Endpoint(.post, "api/v1/files/\(id)/transcode", json: request))
    }

    func languages() async throws(MeleteError) -> Languages {
        try await send(Endpoint(.get, "api/v1/me/languages"))
    }

    func setLanguages(_ languages: Languages) async throws(MeleteError) -> Languages {
        try await send(Endpoint(.put, "api/v1/me/languages", json: languages))
    }

    /// Which device a Quick Connect code belongs to, before approving it.
    func lookUpQuickConnect(code: String) async throws(MeleteError) -> QuickConnectLookup {
        try await send(Endpoint(.post, "api/v1/auth/quick-connect/lookup", json: QuickConnectApproveRequest(code: code)))
    }

    /// Signs the device showing the code in as this user.
    func approveQuickConnect(code: String) async throws(MeleteError) -> QuickConnectApproved {
        try await send(Endpoint(.post, "api/v1/auth/quick-connect/approve", json: QuickConnectApproveRequest(code: code)))
    }
}
