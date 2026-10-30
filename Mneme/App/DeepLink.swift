//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation
import MeleteKit

/// `mneme://` links, from the Top Shelf into the app.
///
/// - `mneme://title?kind=series&id=12&title=The%20Office` opens a title.
/// - `mneme://play?file=345&kind=series&id=12&season=2&episode=4&label=…`
///   plays a file, knowing which title it is so the next episode follows.
enum DeepLink {

    static func title(_ summary: TitleSummary) -> URL? {
        link("title", [
            ("kind", summary.kind.rawValue),
            ("id", String(summary.ref.id)),
            ("title", summary.title),
        ])
    }

    static func play(_ target: PlayTarget) -> URL? {
        link("play", [
            ("file", String(target.fileID)),
            ("kind", target.title.kind.rawValue),
            ("id", String(target.title.id)),
            ("season", target.season.map(String.init)),
            ("episode", target.episode.map(String.init)),
            ("label", target.label),
        ])
    }

    /// Where a link goes, or nil for one this app does not know.
    static func route(for url: URL) -> Route? {
        guard url.scheme == "mneme", let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let query = Dictionary(
            (components.queryItems ?? []).compactMap { item in item.value.map { (item.name, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        guard let kind = query["kind"].flatMap(TitleKind.init(rawValue:)), let id = query["id"].flatMap(Int.init) else { return nil }
        let ref = TitleRef(kind: kind, id: id)

        switch components.host {
        case "title":
            return .title(TitleSummary(placeholder: ref, title: query["title"] ?? ""))
        case "play":
            guard let file = query["file"].flatMap(Int.init) else { return nil }
            return .play(PlayTarget(
                fileID: file,
                label: query["label"] ?? "",
                title: ref,
                season: query["season"].flatMap(Int.init),
                episode: query["episode"].flatMap(Int.init),
                restarts: false
            ))
        default:
            return nil
        }
    }

    private static func link(_ host: String, _ items: [(String, String?)]) -> URL? {
        var components = URLComponents()
        components.scheme = "mneme"
        components.host = host
        components.queryItems = items.compactMap { name, value in value.map { URLQueryItem(name: name, value: $0) } }
        return components.url
    }
}

extension TitleSummary {

    /// A title known only by its kind, id and name; its page fills in the
    /// rest when it loads.
    init(placeholder ref: TitleRef, title: String, poster: String? = nil, year: Int? = nil) {
        self.ref = ref
        self.title = title
        self.year = year
        genres = []
        runtimeMinutes = nil
        overview = nil
        self.poster = poster
        backdrop = nil
        backdropFocus = nil
        logo = nil
        addedAt = nil
        unwatchedEpisodes = nil
        episode = nil
        progress = nil
        isComplete = false
    }
}
