//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation
@testable import MeleteKit
import Testing

struct SegmentGuideTests {

    private func segment(_ start: Double, _ end: Double) -> Segment {
        Segment(startSeconds: start, endSeconds: end, source: "audio")
    }

    private func guide(
        intro: Segment? = nil,
        recap: Segment? = nil,
        preview: Segment? = nil,
        credits: Segment? = nil,
        duration: Double? = 1500
    ) -> SegmentGuide {
        SegmentGuide(
            segments: FileSegments(scanned: true, intro: intro, credits: credits, recap: recap, preview: preview),
            duration: duration
        )
    }

    @Test
    func `offers the intro while it plays`() {
        let guide = guide(intro: segment(60, 150))
        #expect(guide.skip(at: 59) == nil)
        #expect(guide.skip(at: 60) == SkipOffer(kind: .intro, end: 150))
        #expect(guide.skip(at: 140) == SkipOffer(kind: .intro, end: 150))
        #expect(guide.skip(at: 150) == nil)
    }

    @Test
    func `drops the offer in the last seconds`() {
        // Pressing Skip two seconds before the end would jump two seconds.
        let guide = guide(intro: segment(60, 150))
        #expect(guide.skip(at: 148) == nil)
    }

    @Test
    func `recap comes before an overlapping intro`() {
        let guide = guide(intro: segment(30, 120), recap: segment(0, 60))
        #expect(guide.skip(at: 40)?.kind == .recap)
        #expect(guide.skip(at: 70)?.kind == .intro)
    }

    @Test
    func `credits are never skipped`() {
        let guide = guide(credits: segment(1400, 1500))
        #expect(guide.skip(at: 1450) == nil)
    }

    @Test
    func `next up starts at the credits`() {
        #expect(guide(credits: segment(1380, 1500)).nextUpStart == 1380)
    }

    @Test
    func `next up falls back to before the end`() {
        #expect(guide(duration: 1500).nextUpStart == 1480)
        #expect(guide(duration: nil).nextUpStart == nil)
    }
}

struct EpisodeOrderTests {

    private func episode(_ number: Int, onDisk: Bool = true) -> Episode {
        Episode(
            episode: number,
            name: nil,
            overview: nil,
            airDate: nil,
            runtimeMinutes: nil,
            still: nil,
            files: onDisk ? [MediaFile(id: number, path: "e\(number).mkv", size: 1, modifiedAt: 0)] : []
        )
    }

    private let seasons = [
        SeasonSummary(season: 0, episodes: 2, available: 2),
        SeasonSummary(season: 1, episodes: 3, available: 3),
        SeasonSummary(season: 2, episodes: 3, available: 0),
        SeasonSummary(season: 3, episodes: 2, available: 2),
    ]

    @Test
    func `next in the same season`() {
        let season = Season(season: 1, episodes: [episode(1), episode(2), episode(3)])
        #expect(EpisodeOrder.next(after: 1, in: season, seasons: seasons) == .inSeason(episode(2)))
    }

    @Test
    func `skips episodes not on disk`() {
        let season = Season(season: 1, episodes: [episode(1), episode(2, onDisk: false), episode(3)])
        #expect(EpisodeOrder.next(after: 1, in: season, seasons: seasons) == .inSeason(episode(3)))
    }

    @Test
    func `moves to the next season with something on disk`() {
        // Season 2 has nothing on disk, so the next is season 3.
        let season = Season(season: 1, episodes: [episode(1), episode(2), episode(3)])
        #expect(EpisodeOrder.next(after: 3, in: season, seasons: seasons) == .firstOf(season: 3))
    }

    @Test
    func `the last episode has no next`() {
        let season = Season(season: 3, episodes: [episode(1), episode(2)])
        #expect(EpisodeOrder.next(after: 2, in: season, seasons: seasons) == .none)
    }

    @Test
    func `specials do not run on`() {
        let specials = Season(season: 0, episodes: [episode(1), episode(2)])
        #expect(EpisodeOrder.next(after: 1, in: specials, seasons: seasons) == .inSeason(episode(2)))
        #expect(EpisodeOrder.next(after: 2, in: specials, seasons: seasons) == .none)
    }
}

struct ProgressCadenceTests {

    @Test
    func `first report is always due`() {
        #expect(ProgressCadence.isDue(lastReport: nil, now: .now))
    }

    @Test
    func `reports every ten seconds`() {
        let start = Date(timeIntervalSince1970: 1000)
        #expect(!ProgressCadence.isDue(lastReport: start, now: start.addingTimeInterval(9)))
        #expect(ProgressCadence.isDue(lastReport: start, now: start.addingTimeInterval(10)))
    }
}
