//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit
import SwiftUI

/// Search: the system keyboard over results in rows.
struct SearchView: View {

    @Environment(Library.self)
    private var library
    @Environment(Router.self)
    private var router

    @State
    private var model: SearchModel?
    @State
    private var query = ""
    /// The title the request page is open for.
    @State
    private var requesting: DiscoverItem?

    var body: some View {
        ScrollView(.vertical) {
            if let model {
                VStack(alignment: .leading, spacing: 48) {
                    if query.trimmingCharacters(in: .whitespaces).isEmpty {
                        start(model)
                    } else {
                        found(model)
                    }
                }
                .padding(.vertical, 40)
            }
        }
        .scrollClipDisabled()
        .searchable(text: $query, prompt: "Movies, shows, or describe what you want")
        // The system draws the field and keyboard at the top of the view,
        // where the tab strip floats; the view starts below the strip instead.
        .padding(.top, HeroLayout.top)
        .task {
            let model = SearchModel(client: library.client)
            self.model = model
            await model.loadStart()
        }
        .task(id: query) {
            await model?.search(query)
        }
        .fullScreenCover(item: $requesting) { item in
            RequestView(item: item, model: model)
        }
    }

    // MARK: - Before typing

    @ViewBuilder
    private func start(_ model: SearchModel) -> some View {
        if !model.requests.isEmpty {
            RequestRow(title: "Your Requests", requests: model.requests)
        }
        if let trending = model.trending {
            if trending.isEmpty {
                MeleteGapNotice(
                    feature: "Trending",
                    detail: "Shown once discovery is turned on in Melete (MELETE_DISCOVERY)."
                )
            } else {
                DiscoverRow(title: "Trending", items: trending) { requesting = $0 }
            }
        }
    }

    // MARK: - Results

    @ViewBuilder
    private func found(_ model: SearchModel) -> some View {
        if model.aiEnabled {
            askButton(model)
        }

        if let ai = model.ai {
            if !ai.movies.isEmpty {
                TileRow(title: "Movies for \u{201C}\(ai.query)\u{201D}", items: ai.movies, shape: .portrait, open: router.open)
            }
            if !ai.shows.isEmpty {
                TileRow(title: "Shows for \u{201C}\(ai.query)\u{201D}", items: ai.shows, shape: .portrait, open: router.open)
            }
            if ai.movies.isEmpty, ai.shows.isEmpty {
                Text("Nothing in the library fits that description.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, RowLayout.edge)
            }
        }

        let results = model.results
        if !results.movies.isEmpty {
            TileRow(title: "Movies", items: results.movies, shape: .portrait, open: router.open)
        }
        if !results.shows.isEmpty {
            TileRow(title: "Shows", items: results.shows, shape: .portrait, open: router.open)
        }
        if !results.elsewhere.isEmpty {
            DiscoverRow(title: "Not in the Library", items: results.elsewhere) { requesting = $0 }
        }
        if results.movies.isEmpty, results.shows.isEmpty, results.elsewhere.isEmpty, !model.isSearching, model.ai == nil {
            Text("No matches for \u{201C}\(query)\u{201D}.")
                .foregroundStyle(.secondary)
                .padding(.horizontal, RowLayout.edge)
        }
    }

    @ViewBuilder
    private func askButton(_ model: SearchModel) -> some View {
        HStack(spacing: 24) {
            HeroActionButton(
                title: model.isAsking ? "Asking…" : "Find by Description",
                systemImage: "sparkles",
                isProminent: false
            ) {
                Task { await model.ask(query) }
            }
            .disabled(model.isAsking)

            if let error = model.aiError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, RowLayout.edge)
    }
}
