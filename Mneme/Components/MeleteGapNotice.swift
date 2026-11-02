//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
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
