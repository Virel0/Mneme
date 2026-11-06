//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
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

    private static let columns: CGFloat = 7

    private var tileWidth: CGFloat {
        RowLayout.baseWidth(columns: Self.columns)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RowLayout.headingSpacing) {
            HStack(spacing: 24) {
                Text(Self.heading(for: kind, total: total))
                    .font(.title3.weight(.semibold))
                Spacer()
                Menu {
                    Picker("Sort", selection: $sort) {
                        Text("A to Z").tag(ListSort.title)
                        Text("Newest").tag(ListSort.year)
                        Text("Recently Added").tag(ListSort.recent)
                    }
                } label: {
                    Label(Self.name(of: sort), systemImage: "arrow.up.arrow.down")
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
            genres = await Self.genres(of: kind, from: library.client)
        }
    }

    private func loadMore() async {
        guard !isLoading, total.map({ items.count < $0 }) ?? true else { return }
        isLoading = true
        defer { isLoading = false }

        guard let page = await Self.page(of: kind, from: library.client, genre: genre, sort: sort, offset: items.count)
        else { return }
        items += page.items
        total = page.total
    }

    private struct Reload: Equatable {
        let version: Int
        let sort: ListSort
        let genre: String?
    }
}

// The touch layout's grid shares these, so both ask for the same titles and
// name them the same way.
extension AllTitlesGrid {

    private static let pageSize = 100

    /// A page of the kind's titles from `offset`; nil when it couldn't be
    /// fetched.
    static func page(
        of kind: WatchKind,
        from client: MeleteClient,
        genre: String?,
        sort: ListSort,
        offset: Int
    ) async -> (items: [TitleSummary], total: Int)? {
        let page: Page<ListItem>? = switch kind {
        case .movies: try? await client.movies(genre: genre, sort: sort, limit: pageSize, offset: offset)
        case .anime: try? await client.series(genre: genre, anime: .only, sort: sort, limit: pageSize, offset: offset)
        case .home, .shows: try? await client.series(genre: genre, anime: .exclude, sort: sort, limit: pageSize, offset: offset)
        }
        guard let page else { return nil }

        let titleKind: TitleKind = kind == .movies ? .movie : .series
        return (page.items.map { TitleSummary($0, kind: titleKind) }, page.total)
    }

    /// The genres that have titles of the kind.
    static func genres(of kind: WatchKind, from client: MeleteClient) async -> [String] {
        await (try? client.genres())?
            .filter { kind == .movies ? $0.movies > 0 : $0.series > 0 }
            .map(\.name) ?? []
    }

    static func heading(for kind: WatchKind, total: Int?) -> String {
        let name = switch kind {
        case .home, .shows: "All Shows"
        case .anime: "All Anime"
        case .movies: "All Movies"
        }
        return total.map { "\(name) · \($0)" } ?? name
    }

    static func name(of sort: ListSort) -> String {
        switch sort {
        case .title: "A to Z"
        case .year: "Newest"
        case .recent: "Recently Added"
        }
    }
}
