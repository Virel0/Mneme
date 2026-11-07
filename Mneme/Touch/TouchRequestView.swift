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

/// A title that is not in the library, and asking for it, as a sheet over
/// Search: the touch counterpart of `RequestView`. A series can be asked for
/// whole or one season at a time, as there.
struct TouchRequestView: View {

    @Environment(\.dismiss)
    private var dismiss
    @Environment(Library.self)
    private var library
    @Environment(\.horizontalSizeClass)
    private var sizeClass

    let item: DiscoverItem
    /// Search's model, told of a request made here; nil elsewhere.
    let model: SearchModel?

    @State
    private var state: RequestState = .idle
    /// The season last asked for, so Try Again asks for the same.
    @State
    private var season: Int?

    private enum RequestState: Equatable {
        case idle
        case sending
        case sent(String)
        case failed(String)
    }

    private var posterWidth: CGFloat {
        sizeClass == .regular ? 180 : 120
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 16) {
                        TouchPosterImage(poster: item.poster, title: item.title)
                            .frame(width: posterWidth, height: posterWidth * 3 / 2)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.title2.bold())
                            Text(facts)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    action

                    if let overview = item.overview {
                        Text(overview)
                            .font(.body)
                    }
                }
                .padding(TouchLayout.edge)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.mnemePageBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isSent ? "Done" : "Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// "Series · 2019".
    private var facts: String {
        [item.kind == .movie ? "Movie" : "Series", item.year.map(String.init)].compactMap(\.self).joined(separator: " · ")
    }

    private var isSent: Bool {
        if case .sent = state {
            true
        } else {
            false
        }
    }

    @ViewBuilder
    private var action: some View {
        switch state {
        case .idle where item.state == .requested:
            Label("Already Requested", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        case .idle:
            choices
        case .sending:
            ProgressView("Requesting…")
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
        case let .sent(status):
            Label(status, systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(Color.mnemeCyan)
        case let .failed(message):
            VStack(alignment: .leading, spacing: 12) {
                Text(message)
                    .foregroundStyle(.red)
                Button {
                    send(season: season)
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    private var choices: some View {
        VStack(spacing: 10) {
            Button {
                send(season: nil)
            } label: {
                Label(item.kind == .series ? "Request All Seasons" : "Request", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)

            if item.kind == .series {
                // A menu rather than the Apple TV's dialog: twenty-odd
                // choices read better as a list that scrolls than as a
                // column of buttons over the page.
                Menu {
                    SeasonChoices { send(season: $0) }
                } label: {
                    Label("Request One Season", systemImage: "list.number")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .controlSize(.large)
    }

    private func send(season: Int?) {
        self.season = season
        state = .sending
        Task {
            do {
                let made = try await library.client.request(NewRequest(kind: item.kind, tmdbId: item.tmdbId, season: season))
                model?.add(made)
                state = .sent(RequestView.outcome(of: made))
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }
}
#endif
