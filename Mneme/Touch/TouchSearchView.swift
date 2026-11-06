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

/// Search on a touch screen: the tab's own search field over rows. Before
/// typing, the viewer's requests and what is trending; while typing, titles
/// in the library and on TMDB, and Find by Description when the server has AI
/// on. The same `SearchModel` as the Apple TV's page.
struct TouchSearchView: View {

    @Environment(Library.self)
    private var library
    @Environment(Router.self)
    private var router

    @State
    private var model: SearchModel?
    @State
    private var query = ""
    /// The title the request sheet is open for.
    @State
    private var requesting: DiscoverItem?

    private var isTyping: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView(.vertical) {
            if let model {
                VStack(alignment: .leading, spacing: 28) {
                    if isTyping {
                        found(model)
                    } else {
                        start(model)
                    }
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LoadingMark()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color.mnemePageBackground.ignoresSafeArea())
        .navigationTitle("Search")
        .searchable(text: $query, prompt: "Movies, shows, or describe what you want")
        .refreshable {
            await model?.loadStart()
        }
        .task {
            let model = SearchModel(client: library.client)
            self.model = model
            await model.loadStart()
        }
        .task(id: query) {
            await model?.search(query)
        }
        .sheet(item: $requesting) { item in
            TouchRequestView(item: item, model: model)
        }
    }

    // MARK: - Before typing

    @ViewBuilder
    private func start(_ model: SearchModel) -> some View {
        // The stream's copy once it has sent one: it follows each request
        // as it downloads.
        let requests = library.requests ?? model.requests
        if !requests.isEmpty {
            TouchPosterRow(title: "Your Requests", items: requests) { request in
                NavigationLink {
                    TouchRequestDetailView(request: request, model: model)
                } label: {
                    TouchPoster(poster: request.poster, title: request.title, caption: RequestRow.status(of: request))
                }
                .buttonStyle(.plain)
            }
        }
        if let trending = model.trending {
            if trending.isEmpty {
                MeleteGapNotice(
                    feature: "Trending",
                    detail: "Shown once discovery is turned on in Melete (MELETE_DISCOVERY)."
                )
            } else {
                TouchPosterRow(title: "Trending", items: trending) { item in
                    Button {
                        requesting = item
                    } label: {
                        TouchPoster(poster: item.poster, title: item.title, caption: Self.caption(of: item))
                    }
                    .buttonStyle(.plain)
                }
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
                TouchTileRow(title: "Movies for \u{201C}\(ai.query)\u{201D}", items: ai.movies, shape: .portrait, open: router.open)
            }
            if !ai.shows.isEmpty {
                TouchTileRow(title: "Shows for \u{201C}\(ai.query)\u{201D}", items: ai.shows, shape: .portrait, open: router.open)
            }
            if ai.movies.isEmpty, ai.shows.isEmpty {
                Text("Nothing in the library fits that description.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, TouchLayout.edge)
            }
        }

        let results = model.results
        if !results.movies.isEmpty {
            TouchTileRow(title: "Movies", items: results.movies, shape: .portrait, open: router.open)
        }
        if !results.shows.isEmpty {
            TouchTileRow(title: "Shows", items: results.shows, shape: .portrait, open: router.open)
        }
        if !results.elsewhere.isEmpty {
            elsewhere(results.elsewhere)
        }

        if results.movies.isEmpty, results.shows.isEmpty, results.elsewhere.isEmpty, model.ai == nil {
            if model.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            } else {
                ContentUnavailableView.search(text: query.trimmingCharacters(in: .whitespaces))
                    .padding(.top, 40)
            }
        }
    }

    private func askButton(_ model: SearchModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { await model.ask(query) }
            } label: {
                Label(model.isAsking ? "Asking…" : "Find by Description", systemImage: "sparkles")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(model.isAsking)

            if let error = model.aiError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, TouchLayout.edge)
    }

    /// Titles from TMDB as a list rather than posters: each says plainly
    /// whether it has been asked for, which a poster's caption does not.
    private func elsewhere(_ items: [DiscoverItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Not in the Library")
                .font(.title3.bold())
                .padding(.horizontal, TouchLayout.edge)

            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    Button {
                        requesting = item
                    } label: {
                        TouchDiscoverRow(item: item)
                    }
                    .buttonStyle(.plain)
                    if item.id != items.last?.id {
                        Divider()
                            .padding(.leading, TouchLayout.edge + TouchDiscoverRow.posterWidth + 12)
                    }
                }
            }
        }
    }

    /// "Requested", or the year.
    static func caption(of item: DiscoverItem) -> String? {
        item.state == .requested ? "Requested" : item.year.map(String.init)
    }
}

/// A title from TMDB: its poster, name, year and whether it can be asked for.
private struct TouchDiscoverRow: View {

    let item: DiscoverItem

    static let posterWidth: CGFloat = 46

    var body: some View {
        HStack(spacing: 12) {
            TouchPosterImage(poster: item.poster, title: item.title)
                .frame(width: Self.posterWidth, height: Self.posterWidth * 3 / 2)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                Text([item.kind == .movie ? "Movie" : "Series", item.year.map(String.init)].compactMap(\.self).joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            state
        }
        .padding(.horizontal, TouchLayout.edge)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the request")
    }

    @ViewBuilder
    private var state: some View {
        switch item.state {
        case .requestable:
            Label("Request", systemImage: "plus.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.mnemeCyan)
        case .requested:
            Label("Requested", systemImage: "checkmark.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .playable:
            Label("In the Library", systemImage: "play.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
#endif
