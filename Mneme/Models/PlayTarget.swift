//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation
import MeleteKit

/// What Play does for a title, and what its button says: "Resume S2:E4 ·
/// 23m left", "Play S3:E1", "Play · 1 h 52 min", "Play again".
///
/// Worked out the way Melete's own web player does, so the two never
/// disagree about what Play will start.
struct PlayTarget: Hashable, Sendable {

    let fileID: Int
    let label: String
    /// The title it belongs to, so the player can find the next episode.
    let title: TitleRef
    let season: Int?
    let episode: Int?
    /// Start from the beginning rather than where it was left.
    let restarts: Bool

    /// What the summary itself says, when that is enough: the episode the
    /// home says is next or partway through, or the movie's file last played.
    static func known(for summary: TitleSummary) -> PlayTarget? {
        switch summary.kind {
        case .series: knownEpisode(of: summary)
        case .movie: knownMovieFile(of: summary)
        }
    }

    private static func knownEpisode(of summary: TitleSummary) -> PlayTarget? {
        guard let episode = summary.episode else { return nil }

        let code = Format.episodeCode(season: episode.season, episode: episode.episode)
        let label: String = if let progress = summary.progress, progress.isPartway, progress.fileId == episode.fileId {
            "Resume " + [code, progress.timeLeft].compactMap(\.self).joined(separator: " · ")
        } else {
            code.map { "Play \($0)" } ?? "Play"
        }
        return PlayTarget(
            fileID: episode.fileId,
            label: label,
            title: summary.ref,
            season: episode.season,
            episode: episode.episode,
            restarts: false
        )
    }

    private static func knownMovieFile(of summary: TitleSummary) -> PlayTarget? {
        guard let progress = summary.progress else { return nil }

        if progress.isPartway {
            return PlayTarget(
                fileID: progress.fileId,
                label: ["Resume", progress.timeLeft].compactMap(\.self).joined(separator: " · "),
                title: summary.ref,
                season: nil,
                episode: nil,
                restarts: false
            )
        }
        guard progress.watched else { return nil }
        return PlayTarget(
            fileID: progress.fileId,
            label: "Play Again",
            title: summary.ref,
            season: nil,
            episode: nil,
            restarts: true
        )
    }

    /// Asks the server when the summary does not say: the movie's first file,
    /// or the series' first episode on disk, Specials last.
    static func lookUp(for summary: TitleSummary, client: MeleteClient) async throws(MeleteError) -> PlayTarget? {
        if let known = known(for: summary) {
            return known
        }

        switch summary.kind {
        case .movie:
            let movie = try await client.movie(summary.ref.id)
            guard let file = movie.files.first else { return nil }
            let length = movie.runtimeMinutes.flatMap(Format.runtime(minutes:))
            return PlayTarget(
                fileID: file.id,
                label: length.map { "Play · \($0)" } ?? "Play",
                title: summary.ref,
                season: nil,
                episode: nil,
                restarts: false
            )

        case .series:
            let series = try await client.series(summary.ref.id)
            guard let first = series.seasons.filter({ $0.available > 0 }).sorted(by: SeasonSummary.playOrder).first else {
                return nil
            }
            let season = try await client.season(first.season, ofSeries: summary.ref.id)
            guard let episode = season.episodes.first(where: { !$0.files.isEmpty }), let file = episode.files.first else {
                return nil
            }
            let code = Format.episodeCode(season: first.season, episode: episode.episode)
            return PlayTarget(
                fileID: file.id,
                label: code.map { "Play \($0)" } ?? "Play",
                title: summary.ref,
                season: first.season,
                episode: episode.episode,
                restarts: false
            )
        }
    }
}

extension SeasonSummary {

    /// Seasons in order, Specials last.
    static func playOrder(_ lhs: SeasonSummary, _ rhs: SeasonSummary) -> Bool {
        if (lhs.season == 0) != (rhs.season == 0) {
            return rhs.season == 0
        }
        return lhs.season < rhs.season
    }

    var displayTitle: String {
        season == 0 ? "Specials" : "Season \(season)"
    }
}

extension WatchHomeItem.Progress {

    /// There is a place to resume from.
    var isPartway: Bool {
        !watched && positionSeconds > 0
    }

    var timeLeft: String? {
        Format.timeLeft(position: positionSeconds, duration: durationSeconds, watched: watched)
    }
}
