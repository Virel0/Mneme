//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
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
    /// HEVC whose parameter sets are only in the stream: Melete refuses to
    /// copy its video into a stream, as Apple's players may refuse the
    /// result. Nil from a server older than the field.
    public let parameterSetsInStreamOnly: Bool?
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
    /// The parts to skip, as the play link gives them. Nil from a server
    /// older than the field.
    public let segments: FileSegments?
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
    /// Channels to keep; Melete's default is two.
    public let audioChannels: Int?
    /// `h264` (plays everywhere, HDR tone-mapped), `hevc` (keeps HDR), or
    /// `copy`: the video unchanged, only the audio converted.
    public let videoCodec: String?
    /// With `copy`: the audio formats the player takes, so audio already in
    /// one is copied and lossless audio stays lossless (FLAC or ALAC).
    public let audioCodecs: [String]?
    /// With `copy`: whether the player shows Dolby Vision, so the file's is
    /// kept rather than labelled HDR10.
    public let dolbyVision: Bool?
    /// A subtitle track to draw into the picture: how a picture track (PGS,
    /// VobSub) shows in a conversion, which carries no subtitles of its own.
    public let burnSubtitle: String?
    /// The subtitle track the viewer chose, if any. With `rendersAss` false,
    /// a styled ASS/SSA track is drawn into the picture.
    public let subtitle: String?
    /// Whether the player draws ASS/SSA itself, from the track's `assUrl`.
    public let rendersAss: Bool?

    public init(
        maxHeight: Int? = nil,
        maxBitrate: Int? = nil,
        audioStream: Int? = nil,
        audioChannels: Int? = nil,
        videoCodec: String? = nil,
        audioCodecs: [String]? = nil,
        dolbyVision: Bool? = nil,
        burnSubtitle: String? = nil,
        subtitle: String? = nil,
        rendersAss: Bool? = nil
    ) {
        self.maxHeight = maxHeight
        self.maxBitrate = maxBitrate
        self.audioStream = audioStream
        self.audioChannels = audioChannels
        self.videoCodec = videoCodec
        self.audioCodecs = audioCodecs
        self.dolbyVision = dolbyVision
        self.burnSubtitle = burnSubtitle
        self.subtitle = subtitle
        self.rendersAss = rendersAss
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
    /// The subtitle track drawn into the picture, not to be shown again.
    /// Nil for none, and from a server older than the field.
    public let burnedSubtitle: String?
    /// Why a subtitle is or isn't drawn in: `asked`, `styled_ass`,
    /// `copy_kept`, or nil.
    public let burnReason: String?
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

/// The languages one kind of title plays with: its own, or the viewer's,
/// which it then follows.
public struct KindLanguages: Codable, Hashable, Sendable {

    public enum Kind: String, Codable, CaseIterable, Sendable {
        case movies
        case shows
        /// A series wanted as anime, or in a library for anime.
        case anime
    }

    public let kind: Kind
    /// Whether these are the kind's own; false when it follows the
    /// viewer's languages, which these then are.
    public let own: Bool
    public let audioLanguages: [String]
    public let subtitleLanguages: [String]
    public let subtitleMode: String

    public var languages: Languages {
        Languages(audioLanguages: audioLanguages, subtitleLanguages: subtitleLanguages, subtitleMode: subtitleMode)
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

    /// What one kind of title plays with. Not found from a server older
    /// than languages by kind.
    func languages(for kind: KindLanguages.Kind) async throws(MeleteError) -> KindLanguages {
        try await send(Endpoint(.get, "api/v1/me/languages/\(kind.rawValue)"))
    }

    /// Gives the kind languages of its own.
    func setLanguages(_ languages: Languages, for kind: KindLanguages.Kind) async throws(MeleteError) -> KindLanguages {
        try await send(Endpoint(.put, "api/v1/me/languages/\(kind.rawValue)", json: languages))
    }

    /// Drops the kind's own languages: it follows the viewer's again.
    func followLanguages(for kind: KindLanguages.Kind) async throws(MeleteError) -> KindLanguages {
        try await send(Endpoint(.delete, "api/v1/me/languages/\(kind.rawValue)"))
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
