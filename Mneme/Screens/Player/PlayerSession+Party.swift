//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import AetherEngine
import Foundation
import MeleteKit

/// The player in a watch party, as Melete's web player plays one: it follows
/// each change the party hears of, keeps to the party every second, gently,
/// sends this viewer's play, pause and seek, and says when it is buffering.
/// The host alone takes the party to another file; everyone else follows.
extension PlayerSession {

    var parties: WatchParties {
        library.parties
    }

    /// The party, while it plays this file.
    var partyHere: WatchParty? {
        guard let party = parties.party, party.fileId == target.fileID, target.downloadID == nil else { return nil }
        return party
    }

    /// Whether this player follows a party rather than its own choices:
    /// the next episode and the speed are the host's, or the party's.
    var followsParty: Bool {
        parties.party != nil && !parties.isHost
    }

    /// Where a file joined in a party starts: where the party is.
    var partyStart: Double? {
        partyHere.map { PartySync.expected($0, serverTime: parties.serverTime) }
    }

    /// Starts a party on what's playing, from where it is.
    func startParty() async throws(MeleteError) {
        try await parties.start(file: target.fileID, at: position, playing: !isPaused)
    }

    // MARK: - Following

    func followParty() async {
        for await party in parties.updates() {
            guard let party else {
                partyStartTask?.cancel()
                engine?.setRate(rate)
                continue
            }
            followParty(party)
        }
    }

    /// Plays the party where it plays; another file is gone to.
    func followParty(_ party: WatchParty) {
        guard phase == .playing else { return }
        guard party.fileId == target.fileID else {
            // The host's own new file goes to the party once it plays (see
            // `partyLoaded`); everyone else goes to the party's.
            if !parties.isHost {
                openPartyFile(party)
            }
            return
        }
        settleParty()
        partyStartTask?.cancel()
        let correction = PartySync.correct(
            current: position,
            isPaused: isPaused,
            party: party,
            serverTime: parties.serverTime,
            coarse: isConverted
        )
        apply(correction)
        if correction.kind == .wait {
            // A start set a moment ahead: played when it comes, with everyone.
            let delay = PartySync.startsIn(party, serverTime: parties.serverTime)
            partyStartTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(Int(delay)))
                guard !Task.isCancelled, let self, let party = self.parties.party else { return }
                self.followParty(party)
            }
        } else if party.playing, isPaused {
            togglePause()
        }
        if !party.playing, !isPaused {
            togglePause()
        }
    }

    /// Every second while the party plays here: the player kept to it,
    /// gently; each minute, the clock asked afresh.
    func keepInStepWithParty() async {
        var ticks = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            ticks += 1
            guard let party = partyHere, phase == .playing else { continue }
            if ticks % 60 == 0 {
                await parties.refresh()
            }
            guard party.playing, !isPaused, seekGoal == nil, Date.now >= partySettledAt else { continue }
            let correction = PartySync.correct(
                current: position,
                isPaused: false,
                party: party,
                serverTime: parties.serverTime,
                coarse: isConverted
            )
            if correction.kind == .seek {
                settleParty()
            }
            apply(correction)
        }
    }

    /// A stall here holds a playing party for everyone, said after 700 ms so
    /// a moment's hiccup doesn't; ready again is said at once.
    func sayWaitingToParty(of engine: AetherEngine) async {
        for await buffering in engine.$isBuffering.removeDuplicates().values {
            partyWaitTask?.cancel()
            if buffering {
                partyWaitTask = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(700))
                    guard !Task.isCancelled, let self, let party = self.partyHere, party.playing || party.held else { return }
                    self.saidWaiting = true
                    await self.parties.setWaiting(true)
                }
            } else if saidWaiting {
                saidWaiting = false
                Task { await parties.setWaiting(false) }
            }
        }
    }

    /// Once a file plays: the host takes the party to it, anyone else is
    /// brought to the party.
    func partyLoaded() {
        guard let party = parties.party, target.downloadID == nil else { return }
        if parties.isHost, party.fileId != target.fileID {
            let file = target.fileID
            let at = position
            Task { await parties.change(file: file, at: at, playing: true) }
        } else {
            followParty(party)
        }
    }

    // MARK: - Sending

    enum PartyAction {
        case play
        case pause
        case seek
    }

    /// This viewer's own play, pause or seek, sent to the party: changes
    /// close together go as one. What the player does to follow the party
    /// isn't sent back. A play while the party plays only catches up.
    func tellParty(_ action: PartyAction) {
        guard let party = partyHere, phase == .playing, Date.now >= partySettledAt else { return }
        if action == .play, party.playing {
            followParty(party)
            return
        }
        partySendTask?.cancel()
        partySendTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            await self.parties.change(file: self.target.fileID, at: self.shownPosition, playing: !self.isPaused)
        }
    }

    // MARK: - Helpers

    /// For 800 ms after following, the player's own changes are the party's,
    /// not this viewer's.
    private func settleParty() {
        partySettledAt = Date.now.addingTimeInterval(0.8)
    }

    private func apply(_ correction: PartySync.Correction) {
        if correction.pause, !isPaused {
            togglePause()
        }
        if let place = correction.seek {
            seek(to: place)
        }
        if let rate = correction.rate {
            engine?.setRate(rate)
        }
    }
}
