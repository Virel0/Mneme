//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

/// Playback choices kept on this Apple TV.
///
/// Auto-play would belong to each person on the server, as Jellyfin kept it;
/// Melete has no such setting yet, so for now it is the device's.
enum PlaybackPreferences {

    static let autoPlayNextKey = "autoPlayNext"
    static let autoSkipIntrosKey = "autoSkipIntros"
    /// The profiles this device's skipping choice was handed to Melete for.
    static let autoSkipCarriedKey = "autoSkipCarried"
    static let maxBitrateKey = "maxBitrate"
    static let resumeOffsetKey = "resumeOffset"
    static let subtitleSizeKey = "subtitleSize"
    static let previewClipsKey = "previewClips"
    static let meleteConvertsAudioKey = "meleteConvertsAudio"
    static let previewSoundKey = "previewSound"

    /// Start the next episode when the credits have counted down. On unless
    /// turned off.
    static var autoPlayNext: Bool {
        UserDefaults.standard.object(forKey: autoPlayNextKey) as? Bool ?? true
    }

    /// Skip recaps, intros and previews without a press, where the server
    /// doesn't keep the choice. Credits are never skipped; the next episode
    /// is offered there instead.
    static var autoSkipIntros: Bool {
        UserDefaults.standard.bool(forKey: autoSkipIntrosKey)
    }

    /// The most bits per second to stream, chosen in Settings; nil for the
    /// file as it is. Melete converts anything over it.
    static var maxBitrate: Int? {
        let value = UserDefaults.standard.integer(forKey: maxBitrateKey)
        return value > 0 ? value : nil
    }

    /// Play preview clips and hero trailers with their sound, at a lower
    /// volume. On unless turned off.
    static var previewSound: Bool {
        UserDefaults.standard.object(forKey: previewSoundKey) as? Bool ?? true
    }

    /// Have Melete convert a soundtrack the Apple TV can't play itself
    /// (TrueHD, DTS, PCM), streaming the video unchanged beside it, instead
    /// of converting it on the Apple TV. Off unless turned on.
    static var meleteConvertsAudio: Bool {
        UserDefaults.standard.bool(forKey: meleteConvertsAudioKey)
    }

    /// The choices offered, in bits per second; 0 is the original.
    static let bitrateChoices = [0, 40_000_000, 20_000_000, 10_000_000, 6_000_000, 3_000_000]

    /// How far before the saved position to resume, in seconds, so the
    /// viewer rejoins before the line they stopped on.
    static var resumeOffset: Double {
        UserDefaults.standard.object(forKey: resumeOffsetKey) as? Double ?? 5
    }

    /// Subtitle text size, in points.
    static var subtitleSize: Double {
        UserDefaults.standard.object(forKey: subtitleSizeKey) as? Double ?? 46
    }

    /// Play a quiet clip of the title in the hero and the spotlight.
    static var previewClips: Bool {
        UserDefaults.standard.object(forKey: previewClipsKey) as? Bool ?? true
    }
}
