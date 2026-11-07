//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

#if os(iOS)
import SwiftUI

/// Posters filling the page's width, as many to a line as fit: three on a
/// phone held upright, more on a wider screen.
///
/// The column count is worked out from the measured width rather than left
/// to an adaptive `GridItem`, because a tile is drawn at a width it is
/// given, and every column has to be told the same one.
struct TouchPosterGrid<Content: View>: View {

    @Environment(\.horizontalSizeClass)
    private var sizeClass

    /// The tiles, given the width each is to be.
    @ViewBuilder
    let content: (CGFloat) -> Content

    @State
    private var width: CGFloat = 0

    private let spacing: CGFloat = 10

    /// The narrowest a poster may be: about the width of a row's, so a grid
    /// and the rows above it look alike.
    private var narrowest: CGFloat {
        sizeClass == .regular ? 140 : 100
    }

    var body: some View {
        let count = max(1, Int((width + spacing) / (narrowest + spacing)))
        let tileWidth = max(0, (width - spacing * CGFloat(count - 1)) / CGFloat(count))

        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(tileWidth), spacing: spacing), count: count),
            alignment: .leading,
            spacing: 16
        ) {
            // Not before the width is known: tiles of no size would all be
            // on screen at once, and a grid that loads more at its end would
            // ask for the next page straight away.
            if width > 0 {
                content(tileWidth)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            self.width = width
        }
        .padding(.horizontal, TouchLayout.edge)
    }
}
#endif
