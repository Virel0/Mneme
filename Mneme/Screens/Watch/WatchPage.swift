//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit
import SwiftUI

/// Home, Shows, Anime or Movies: the hero over rows, and on the kind pages
/// every title of the kind under them.
struct WatchPage: View {

    @Environment(Library.self)
    private var library
    @Environment(Router.self)
    private var router

    @State
    private var spotlight = TileSpotlight()

    let kind: WatchKind

    var body: some View {
        ZStack {
            TileSpotlightView(spotlight: spotlight)
                .ignoresSafeArea()

            switch library.home {
            case .loading:
                ProgressView()
            case let .failed(error):
                FailureView(title: "Couldn't load \(kind.title)", error: error) {
                    Task { await library.load() }
                }
            case let .loaded(home):
                content(WatchSections(home: home, kind: kind, kindOf: library.kind(of:), becauseYouWatched: library.becauseYouWatched))
            }
        }
        .environment(\.tileSpotlight, spotlight)
    }

    @ViewBuilder
    private func content(_ sections: WatchSections) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 48) {
                if !sections.picks.isEmpty {
                    HeroBillboard(picks: sections.picks, open: router.open, play: router.play)
                        .padding(.top, HeroLayout.top)
                }

                ForEach(sections.rows) { row in
                    TileRow(title: row.title, items: row.items, shape: row.shape) { item in
                        select(item, in: row)
                    }
                }

                if kind == .home {
                    MeleteGapNotice(
                        feature: "Featured for You",
                        detail: "Picks chosen for each viewer need a recommendations endpoint in Melete."
                    )
                } else {
                    AllTitlesGrid(kind: kind)
                }
            }
            .padding(.bottom, 120)
            .padding(.top, sections.picks.isEmpty ? HeroLayout.top : 0)
            .overlay(alignment: .top) { PageTop() }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .modifier(ScrollsToTopOnRequest())
        .mask { SpotlightMask(spotlight: spotlight) }
        // The page keeps its own 60-point margins, as every row does, rather
        // than tvOS's wider safe area on top of them.
        .ignoresSafeArea(edges: [.top, .horizontal])
    }

    /// A wide tile plays what it is about; a poster opens its title.
    private func select(_ item: TitleSummary, in row: WatchSections.Row) {
        if row.shape == .landscape, let target = PlayTarget.known(for: item) {
            router.play(target)
        } else {
            router.open(item)
        }
    }
}

/// While a tile is focused, the page fades out above its row so rows
/// scrolled up past it do not draw over the spotlight's text. In window
/// points, where the spotlight's own lines are.
struct SpotlightMask: View {

    let spotlight: TileSpotlight

    var body: some View {
        GeometryReader { proxy in
            let top = proxy.frame(in: .global).minY
            let fade = TileSpotlightLayout.fade(forRowTop: spotlight.rowTop, lift: spotlight.fadeLift)
            let fadeTop = spotlight.entry == nil ? -1000 : fade.lowerBound - top
            let fadeBottom = spotlight.entry == nil ? -1000 : fade.upperBound - top

            VStack(spacing: 0) {
                Color.clear
                    .frame(height: max(0, fadeTop))
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: max(0, fadeBottom - max(0, fadeTop)))
                Color.black
            }
            .animation(.easeInOut(duration: 0.3), value: spotlight.entry == nil)
        }
        .ignoresSafeArea()
    }
}

struct FailureView: View {

    let title: String
    let error: MeleteError
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.title2)
            Text(error.localizedDescription)
                .foregroundStyle(.secondary)
            Button("Try Again", action: retry)
        }
    }
}
