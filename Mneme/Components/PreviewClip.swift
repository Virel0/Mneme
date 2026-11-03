//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
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
/// In the hero, the title's trailer when its folder has one. Otherwise the
/// title itself, from where the viewer left it or a little way in. Either is
/// the file itself, as the player opens it: full quality, with its sound
/// faded up to a lower volume unless Settings turns it off, and the
/// television left in the mode it is in, so an HDR clip doesn't blank the
/// screen to switch. Played only on the home network, and nothing about it
/// is reported as watched.
/// Trailers online are YouTube's web player, which an Apple TV app cannot
/// show, so those titles get the clip of themselves.
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
    /// Below the film's own level: it plays unasked while someone browses.
    private static let volume: Float = 0.6
    /// Enough for nearly any trailer to finish.
    private static let trailerLength: Duration = .seconds(150)

    /// Said once a launch, so a report shows why no clip plays without a
    /// line for every title focused.
    private static var saidOffNetwork = false

    /// Plays the trailer file when given one, else a clip of the title.
    func start(for summary: TitleSummary, client: MeleteClient, trailerFile: Int? = nil) {
        stop()
        guard PlaybackPreferences.previewClips else { return }
        guard client.baseURL.isOnHomeNetwork else {
            if !Self.saidOffNetwork {
                Self.saidOffNetwork = true
                PlaybackDiagnostics.shared.record("clip", "off: \(client.baseURL.host() ?? "the server") isn't on the home network")
            }
            return
        }

        task = Task { [weak self] in
            try? await Task.sleep(for: Self.delay)
            guard !Task.isCancelled else { return }
            await self?.play(summary, trailerFile: trailerFile, client: client)
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        engine?.stop()
        engine = nil
        isPlaying = false
    }

    /// Each step that can fail says so in the diagnostics report: a clip
    /// that doesn't start otherwise leaves no trace.
    private func play(_ summary: TitleSummary, trailerFile: Int?, client: MeleteClient) async {
        let diagnostics = PlaybackDiagnostics.shared
        let source: (file: Int, start: Double, length: Duration, what: String)
        if let file = trailerFile {
            source = (file, 0, Self.trailerLength, "trailer")
        } else if let target = try? await PlayTarget.lookUp(for: summary, client: client),
                  let start = await Self.startPoint(for: summary, target: target, client: client)
        {
            source = (target.fileID, start, Self.length, "clip")
        } else {
            diagnostics.record("clip", "\(summary.title): no file to play")
            return
        }

        let play: PlayResponse
        do {
            play = try await client.play(file: source.file)
        } catch {
            diagnostics.record("clip", "file \(source.file) · no stream: \(error.localizedDescription)")
            return
        }
        guard let url = client.url(for: play.streamUrl) else {
            diagnostics.record("clip", "file \(source.file) · no address for the stream")
            return
        }
        guard !Task.isCancelled else { return }
        let engine: AetherEngine
        do {
            engine = try AetherEngine()
        } catch {
            diagnostics.record("clip", "engine didn't start: \(error.localizedDescription)")
            return
        }

        // Filling the frame, as the pictures behind do: fitted, a 16:9 clip
        // in the hero's wider card had black bars at both sides.
        engine.videoGravity = .resizeAspectFill

        var options = LoadOptions()
        options.displayCriteriaOwner = .host
        engine.volume = 0
        do {
            try await engine.load(url: url, startPosition: source.start, options: options)
        } catch {
            // Stopped because focus moved on: not a failure worth a line.
            if !(error is CancellationError) {
                diagnostics.record("clip", "file \(source.file) · didn't load: \(error.localizedDescription)")
            }
            engine.stop()
            return
        }
        guard !Task.isCancelled else {
            engine.stop()
            return
        }
        engine.volume = 0
        engine.play()
        self.engine = engine
        isPlaying = true
        if PlaybackPreferences.previewSound {
            for step in 1 ... 10 {
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled, self.engine === engine else { return }
                engine.volume = Self.volume * Float(step) / 10
            }
        }
        diagnostics.record("clip", "file \(source.file) · playing the \(source.what) from \(Int(source.start))s")

        try? await Task.sleep(for: source.length)
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
