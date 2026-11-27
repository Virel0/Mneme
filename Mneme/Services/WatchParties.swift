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
import Observation

/// The watch party this device is in, if any: one film or episode played in
/// step on every device in it. Melete keeps the party; each change here is
/// sent against the version last seen, and every device hears of each change
/// from the event stream's `watch_party` and follows it. The player follows
/// through `updates()`.
@MainActor
@Observable
final class WatchParties {

    private let client: MeleteClient

    private(set) var party: WatchParty?
    /// Said when the party ended or this device was let go, for the player
    /// to show once.
    private(set) var endedNote: String?

    @ObservationIgnored
    private(set) var clock = PartyClock()
    @ObservationIgnored
    private var follower: AsyncStream<WatchParty?>.Continuation?

    init(client: MeleteClient) {
        self.client = client
    }

    /// Whether this device's account started the party: only it moves the
    /// party to another file.
    var isHost: Bool {
        guard let party else { return false }
        return party.members.contains { $0.you && $0.username == party.host }
    }

    /// Melete's time now, in Unix milliseconds.
    var serverTime: Double {
        clock.serverTime(at: Self.now)
    }

    /// The party as it changes, for the one player open; a new call replaces
    /// the last one's stream. Starts with where it is now.
    func updates() -> AsyncStream<WatchParty?> {
        follower?.finish()
        let (stream, continuation) = AsyncStream<WatchParty?>.makeStream(bufferingPolicy: .bufferingNewest(1))
        follower = continuation
        continuation.yield(party)
        return stream
    }

    // MARK: - From the event stream

    /// The parties the event stream says this device is in: sent at its
    /// start and on every change.
    func take(_ parties: [WatchParty]) {
        guard let latest = parties.first else {
            if party != nil {
                end(saying: "The watch party has ended.")
            }
            return
        }
        // A sample for the clock now and then, so a party joined elsewhere
        // starts on time here too.
        if party?.id != latest.id {
            Task { await sampleClock(latest.id) }
        }
        follow(latest)
    }

    // MARK: - Asking

    /// Starts a party playing the file from where this player is.
    func start(file: Int, at seconds: Double, playing: Bool) async throws(MeleteError) {
        let sent = Self.now
        try await took(client.startWatchParty(WatchPartyStart(fileId: file, positionMs: Self.ms(seconds), playing: playing)), sent: sent)
        await sampleClock(party?.id)
    }

    func join(code: String) async throws(MeleteError) {
        let sent = Self.now
        try await took(client.joinWatchParty(code: code.trimmingCharacters(in: .whitespaces).uppercased()), sent: sent)
        await sampleClock(party?.id)
    }

    /// This device's play, pause or seek, or the host's move to another
    /// file. Refused because another change got in first, the newer one is
    /// fetched and followed instead.
    func change(file: Int, at seconds: Double, playing: Bool) async {
        guard let party else { return }
        let change = WatchPartyChange(version: party.version, fileId: file, positionMs: Self.ms(seconds), playing: playing)
        let sent = Self.now
        do {
            try await took(client.changeWatchParty(party.id, change), sent: sent)
        } catch {
            switch error {
            case .server(status: 409, message: _): await refresh()
            case .notFound: end(saying: "The watch party has ended.")
            default: PlaybackDiagnostics.shared.record("party", "change not sent: \(error.localizedDescription)")
            }
        }
    }

    /// This device is loading or buffering, or ready again. A playing party
    /// pauses for it, for 30 seconds at most.
    func setWaiting(_ waiting: Bool) async {
        guard let party else { return }
        let sent = Self.now
        do {
            try await took(client.setWatchPartyWaiting(party.id, waiting), sent: sent)
        } catch {
            PlaybackDiagnostics.shared.record("party", "waiting not said: \(error.localizedDescription)")
        }
    }

    /// Asked afresh, which also sets the clock.
    func refresh() async {
        guard let party else { return }
        let sent = Self.now
        do {
            try await took(client.watchParty(party.id), sent: sent)
        } catch {
            if case .notFound = error {
                end(saying: "The watch party has ended.")
            }
        }
    }

    func leave() async {
        guard let party else { return }
        try? await client.leaveWatchParty(party.id)
        end(saying: nil)
    }

    /// Ends it for everyone: the host's to do.
    func endForEveryone() async {
        guard let party else { return }
        try? await client.endWatchParty(party.id)
        end(saying: nil)
    }

    func noteSeen() {
        endedNote = nil
    }

    // MARK: - Keeping in step

    /// An answer asked for at `sent`: it gives the clock a sample, and the
    /// party it carries is followed.
    private func took(_ answer: WatchPartyAnswer, sent: Double) {
        let arrived = Self.now
        clock.take(serverTime: answer.serverTime, sent: sent, arrived: arrived, now: arrived)
        follow(answer.party)
    }

    /// Three samples on joining, as the web player takes, so the first start
    /// lands together.
    private func sampleClock(_ id: Int?) async {
        guard let id else { return }
        for _ in 0 ..< 3 {
            let sent = Self.now
            guard let answer = try? await client.watchParty(id) else { return }
            let arrived = Self.now
            clock.take(serverTime: answer.serverTime, sent: sent, arrived: arrived, now: arrived)
        }
    }

    /// A newer version, or another party, is passed on; an older one, which
    /// can come from a slow answer, or the same one again, is not.
    private func follow(_ latest: WatchParty) {
        if let party, party.id == latest.id, latest.version < party.version || latest == party {
            return
        }
        party = latest
        follower?.yield(latest)
    }

    private func end(saying note: String?) {
        party = nil
        endedNote = note
        follower?.yield(nil)
    }

    private static var now: Double {
        Date.now.timeIntervalSince1970 * 1000
    }

    private static func ms(_ seconds: Double) -> Int {
        Int((max(0, seconds) * 1000).rounded())
    }
}
