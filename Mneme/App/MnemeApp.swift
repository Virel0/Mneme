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

    var body: some View {
        if let session = sessions.current, let client = sessions.client(for: session) {
            // Keyed on the session, so switching profiles starts the app afresh
            // for the new person rather than showing them someone else's pages.
            MainView(session: session, library: Library(client: client))
                .id(session.id)
        } else {
            SignInFlow()
        }
    }
}
