//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

/// The server's clock as this device sees it, NTP-style, as Melete's web
/// player keeps it (`src/web/party-clock.js`). Each answer timed from ask to
/// arrival gives a sample: the server's time less the request's midpoint.
/// The sample with the shortest round trip among the latest few wins, so a
/// slow answer can't skew it.
public struct PartyClock: Sendable {

    static let samplesKept = 8
    /// How long a sample counts, in milliseconds.
    static let sampleLife: Double = 5 * 60 * 1000

    private struct Sample: Sendable {
        let roundTrip: Double
        let offset: Double
        let at: Double
    }

    private var samples: [Sample] = []
    /// Server time less this device's, in milliseconds.
    public private(set) var offset: Double = 0

    public init() {}

    /// An answer's `serverTime`, asked at `sent` and arrived at `arrived`,
    /// all in Unix milliseconds by this device's clock.
    public mutating func take(serverTime: Int, sent: Double, arrived: Double, now: Double) {
        samples = Array(samples.filter { now - $0.at < Self.sampleLife }.suffix(Self.samplesKept - 1))
        samples.append(Sample(roundTrip: arrived - sent, offset: Double(serverTime) - (sent + arrived) / 2, at: now))
        offset = samples.min { $0.roundTrip < $1.roundTrip }?.offset ?? 0
    }

    /// The server's time now, given this device's, in Unix milliseconds.
    public func serverTime(at local: Double) -> Double {
        local + offset
    }
}

/// How a player is brought to its party, as Melete's web player does:
/// drift under 80 ms is left alone, up to the seek limit the player plays a
/// little faster or slower until it's gone, and past it the player seeks. A
/// conversion seeks coarser, so its limit is looser. A player that isn't
/// going yet seeks past 80 ms instead: a jump nobody sees. A paused party has
/// every player where it paused.
public enum PartySync {

    /// Drift left alone, in seconds.
    static let close = 0.08
    /// Drift sought past, in seconds: a file played as it is, and a
    /// conversion.
    static let seek = 1.5
    static let seekCoarse = 2.5
    /// How much faster or slower a nudge plays.
    static let nudge: Float = 0.05

    /// What to do to the player.
    public struct Correction: Equatable, Sendable {

        public enum Kind: Equatable, Sendable {
            /// Close enough.
            case close
            /// Playing a little faster or slower to close the gap.
            case nudge
            /// Moved to where the party is.
            case seek
            /// A start set a moment ahead: paused until it comes.
            case wait
        }

        public let kind: Kind
        /// The speed to play at; nil to leave it.
        public let rate: Float?
        /// Where to move to, in seconds; nil to stay.
        public let seek: Double?
        /// Pause until the start comes.
        public let pause: Bool
    }

    /// How long until a party set playing starts, in milliseconds; zero
    /// once it has.
    public static func startsIn(_ party: WatchParty, serverTime: Double) -> Double {
        party.playing ? max(0, Double(party.positionAt) - serverTime) : 0
    }

    /// Where the party's file is now, in seconds: held at its start until a
    /// start set a moment ahead comes.
    public static func expected(_ party: WatchParty, serverTime: Double) -> Double {
        let played = party.playing ? max(0, serverTime - Double(party.positionAt)) : 0
        return (Double(party.positionMs) + played) / 1000
    }

    /// Brings a player at `current` seconds, paused or not, to the party.
    public static func correct(current: Double, isPaused: Bool, party: WatchParty, serverTime: Double, coarse: Bool) -> Correction {
        let held = Double(party.positionMs) / 1000
        guard party.playing else {
            let seek = abs(current - held) > close ? held : nil
            return Correction(kind: seek == nil ? .close : .seek, rate: 1, seek: seek, pause: false)
        }
        if startsIn(party, serverTime: serverTime) > 0 {
            return Correction(kind: .wait, rate: nil, seek: abs(current - held) > close ? held : nil, pause: true)
        }
        let expected = expected(party, serverTime: serverTime)
        let drift = expected - current
        let limit = isPaused ? close : coarse ? seekCoarse : seek
        if abs(drift) > limit {
            return Correction(kind: .seek, rate: 1, seek: expected, pause: false)
        }
        if abs(drift) > close {
            return Correction(kind: .nudge, rate: drift > 0 ? 1 + nudge : 1 - nudge, seek: nil, pause: false)
        }
        return Correction(kind: .close, rate: 1, seek: nil, pause: false)
    }
}
