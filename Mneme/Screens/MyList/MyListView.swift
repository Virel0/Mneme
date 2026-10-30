//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit
import SwiftUI

/// Every title on My List, newest first.
struct MyListView: View {

    @Environment(Library.self)
    private var library
    @Environment(Router.self)
    private var router

    @State
    private var spotlight = TileSpotlight()
    @State
    private var items: [TitleSummary]?

    private static let columns: CGFloat = 7

    private var tileWidth: CGFloat {
        RowLayout.baseWidth(columns: Self.columns)
    }

    var body: some View {
        ZStack {
            TileSpotlightView(spotlight: spotlight)
                .ignoresSafeArea()

            if let items {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Nothing on My List",
                        systemImage: "plus.circle",
                        description: Text("Add a movie or a show with the + on its page, and it will be here.")
                    )
                } else {
                    grid(items)
                }
            } else {
                ProgressView()
            }
        }
        .environment(\.tileSpotlight, spotlight)
        // Reloaded whenever My List changes anywhere in the app.
        .task(id: library.favouritesVersion) {
            guard let list = try? await library.client.favourites(limit: 500) else {
                items = items ?? []
                return
            }
            items = list.items.filter(\.present).map(TitleSummary.init)
        }
    }

    @ViewBuilder
    private func grid(_ items: [TitleSummary]) -> some View {
        ScrollView(.vertical) {
            Text("My List · \(items.count)")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, RowLayout.edge)
                .padding(.top, TileSpotlightLayout.preferredRowTop - 60)

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(tileWidth), spacing: RowLayout.spacing), count: Int(Self.columns)),
                alignment: .leading,
                spacing: TileSpotlightLayout.gridRowSpacing
            ) {
                ForEach(items) { item in
                    TitleTile(summary: item, slot: .grid(.portrait, width: tileWidth)) {
                        router.open(item)
                    }
                }
            }
            .padding(.horizontal, RowLayout.edge)
            .padding(.vertical, RowLayout.verticalPadding)
            .padding(.bottom, 120)
            // The whole width, so Down from any tab in the strip finds the
            // grid even when its few posters sit at the far left.
            .frame(maxWidth: .infinity, alignment: .leading)
            .focusSection()
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .mask { SpotlightMask(spotlight: spotlight) }
        // The page keeps its own 60-point margins, as every row does, rather
        // than tvOS's wider safe area on top of them.
        .ignoresSafeArea(edges: [.top, .horizontal])
    }
}
