//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation
import MeleteKit
import Observation

@MainActor
@Observable
final class HomeModel {

    enum State {
        case loading
        case loaded(WatchHome)
        case failed(MeleteError)
    }

    let client: MeleteClient
    private(set) var state: State = .loading

    init(client: MeleteClient) {
        self.client = client
    }

    func load() async {
        do {
            state = try await .loaded(client.home())
        } catch {
            state = .failed(error)
        }
    }
}

extension WatchHomeRow.Key {

    var title: String {
        switch self {
        case .continueWatching: "Continue Watching"
        case .nextUp: "Next Up"
        case .favourites: "My List"
        case .latestShows: "Latest Shows"
        case .latestAnime: "Latest Anime"
        case .latestMovies: "Latest Movies"
        default: rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Rows of things to play now show wide tiles; rows of titles to open
    /// show posters.
    var isLandscape: Bool {
        self == .continueWatching || self == .nextUp
    }
}
