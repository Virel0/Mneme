//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation
import MeleteKit

/// What plays after an episode.
enum NextUp {

    /// The next episode on disk, or nil for a movie or the last episode.
    static func find(after target: PlayTarget, client: MeleteClient) async -> PlayTarget? {
        guard target.title.kind == .series, let seasonNumber = target.season, let episodeNumber = target.episode else {
            return nil
        }

        let seriesID = target.title.id
        guard let series = try? await client.series(seriesID),
              let season = try? await client.season(seasonNumber, ofSeries: seriesID)
        else { return nil }

        let episode: Episode
        let seasonOfNext: Int
        switch EpisodeOrder.next(after: episodeNumber, in: season, seasons: series.seasons) {
        case let .inSeason(found):
            episode = found
            seasonOfNext = seasonNumber
        case let .firstOf(number):
            guard let following = try? await client.season(number, ofSeries: seriesID),
                  let first = following.episodes.filter({ !$0.files.isEmpty }).min(by: { $0.episode < $1.episode })
            else { return nil }
            episode = first
            seasonOfNext = number
        case .none:
            return nil
        }

        guard let file = episode.files.first else { return nil }
        return PlayTarget(
            fileID: file.id,
            label: [Format.episodeCode(season: seasonOfNext, episode: episode.episode), episode.name]
                .compactMap(\.self)
                .joined(separator: " · "),
            title: target.title,
            season: seasonOfNext,
            episode: episode.episode,
            restarts: false
        )
    }
}
