//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit
import SwiftUI

/// A title that is not in the library, and asking for it.
///
/// Melete sends a request to an admin, or straight to the wanted list for
/// someone whose requests are let through; either way it shows under Your
/// Requests on Search.
struct RequestView: View {

    @Environment(\.dismiss)
    private var dismiss
    @Environment(Library.self)
    private var library

    let item: DiscoverItem
    /// Search's model, told of a request made here; nil elsewhere.
    let model: SearchModel?

    @State
    private var state: RequestState = .idle

    private enum RequestState: Equatable {
        case idle
        case sending
        case sent(String)
        case failed(String)
    }

    private var alreadyRequested: Bool {
        item.state == .requested
    }

    var body: some View {
        ZStack {
            Color.mnemePageBackground.ignoresSafeArea()

            HStack(alignment: .top, spacing: 70) {
                PosterCard(poster: item.poster, title: item.title, caption: nil, showsLabel: false)
                    .scaleEffect(1.6, anchor: .topLeading)
                    .frame(width: PosterCard.width * 1.6, height: PosterCard.width * 2.4, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 24) {
                    Text(item.title)
                        .font(.system(size: 60, weight: .heavy))
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)

                    Text([item.kind == .movie ? "Movie" : "Series", item.year.map(String.init)].compactMap(\.self).joined(separator: " · "))
                        .foregroundStyle(.secondary)

                    if let overview = item.overview {
                        Text(overview)
                            .lineLimit(6)
                            .frame(maxWidth: 900, alignment: .leading)
                    }

                    action
                        .padding(.top, 20)
                }
            }
            .padding(100)
        }
    }

    @ViewBuilder
    private var action: some View {
        switch state {
        case .idle where alreadyRequested:
            Label("Already Requested", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        case .idle:
            HeroActionButton(
                title: item.kind == .series ? "Request All Seasons" : "Request",
                systemImage: "plus.circle",
                isProminent: true,
                action: send
            )
        case .sending:
            ProgressView()
        case let .sent(status):
            Label(status, systemImage: "checkmark.circle.fill")
        case let .failed(message):
            VStack(alignment: .leading, spacing: 16) {
                Text(message)
                    .foregroundStyle(.red)
                HeroActionButton(title: "Try Again", systemImage: "arrow.clockwise", isProminent: false, action: send)
            }
        }
    }

    private func send() {
        state = .sending
        Task {
            do {
                let made = try await library.client.request(NewRequest(kind: item.kind, tmdbId: item.tmdbId))
                model?.add(made)
                state = .sent(made.state == "approved" ? "Requested and on its way" : "Requested: waiting for approval")
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }
}
