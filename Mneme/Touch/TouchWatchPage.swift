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

/// Home on a touch screen: Home, Movies, Shows or Anime chosen at the top,
/// then the hero's picks to swipe through, then the rows. The same sections
/// as the Apple TV's pages (`WatchSections`), laid out for a hand.
struct TouchWatchPage: View {

    @Environment(Library.self)
    private var library
    @Environment(Router.self)
    private var router

    let session: Session
    @Binding
    var showsProfiles: Bool

    @State
    private var kind: WatchKind = .home

    private static let kinds: [WatchKind] = [.home, .movies, .shows, .anime]

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 28) {
                Picker("Show", selection: $kind) {
                    ForEach(Self.kinds, id: \.self) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, TouchLayout.edge)

                sections
            }
            .padding(.bottom, 32)
        }
        .refreshable {
            await library.load()
        }
        .background(Color.mnemePageBackground.ignoresSafeArea())
        .navigationTitle(kind.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AccountButton(user: session.user) { showsProfiles = true }
            }
        }
        .task(id: kind) {
            await library.loadPage(kind)
        }
    }

    @ViewBuilder
    private var sections: some View {
        switch library.home {
        case .loading:
            LoadingMark()
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
        case let .failed(error):
            FailureView(title: "Couldn't load \(kind.title)", error: error) {
                Task { await library.load() }
            }
        case let .loaded(home):
            let sections = WatchSections(
                home: library.pageHomes[kind] ?? home,
                kind: kind,
                kindOf: library.kind(of:),
                becauseYouWatched: library.becauseYouWatched
            )

            if !sections.picks.isEmpty {
                TouchHero(picks: sections.picks)
            }

            ForEach(sections.rows) { row in
                TouchTileRow(
                    title: row.title,
                    items: row.items,
                    shape: row.shape,
                    open: { select($0, in: row) },
                    goToTitle: row.shape == .landscape ? { router.open($0) } : nil
                )
            }
        }
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

/// The signed-in person's picture, or their initial, opening Who's Watching.
private struct AccountButton: View {

    let user: User
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ArtworkImage(path: user.avatarUrl) {
                Text(String(user.username.prefix(1)).uppercased())
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(white: 0.25))
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profiles")
    }
}

/// The measures the touch screens share.
enum TouchLayout {
    /// The margin at either side of the page.
    static let edge: CGFloat = 16
}
#endif
