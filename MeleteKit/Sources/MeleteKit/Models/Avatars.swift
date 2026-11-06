//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

/// The profile pictures a server offers: Melete's own first, then any the
/// server's owner has added, a category to each folder.
public struct AvatarGallery: Codable, Sendable {
    public let categories: [AvatarCategory]
}

public struct AvatarCategory: Codable, Hashable, Identifiable, Sendable {
    /// `official`, or `gallery/` and the folder's name.
    public let id: String
    /// As shown: "Melete" for Melete's own.
    public let name: String
    /// Pictures in it.
    public let count: Int
}

/// A page of one category's pictures.
public struct AvatarPictures: Codable, Sendable {

    public struct Picture: Codable, Hashable, Identifiable, Sendable {
        public let id: String
        /// The picture, to show.
        public let url: String
    }

    public let total: Int
    public let pictures: [Picture]
}

/// Where the user's picture is fetched from now; nil without one.
public struct AvatarSet: Codable, Sendable {
    public let avatarUrl: String?
}

struct AvatarChoice: Codable, Sendable {
    let id: String
}

public extension MeleteClient {

    func avatarGallery() async throws(MeleteError) -> AvatarGallery {
        try await send(Endpoint(.get, "api/v1/avatars"))
    }

    /// Up to 200 at a time.
    func avatarPictures(in category: String, offset: Int = 0, limit: Int = 60) async throws(MeleteError) -> AvatarPictures {
        try await send(Endpoint(.get, "api/v1/avatars/pictures", query: [
            URLQueryItem(name: "category", value: category),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]))
    }

    /// The server keeps a copy as the user's own, so it stays when the
    /// gallery changes. Everyone signed in sees it beside the user's name.
    func setAvatar(fromGallery id: String) async throws(MeleteError) -> AvatarSet {
        try await send(Endpoint(.put, "api/v1/me/avatar/gallery", json: AvatarChoice(id: id)))
    }

    func removeAvatar() async throws(MeleteError) -> AvatarSet {
        try await send(Endpoint(.delete, "api/v1/me/avatar"))
    }
}
