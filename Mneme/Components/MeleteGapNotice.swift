//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI

/// Marks where a feature will go once Melete can answer for it.
///
/// Shown in debug builds only: testers on TestFlight see the page without
/// it, and developers see what is still waiting on the server.
struct MeleteGapNotice: View {

    let feature: String
    let detail: String

    var body: some View {
        #if DEBUG
        HStack(spacing: 16) {
            Image(systemName: "hammer.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(feature): waiting on Melete")
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, RowLayout.edge)
        #endif
    }
}
