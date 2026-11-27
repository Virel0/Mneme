//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

/// A watch party: one film or episode played in step on every device in it.
/// Each device plays its own stream, with its own audio and subtitles.
public struct WatchParty: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    /// The six letters others join with.
    public let code: String
    /// Whoever started it, by username: they alone move it to another file.
    public let host: String
    public let fileId: Int
    public let movieId: Int?
    public let seriesId: Int?
    public let season: Int?
    public let episode: Int?
    /// Where the file was at `positionAt`, in milliseconds.
    public let positionMs: Int
    /// The server's time, in Unix milliseconds, that `positionMs` holds for.
    /// A moment ahead when a play was just set, so everyone starts together.
    public let positionAt: Int
    public let playing: Bool
    /// Raised by every change. A change sent against an older one is
    /// refused (409): another device got in first.
    public let version: Int
    /// What guests' streams are held to, in bits a second; nil for none.
    public let guestMaxBitrate: Int?
    /// Paused by Melete while someone loads, rather than by anyone's hand.
    public let held: Bool
    /// The names of those it is waiting for.
    public let waiting: [String]
    public let guests: [WatchPartyGuest]
    public let members: [WatchPartyMember]
}

/// A party and the server's clock when it answered, for keeping in step.
public struct WatchPartyAnswer: Codable, Hashable, Sendable {
    public let party: WatchParty
    /// Unix milliseconds.
    public let serverTime: Int
}

/// An account in a party, on one of its devices.
public struct WatchPartyMember: Codable, Hashable, Sendable {
    public let username: String
    public let avatarUrl: String?
    public let device: String
    /// This device.
    public let you: Bool
}

/// A guest with no account, let in by an invite.
public struct WatchPartyGuest: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let name: String
}

/// A link that lets one guest in once, within a day.
public struct WatchPartyInvite: Codable, Hashable, Sendable {
    public let invite: String
    /// The whole address, when Melete knows the one guests reach it at.
    public let link: String?
    /// The web page's path for it, to put after Melete's own address.
    public let path: String
    /// Unix seconds.
    public let expiresAt: Int
}

public struct WatchPartyStart: Codable, Sendable {
    public let fileId: Int
    public let positionMs: Int
    public let playing: Bool
    public let guestMaxBitrate: Int?

    public init(fileId: Int, positionMs: Int, playing: Bool, guestMaxBitrate: Int? = nil) {
        self.fileId = fileId
        self.positionMs = positionMs
        self.playing = playing
        self.guestMaxBitrate = guestMaxBitrate
    }
}

public struct WatchPartyJoin: Codable, Sendable {
    public let code: String

    public init(code: String) {
        self.code = code
    }
}

/// This device's play, pause or seek, or the host's move to another file,
/// against the version last seen.
public struct WatchPartyChange: Codable, Sendable {
    public let version: Int
    public let fileId: Int
    public let positionMs: Int
    public let playing: Bool

    public init(version: Int, fileId: Int, positionMs: Int, playing: Bool) {
        self.version = version
        self.fileId = fileId
        self.positionMs = positionMs
        self.playing = playing
    }
}

public struct WatchPartyWaiting: Codable, Sendable {
    public let waiting: Bool

    public init(waiting: Bool) {
        self.waiting = waiting
    }
}
