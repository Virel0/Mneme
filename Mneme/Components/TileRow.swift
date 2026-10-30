//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Nuke
import SwiftUI

/// A heading over a sideways row of title tiles.
///
/// Everything a row needs that is not the tile: the scroll view and its
/// margins, the mask that stops the sideways bleed, the standing back of
/// rows you are not on, the lifted tile drawn over its neighbours, and the
/// artwork fetched before anybody scrolls to it.
struct TileRow: View {

    @Environment(\.melete)
    private var client

    let title: String
    let items: [TitleSummary]
    let shape: TileShape
    let open: (TitleSummary) -> Void

    /// Seeded with the screen width so the first frame is already right.
    @State
    private var rowWidth: CGFloat = UIScreen.main.bounds.width

    @FocusState
    private var focusedTile: TitleRef?

    /// Made on first use: a `@State` initial value is evaluated every time
    /// the struct is built, which would be a prefetcher per render.
    @State
    private var prefetcher: ImagePrefetcher?

    private var isActive: Bool {
        focusedTile != nil
    }

    private var slot: TileSlot {
        TileSlot(
            shape: shape,
            width: RowLayout.baseWidth(columns: RowLayout.defaultColumns(for: shape)),
            paintedStrip: RowLayout.paintedStrip(inRowOfWidth: rowWidth)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RowLayout.headingSpacing) {
            Text(title)
                .font(.title3.weight(.semibold))
                .padding(.horizontal, RowLayout.edge)
                .opacity(isActive ? 1 : RowLayout.headingOpacity)
                .animation(.easeOut(duration: 0.2), value: isActive)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: RowLayout.spacing) {
                    ForEach(items) { item in
                        TitleTile(summary: item, slot: slot) {
                            open(item)
                        }
                        // The lifted tile over its neighbours: here, on the
                        // stack's own child, is the only place it means anything.
                        .zIndex(focusedTile == item.ref ? 1 : 0)
                        .focused($focusedTile, equals: item.ref)
                    }
                }
                .padding(.vertical, RowLayout.verticalPadding)
            }
            // The margin as a safe-area inset rather than padding: padding
            // scrolls with the content, so a tile scrolled to the leading
            // edge sat flush against the side of the screen.
            .safeAreaPadding(.horizontal, RowLayout.edge)
            .opacity(isActive ? 1 : RowLayout.restingOpacity)
            .animation(.easeOut(duration: 0.25), value: isActive)
            .scrollClipDisabled()
            .coordinateSpace(.named(RowLayout.space))
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
            // Clip sideways, never up and down: a lifted tile grows past the
            // row's frame upwards and must not be cut, but sideways the row
            // would otherwise paint into the margins and off the screen.
            .mask {
                Rectangle()
                    .padding(.horizontal, RowLayout.edge)
                    .padding(.vertical, -RowLayout.verticalBleed)
            }
            .focusSection()
        }
        .task(id: items.map(\.ref)) {
            prefetch()
        }
        .onDisappear {
            prefetcher?.stopPrefetching()
        }
    }

    /// The whole row's artwork, so a scroll arrives complete instead of
    /// popping in tile by tile. A row is a handful of right-sized images.
    private func prefetch() {
        guard let client else { return }
        let requests = items.compactMap { item in
            client.artworkRequest(shape == .landscape ? item.episode?.still ?? item.backdrop : item.poster)
        }
        guard !requests.isEmpty else { return }
        if prefetcher == nil {
            prefetcher = ImagePrefetcher(destination: .diskCache)
        }
        prefetcher?.startPrefetching(with: requests)
    }
}
