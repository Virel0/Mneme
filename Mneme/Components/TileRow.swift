//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
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
    /// For a row whose tiles play when selected: opens the title instead,
    /// from the tile's long-press menu.
    var goToTitle: ((TitleSummary) -> Void)?
    /// After the last title, the first again, for as far as anybody goes.
    var loops = false

    /// Seeded with the screen width so the first frame is already right.
    @State
    private var rowWidth: CGFloat = UIScreen.main.bounds.width

    @FocusState
    private var focusedTile: RowPlace?

    /// How many times over the titles are laid out; one more is added on
    /// reaching the last, so the end is never reached.
    @State
    private var rounds = 2

    /// Made on first use: a `@State` initial value is evaluated every time
    /// the struct is built, which would be a prefetcher per render.
    @State
    private var prefetcher: ImagePrefetcher?

    private var isActive: Bool {
        focusedTile != nil
    }

    /// Only a row longer than the screen goes round: a shorter one would
    /// show the same titles side by side.
    private var places: [(place: RowPlace, item: TitleSummary)] {
        let goesRound = loops && CGFloat(items.count) > RowLayout.defaultColumns(for: shape)
        return items.inRounds(goesRound ? rounds : 1)
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
                    ForEach(places, id: \.place) { place, item in
                        // The lifted tile over its neighbours: here, on the
                        // stack's own child, is the only place it means anything.
                        tile(item)
                            .zIndex(focusedTile == place ? 1 : 0)
                            .focused($focusedTile, equals: place)
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
        .onChange(of: focusedTile) {
            if let place = focusedTile, place.round == rounds - 1 {
                rounds += 1
            }
        }
        .task(id: items.map(\.ref)) {
            prefetch()
        }
        .onDisappear {
            prefetcher?.stopPrefetching()
        }
    }

    /// A row without `goToTitle` gets no menu at all, so a long press on
    /// its tiles does nothing.
    @ViewBuilder
    private func tile(_ item: TitleSummary) -> some View {
        if let goToTitle {
            let place = item.kind == .series ? "Show" : "Movie"
            TitleTile(summary: item, slot: slot, hint: "Hold Select to go to the \(place.lowercased())") {
                open(item)
            }
            .contextMenu {
                Button("Go to \(place)", systemImage: "info.circle") {
                    goToTitle(item)
                }
            }
        } else {
            TitleTile(summary: item, slot: slot) {
                open(item)
            }
        }
    }

    /// The whole row's artwork, so a scroll arrives complete instead of
    /// popping in tile by tile. A row is a handful of right-sized images.
    private func prefetch() {
        guard let client else { return }
        let requests = items.compactMap { item in
            client.artworkRequest(TitleTile.picture(of: item, in: slot))
        }
        guard !requests.isEmpty else { return }
        if prefetcher == nil {
            prefetcher = ImagePrefetcher(destination: .diskCache)
        }
        prefetcher?.startPrefetching(with: requests)
    }
}

/// A title's place in a row that goes round: the same title has one in each
/// round.
struct RowPlace: Hashable {
    let round: Int
    let ref: TitleRef
}

extension [TitleSummary] {
    /// The titles `rounds` times over, each with its place.
    func inRounds(_ rounds: Int) -> [(place: RowPlace, item: TitleSummary)] {
        (0 ..< rounds).flatMap { round in
            map { (RowPlace(round: round, ref: $0.ref), $0) }
        }
    }
}
