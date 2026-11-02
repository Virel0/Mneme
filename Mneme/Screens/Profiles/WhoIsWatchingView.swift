//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI

/// The first screen when more than one person is signed in on the Apple
/// TV: pick who is watching, and the app opens as them.
struct WhoIsWatchingView: View {

    @Environment(SessionStore.self)
    private var sessions

    @FocusState
    private var focused: String?

    let chosen: () -> Void

    var body: some View {
        ZStack {
            Color.mnemePageBackground.ignoresSafeArea()

            LoopingVideo(resource: "WhoIsWatching")
                .opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 60) {
                Text("Who's watching?")
                    .font(.title.bold())

                HStack(spacing: 48) {
                    ForEach(sessions.sessions) { session in
                        ProfileButton(session: session, isCurrent: session.id == sessions.current?.id) {
                            sessions.switchTo(session)
                            chosen()
                        }
                        .focused($focused, equals: session.id)
                    }
                }
            }
        }
        // The last person to watch is where focus starts.
        .defaultFocus($focused, sessions.current?.id)
    }
}
