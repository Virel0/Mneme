//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import AetherEngine
import MediaPlayer
import MeleteKit
import Nuke
import UIKit

/// The film as the system sees it: its name and poster, where it is, and
/// buttons that answer from outside the player. On the Apple TV that is the
/// Remote in an iPhone's Control Center and the television's own Control
/// Center; on a phone or tablet, the lock screen and Control Center.
extension PlayerSession {

    /// Before `start()`: the engine reads these when it builds its player.
    /// It then publishes the elapsed time and rate itself; the app gives it
    /// the name and poster and answers the buttons.
    func prepareNowPlaying() {
        guard let engine else { return }
        engine.ownsVideoNowPlayingSession = true
        // The software path (Dolby Vision FEL) answers its own buttons.
        engine.ownsSoftwareNowPlaying = true
        engine.remoteSkipInterval = Self.remoteSkip
    }

    /// The buttons on the native path, once its player exists. Each load can
    /// bring a new one, so this runs again after each, and clears what it set
    /// before so no button is answered twice.
    func registerRemoteCommands() {
        guard let center = engine?.videoNowPlayingSession?.remoteCommandCenter else { return }
        center.playCommand.removeTarget(nil)
        center.playCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.setPaused(false) }
            return .success
        }
        center.pauseCommand.removeTarget(nil)
        center.pauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.setPaused(true) }
            return .success
        }
        center.togglePlayPauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.togglePause() }
            return .success
        }
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: Self.remoteSkip)]
        center.skipForwardCommand.removeTarget(nil)
        center.skipForwardCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.jump(by: Self.remoteSkip) }
            return .success
        }
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: Self.remoteSkip)]
        center.skipBackwardCommand.removeTarget(nil)
        center.skipBackwardCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.jump(by: -Self.remoteSkip) }
            return .success
        }
        center.changePlaybackPositionCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            MainActor.assumeIsolated { self?.seek(to: event.positionTime) }
            return .success
        }
        // A track chosen from the lists `publishTrackOptions` gives.
        center.enableLanguageOptionCommand.removeTarget(nil)
        center.enableLanguageOptionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangeLanguageOptionCommandEvent else { return .commandFailed }
            let id = event.languageOption.identifier ?? ""
            let chosen = MainActor.assumeIsolated { self?.chooseTrack(id) ?? false }
            return chosen ? .success : .noSuchContent
        }
        center.disableLanguageOptionCommand.removeTarget(nil)
        center.disableLanguageOptionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangeLanguageOptionCommandEvent,
                  event.languageOption.languageOptionType == .legible
            else { return .commandFailed }
            MainActor.assumeIsolated { self?.selectSubtitle(nil) }
            return .success
        }
    }

    /// The audio and subtitle tracks, as the player's own lists name them,
    /// and which are on, laid over the name and poster: the Remote and
    /// Control Center offer them. Again after every change of track.
    func publishTrackOptions() {
        guard let engine, let nowPlaying, nowPlaying.target == target else { return }
        let audio = audioTracks.map { track in
            MPNowPlayingInfoLanguageOption(
                type: .audible,
                languageTag: track.language ?? "und",
                characteristics: nil,
                displayName: TrackPicker.title(of: track),
                identifier: Self.audioOption + String(track.id)
            )
        }
        // The ones the player's list offers: picture tracks beside the video
        // can't be fetched as text.
        let subtitles = subtitles.filter { $0.text || $0.embeddedIndex != nil }.map { track in
            MPNowPlayingInfoLanguageOption(
                type: .legible,
                languageTag: track.language ?? "und",
                characteristics: nil,
                displayName: TrackPicker.title(of: track),
                identifier: Self.subtitleOption + track.track
            )
        }
        let current = audio.filter { $0.identifier == activeAudio.map { Self.audioOption + String($0) } }
            + subtitles.filter { $0.identifier == subtitleTrack.map { Self.subtitleOption + $0 } }

        var info = nowPlaying.info
        info[MPNowPlayingInfoPropertyAvailableLanguageOptions] = [
            MPNowPlayingInfoLanguageOptionGroup(languageOptions: audio, defaultLanguageOption: nil, allowEmptySelection: false),
            MPNowPlayingInfoLanguageOptionGroup(languageOptions: subtitles, defaultLanguageOption: nil, allowEmptySelection: true),
        ]
        info[MPNowPlayingInfoPropertyCurrentLanguageOptions] = current
        engine.setVideoNowPlayingInfo(info)
    }

    /// Plays the track a list's identifier names, as the player's own list
    /// would; false for one no longer there.
    private func chooseTrack(_ id: String) -> Bool {
        if id.hasPrefix(Self.audioOption), let index = Int(id.dropFirst(Self.audioOption.count)),
           let track = audioTracks.first(where: { $0.id == index })
        {
            selectAudio(track)
            return true
        }
        if id.hasPrefix(Self.subtitleOption),
           let track = subtitles.first(where: { $0.track == id.dropFirst(Self.subtitleOption.count) })
        {
            selectSubtitle(track)
            return true
        }
        return false
    }

    private static let audioOption = "audio:"
    private static let subtitleOption = "subtitle:"

    /// The name and poster of what is playing: the movie, or the episode
    /// under its series. Asked for once the picture is up, for each file.
    /// MediaPlayer asks for the picture on a queue of its own, so the
    /// closure that hands it over is made outside the main actor: made in
    /// it, it would belong to it, and the call would stop the app.
    private nonisolated static func artworkItem(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    func publishNowPlaying(for target: PlayTarget) async {
        guard engine != nil else { return }
        var info: [String: Any] = [
            MPNowPlayingInfoPropertyMediaType: NSNumber(value: MPNowPlayingInfoMediaType.video.rawValue),
        ]
        let poster: String?
        switch target.title.kind {
        case .movie:
            guard let movie = try? await client.movie(target.title.id) else { return }
            info[MPMediaItemPropertyTitle] = movie.title
            poster = movie.poster
        case .series:
            guard let series = try? await client.series(target.title.id) else { return }
            let code = target.season.flatMap { season in
                target.episode.flatMap { Format.episodeCode(season: season, episode: $0) }
            }
            var name: String?
            if let season = target.season, let number = target.episode {
                name = try? await client.season(season, ofSeries: target.title.id)
                    .episodes.first { $0.episode == number }?.name
            }
            info[MPMediaItemPropertyTitle] = name ?? code ?? series.title
            info[MPMediaItemPropertyArtist] = [series.title, name == nil ? nil : code].compactMap(\.self).joined(separator: " · ")
            poster = series.poster
        }
        if let image = await Self.artwork(poster, client: client) {
            info[MPMediaItemPropertyArtwork] = Self.artworkItem(image)
        }
        // The next file may have started while this was asked for.
        guard self.target == target else { return }
        nowPlaying = (target, info)
        publishTrackOptions()
    }

    private static func artwork(_ path: String?, client: MeleteClient) async -> UIImage? {
        guard let request = client.artworkRequest(ArtworkSlot(path: path, kind: .poster, width: 300)),
              let image = try? await ImagePipeline.shared.image(for: request)
        else { return nil }
        // Drawn ready, as the engine asks: the system reads it off the main
        // thread.
        return image.preparingForDisplay() ?? image
    }

    private func setPaused(_ paused: Bool) {
        if isPaused != paused {
            togglePause()
        }
    }

    private static let remoteSkip: Double = 10
}
