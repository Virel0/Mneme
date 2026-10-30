//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI

/// The signed-in app: the tab strip over the current page, inside one
/// navigation stack.
struct MainView: View {

    let session: Session

    @State
    private var library: Library
    @State
    private var router = Router()
    @State
    private var selected: AppTab = .home
    @State
    private var showsProfiles = false

    @FocusState
    private var stripFocus: NavStripFocus?

    init(session: Session, library: Library) {
        self.session = session
        _library = State(initialValue: library)
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            // The page inside a container that stays the same view while the
            // page is swapped. With the strip attached to the page itself,
            // changing tab rebuilt the strip and focus fell to its first button.
            ZStack { page }
                // Only for Menu pressed in the page: it brings focus up to the
                // strip. On the strip, Menu keeps its system meaning and leaves
                // the app.
                    .onExitCommand {
                        stripFocus = .tab(selected)
                    }
                    .safeAreaInset(edge: .top, spacing: 0) {
                        NavStrip(
                            focused: $stripFocus,
                            selected: selected,
                            userInitial: String(session.user.username.prefix(1)).uppercased(),
                            select: { selected = $0 },
                            openProfile: { showsProfiles = true }
                        )
                    }
                    .background(Color.mnemePageBackground.ignoresSafeArea())
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case let .title(summary):
                            TitleView(summary: summary)
                        case let .play(target):
                            PlayerPlaceholder(target: target)
                        }
                    }
        }
        .task {
            await library.load()
        }
        .onAppear {
            // Start the remote on the tab the app opened to. tvOS hands first
            // focus to the first focusable thing, the profile chip, and
            // `defaultFocus` does not take on a safe-area inset; so the strip
            // is told directly, a beat late, once it is in a window.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                stripFocus = .tab(selected)
            }
        }
        .fullScreenCover(isPresented: $showsProfiles) {
            ProfilesView()
        }
        // Outermost, so what is presented from here — the profiles — has them
        // too; a cover attached outside these crashed for want of the library.
        .environment(library)
        .environment(router)
        .environment(\.melete, library.client)
    }

    @ViewBuilder
    private var page: some View {
        switch selected {
        case .myList:
            MyListView()
        default:
            if let kind = selected.watchKind {
                WatchPage(kind: kind)
                    .id(kind)
            }
        }
    }
}
