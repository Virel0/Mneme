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

/// What a phone or tablet adds to playback: the way back after the app was
/// in the background. Now Playing is shared with the Apple TV, in
/// `PlayerSession+NowPlaying`.
extension PlayerSession {

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
}
#endif
