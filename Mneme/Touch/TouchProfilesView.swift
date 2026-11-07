//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

#if os(iOS)
import SwiftUI

/// Who is watching, on a touch screen: the people signed in on this device
/// and a way to add another, then the current profile's picture, Settings
/// and signing out.
struct TouchProfilesView: View {

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
    @State
    private var confirmsSignOut = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TouchProfileGrid(addProfile: { isAddingProfile = true }, chosen: { dismiss() })
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                }

                Section {
                    if sessions.current != nil {
                        Button {
                            choosesPicture = true
                        } label: {
                            Label("Change Picture", systemImage: "person.crop.square")
                        }
                    }

                    Button {
                        showsSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }

                if let current = sessions.current {
                    Section {
                        Button(role: .destructive) {
                            confirmsSignOut = true
                        } label: {
                            Label("Sign Out of \(current.user.username)", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        .confirmationDialog(
                            "Sign out of \(current.user.username)?",
                            isPresented: $confirmsSignOut,
                            titleVisibility: .visible
                        ) {
                            Button("Sign Out", role: .destructive) {
                                sessions.signOut(current, using: library.client)
                                dismiss()
                            }
                        } message: {
                            Text("This device forgets the profile. Add Profile signs it in again.")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background { PageBackground() }
            .navigationTitle("Who's Watching?")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isAddingProfile) {
            // The Apple TV leaves sign-in with the remote's Back; a touch
            // screen needs a way out on the screen.
            NavigationStack {
                SignInFlow()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(role: .cancel) {
                                isAddingProfile = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showsSettings) {
            SettingsView()
        }
        .sheet(isPresented: $choosesPicture) {
            if let current = sessions.current, let client = sessions.client(for: current) {
                TouchAvatarPickerView(session: current, client: client)
            }
        }
    }
}

/// The profiles signed in on this device, each opening the app as them, two
/// to a row on a phone and four on a wide screen.
struct TouchProfileGrid: View {

    @Environment(SessionStore.self)
    private var sessions
    @Environment(\.horizontalSizeClass)
    private var sizeClass

    /// Offers Add Profile after the profiles when given.
    var addProfile: (() -> Void)?
    let chosen: () -> Void

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 24) {
            ForEach(sessions.sessions) { session in
                ProfileButton(session: session, isCurrent: session.id == sessions.current?.id) {
                    sessions.switchTo(session)
                    chosen()
                }
            }

            if let addProfile {
                Button(action: addProfile) {
                    VStack(spacing: ProfileTileMetrics.spacing) {
                        Image(systemName: "plus")
                            .font(.largeTitle.weight(.semibold))
                            .frame(width: ProfileTileMetrics.edge, height: ProfileTileMetrics.edge)
                            .background(
                                Color(white: 0.15),
                                in: RoundedRectangle(cornerRadius: ProfileTileMetrics.radius, style: .continuous)
                            )
                            .accessibilityHidden(true)
                        Text("Add Profile")
                    }
                }
                .buttonStyle(ProfileTileStyle())
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Fixed widths, as many as there are tiles up to a row's worth, so a
    /// few profiles sit together in the middle rather than to one side.
    private var columns: [GridItem] {
        let tiles = sessions.sessions.count + (addProfile == nil ? 0 : 1)
        let perRow = min(max(tiles, 1), sizeClass == .regular ? 4 : 2)
        return Array(repeating: GridItem(.fixed(ProfileTileMetrics.edge), spacing: 24, alignment: .top), count: perRow)
    }
}
#endif
