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
        applySubtitle(track?.track, stream: url)
        rememberChoice(audioLanguage: audioTracks.first { $0.id == activeAudio }?.language)
    }

    func applySubtitle(_ track: String?, stream: URL) {
        guard let engine else { return }
        subtitleTrack = track

        guard let track else {
            engine.clearSubtitle()
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
            PlaybackDiagnostics.shared.record(
                "subtitles.status",
                "\(track) · \(engine.subtitleCues.count) cues · \(engine.isLoadingSubtitles ? "still loading" : "loaded") · route \(engine.videoRoute.rawValue)"
            )
        }
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
