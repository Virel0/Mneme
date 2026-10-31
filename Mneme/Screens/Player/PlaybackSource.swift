//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import AVFoundation
import MeleteKit
import VideoToolbox

/// What the engine opens: the file itself, or Melete's conversion of it.
struct PlaybackSource {

    let url: URL
    /// An HLS conversion rather than the file. It carries one audio track
    /// and no subtitles of its own.
    let isConverted: Bool

    /// The audio formats the Apple TV plays itself. Anything else (TrueHD,
    /// DTS, PCM) has to be converted, on the Apple TV or by Melete.
    static let audioCodecs = ["aac", "ac3", "eac3", "flac", "alac"]

    /// The file as it is, unless it is over the bitrate allowed: the way in's
    /// limit (a connection from outside the house may have one, and Melete
    /// refuses a stream over it) or the one chosen in Settings. Over either,
    /// Melete converts it to fit. Within it, with the setting on, Melete
    /// converts a soundtrack the Apple TV can't play itself.
    @MainActor
    static func choose(for fileID: Int, play: PlayResponse, client: MeleteClient) async throws(MeleteError) -> PlaybackSource {
        guard let direct = client.url(for: play.streamUrl) else {
            throw .transport("Melete gave an address the player cannot open.")
        }
        let limit = [play.maxBitrate, PlaybackPreferences.maxBitrate].compactMap(\.self).min()
        let info = limit != nil || PlaybackPreferences.meleteConvertsAudio ? try? await client.fileInfo(fileID) : nil

        // A file whose bitrate is not known counts as over: Melete refuses
        // those through a limited way in too.
        let bitrate = info?.media?.bitRate
        guard let limit, bitrate.map({ $0 > limit }) ?? true else {
            if PlaybackPreferences.meleteConvertsAudio,
               let copied = await audioConverted(fileID: fileID, play: play, media: info?.media, client: client)
            {
                return copied
            }
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

    /// Melete's stream of the file with the video unchanged and only the
    /// audio converted, when the chosen soundtrack is one the Apple TV can't
    /// play itself: lossless stays lossless, and Dolby Vision is kept where
    /// the screen shows it. Nil to play the file as it is, including when
    /// Melete refuses the request, as a server from before the choice of
    /// formats does.
    @MainActor
    private static func audioConverted(fileID: Int, play: PlayResponse, media: MediaInfo?, client: MeleteClient) async -> PlaybackSource? {
        guard let streams = media?.audio, let track = streams.first(where: { $0.index == play.tracks?.audio }) ?? streams.first,
              !audioCodecs.contains(track.codec.lowercased())
        else { return nil }

        guard let converted = try? await client.transcode(file: fileID, TranscodeRequest(
            audioStream: track.index,
            audioChannels: 8,
            videoCodec: "copy",
            audioCodecs: audioCodecs,
            dolbyVision: AVPlayer.availableHDRModes.contains(.dolbyVision)
        )), let url = client.url(for: converted.playlistUrl) else { return nil }

        PlaybackDiagnostics.shared.record("play.converted", "file \(fileID) · \(track.codec) audio converted by Melete, video copied")
        return PlaybackSource(url: url, isConverted: true)
    }
}
