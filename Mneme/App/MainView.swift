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
    private var colours: ArtworkColours
    @State
    private var router = Router()
    @State
    private var selected: AppTab = .home
    @State
    private var showsProfiles = false

    @FocusState
    private var stripFocus: NavStripFocus?

    @Environment(\.isEnabled)
    private var isEnabled
    @Environment(\.scenePhase)
    private var scenePhase

    /// Home left alone long enough shows the hero's picks full screen.
    @State
    private var isCinematic = false
    @State
    private var lastActivity = Date.now
    @State
    private var cinematicSince = Date.distantPast
    private static let idleAfter: TimeInterval = 45

    /// Raised each time focus arrives in the strip from the page, which
    /// scrolls the page back to its top under it.
    @State
    private var topRequest = 0

    init(session: Session, library: Library) {
        self.session = session
        _library = State(initialValue: library)
        _colours = State(initialValue: ArtworkColours(client: library.client))
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            // The page inside a container that stays the same view while the
            // page is swapped. With the strip attached to the page itself,
            // changing tab rebuilt the strip and focus fell to its first button.
            ZStack {
                page
                    .id(selected)
                    .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.3), value: selected)
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
            .background(PageBackground())
            .navigationDestination(for: Route.self) { route in
                switch route {
                case let .title(summary):
                    TitleView(summary: summary)
                case let .play(target):
                    PlayerView(target: target)
                case let .person(id):
                    PersonView(id: id)
                }
            }
        }
        // Switched off while cinematic, so the press that wakes the screen
        // reaches nothing under it.
        .disabled(isCinematic)
        .overlay {
            if isCinematic {
                CinematicView(picks: heroPicks)
                    .transition(.opacity)
            }
        }
        .background {
            IdleWatcher(catchesMenu: isCinematic, onActivity: noticeActivity)
        }
        .task(id: mayGoCinematic) {
            guard mayGoCinematic else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                if !isCinematic, scenePhase != .background, !heroPicks.isEmpty,
                   Date.now.timeIntervalSince(lastActivity) >= Self.idleAfter
                {
                    cinematicSince = .now
                    withAnimation(.easeInOut(duration: 1.2)) { isCinematic = true }
                }
            }
        }
        .task {
            await library.load()
        }
        .task {
            await library.listen()
        }
        .onAppear(perform: focusStripSoon)
        // Behind the launch intro the page cannot take focus, so it is given
        // again when the intro goes.
        .onChange(of: isEnabled) {
            if isEnabled {
                focusStripSoon()
            }
        }
        .onChange(of: stripFocus) { previous, current in
            if previous == nil, current != nil {
                topRequest += 1
            }
        }
        .environment(\.pageTopRequest, topRequest)
        .environment(\.focusStrip) { stripFocus = .tab(selected) }
        // Top Shelf's links: the title's page, or straight into the player.
        .onOpenURL { url in
            guard let route = DeepLink.route(for: url) else { return }
            showsProfiles = false
            router.path = [route]
        }
        // tvOS crossfades between pages and draws no zoom transition, so a
        // pressed tile's picture is grown over the crossfade here.
        .overlay {
            if let zoom = router.zoom {
                TileZoomView(zoom: zoom, done: router.endZoom)
                    .id(zoom.id)
            }
        }
        // Playback starts out of the dark: the page fades to black, and the
        // player is put in behind it.
        .overlay {
            if router.isCurtainDown {
                Color.black
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $showsProfiles) {
            ProfilesView()
        }
        // Outermost, so what is presented from here — the profiles — has them
        // too; a cover attached outside these crashed for want of the library.
        .environment(library)
        .environment(colours)
        .environment(router)
        .environment(\.melete, library.client)
    }

    /// Only on Home, with nothing open over it.
    private var mayGoCinematic: Bool {
        selected == .home && router.path.isEmpty && !showsProfiles
    }

    private var heroPicks: [TitleSummary] {
        guard case let .loaded(home) = library.home else { return [] }
        return home.hero.map(TitleSummary.init)
    }

    /// A press, a swipe or focus moving. It ends cinematic mode, except in
    /// the moment after it starts, when switching the page off moves focus.
    private func noticeActivity() {
        lastActivity = .now
        guard isCinematic, Date.now.timeIntervalSince(cinematicSince) > 1.5 else { return }
        withAnimation(.easeInOut(duration: 0.6)) { isCinematic = false }
        focusStripSoon()
    }

    /// Start the remote on the current tab. tvOS hands first focus to the
    /// first focusable thing, the profile chip, and `defaultFocus` does not
    /// take on a safe-area inset; so the strip is told directly, a beat late,
    /// once it is in a window.
    private func focusStripSoon() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            stripFocus = .tab(selected)
        }
    }

    @ViewBuilder
    private var page: some View {
        switch selected {
        case .myList:
            MyListView()
        case .search:
            SearchView()
        default:
            if let kind = selected.watchKind {
                WatchPage(kind: kind)
                    .id(kind)
            }
        }
    }
}

extension EnvironmentValues {

    /// Changes when the page should go back to its top, as focus moves up
    /// to the tab strip.
    @Entry
    var pageTopRequest = 0

    /// Puts focus on the current tab, for a page left with nothing to focus.
    @Entry
    var focusStrip: () -> Void = {}
}

/// Scrolls the page to its top when `pageTopRequest` changes: put focus in
/// the strip and the page under it goes back to where it started, instead of
/// leaving rows half under the strip.
struct ScrollsToTopOnRequest: ViewModifier {

    @Environment(\.pageTopRequest)
    private var request

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .onChange(of: request) {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(PageTop.id, anchor: .top)
                    }
                }
        }
    }
}

/// The marker a page puts at its top, for `ScrollsToTopOnRequest`.
struct PageTop: View {

    static let id = "page.top"

    var body: some View {
        Color.clear
            .frame(height: 0)
            .id(Self.id)
    }
}
