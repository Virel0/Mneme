//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit
import SwiftUI

/// Every title of a kind, A to Z, as posters, fetched a page at a time as
/// the viewer nears the end of what is loaded.
struct AllTitlesGrid: View {

    @Environment(Library.self)
    private var library
    @Environment(Router.self)
    private var router

    let kind: WatchKind

    @State
    private var items: [TitleSummary] = []
    @State
    private var total: Int?
    @State
    private var isLoading = false

    private static let pageSize = 100
    private static let columns: CGFloat = 7

    private var tileWidth: CGFloat {
        RowLayout.baseWidth(columns: Self.columns)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RowLayout.headingSpacing) {
            Text(heading)
                .font(.title3.weight(.semibold))
                .padding(.horizontal, RowLayout.edge)

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(tileWidth), spacing: RowLayout.spacing), count: Int(Self.columns)),
                alignment: .leading,
                spacing: TileSpotlightLayout.gridRowSpacing
            ) {
                ForEach(items) { item in
                    TitleTile(summary: item, slot: .grid(.portrait, width: tileWidth)) {
                        router.open(item)
                    }
                    .onAppear {
                        if item.ref == items.last?.ref {
                            Task { await loadMore() }
                        }
                    }
                }
            }
            .padding(.horizontal, RowLayout.edge)
            .padding(.vertical, RowLayout.verticalPadding)
            .focusSection()
        }
        // Again from the start when titles come or go.
        .task(id: library.libraryVersion) {
            items = []
            total = nil
            await loadMore()
        }
    }

    private var heading: String {
        let name = switch kind {
        case .home, .shows: "All Shows"
        case .anime: "All Anime"
        case .movies: "All Movies"
        }
        return total.map { "\(name) · \($0)" } ?? name
    }

    private func loadMore() async {
        guard !isLoading, total.map({ items.count < $0 }) ?? true else { return }
        isLoading = true
        defer { isLoading = false }

        let client = library.client
        let page: Page<ListItem>? = switch kind {
        case .movies: try? await client.movies(limit: Self.pageSize, offset: items.count)
        case .anime: try? await client.series(anime: .only, limit: Self.pageSize, offset: items.count)
        case .home, .shows: try? await client.series(anime: .exclude, limit: Self.pageSize, offset: items.count)
        }
        guard let page else { return }

        let titleKind: TitleKind = kind == .movies ? .movie : .series
        items += page.items.map { TitleSummary($0, kind: titleKind) }
        total = page.total
    }
}
