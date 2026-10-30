//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
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
    static let maxBitrateKey = "maxBitrate"
    static let resumeOffsetKey = "resumeOffset"
    static let subtitleSizeKey = "subtitleSize"
    static let previewClipsKey = "previewClips"

    /// Start the next episode when the credits have counted down. On unless
    /// turned off.
    static var autoPlayNext: Bool {
        UserDefaults.standard.object(forKey: autoPlayNextKey) as? Bool ?? true
    }

    /// Skip recaps, intros and previews without a press. Credits are never
    /// skipped; the next episode is offered there instead.
    static var autoSkipIntros: Bool {
        UserDefaults.standard.bool(forKey: autoSkipIntrosKey)
    }

    /// The most bits per second to stream, chosen in Settings; nil for the
    /// file as it is. Melete converts anything over it.
    static var maxBitrate: Int? {
        let value = UserDefaults.standard.integer(forKey: maxBitrateKey)
        return value > 0 ? value : nil
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
