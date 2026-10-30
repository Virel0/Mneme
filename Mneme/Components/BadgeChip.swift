//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI

/// A small dark plate with a coloured glyph and a few words, on artwork.
///
/// Opaque rather than a material: over a bright poster a material turns
/// grey and the words go with it.
struct BadgeChip: View {

    enum Kind {
        /// Part-watched: how much is left.
        case resume
        /// Arrived in the last two weeks.
        case new
        /// Episodes on disk not yet watched.
        case unwatched

        var systemImage: String {
            switch self {
            case .resume: "play.fill"
            case .new: "megaphone.fill"
            case .unwatched: "circle.badge.plus.fill"
            }
        }

        /// Full colour: a row of white glyphs reads as chrome, a coloured one
        /// as a mark somebody put there on purpose.
        var tint: Color {
            switch self {
            case .resume: .white
            case .new: Color(red: 0.90, green: 0.20, blue: 0.24)
            case .unwatched: Color(red: 0.36, green: 0.68, blue: 1.0)
            }
        }
    }

    let kind: Kind
    let title: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: kind.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(kind.tint)

            Text(title)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
