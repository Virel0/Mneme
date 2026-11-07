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

/// A new profile picture from the server's gallery, a row to each category.
/// The Apple TV has no photos of its own to upload, so the gallery is all
/// there is to choose from here.
struct AvatarPickerView: View {

    @Environment(SessionStore.self)
    private var sessions
    @Environment(\.dismiss)
    private var dismiss

    let session: Session
    let client: MeleteClient

    @State
    private var categories: [AvatarCategory]?
    @State
    private var error: String?
    /// While the server takes the choice: nothing else can be chosen.
    @State
    private var isSaving = false

    var body: some View {
        ZStack {
            PageBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 50) {
                    header

                    if let categories {
                        ForEach(categories) { category in
                            AvatarCategoryRow(category: category, client: client, isDisabled: isSaving) { picture in
                                save { try await client.setAvatar(fromGallery: picture.id) }
                            }
                        }
                    } else if error == nil {
                        LoadingMark()
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 90)
                .padding(.vertical, 60)
            }
        }
        .environment(\.melete, client)
        .task {
            do {
                categories = try await client.avatarGallery().categories
            } catch {
                self.error = "Couldn't load the pictures: \(error.localizedDescription)"
            }
        }
    }

    private var header: some View {
        HStack(spacing: 40) {
            ArtworkImage(path: session.user.avatarUrl) {
                Text(String(session.user.username.prefix(1)).uppercased())
                    .font(.system(size: 60, weight: .bold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(white: 0.2))
            }
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                Text("Choose a Picture")
                    .font(.title2.bold())
                Text("For \(session.user.username), on every device signed in to this server.")
                    .foregroundStyle(.secondary)
                if let error {
                    Text(error)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if session.user.avatarUrl != nil {
                HeroActionButton(title: "Remove Picture", systemImage: "person.crop.circle.badge.xmark", isProminent: false) {
                    save { try await client.removeAvatar() }
                }
                .disabled(isSaving)
            }
        }
    }

    private func save(_ change: @escaping () async throws -> AvatarSet) {
        isSaving = true
        error = nil
        Task {
            defer { isSaving = false }
            do {
                try await sessions.changePicture(of: session, using: client, change)
                dismiss()
            } catch {
                self.error = "Couldn't change the picture: \(error.localizedDescription)"
            }
        }
    }
}

extension SessionStore {

    /// Makes the change, then takes the user as the server has them now, so
    /// the new picture shows everywhere in the app at once.
    func changePicture(of session: Session, using client: MeleteClient, _ change: () async throws -> AvatarSet) async throws {
        _ = try await change()
        let user = try await client.me()
        refresh(session, with: user)
    }
}

/// One category's pictures in a row, fetched a page at a time as the row is
/// scrolled.
struct AvatarCategoryRow: View {

    let category: AvatarCategory
    let client: MeleteClient
    let isDisabled: Bool
    let choose: (AvatarPictures.Picture) -> Void

    @State
    private var pictures: [AvatarPictures.Picture] = []
    @State
    private var total: Int?
    @State
    private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.titleSpacing) {
            Text(category.name)
                .font(.headline)
                #if os(iOS)
                .padding(.horizontal, TouchLayout.edge)
                #endif

            ScrollView(.horizontal) {
                LazyHStack(spacing: Metrics.spacing) {
                    ForEach(pictures) { picture in
                        Button {
                            choose(picture)
                        } label: {
                            ArtworkImage(path: picture.url)
                                .frame(width: Metrics.edge, height: Metrics.edge)
                                .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
                        }
                        .buttonStyle(ProfileTileStyle())
                        .disabled(isDisabled)
                        #if os(iOS)
                        .accessibilityLabel("\(category.name) picture")
                        #endif
                        .onAppear {
                            if picture.id == pictures.last?.id {
                                Task { await loadMore() }
                            }
                        }
                    }
                }
                // Room for the focused picture to grow without being cut off.
                .padding(.vertical, Metrics.lift)
            }
            #if os(iOS)
            // From the page's margin, and to the screen's edge as it scrolls.
            .contentMargins(.horizontal, TouchLayout.edge, for: .scrollContent)
            #endif
            .scrollClipDisabled()
            .frame(height: Metrics.edge + Metrics.lift * 2)
        }
        .focusSection()
        .task {
            await loadMore()
        }
    }

    private func loadMore() async {
        guard !isLoading, pictures.count < (total ?? .max) else { return }
        isLoading = true
        defer { isLoading = false }
        guard let page = try? await client.avatarPictures(in: category.id, offset: pictures.count) else { return }
        total = page.total
        pictures += page.pictures
    }

    /// Big enough to tell apart across a room; on a phone, four or so to a
    /// screen. Nothing grows under a finger, so a phone needs no room for it.
    private enum Metrics {
        #if os(tvOS)
        static let edge: CGFloat = 180
        static let radius: CGFloat = 24
        static let spacing: CGFloat = 40
        static let titleSpacing: CGFloat = 20
        static let lift: CGFloat = 24
        #else
        static let edge: CGFloat = 80
        static let radius: CGFloat = 14
        static let spacing: CGFloat = 12
        static let titleSpacing: CGFloat = 10
        static let lift: CGFloat = 0
        #endif
    }
}
