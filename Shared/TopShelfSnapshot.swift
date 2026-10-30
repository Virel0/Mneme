//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
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

    static var imagesFolder: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: "TopShelf", directoryHint: .isDirectory)
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
