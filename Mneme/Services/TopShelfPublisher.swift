//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import CryptoKit
import Foundation
import MeleteKit
import TVServices

/// Puts the home's rows on the Apple TV home screen: Continue Watching and
/// Next Up as wide pictures that play, Latest Movies and Latest Shows as
/// posters that open the title.
@MainActor
enum TopShelfPublisher {

    private static let itemLimit = 10

    static func publish(_ home: WatchHome, client: MeleteClient) async {
        guard let folder = TopShelfSnapshot.imagesFolder else {
            PlaybackDiagnostics.shared.record("topshelf", "no app group container")
            return
        }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            PlaybackDiagnostics.shared.record("topshelf", "cannot make the picture folder: \(error.localizedDescription)")
        }

        func row(_ key: WatchHomeRow.Key) -> [WatchHomeItem] {
            Array((home.rows.first { $0.key == key }?.items ?? []).prefix(itemLimit))
        }

        var sections: [TopShelfSnapshot.Section] = []
        for (key, isLandscape) in [
            (WatchHomeRow.Key.continueWatching, true),
            (.nextUp, true),
            (.latestMovies, false),
            (.latestShows, false),
        ] {
            var items: [TopShelfSnapshot.Item] = []
            for item in row(key) {
                let picture = isLandscape ? item.episode?.still ?? item.textlessBackdrop ?? item.backdrop : item.poster
                await items.append(TopShelfSnapshot.Item(
                    id: "\(item.kind.rawValue)-\(item.id)-\(key.rawValue)",
                    title: title(of: item),
                    imageURL: save(picture, into: folder, client: client),
                    displayURL: DeepLink.title(TitleSummary(item)),
                    playURL: isLandscape ? PlayTarget.known(for: TitleSummary(item)).flatMap(DeepLink.play) : nil
                ))
            }
            if !items.isEmpty {
                sections.append(TopShelfSnapshot.Section(title: key.title, isLandscape: isLandscape, items: items))
            }
        }

        let items = sections.flatMap(\.items)
        PlaybackDiagnostics.shared.record("topshelf", "\(items.count(where: { $0.imageURL != nil })) of \(items.count) pictures saved")
        TopShelfSnapshot(sections: sections, updatedAt: .now).save()
        prune(folder, keeping: Set(sections.flatMap(\.items).compactMap(\.imageURL?.lastPathComponent)))
        TVTopShelfContentProvider.topShelfContentDidChange()
    }

    static func clear() {
        TopShelfSnapshot.remove()
        TVTopShelfContentProvider.topShelfContentDidChange()
    }

    /// "The Office · S2:E4" for an episode, else the title.
    private static func title(of item: WatchHomeItem) -> String {
        guard let episode = item.episode, let code = Format.episodeCode(season: episode.season, episode: episode.episode) else {
            return item.title
        }
        return "\(item.title) · \(code)"
    }

    /// The picture saved under a name made from its path, which never
    /// changes meaning: a picture already saved is not fetched again.
    private static func save(_ path: String?, into folder: URL, client: MeleteClient) async -> URL? {
        guard let path, let url = client.url(for: path) else { return nil }
        let name = SHA256.hash(data: Data(path.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined() + ".jpg"
        let file = folder.appending(path: name)
        if FileManager.default.fileExists(atPath: file.path()) {
            return file
        }

        var request = URLRequest(url: url)
        if let header = client.authorizationHeader {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              (try? data.write(to: file, options: .atomic)) != nil
        else { return nil }
        return file
    }

    private static func prune(_ folder: URL, keeping names: Set<String>) {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for file in files where !names.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
