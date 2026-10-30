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
}
