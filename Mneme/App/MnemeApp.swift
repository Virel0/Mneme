//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI

@main
struct MnemeApp: App {

    @State
    private var sessions = SessionStore()
    @State
    private var away = AwayFromHome()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(sessions)
                .environment(away)
                .preferredColorScheme(.dark)
        }
        .hearsDownloads()
    }
}

private extension Scene {

    /// Downloads go on with the app closed; the system wakes it to say how
    /// they ended. The Apple TV keeps none.
    func hearsDownloads() -> some Scene {
        #if os(iOS)
        backgroundTask(.urlSession(DownloadTransfer.sessionIdentifier)) {
            await DownloadTransfer.hearBackgroundEvents()
        }
        #else
        self
        #endif
    }
}

struct RootView: View {

    @Environment(SessionStore.self)
    private var sessions
    @Environment(AwayFromHome.self)
    private var away
    @Environment(\.scenePhase)
    private var scenePhase

    /// Where the current session's server was found, when this device has
    /// a tunnel to it: at home or through the tunnel.
    @State
    private var reached: Reached?

    private struct Reached: Equatable {
        let session: String
        let address: URL
    }

    /// Whether "Who's watching?" has been answered since the app opened.
    @State
    private var hasChosen = false

    /// A phone or tablet opens without the intro: it plays with sound, and a
    /// phone is often opened where sound is not wanted.
    @State
    private var introIsOver = Self.skipsIntro

    #if os(tvOS)
    private static let skipsIntro = false
    #else
    private static let skipsIntro = true
    #endif

    var body: some View {
        ZStack {
            screen
                // Nothing behind the intro can take focus, so every press
                // reaches the intro and skips it.
                    .disabled(!introIsOver)
                    // The app comes up out of the intro's dark, settling from a
                    // little larger, as the intro fades.
                    .opacity(introIsOver ? 1 : 0)
                    .scaleEffect(introIsOver ? 1 : 1.04)

            if !introIsOver {
                LaunchIntro {
                    withAnimation(.easeInOut(duration: 1.0)) { introIsOver = true }
                }
                .transition(.opacity)
            }
        }
        // Looked for again each time the app comes forward, as the device
        // may have left home or come back since.
        .task(id: WayKey(session: sessions.current?.id, phase: scenePhase)) {
            await findWayIn()
        }
    }

    private struct WayKey: Equatable {
        let session: String?
        let phase: ScenePhase
    }

    /// Where to reach the session's server: its own address, unless this
    /// device has a tunnel to it, in which case only once that's been
    /// looked for.
    private func address(for session: Session) -> URL? {
        guard away.goesAway(from: session.server) else { return session.server }
        return reached?.session == session.id ? reached?.address : nil
    }

    private func findWayIn() async {
        guard scenePhase == .active, let session = sessions.current, away.goesAway(from: session.server) else { return }
        let address = await away.address(for: session.server)
        let found = Reached(session: session.id, address: address)
        if !Task.isCancelled, reached != found {
            reached = found
        }
    }

    @ViewBuilder
    private var screen: some View {
        if sessions.asksWhoIsWatching, !hasChosen {
            #if os(tvOS)
            WhoIsWatchingView { hasChosen = true }
            #else
            TouchWhoIsWatchingView { hasChosen = true }
            #endif
        } else if let session = sessions.current, let address = address(for: session),
                  let client = sessions.client(for: session, at: address)
        {
            // Keyed on the session, so switching profiles starts the app afresh
            // for the new person rather than showing them someone else's
            // pages; and on the way in, which a new place changes.
            #if os(tvOS)
            MainView(session: session, library: Library(client: client, sessionID: session.id))
                .id("\(session.id) \(address)")
            #else
            TouchMainView(session: session, library: Library(client: client, sessionID: session.id))
                .id("\(session.id) \(address)")
            #endif
        } else if let session = sessions.current, address(for: session) == nil {
            // A few seconds at most, while home is tried.
            ProgressView()
        } else {
            SignInFlow()
        }
    }
}
