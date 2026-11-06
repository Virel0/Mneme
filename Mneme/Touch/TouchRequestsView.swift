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

/// Every film and series the viewer has asked for, in sections by where it
/// has got to, as on the Apple TV's Requests page (`RequestsView.Stage`). It
/// follows the live list, so a download moves along and a title moves
/// between sections as Melete works. Each opens its page.
struct TouchRequestsView: View {

    @Environment(Library.self)
    private var library

    /// Read once, for while the event stream has not yet sent its list.
    @State
    private var loaded: [MediaRequest]?

    /// Music asked for elsewhere is left out, as on the Apple TV: nothing
    /// here plays it.
    private var requests: [MediaRequest]? {
        (library.requests ?? loaded)?.filter(\.isVideo)
    }

    var body: some View {
        Group {
            if let requests {
                if requests.isEmpty {
                    ContentUnavailableView(
                        "No Requests",
                        systemImage: "tray",
                        description: Text(
                            "Find a movie or a show in Search that isn't in the library, and ask for it. It will be here while it's on its way."
                        )
                    )
                } else {
                    list(requests)
                }
            } else {
                LoadingMark()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.mnemePageBackground.ignoresSafeArea())
        .navigationTitle("Requests")
        .task {
            guard library.requests == nil else { return }
            loaded = await (try? library.client.requests(limit: 200))?.items ?? []
        }
    }

    private func list(_ requests: [MediaRequest]) -> some View {
        List {
            ForEach(RequestsView.Stage.allCases, id: \.self) { stage in
                let inStage = requests.filter { RequestsView.Stage(of: $0) == stage }
                if !inStage.isEmpty {
                    Section(stage.title) {
                        ForEach(inStage) { request in
                            NavigationLink {
                                TouchRequestDetailView(request: request, model: nil)
                            } label: {
                                TouchRequestRow(request: request)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

/// A request in a list: its poster, title, how it is getting on, and a bar
/// while it downloads or copies home.
struct TouchRequestRow: View {

    let request: MediaRequest

    var body: some View {
        HStack(spacing: 12) {
            TouchPosterImage(poster: request.poster, title: request.title)
                .frame(width: 46, height: 69)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(request.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                Text(RequestRow.status(of: request))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let fraction = Self.fraction(of: request) {
                    ProgressView(value: fraction)
                        .tint(Color.mnemeCyan)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// How far a download or a copy home has got, while one is under way.
    static func fraction(of request: MediaRequest) -> Double? {
        guard request.state == "approved", let progress = request.progress else { return nil }
        if let copied = progress.copied, copied.total > 0 {
            return min(max(Double(copied.bytes) / Double(copied.total), 0), 1)
        }
        if progress.step == "downloading", let percent = progress.percent {
            return min(max(percent / 100, 0), 1)
        }
        return nil
    }
}
#endif
