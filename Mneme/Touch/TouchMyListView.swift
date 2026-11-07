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

/// Every title on My List, newest first, as posters; a long press takes one
/// off. Loaded as the Apple TV's list is (`MyListView.load`).
struct TouchMyListView: View {

    @Environment(Library.self)
    private var library
    @Environment(Router.self)
    private var router

    @State
    private var items: [TitleSummary]?

    var body: some View {
        content
            .background(Color.mnemePageBackground.ignoresSafeArea())
            .navigationTitle("My List")
            // Reloaded whenever My List changes anywhere in the app.
            .task(id: library.favouritesVersion) {
                // As on the Apple TV, a list that can't be fetched keeps what
                // it showed, or shows as empty.
                items = await MyListView.load(from: library.client) ?? items ?? []
            }
    }

    @ViewBuilder
    private var content: some View {
        if let items {
            if items.isEmpty {
                ArtPage(
                    art: "ArtMyListEmpty",
                    title: "Nothing on My List",
                    message: "Add a movie or a show with the + on its page, and it will be here."
                )
            } else {
                grid(items)
            }
        } else {
            LoadingMark()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func grid(_ items: [TitleSummary]) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                Text(items.count == 1 ? "1 title" : "\(items.count) titles")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, TouchLayout.edge)

                TouchPosterGrid { width in
                    ForEach(items) { item in
                        tile(item, width: width)
                    }
                }
            }
            .padding(.vertical, 16)
        }
    }

    private func tile(_ item: TitleSummary, width: CGFloat) -> some View {
        Button {
            router.open(item)
        } label: {
            TouchTile(summary: item, shape: .portrait, width: width)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .contextMenu {
            if library.isFavourite(item.ref) {
                Button("Remove from My List", systemImage: "minus.circle", role: .destructive) {
                    Task { await library.toggleFavourite(item.ref) }
                }
            }
        }
    }
}
#endif
