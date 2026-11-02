//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
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
