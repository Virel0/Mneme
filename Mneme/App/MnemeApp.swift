//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
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

    @State
    private var introIsOver = false

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
            WhoIsWatchingView { hasChosen = true }
        } else if let session = sessions.current, let client = sessions.client(for: session) {
            // Keyed on the session, so switching profiles starts the app afresh
            // for the new person rather than showing them someone else's pages.
            MainView(session: session, library: Library(client: client, sessionID: session.id))
                .id(session.id)
        } else {
            SignInFlow()
        }
    }
}
