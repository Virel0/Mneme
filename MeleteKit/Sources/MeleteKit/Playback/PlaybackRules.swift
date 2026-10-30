//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

/// A part of a file that can be skipped, offered while it plays.
public struct SkipOffer: Hashable, Sendable {

    public enum Kind: String, Sendable {
        case recap
        case intro
        case preview
    }

    public let kind: Kind
    /// Where skipping lands.
    public let end: Double

    public var title: String {
        switch kind {
        case .recap: "Skip Recap"
        case .intro: "Skip Intro"
        case .preview: "Skip Preview"
        }
    }
}

/// What the player offers at a moment of a file, from its segments.
public struct SegmentGuide: Sendable {

    public let segments: FileSegments
    public let duration: Double?

    /// With no credits marked, the next episode is offered this long before
    /// the end, as Melete's web player does.
    public static let unmarkedCreditsLead: Double = 20

    /// A skip ending this close to where it would land is not worth a button.
    private static let minimumSkip: Double = 3

    public init(segments: FileSegments, duration: Double?) {
        self.segments = segments
        self.duration = duration
    }

    /// The skip to offer at `time`, if any. Credits are not skipped: skipping
    /// them ends the episode, which is the next-episode offer's job.
    public func skip(at time: Double) -> SkipOffer? {
        let candidates: [(SkipOffer.Kind, Segment?)] = [(.recap, segments.recap), (.intro, segments.intro), (.preview, segments.preview)]
        for (kind, segment) in candidates {
            guard let segment, segment.startSeconds <= time, time < segment.endSeconds - Self.minimumSkip else { continue }
            return SkipOffer(kind: kind, end: segment.endSeconds)
        }
        return nil
    }

    /// When the next episode is offered: the credits' start, else a little
    /// before the end. Nil when neither is known.
    public var nextUpStart: Double? {
        if let credits = segments.credits {
            return credits.startSeconds
        }
        return duration.map { max(0, $0 - Self.unmarkedCreditsLead) }
    }
}

/// Where the episode after this one is.
public enum NextEpisode: Equatable, Sendable {
    /// Later in the same season.
    case inSeason(Episode)
    /// The first episode on disk of another season, which has to be fetched.
    case firstOf(season: Int)
    /// This was the last.
    case none
}

public enum EpisodeOrder {

    /// The episode after `episode` of `season`, with a file on disk: later in
    /// the season, else the next season in play order (Specials last).
    /// Specials themselves have no "next": they are watched one by one.
    public static func next(after episode: Int, in season: Season, seasons: [SeasonSummary]) -> NextEpisode {
        if let later = season.episodes
            .filter({ $0.episode > episode && !$0.files.isEmpty })
            .min(by: { $0.episode < $1.episode })
        {
            return .inSeason(later)
        }

        guard season.season != 0 else { return .none }

        let following = seasons
            .filter { $0.available > 0 && $0.season > season.season }
            .map(\.season)
            .min()
        return following.map { .firstOf(season: $0) } ?? .none
    }
}

/// How often progress is reported while playing.
public enum ProgressCadence {

    public static let interval: TimeInterval = 10

    /// Whether a report is due, given when the last one went.
    public static func isDue(lastReport: Date?, now: Date) -> Bool {
        guard let lastReport else { return true }
        return now.timeIntervalSince(lastReport) >= interval
    }
}
