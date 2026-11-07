//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

#if os(iOS)
import AetherEngine
import MediaPlayer

/// What a phone or tablet adds to playback: the film on the lock screen and
/// in Control Center, its buttons there, and the way back after the app was
/// in the background.
extension PlayerSession {

    /// Before `start()`: the engine reads these when it builds its player.
    /// It then publishes the elapsed time and rate itself; the app gives it
    /// the title and answers the buttons.
    func prepareForTouch() {
        guard let engine else { return }
        engine.ownsVideoNowPlayingSession = true
        // The software path (Dolby Vision FEL) answers its own buttons.
        engine.ownsSoftwareNowPlaying = true
        engine.remoteSkipInterval = Self.remoteSkip
        engine.setVideoNowPlayingInfo([MPMediaItemPropertyTitle: target.label])
    }

    /// The lock screen's buttons on the native path, once its player exists.
    /// Each load can bring a new one, so this runs again after each, and
    /// clears what it set before so no button is answered twice.
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
    }

    /// Back from the background. The engine keeps a playing film going there
    /// and tears down one left paused; only a torn-down film is opened again,
    /// where it was and paused as it was. Reloading a live one would close
    /// Picture in Picture and stop sound that kept playing.
    func restoreAfterBackground() async {
        guard let engine, phase == .playing, engine.needsForegroundVideoRestore else { return }
        let wasPaused = isPaused
        do {
            try await engine.reloadAtCurrentPosition()
            if wasPaused {
                engine.pause()
                isPaused = true
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func setPaused(_ paused: Bool) {
        if isPaused != paused {
            togglePause()
        }
    }

    private static let remoteSkip: Double = 10
}
#endif
