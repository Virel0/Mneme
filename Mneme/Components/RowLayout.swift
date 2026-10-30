//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI

enum TileShape: Hashable {
    /// 16:9, for things to play now.
    case landscape
    /// 2:3, for titles to open.
    case portrait

    func size(forWidth width: CGFloat) -> CGSize {
        switch self {
        case .landscape: CGSize(width: width, height: width * 9 / 16)
        case .portrait: CGSize(width: width, height: width * 3 / 2)
        }
    }
}

/// The geometry every row of tiles shares.
enum RowLayout {

    static let edge: CGFloat = 60
    static let spacing: CGFloat = 40

    /// Room above and below the tiles inside the row's scroll view, so a
    /// lifted tile is not clipped by the row's own frame.
    static let verticalPadding: CGFloat = 16

    static let headingSpacing: CGFloat = 12

    /// The row's own coordinate space, so a tile can work out how much of
    /// itself falls inside the strip the row actually paints.
    static let space = "mneme.row"

    /// How far the row's mask reaches above and below the row, for the
    /// lifted tile and its shadow.
    static let verticalBleed: CGFloat = 80

    /// How far a row you are not on stands back: dim enough to recede, bright
    /// enough to browse out of the corner of the eye.
    static let restingOpacity: Double = 0.68

    /// Dimmer than the tiles, so the lit row's name is the one heading on
    /// the page.
    static let headingOpacity: Double = 0.55

    /// Shared by the tile and the row it sits in, so they move together.
    static let motion: Animation = .spring(response: 0.28, dampingFraction: 0.9)

    /// The strip of a row of this width that is painted: everything between
    /// the two margins.
    static func paintedStrip(inRowOfWidth width: CGFloat) -> ClosedRange<CGFloat> {
        edge ... Swift.max(edge, width - edge)
    }

    static func baseWidth(columns: CGFloat) -> CGFloat {
        (UIScreen.main.bounds.width - edge * 2 - spacing * (columns - 1)) / columns
    }

    /// Fractional on purpose: the row ends on a half tile, which says there
    /// is more to the right without a chevron. Small enough that a row fits
    /// under the spotlight with its heading.
    static func defaultColumns(for shape: TileShape) -> CGFloat {
        shape == .landscape ? 4.5 : 7.5
    }
}
