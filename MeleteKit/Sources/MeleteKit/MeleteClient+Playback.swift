//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

public extension MeleteClient {

    /// A stream link for a file, where to resume, its skippable parts and
    /// the tracks chosen for this viewer.
    func play(file id: Int) async throws(MeleteError) -> PlayResponse {
        try await send(Endpoint(.post, "api/v1/files/\(id)/play"))
    }

    /// Sent every few seconds while playing and when stopping. Reaching 90%
    /// marks the file watched.
    func reportProgress(file id: Int, _ report: ProgressReport) async throws(MeleteError) -> Progress {
        try await send(Endpoint(.put, "api/v1/files/\(id)/progress", json: report))
    }

    func subtitles(file id: Int) async throws(MeleteError) -> [SubtitleTrack] {
        try await send(Endpoint(.get, "api/v1/files/\(id)/subtitles"))
    }

    /// The viewer's playback choices.
    func playbackSettings() async throws(MeleteError) -> PlaybackSettings {
        try await send(Endpoint(.get, "api/v1/me/playback"))
    }

    func setPlaybackSettings(_ change: PlaybackSettingsChange) async throws(MeleteError) -> PlaybackSettings {
        try await send(Endpoint(.put, "api/v1/me/playback", json: change))
    }

    func trickplay(file id: Int) async throws(MeleteError) -> Trickplay {
        try await send(Endpoint(.get, "api/v1/files/\(id)/trickplay"))
    }

    /// The viewer changed tracks by hand in an episode; the series' next
    /// episodes play with tracks like these.
    func setTrackChoice(file id: Int, _ choice: TrackChoice) async throws(MeleteError) {
        _ = try await send(Endpoint<NoContent>(.put, "api/v1/files/\(id)/track-choice", json: choice))
    }

    func sendDiagnostics(_ report: DiagnosticsReport) async throws(MeleteError) -> DiagnosticsKept {
        try await send(Endpoint(.post, "api/v1/me/diagnostics", json: report))
    }

    /// A text subtitle track of the stream link's file, as WebVTT. Loads
    /// without headers: the link carries its own token.
    func subtitleURL(stream streamURL: URL, track: String) -> URL {
        streamURL.appending(path: "subtitles/\(track).vtt")
    }

    /// An ASS/SSA track of the stream link's file as it is, styling and all,
    /// and the encoding its Content-Type names: an embedded track comes in
    /// UTF-8, a file beside the video byte for byte.
    func assScript(stream streamURL: URL, track: SubtitleTrack) async throws(MeleteError) -> String {
        guard let path = track.assUrl else { throw .transport("\(track.track) isn't an ASS track.") }
        let (data, response) = try await fetch(streamURL.appending(path: path))
        let encoding = response.textEncodingName
            .map { CFStringConvertIANACharSetNameToEncoding($0 as CFString) }
            .flatMap { $0 == kCFStringEncodingInvalidId ? nil : String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding($0)) }
        guard let script = String(data: data, encoding: encoding ?? .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw .decoding("\(track.track)'s ASS file isn't text.")
        }
        return script
    }

    /// The fonts attached to the stream link's file, for drawing its ASS
    /// tracks as made.
    func attachedFonts(stream streamURL: URL) async throws(MeleteError) -> [AttachedFont] {
        let (data, _) = try await fetch(streamURL.appending(path: "fonts"))
        do {
            return try JSONDecoder.melete.decode([AttachedFont].self, from: data)
        } catch {
            throw .decoding(String(describing: error))
        }
    }

    /// One attached font's bytes.
    func fontData(_ font: AttachedFont) async throws(MeleteError) -> Data {
        guard let url = url(for: font.url) else { throw .transport("Not a valid address: \(font.url)") }
        return try await fetch(url).data
    }

    /// One sheet of seek-bar previews for the stream link's file.
    func trickplaySheetURL(stream streamURL: URL, sheet: Int) -> URL {
        streamURL.appending(path: "trickplay/\(sheet).jpg")
    }
}
