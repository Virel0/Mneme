//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import AetherEngine
import Foundation
import MeleteKit
import Observation

/// A quiet clip of a title, played over its backdrop in the hero or the
/// spotlight once focus has rested there a moment.
///
/// It is the title itself, from where the viewer left it or a little way
/// in, through Melete's conversion at 720p: small enough to start at once
/// and to leave the network to the film being watched. Played only on the
/// home network, muted, and nothing about it is reported as watched.
@MainActor
@Observable
final class PreviewClip {

    private(set) var engine: AetherEngine?
    private(set) var isPlaying = false

    @ObservationIgnored
    private var task: Task<Void, Never>?

    /// Long enough that sweeping across titles starts nothing.
    private static let delay: Duration = .milliseconds(900)
    private static let length: Duration = .seconds(40)

    func start(for summary: TitleSummary, client: MeleteClient) {
        stop()
        guard PlaybackPreferences.previewClips, client.baseURL.isOnHomeNetwork else { return }

        task = Task { [weak self] in
            try? await Task.sleep(for: Self.delay)
            guard !Task.isCancelled else { return }
            await self?.play(summary, client: client)
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        engine?.stop()
        engine = nil
        isPlaying = false
    }

    private func play(_ summary: TitleSummary, client: MeleteClient) async {
        guard let target = try? await PlayTarget.lookUp(for: summary, client: client),
              let start = await Self.startPoint(for: summary, target: target, client: client),
              let converted = try? await client.transcode(
                  file: target.fileID,
                  TranscodeRequest(maxHeight: 720, maxBitrate: 3_000_000, videoCodec: "h264")
              ),
              let url = client.url(for: converted.playlistUrl),
              !Task.isCancelled,
              let engine = try? AetherEngine()
        else { return }

        var options = LoadOptions()
        options.nativeRemoteHLS = true
        engine.volume = 0
        guard await (try? engine.load(url: url, startPosition: start, options: options)) != nil, !Task.isCancelled else {
            engine.stop()
            return
        }
        engine.volume = 0
        engine.play()
        self.engine = engine
        isPlaying = true

        try? await Task.sleep(for: Self.length)
        guard !Task.isCancelled else { return }
        stop()
    }

    /// Where the viewer left it, else an eighth of the way in, past the
    /// titles of most films and the recap of most episodes.
    private static func startPoint(for summary: TitleSummary, target: PlayTarget, client: MeleteClient) async -> Double? {
        if let progress = summary.progress, progress.fileId == target.fileID, progress.isPartway {
            return progress.positionSeconds
        }
        let runtime = summary.runtimeMinutes.map { Double($0) * 60 }
        if let runtime {
            return runtime / 8
        }
        let duration = try? await client.fileInfo(target.fileID).media?.durationSeconds
        return (duration ?? 600) / 8
    }
}

extension URL {

    /// Whether the address is on the local network: a private address, a
    /// `.local` name or a name without dots. A guess, which is all it needs
    /// to be: it only decides whether clips play.
    var isOnHomeNetwork: Bool {
        guard let host = host()?.lowercased() else { return false }
        if host == "localhost" || host.hasSuffix(".local") || !host.contains(".") {
            return true
        }
        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return false }
        switch (parts[0], parts[1]) {
        case (10, _), (127, _), (192, 168): return true
        case (172, 16 ... 31): return true
        default: return false
        }
    }
}
