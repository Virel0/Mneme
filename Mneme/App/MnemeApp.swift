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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(sessions)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {

    @Environment(SessionStore.self)
    private var sessions

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
    }

    @ViewBuilder
    private var screen: some View {
        if sessions.asksWhoIsWatching, !hasChosen {
            #if os(tvOS)
            WhoIsWatchingView { hasChosen = true }
            #else
            TouchWhoIsWatchingView { hasChosen = true }
            #endif
        } else if let session = sessions.current, let client = sessions.client(for: session) {
            // Keyed on the session, so switching profiles starts the app afresh
            // for the new person rather than showing them someone else's pages.
            #if os(tvOS)
            MainView(session: session, library: Library(client: client, sessionID: session.id))
                .id(session.id)
            #else
            TouchMainView(session: session, library: Library(client: client, sessionID: session.id))
                .id(session.id)
            #endif
        } else {
            SignInFlow()
        }
    }
}
