//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

/// What the Apple TV home screen shows for Mneme, written by the app and read
/// by its Top Shelf extension through their shared app group.
///
/// The extension cannot sign in, and Melete's artwork needs the session's
/// token, so the app saves each picture as a file in the group and the
/// snapshot points at those files.
struct TopShelfSnapshot: Codable {

    struct Section: Codable {
        let title: String
        /// Wide pictures (what to play now) or posters.
        let isLandscape: Bool
        let items: [Item]
    }

    struct Item: Codable {
        let id: String
        let title: String
        /// A file in the app group.
        let imageURL: URL?
        /// Opens the title in Mneme.
        let displayURL: URL?
        /// Plays it, where there is something to play.
        let playURL: URL?
    }

    let sections: [Section]
    let updatedAt: Date

    /// Shared with the extension through both targets' entitlements. Read
    /// from Info.plist, where the build writes it from `MNEME_APP_ID`, so the
    /// identifier lives in one place.
    static let appGroup = Bundle.main.object(forInfoDictionaryKey: "MnemeAppGroup") as? String ?? ""
    private static let key = "topShelfSnapshot"

    /// In the group's caches: on tvOS that is the one place in a shared
    /// container an app may write, and writing at its top level fails.
    /// Caches can be cleared; the app writes the shelf again at every home
    /// load.
    static var imagesFolder: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: "Library/Caches/TopShelf", directoryHint: .isDirectory)
    }

    static func load() -> TopShelfSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TopShelfSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.appGroup)?.set(data, forKey: Self.key)
    }

    /// Takes the shelf off the home screen, so it does not outlive the
    /// person it was made for.
    static func remove() {
        UserDefaults(suiteName: appGroup)?.removeObject(forKey: key)
        if let folder = imagesFolder {
            try? FileManager.default.removeItem(at: folder)
        }
    }
}
