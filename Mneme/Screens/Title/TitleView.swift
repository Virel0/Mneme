//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit
import SwiftUI

/// A title's page: a header on the title's own backdrop with Play, Mark
/// Watched and My List, and for a series its seasons and episodes.
struct TitleView: View {

    @Environment(Library.self)
    private var library
    @Environment(Router.self)
    private var router

    @State
    private var model: TitleModel?

    let summary: TitleSummary

    var body: some View {
        ZStack(alignment: .top) {
            Color.mnemePageBackground.ignoresSafeArea()

            if let model {
                if let error = model.error {
                    FailureView(title: "Couldn't load \(summary.title)", error: error) {
                        Task { await model.load() }
                    }
                } else {
                    page(model)
                }
            }
        }
        .task {
            let model = TitleModel(summary: summary, library: library)
            self.model = model
            await model.load()
        }
    }

    @ViewBuilder
    private func page(_ model: TitleModel) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 60) {
                TitleHeader(model: model)

                if model.summary.kind == .series {
                    EpisodePicker(model: model)
                }
            }
            .padding(.bottom, 80)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Part of what scrolls, so it moves up and away with the header
            // instead of staying behind the episodes.
            .background(alignment: .top) {
                FocusedBackdrop(path: model.summary.backdrop, focus: model.summary.backdropFocus)
                    .frame(height: TitleLayout.backdropHeight)
                    .overlay {
                        LinearGradient(
                            colors: [Color.mnemePageBackground.opacity(0.9), Color.mnemePageBackground.opacity(0.3), .clear],
                            startPoint: .leading,
                            endPoint: .init(x: 0.7, y: 0.5)
                        )
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.35),
                                .init(color: Color.mnemePageBackground, location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        // The page keeps its own 60-point margins, as every row does, rather
        // than tvOS's wider safe area on top of them.
        .ignoresSafeArea(edges: [.top, .horizontal])
    }
}

/// The logo, the facts, the overview, and what can be done with the title.
private struct TitleHeader: View {

    @Environment(Library.self)
    private var library
    @Environment(Router.self)
    private var router

    let model: TitleModel

    private var summary: TitleSummary {
        model.summary
    }

    private var facts: String {
        var parts = [summary.facts]
        if let series = model.series {
            let count = model.seasonList.filter { $0.season > 0 }.count
            if count > 0 {
                parts.append(count == 1 ? "1 season" : "\(count) seasons")
            }
            if let status = series.status {
                parts.append(status)
            }
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            TitleLogo(entry: summary, maxWidth: 640, maxHeight: 200, fontSize: 70)

            Text(facts)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.9))

            if let overview = summary.overview, !overview.isEmpty {
                Text(overview)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(4)
                    .frame(maxWidth: 1000, alignment: .leading)
            }

            HStack(spacing: 18) {
                HeroActionButton(title: model.target?.label ?? "Play", systemImage: "play.fill", isProminent: true) {
                    if let target = model.target {
                        router.play(target)
                    }
                }
                .disabled(model.target == nil)

                HeroActionButton(
                    title: model.isTitleWatched ? "Watched" : (summary.kind == .series ? "Mark All Watched" : "Mark Watched"),
                    systemImage: model.isTitleWatched ? "checkmark.circle.fill" : "checkmark.circle",
                    isProminent: false
                ) {
                    Task { await model.setTitleWatched(!model.isTitleWatched) }
                }

                HeroActionButton(
                    title: "My List",
                    systemImage: library.isFavourite(summary.ref) ? "checkmark" : "plus",
                    isProminent: false
                ) {
                    Task { await library.toggleFavourite(summary.ref) }
                }
            }
            .padding(.top, 16)
            .focusSection()
        }
        .padding(.horizontal, RowLayout.edge)
        .padding(.top, TitleLayout.headerTop)
        .shadow(color: .black.opacity(0.4), radius: 12)
    }
}

enum TitleLayout {
    static let backdropHeight: CGFloat = 1080
    /// The header sits low on the backdrop, as a poster's title does.
    static let headerTop: CGFloat = 420
}
