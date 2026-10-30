//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI

/// Where the player will be. Says what Play chose, so the choice can be
/// checked before playback exists.
struct PlayerPlaceholder: View {

    let target: PlayTarget

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "play.rectangle")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)
                Text("The player is being rebuilt for Melete")
                    .font(.title2)
                Text("\(target.label) · file \(target.fileID)\(target.restarts ? " · from the start" : "")")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
