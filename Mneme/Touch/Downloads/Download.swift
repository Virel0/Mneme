//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

#if os(iOS)
import Foundation
import MeleteKit

/// A film or an episode kept on this device: what it is, how far it has
/// come, and where the viewer is in it.
struct Download: Codable, Hashable, Identifiable, Sendable {

    enum Phase: Codable, Hashable, Sendable {
        /// The server is making the copy, this far along.
        case preparing(Double)
        /// The copy is coming to the device, this far along.
        case downloading(Double)
        case ready
        case failed(String)
    }

    /// The device's own name for it, which names its folder too.
    let id: UUID
    /// The signed-in session it was asked for under.
    let sessionID: String
    /// The server's copy, deleted there once the device has it.
    let copyID: Int
    let fileID: Int
    let title: TitleRef
    /// The movie's title, or the episode's name.
    let name: String
    /// The series an episode belongs to.
    let seriesName: String?
    let season: Int?
    let episode: Int?
    /// The poster, or the episode's still, as the server names it.
    let artwork: String?
    let maxHeight: Int
    let addedAt: Date
    /// The subtitle tracks kept beside the video, as the server lists them.
    let subtitles: [SubtitleTrack]
    /// The parts to skip, as the server marked them in the file; nil when
    /// unknown.
    let segments: FileSegments?

    var phase: Phase
    var estimatedBytes: Int
    var bytes: Int?
    /// Whether the copy is still on the server, to be deleted there.
    var serverCopyKept = true
    /// Where the viewer is, in seconds, and whether the server is yet to
    /// hear it.
    var position: Double = 0
    var duration: Double?
    var positionUnsent = false

    var isReady: Bool {
        phase == .ready
    }

    /// Plays it from the device.
    var playTarget: PlayTarget {
        PlayTarget(
            fileID: fileID,
            label: label,
            title: title,
            season: season,
            episode: episode,
            restarts: false,
            downloadID: id
        )
    }

    /// What the Downloads tab and the player call it: the movie, or
    /// "S1:E3 · Name".
    var label: String {
        guard title.kind == .series else { return name }
        let code = season.flatMap { season in episode.flatMap { Format.episodeCode(season: season, episode: $0) } }
        return [code, name == code ? nil : name].compactMap(\.self).joined(separator: " · ")
    }
}

extension TitleRef: Codable {

    private enum CodingKeys: String, CodingKey {
        case kind
        case id
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(kind: container.decode(TitleKind.self, forKey: .kind), id: container.decode(Int.self, forKey: .id))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(id, forKey: .id)
    }
}

/// What the page asking for a download knows about it.
struct DownloadSubject: Hashable, Sendable {
    let fileID: Int
    let title: TitleRef
    let name: String
    let seriesName: String?
    let season: Int?
    let episode: Int?
    let artwork: String?
}
#endif
