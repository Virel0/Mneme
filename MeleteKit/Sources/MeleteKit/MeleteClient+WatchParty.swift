//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

/// Watch parties, for this device: membership belongs to its sign-in. The
/// event stream's `watch_party` says when any of them changes.
public extension MeleteClient {

    /// The parties this device is in.
    func watchParties() async throws(MeleteError) -> [WatchParty] {
        try await send(Endpoint(.get, "api/v1/watch-parties"))
    }

    /// Starts a party playing the file, with this device as its host.
    func startWatchParty(_ start: WatchPartyStart) async throws(MeleteError) -> WatchPartyAnswer {
        try await send(Endpoint(.post, "api/v1/watch-parties", json: start))
    }

    /// Joins by the party's code. Refused (403) when this account may not
    /// watch what it plays; five wrong codes lock joining for a while (429).
    func joinWatchParty(code: String) async throws(MeleteError) -> WatchPartyAnswer {
        try await send(Endpoint(.post, "api/v1/watch-parties/join", json: WatchPartyJoin(code: code)))
    }

    func watchParty(_ id: Int) async throws(MeleteError) -> WatchPartyAnswer {
        try await send(Endpoint(.get, "api/v1/watch-parties/\(id)"))
    }

    /// Refused (409) when another change got in first: fetch it and follow.
    func changeWatchParty(_ id: Int, _ change: WatchPartyChange) async throws(MeleteError) -> WatchPartyAnswer {
        try await send(Endpoint(.put, "api/v1/watch-parties/\(id)", json: change))
    }

    /// Says this device is loading or buffering, or ready again. A playing
    /// party pauses for it, for 30 seconds at most.
    func setWatchPartyWaiting(_ id: Int, _ waiting: Bool) async throws(MeleteError) -> WatchPartyAnswer {
        try await send(Endpoint(.put, "api/v1/watch-parties/\(id)/waiting", json: WatchPartyWaiting(waiting: waiting)))
    }

    func leaveWatchParty(_ id: Int) async throws(MeleteError) {
        _ = try await send(Endpoint<NoContent>(.post, "api/v1/watch-parties/\(id)/leave"))
    }

    /// Ends it for everyone: its host's, or an admin's.
    func endWatchParty(_ id: Int) async throws(MeleteError) {
        _ = try await send(Endpoint<NoContent>(.delete, "api/v1/watch-parties/\(id)"))
    }

    /// A link that lets one guest with no account in, once, within a day.
    func inviteWatchPartyGuest(_ id: Int) async throws(MeleteError) -> WatchPartyInvite {
        try await send(Endpoint(.post, "api/v1/watch-parties/\(id)/invites"))
    }

    func sendWatchPartyGuestAway(_ id: Int, guest: Int) async throws(MeleteError) {
        _ = try await send(Endpoint<NoContent>(.delete, "api/v1/watch-parties/\(id)/guests/\(guest)"))
    }
}
