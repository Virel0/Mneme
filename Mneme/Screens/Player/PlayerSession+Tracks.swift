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
        } else {
            engine.selectSidecarSubtitle(url: client.subtitleURL(stream: stream, track: track))
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
