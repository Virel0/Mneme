//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

#if os(iOS)
import ImageIO
import MeleteKit
import PhotosUI
import SwiftUI

/// A new profile picture: a photo from the device's library, or one from the
/// server's gallery, a row to each category as on the Apple TV.
struct TouchAvatarPickerView: View {

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
    @State
    private var photo: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                        .padding(.horizontal, TouchLayout.edge)

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
                .padding(.vertical, 20)
            }
            .background(Color.mnemePageBackground.ignoresSafeArea())
            .navigationTitle("Choose a Picture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
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
        .onChange(of: photo) { _, item in
            guard let item else { return }
            photo = nil
            save {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let jpeg = await Self.avatarJPEG(from: data)
                else { throw PhotoError.unreadable }
                return try await client.uploadAvatar(jpeg, contentType: "image/jpeg")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            ArtworkImage(path: session.user.avatarUrl) {
                Text(String(session.user.username.prefix(1)).uppercased())
                    .font(.system(size: 48, weight: .bold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(white: 0.2))
            }
            .frame(width: 112, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                if isSaving {
                    ProgressView()
                }
            }
            .accessibilityHidden(true)

            Text("For \(session.user.username), on every device signed in to this server.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let error {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                PhotosPicker(selection: $photo, matching: .images) {
                    Label("Choose from Photos", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)

                if session.user.avatarUrl != nil {
                    Button(role: .destructive) {
                        save { try await client.removeAvatar() }
                    } label: {
                        Label("Remove Picture", systemImage: "person.crop.circle.badge.xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .controlSize(.large)
            .disabled(isSaving)
        }
        .frame(maxWidth: .infinity)
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

    private enum PhotoError: LocalizedError {
        case unreadable

        var errorDescription: String? {
            "The photo couldn't be read."
        }
    }

    /// The photo as a JPEG no more than 1024 pixels on its longer side, the
    /// right way up: far more than a profile picture is ever shown at, and so
    /// always well under the server's 5 MB. A phone's photo as taken is often
    /// over that, and in HEIC, which the server does not take.
    ///
    /// Off the main actor: decoding a large photo takes long enough to be felt.
    @concurrent
    private nonisolated static func avatarJPEG(from data: Data) async -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1024,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return UIImage(cgImage: image).jpegData(compressionQuality: 0.85)
    }
}
#endif
