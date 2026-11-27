//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation
@testable import MeleteKit
import Testing

struct PartyClockTests {

    @Test
    func `takes the sample with the shortest round trip`() {
        var clock = PartyClock()
        // Asked at 1000, back at 1400: the server said 5200, so 4000 ahead.
        clock.take(serverTime: 5200, sent: 1000, arrived: 1400, now: 1400)
        // A quicker answer wins: midpoint 2010, server 6060, 4050 ahead.
        clock.take(serverTime: 6060, sent: 2000, arrived: 2020, now: 2020)
        // A slower one after it doesn't.
        clock.take(serverTime: 9000, sent: 3000, arrived: 3600, now: 3600)
        #expect(clock.offset == 4050)
        #expect(clock.serverTime(at: 10000) == 14050)
    }

    @Test
    func `forgets samples after five minutes`() {
        var clock = PartyClock()
        clock.take(serverTime: 1010, sent: 0, arrived: 20, now: 20)
        let later = 20 + PartyClock.sampleLife
        clock.take(serverTime: Int(later) + 500, sent: later - 100, arrived: later, now: later)
        #expect(clock.offset == 550)
    }

    @Test
    func `keeps the latest eight`() {
        var clock = PartyClock()
        // The best sample first, then eight worse ones push it out.
        clock.take(serverTime: 100, sent: 0, arrived: 0, now: 0)
        for i in 1 ... 8 {
            let at = Double(i * 1000)
            clock.take(serverTime: Int(at) + 7, sent: at - 10, arrived: at, now: at)
        }
        #expect(clock.offset == 12)
    }
}

struct PartySyncTests {

    private func party(at positionMs: Int, from positionAt: Int, playing: Bool) -> WatchParty {
        WatchParty(
            id: 1, code: "ABCDEF", host: "host", fileId: 7, movieId: 3, seriesId: nil, season: nil, episode: nil,
            positionMs: positionMs, positionAt: positionAt, playing: playing, version: 1, guestMaxBitrate: nil,
            held: false, waiting: [], guests: [], members: []
        )
    }

    @Test
    func `a playing party moves on from where it was`() {
        let party = party(at: 60000, from: 1_000_000, playing: true)
        #expect(PartySync.expected(party, serverTime: 1_002_500) == 62.5)
        // Before its start, held at it.
        #expect(PartySync.expected(party, serverTime: 999_600) == 60)
        #expect(PartySync.startsIn(party, serverTime: 999_600) == 400)
    }

    @Test
    func `a paused party holds every player where it paused`() {
        let party = party(at: 60000, from: 1_000_000, playing: false)
        #expect(PartySync.expected(party, serverTime: 2_000_000) == 60)
        let far = PartySync.correct(current: 58, isPaused: true, party: party, serverTime: 2_000_000, coarse: false)
        #expect(far == .init(kind: .seek, rate: 1, seek: 60, pause: false))
        let near = PartySync.correct(current: 60.05, isPaused: true, party: party, serverTime: 2_000_000, coarse: false)
        #expect(near == .init(kind: .close, rate: 1, seek: nil, pause: false))
    }

    @Test
    func `waits for a start set ahead`() {
        let party = party(at: 60000, from: 1_000_400, playing: true)
        let correction = PartySync.correct(current: 61, isPaused: false, party: party, serverTime: 1_000_000, coarse: false)
        #expect(correction == .init(kind: .wait, rate: nil, seek: 60, pause: true))
    }

    @Test
    func `nudges small drift and seeks large`() {
        let party = party(at: 60000, from: 1_000_000, playing: true)
        let now = 1_010_000.0 // The party is at 70 s.
        #expect(PartySync.correct(current: 69.5, isPaused: false, party: party, serverTime: now, coarse: false).rate == 1.05)
        #expect(PartySync.correct(current: 70.5, isPaused: false, party: party, serverTime: now, coarse: false).rate == 0.95)
        #expect(PartySync.correct(current: 70.05, isPaused: false, party: party, serverTime: now, coarse: false).kind == .close)
        #expect(PartySync.correct(current: 68, isPaused: false, party: party, serverTime: now, coarse: false) == .init(
            kind: .seek,
            rate: 1,
            seek: 70,
            pause: false
        ))
        // A conversion seeks coarser, so two seconds is still a nudge.
        #expect(PartySync.correct(current: 68, isPaused: false, party: party, serverTime: now, coarse: true).kind == .nudge)
        // A player not going yet seeks past 80 ms.
        #expect(PartySync.correct(current: 69.8, isPaused: true, party: party, serverTime: now, coarse: false).kind == .seek)
    }
}
