//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
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

    /// One sheet of seek-bar previews for the stream link's file.
    func trickplaySheetURL(stream streamURL: URL, sheet: Int) -> URL {
        streamURL.appending(path: "trickplay/\(sheet).jpg")
    }
}
