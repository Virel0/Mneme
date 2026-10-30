//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation
import MeleteKit
import VideoToolbox

/// What the engine opens: the file itself, or Melete's conversion of it.
struct PlaybackSource {

    let url: URL
    /// An HLS conversion rather than the file. It carries one audio track
    /// and no subtitles of its own.
    let isConverted: Bool

    /// The file as it is, unless it is over the bitrate allowed: the way in's
    /// limit (a connection from outside the house may have one, and Melete
    /// refuses a stream over it) or the one chosen in Settings. Over either,
    /// Melete converts it to fit.
    @MainActor
    static func choose(for fileID: Int, play: PlayResponse, client: MeleteClient) async throws(MeleteError) -> PlaybackSource {
        guard let direct = client.url(for: play.streamUrl) else {
            throw .transport("Melete gave an address the player cannot open.")
        }
        let limit = [play.maxBitrate, PlaybackPreferences.maxBitrate].compactMap(\.self).min()
        guard let limit else { return PlaybackSource(url: direct, isConverted: false) }

        // A file whose bitrate is not known counts as over: Melete refuses
        // those through a limited way in too.
        let bitrate = try? await client.fileInfo(fileID).media?.bitRate
        if let bitrate, bitrate <= limit {
            return PlaybackSource(url: direct, isConverted: false)
        }

        let converted = try await client.transcode(file: fileID, TranscodeRequest(
            maxBitrate: limit,
            audioStream: play.tracks?.audio,
            // HEVC keeps HDR; only where the Apple TV decodes it in hardware.
            videoCodec: VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC) ? "hevc" : "h264"
        ))
        guard let url = client.url(for: converted.playlistUrl) else {
            throw .transport("Melete gave an address the player cannot open.")
        }
        PlaybackDiagnostics.shared.record(
            "play.converted",
            "file \(fileID) · \(bitrate.map { "\($0 / 1_000_000) Mbps" } ?? "bitrate unknown") over the \(limit / 1_000_000) Mbps limit"
        )
        return PlaybackSource(url: url, isConverted: true)
    }
}
