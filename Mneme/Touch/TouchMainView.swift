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

/// The signed-in app on iPhone and iPad: tabs along the bottom, or a sidebar
/// on a wide iPad, each with a navigation stack of its own.
///
/// Four tabs rather than the Apple TV's seven, and Downloads as a fifth
/// while there are any: a phone's tab bar holds five before it folds the
/// rest under More, so Movies, Shows and Anime are a switch at the top of
/// Home instead.
struct TouchMainView: View {

    let session: Session

    @State
    private var library: Library
    @State
    private var colours: ArtworkColours
    @State
    private var selected: TouchTab = .home
    @State
    private var showsProfiles = false

    @Environment(SessionStore.self)
    private var sessions

    init(session: Session, library: Library) {
        self.session = session
        _library = State(initialValue: library)
        _colours = State(initialValue: ArtworkColours(client: library.client))
    }

    private var hasDownloads: Bool {
        !DownloadStore.shared.downloads(for: session.id).isEmpty
    }

    var body: some View {
        TabView(selection: $selected) {
            Tab("Home", systemImage: "house", value: TouchTab.home) {
                TouchStack {
                    TouchWatchPage(session: session, showsProfiles: $showsProfiles)
                }
            }

            Tab("My List", systemImage: "checkmark.circle", value: TouchTab.myList) {
                TouchStack { TouchMyListView() }
            }

            Tab("Requests", systemImage: "tray.and.arrow.down", value: TouchTab.requests) {
                TouchStack { TouchRequestsView() }
            }

            // Only while there is something downloaded or on its way.
            if hasDownloads {
                Tab("Downloads", systemImage: "arrow.down.circle", value: TouchTab.downloads) {
                    TouchStack { TouchDownloadsView() }
                }
            }

            Tab(value: TouchTab.search, role: .search) {
                TouchStack { TouchSearchView() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(.white)
        .task {
            DownloadStore.shared.attach(library.client, sessionID: session.id)
            await library.load()
        }
        // The last download removed takes its tab with it.
        .onChange(of: hasDownloads) { _, has in
            if !has, selected == .downloads {
                selected = .home
            }
        }
        .task {
            await library.listen()
        }
        // The user as signed in may have a new name or profile picture since.
        // With no way to the server, the app opens on what is downloaded,
        // the one thing that can be watched.
        .task {
            do throws(MeleteError) {
                let user = try await library.client.me()
                sessions.refresh(session, with: user)
            } catch {
                if case .transport = error, hasDownloads, selected == .home {
                    selected = .downloads
                }
            }
        }
        .fullScreenCover(isPresented: $showsProfiles) {
            // Presented outside the tabs, so the app's white tint is given again.
            TouchProfilesView()
                .tint(.white)
        }
        // Outermost, so what is presented from here has them too.
        .environment(library)
        .environment(colours)
        .environment(\.melete, library.client)
    }
}

enum TouchTab: Hashable {
    case home
    case myList
    case requests
    case downloads
    case search
}

/// One tab's navigation, with a router of its own: a title opened in one tab
/// stays in that tab when another is chosen.
private struct TouchStack<Root: View>: View {

    @State
    private var router = Router()

    let root: Root

    init(@ViewBuilder root: () -> Root) {
        self.root = root()
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            root
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case let .title(summary):
                        TouchTitleView(summary: summary)
                    case let .play(target):
                        TouchPlayerView(target: target)
                    case let .person(id):
                        TouchPersonView(id: id)
                    }
                }
        }
        // Playback starts out of the dark, as on the Apple TV.
        .overlay {
            if router.isCurtainDown {
                Color.black
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .environment(router)
    }
}
#endif
