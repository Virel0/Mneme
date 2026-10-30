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
    @State
    private var sort: ListSort = .title
    /// Nil for every genre.
    @State
    private var genre: String?
    @State
    private var genres: [String] = []

    private static let pageSize = 100
    private static let columns: CGFloat = 7

    private var tileWidth: CGFloat {
        RowLayout.baseWidth(columns: Self.columns)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RowLayout.headingSpacing) {
            HStack(spacing: 24) {
                Text(heading)
                    .font(.title3.weight(.semibold))
                Spacer()
                Menu {
                    Picker("Sort", selection: $sort) {
                        Text("A to Z").tag(ListSort.title)
                        Text("Newest").tag(ListSort.year)
                        Text("Recently Added").tag(ListSort.recent)
                    }
                } label: {
                    Label(sortName, systemImage: "arrow.up.arrow.down")
                }
                Menu {
                    Picker("Genre", selection: $genre) {
                        Text("All Genres").tag(String?.none)
                        ForEach(genres, id: \.self) { name in
                            Text(name).tag(String?.some(name))
                        }
                    }
                } label: {
                    Label(genre ?? "All Genres", systemImage: "line.3.horizontal.decrease")
                }
                .disabled(genres.isEmpty)
            }
            .padding(.horizontal, RowLayout.edge)
            .focusSection()

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
        // Again from the start when titles come or go, or the order or
        // genre changes.
        .task(id: Reload(version: library.libraryVersion, sort: sort, genre: genre)) {
            items = []
            total = nil
            await loadMore()
        }
        .task {
            genres = await (try? library.client.genres())?
                .filter { kind == .movies ? $0.movies > 0 : $0.series > 0 }
                .map(\.name) ?? []
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
        case .movies: try? await client.movies(genre: genre, sort: sort, limit: Self.pageSize, offset: items.count)
        case .anime: try? await client.series(genre: genre, anime: .only, sort: sort, limit: Self.pageSize, offset: items.count)
        case .home, .shows: try? await client.series(genre: genre, anime: .exclude, sort: sort, limit: Self.pageSize, offset: items.count)
        }
        guard let page else { return }

        let titleKind: TitleKind = kind == .movies ? .movie : .series
        items += page.items.map { TitleSummary($0, kind: titleKind) }
        total = page.total
    }

    private var sortName: String {
        switch sort {
        case .title: "A to Z"
        case .year: "Newest"
        case .recent: "Recently Added"
        }
    }

    private struct Reload: Equatable {
        let version: Int
        let sort: ListSort
        let genre: String?
    }
}
