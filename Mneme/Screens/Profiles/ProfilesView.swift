//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI

/// Who is watching: the people signed in on this Apple TV, a way to add
/// another, and signing out.
struct ProfilesView: View {

    @Environment(SessionStore.self)
    private var sessions
    @Environment(Library.self)
    private var library
    @Environment(\.dismiss)
    private var dismiss

    @State
    private var isAddingProfile = false
    @State
    private var showsSettings = false

    var body: some View {
        ZStack {
            Color.mnemePageBackground.ignoresSafeArea()

            VStack(spacing: 60) {
                Text("Who's watching?")
                    .font(.title.bold())

                HStack(spacing: 48) {
                    ForEach(sessions.sessions) { session in
                        ProfileButton(session: session, isCurrent: session.id == sessions.current?.id) {
                            sessions.switchTo(session)
                            dismiss()
                        }
                    }

                    Button {
                        isAddingProfile = true
                    } label: {
                        VStack(spacing: 16) {
                            Image(systemName: "plus")
                                .font(.system(size: 60, weight: .semibold))
                                .frame(width: 180, height: 180)
                                .background(Color(white: 0.15), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            Text("Add Profile")
                        }
                    }
                    .buttonStyle(ProfileTileStyle())
                }

                HStack(spacing: 24) {
                    HeroActionButton(title: "Settings", systemImage: "gearshape", isProminent: false) {
                        showsSettings = true
                    }

                    if let current = sessions.current {
                        HeroActionButton(
                            title: "Sign Out of \(current.user.username)",
                            systemImage: "rectangle.portrait.and.arrow.right",
                            isProminent: false
                        ) {
                            signOut(current)
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isAddingProfile) {
            SignInFlow()
        }
        .fullScreenCover(isPresented: $showsSettings) {
            SettingsView()
        }
    }

    /// Ends the session on the server too, so the device stops appearing in
    /// the account's list; the device forgets it whatever the server says.
    private func signOut(_ session: Session) {
        let client = library.client
        Task {
            try? await client.signOut()
        }
        sessions.remove(session)
        TopShelfPublisher.clear()
        dismiss()
    }
}

struct ProfileButton: View {

    let session: Session
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Text(String(session.user.username.prefix(1)).uppercased())
                    .font(.system(size: 80, weight: .bold))
                    .frame(width: 180, height: 180)
                    .background(Color(white: isCurrent ? 0.28 : 0.15), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                Text(session.user.username)
                Text(session.server.host() ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(ProfileTileStyle())
    }
}

/// A profile's square grows and lifts when focused; the system's
/// borderless style drew a second plate around the glyph inside it.
struct ProfileTileStyle: ButtonStyle {

    @Environment(\.isFocused)
    private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.1 : 1))
            .shadow(color: .black.opacity(isFocused ? 0.5 : 0), radius: 16, y: 8)
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}
