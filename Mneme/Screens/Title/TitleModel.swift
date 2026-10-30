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

/// A title's page: its facts, what Play does, and for a series its seasons
/// and episodes with how far through each one is.
@MainActor
@Observable
final class TitleModel {

    private(set) var summary: TitleSummary
    private(set) var movie: MovieDetail?
    private(set) var series: SeriesDetail?
    private(set) var target: PlayTarget?
    private(set) var error: MeleteError?

    /// Progress by file id.
    private(set) var progress: [Int: ProgressEntry] = [:]

    private(set) var selectedSeason: Int?
    private(set) var seasons: [Int: Season] = [:]

    private let library: Library
    private var client: MeleteClient {
        library.client
    }

    init(summary: TitleSummary, library: Library) {
        self.summary = summary
        self.library = library
    }

    /// Seasons in the order they are listed, Specials last, leaving out those
    /// with nothing on disk.
    var seasonList: [SeasonSummary] {
        (series?.seasons ?? []).filter { $0.available > 0 }.sorted(by: SeasonSummary.playOrder)
    }

    // MARK: - Loading

    func load() async {
        do {
            switch summary.kind {
            case .movie:
                let movie = try await client.movie(summary.ref.id)
                self.movie = movie
                summary = summary.completed(with: movie)
            case .series:
                let series = try await client.series(summary.ref.id)
                self.series = series
                summary = summary.completed(with: series)
            }
            await loadProgress()
            await findTarget()

            if summary.kind == .series {
                await select(season: target?.season ?? seasonList.first?.season)
            }
        } catch {
            self.error = error
        }
    }

    private func loadProgress() async {
        guard let entries = try? await client.progress(summary.kind, summary.ref.id) else { return }
        progress = Dictionary(entries.map { ($0.fileId, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// What the home says if the title is being watched, else the movie's
    /// own progress, else the first thing on disk.
    private func findTarget() async {
        let watching = library.watchingEntry(for: summary.ref) ?? summary
        if let known = PlayTarget.known(for: watching) {
            target = known
            return
        }
        if let movie, let file = movie.files.first {
            target = movieTarget(movie, file: file)
            return
        }
        target = try? await PlayTarget.lookUp(for: summary, client: client)
    }

    private func movieTarget(_ movie: MovieDetail, file: MediaFile) -> PlayTarget {
        let entry = progress[file.id]
        let label: String = if let entry, !entry.watched, entry.positionSeconds > 0 {
            ["Resume", Format.timeLeft(position: entry.positionSeconds, duration: entry.durationSeconds, watched: false)]
                .compactMap(\.self).joined(separator: " · ")
        } else if entry?.watched == true {
            "Play Again"
        } else {
            movie.runtimeMinutes.flatMap(Format.runtime(minutes:)).map { "Play · \($0)" } ?? "Play"
        }
        return PlayTarget(
            fileID: file.id,
            label: label,
            title: summary.ref,
            season: nil,
            episode: nil,
            restarts: entry?.watched == true
        )
    }

    func select(season: Int?) async {
        guard let season else { return }
        selectedSeason = season
        guard seasons[season] == nil else { return }
        if let loaded = try? await client.season(season, ofSeries: summary.ref.id) {
            seasons[season] = loaded
        }
    }

    // MARK: - Episodes

    func target(for episode: Episode, season: Int) -> PlayTarget? {
        guard let file = episode.files.first else { return nil }
        let entry = progress[file.id]
        return PlayTarget(
            fileID: file.id,
            label: Format.episodeCode(season: season, episode: episode.episode) ?? "Play",
            title: summary.ref,
            season: season,
            episode: episode.episode,
            restarts: entry?.watched == true
        )
    }

    func isWatched(_ episode: Episode) -> Bool {
        episode.files.contains { progress[$0.id]?.watched == true }
    }

    /// How far through, 0 to 1; nil when not started or already watched.
    func fraction(_ episode: Episode) -> Double? {
        guard let file = episode.files.first, let entry = progress[file.id], !entry.watched,
              let duration = entry.durationSeconds, duration > 0, entry.positionSeconds > 0
        else { return nil }
        return min(entry.positionSeconds / duration, 1)
    }

    // MARK: - Marking watched

    var isTitleWatched: Bool {
        switch summary.kind {
        case .movie:
            movie?.files.contains { progress[$0.id]?.watched == true } ?? false
        case .series:
            !seasonList.isEmpty && seasonList.allSatisfy { isSeasonWatched($0.season) }
        }
    }

    /// Known only for loaded seasons; an unloaded one counts as not watched.
    func isSeasonWatched(_ season: Int) -> Bool {
        guard let episodes = seasons[season]?.episodes.filter({ !$0.files.isEmpty }), !episodes.isEmpty else { return false }
        return episodes.allSatisfy(isWatched)
    }

    func setTitleWatched(_ watched: Bool) async {
        switch summary.kind {
        case .movie:
            for file in movie?.files ?? [] {
                _ = try? await client.setWatched(file: file.id, watched)
            }
        case .series:
            _ = try? await client.setWatched(series: summary.ref.id, watched)
        }
        await refreshAfterMarking()
    }

    func setSeasonWatched(_ season: Int, _ watched: Bool) async {
        _ = try? await client.setWatched(series: summary.ref.id, season: season, watched)
        await refreshAfterMarking()
    }

    func setWatched(_ episode: Episode, _ watched: Bool) async {
        for file in episode.files {
            _ = try? await client.setWatched(file: file.id, watched)
        }
        await refreshAfterMarking()
    }

    private func refreshAfterMarking() async {
        await loadProgress()
        // What Play does depends on what was watched, and so do the home's
        // Continue Watching and Next Up.
        await library.load()
        await findTarget()
    }
}
