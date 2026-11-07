//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

#if os(iOS)
import MeleteKit
import SwiftUI

/// Every title of a kind, A to Z or as chosen, as posters under the rows of
/// Movies, Shows or Anime. The same pages as the Apple TV's grid
/// (`AllTitlesGrid`), fetched as the end of what is loaded scrolls in.
struct TouchAllTitlesGrid: View {

    @Environment(Library.self)
    private var library
    @Environment(Router.self)
    private var router

    let kind: WatchKind

    @State
    private var items: [TitleSummary] = []
    @State
    private var total: Int?
    /// Which reset of the grid a page is being fetched for, while one is.
    @State
    private var loading: Int?
    /// Counts the grid's resets. A page asked for before the latest one
    /// belongs to another order or genre, and is dropped when it comes.
    @State
    private var generation = 0

    private var isLoading: Bool {
        loading != nil
    }

    @State
    private var sort: ListSort = .title
    /// Nil for every genre.
    @State
    private var genre: String?
    @State
    private var genres: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // On one line where there is room, else the choices go under
            // the heading.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    heading
                    Spacer(minLength: 0)
                    choices
                }
                VStack(alignment: .leading, spacing: 2) {
                    heading
                    choices
                }
            }
            .padding(.horizontal, TouchLayout.edge)

            TouchPosterGrid { width in
                ForEach(items) { item in
                    Button {
                        router.open(item)
                    } label: {
                        TouchTile(summary: item, shape: .portrait, width: width)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                    .onAppear {
                        if item.ref == items.last?.ref {
                            Task { await loadMore() }
                        }
                    }
                }
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
        // Again from the start when titles come or go, or the order or
        // genre changes.
        .task(id: Reload(version: library.libraryVersion, sort: sort, genre: genre)) {
            generation += 1
            items = []
            total = nil
            await loadMore()
        }
        .task {
            genres = await AllTitlesGrid.genres(of: kind, from: library.client)
        }
    }

    private var heading: some View {
        Text(AllTitlesGrid.heading(for: kind, total: total))
            .font(.title3.bold())
            .lineLimit(1)
    }

    private var choices: some View {
        HStack(spacing: 20) {
            Menu {
                Picker("Sort", selection: $sort) {
                    Text("A to Z").tag(ListSort.title)
                    Text("Newest").tag(ListSort.year)
                    Text("Recently Added").tag(ListSort.recent)
                }
            } label: {
                choice(AllTitlesGrid.name(of: sort), systemImage: "arrow.up.arrow.down")
            }
            .accessibilityLabel("Sort")
            .accessibilityValue(AllTitlesGrid.name(of: sort))

            Menu {
                Picker("Genre", selection: $genre) {
                    Text("All Genres").tag(String?.none)
                    ForEach(genres, id: \.self) { name in
                        Text(name).tag(String?.some(name))
                    }
                }
            } label: {
                choice(genre ?? "All Genres", systemImage: "line.3.horizontal.decrease")
            }
            .disabled(genres.isEmpty)
            .accessibilityLabel("Genre")
            .accessibilityValue(genre ?? "All Genres")
        }
        .font(.subheadline)
    }

    /// A menu's label, as tall as a fingertip needs.
    private func choice(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .lineLimit(1)
            .frame(minHeight: 44)
            .contentShape(.rect)
    }

    private func loadMore() async {
        let asked = generation
        // Busy only for this reset: a page still coming for the last one
        // mustn't keep the new order's first page from being asked for.
        guard loading != asked, total.map({ items.count < $0 }) ?? true else { return }
        loading = asked
        defer {
            if loading == asked {
                loading = nil
            }
        }

        guard let page = await AllTitlesGrid.page(of: kind, from: library.client, genre: genre, sort: sort, offset: items.count),
              asked == generation
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
#endif
