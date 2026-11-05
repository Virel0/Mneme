//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import AetherEngine
import AssRendering
import Foundation
import MeleteKit

extension PlayerSession {

    var audioTracks: [TrackInfo] {
        engine?.audioTracks ?? []
    }

    var activeAudio: Int? {
        engine?.activeAudioTrackIndex
    }

    func selectAudio(_ track: TrackInfo) {
        guard let engine, engine.activeAudioTrackIndex != track.id else { return }
        engine.selectAudioTrack(index: track.id)
        rememberChoice(audioLanguage: track.language)
    }

    func selectSubtitle(_ track: SubtitleTrack?) {
        guard let play, let url = client.url(for: play.streamUrl) else { return }
        rememberChoice(audioLanguage: audioTracks.first { $0.id == activeAudio }?.language)
        // A picture track over a conversion that hasn't drawn it in, or a
        // change from the one it has: the stream has to be chosen again.
        let picture = pictureTrack(track?.track)
        if (isConverted && picture != nil && picture != burnedSubtitle) || (burnedSubtitle != nil && burnedSubtitle != track?.track) {
            PlaybackDiagnostics.shared.record("subtitles", "\(track?.track ?? "off") · reopening, the stream playing can't show it")
            reload(showing: track?.track)
            return
        }
        applySubtitle(track?.track, stream: url)
    }

    /// The track, when it is a picture track (PGS, VobSub): one Melete can't
    /// serve as WebVTT.
    func pictureTrack(_ track: String?) -> String? {
        guard let track, let listed = subtitles.first(where: { $0.track == track }), !listed.text else { return nil }
        return track
    }

    func applySubtitle(_ track: String?, stream: URL) {
        guard let engine else { return }
        subtitleTrack = track
        if track != assTrack {
            assLoad?.cancel()
            assTrack = nil
            assRenderer = nil
        }

        // Off, or drawn into the picture by the conversion.
        guard let track, track != burnedSubtitle else {
            engine.clearSubtitle()
            if let track {
                recordSubtitle(track, way: "drawn into the picture by Melete")
            }
            return
        }
        // A styled track is drawn as made once its script and fonts are in;
        // until then, and if that fails, its plain version shows.
        if let listed = subtitles.first(where: { $0.track == track }), listed.ass == true, listed.assUrl != nil, assTrack != track {
            assTrack = track
            assLoad = Task { await loadAss(listed, stream: stream) }
        }
        // Drawn as made already: its plain version would show under it.
        if assRenderer != nil, assTrack == track {
            return
        }
        // An embedded track is `s` and its stream index, which is the
        // engine's id for it too; anything else is a file Melete serves. A
        // conversion carries no subtitles, so every track comes from Melete.
        if !isConverted, track.hasPrefix("s"), let index = Int(track.dropFirst()) {
            // Re-selecting the track already up restarts its decoder.
            guard engine.activeSubtitleTrackIndex != index else { return }
            engine.selectSubtitleTrack(index: index)
            recordSubtitle(track, way: "embedded")
        } else {
            engine.selectSidecarSubtitle(url: client.subtitleURL(stream: stream, track: track))
            recordSubtitle(track, way: "Melete WebVTT")
        }
    }

    /// Which track went which way, and a few seconds on, whether any of it
    /// came: subtitles that don't show leave no other trace.
    private func recordSubtitle(_ track: String, way: String) {
        guard let engine else { return }
        PlaybackDiagnostics.shared.record("subtitles", "\(track) · \(way) · route \(engine.videoRoute.rawValue)")
        subtitleCheck?.cancel()
        subtitleCheck = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, let self, let engine = self.engine, self.subtitleTrack == track else { return }
            if let renderer = self.assRenderer {
                PlaybackDiagnostics.shared.record("subtitles.status", "\(track) · drawn as made · \(renderer.eventCount) lines")
                return
            }
            PlaybackDiagnostics.shared.record(
                "subtitles.status",
                "\(track) · \(engine.subtitleCues.count) cues · \(engine.isLoadingSubtitles ? "still loading" : "loaded") · route \(engine.videoRoute.rawValue) · \(Self.describe(engine.subtitleCues.first))"
            )
        }
    }

    /// The fonts a styled track may bring, together: anime releases carry a
    /// few megabytes, a whole Japanese family tens.
    private static let fontBudget = 96 * 1024 * 1024

    /// A styled track's script and the video's fonts, and the renderer made
    /// from them; the plain version gives way once it is ready.
    private func loadAss(_ track: SubtitleTrack, stream: URL) async {
        async let listed = client.attachedFonts(stream: stream)
        let script: String
        do {
            script = try await client.assScript(stream: stream, track: track)
        } catch {
            PlaybackDiagnostics.shared.record(
                "subtitles",
                "\(track.track) · styled version didn't load, plain instead: \(error.localizedDescription)"
            )
            return
        }
        var fonts: [AssRenderer.Font] = []
        var total = 0
        for font in await (try? listed) ?? [] where total + font.size <= Self.fontBudget {
            guard !Task.isCancelled else { return }
            if let data = try? await client.fontData(font) {
                fonts.append(AssRenderer.Font(name: font.fileName, data: data))
                total += data.count
            }
        }
        let made = await Task.detached(priority: .userInitiated) { [fonts] in AssRenderer(script: script, fonts: fonts) }.value
        guard !Task.isCancelled, assTrack == track.track else { return }
        guard let made else {
            PlaybackDiagnostics.shared.record("subtitles", "\(track.track) · libass couldn't read the styled version, plain instead")
            return
        }
        engine?.clearSubtitle()
        assRenderer = made
        PlaybackDiagnostics.shared.record("subtitles", "\(track.track) · drawn as made · \(made.eventCount) lines · \(fonts.count) fonts")
    }

    /// What a cue is, for a report: a picture's size on its canvas says
    /// whether it will be drawn the size it was authored.
    private static func describe(_ cue: SubtitleCue?) -> String {
        guard let cue else { return "no cue" }
        guard case let .image(image) = cue.body else { return "text" }
        return String(
            format: "picture %.2f×%.2f of a %.0f×%.0f canvas",
            image.position.width, image.position.height, image.canvasSize.width, image.canvasSize.height
        )
    }

    /// A choice made by hand in an episode carries to the series' next
    /// episodes, on Melete's side.
    private func rememberChoice(audioLanguage: String?) {
        guard target.season != nil else { return }
        let subtitle = subtitles.first { $0.track == subtitleTrack }.map {
            TrackChoice.Subtitle(language: $0.language, forced: $0.forced, hearingImpaired: $0.hearingImpaired)
        }
        let file = target.fileID
        let client = client
        Task {
            try? await client.setTrackChoice(file: file, TrackChoice(audioLanguage: audioLanguage, subtitle: subtitle))
        }
    }
}
