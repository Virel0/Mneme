//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit
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
    @State
    private var choosesPicture = false

    var body: some View {
        ZStack {
            PageBackground()

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
                        HeroActionButton(title: "Change Picture", systemImage: "person.crop.square", isProminent: false) {
                            choosesPicture = true
                        }

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
        .fullScreenCover(isPresented: $choosesPicture) {
            if let current = sessions.current, let client = sessions.client(for: current) {
                AvatarPickerView(session: current, client: client)
            }
        }
    }

    private func signOut(_ session: Session) {
        sessions.signOut(session, using: library.client)
        dismiss()
    }
}

extension SessionStore {

    /// Ends the session on the server too, so the device stops appearing in
    /// the account's list; the device forgets it whatever the server says.
    func signOut(_ session: Session, using client: MeleteClient) {
        Task {
            try? await client.signOut()
        }
        remove(session)
        #if os(tvOS)
        TopShelfPublisher.clear()
        #endif
    }
}

struct ProfileButton: View {

    @Environment(SessionStore.self)
    private var sessions

    let session: Session
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: ProfileTileMetrics.spacing) {
                // Their profile picture, fetched as them: each profile can be
                // on another server. The initial while it loads, and without one.
                ArtworkImage(path: session.user.avatarUrl) {
                    Text(String(session.user.username.prefix(1)).uppercased())
                        .font(.system(size: ProfileTileMetrics.initial, weight: .bold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(white: isCurrent ? 0.28 : 0.15))
                }
                .environment(\.melete, sessions.client(for: session))
                .frame(width: ProfileTileMetrics.edge, height: ProfileTileMetrics.edge)
                .clipShape(RoundedRectangle(cornerRadius: ProfileTileMetrics.radius, style: .continuous))
                #if os(iOS)
                // Nothing has focus on a touch screen to say who is
                // watching now, so the current profile is ringed.
                .overlay {
                    if isCurrent {
                        RoundedRectangle(cornerRadius: ProfileTileMetrics.radius, style: .continuous)
                            .strokeBorder(.white, lineWidth: 2)
                    }
                }
                #endif
                Text(session.user.username)
                Text(session.server.host() ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        #if os(iOS)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        #endif
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

/// A profile's square: across a room on a television, a thumb's width and
/// more on a phone, where two sit side by side.
enum ProfileTileMetrics {
    #if os(tvOS)
    static let edge: CGFloat = 180
    static let radius: CGFloat = 24
    static let initial: CGFloat = 80
    static let spacing: CGFloat = 16
    #else
    static let edge: CGFloat = 104
    static let radius: CGFloat = 16
    static let initial: CGFloat = 44
    static let spacing: CGFloat = 8
    #endif
}
