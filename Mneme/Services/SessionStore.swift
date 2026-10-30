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

/// One signed-in user on one server: what the app needs to make requests.
struct Session: Codable, Hashable, Identifiable {
    let server: URL
    let user: User

    /// Unique per user per server, and the token's keychain account.
    var id: String {
        "\(server.absoluteString)#\(user.id)"
    }
}

/// The sessions this device has, and which one is in use.
///
/// The sessions themselves are in user defaults; their tokens are in the
/// keychain and never anywhere else. Several sessions can be kept, one for
/// each person who signs in on the device.
@MainActor
@Observable
final class SessionStore {

    private(set) var sessions: [Session] = []
    private(set) var current: Session?

    private let defaults: UserDefaults
    private static let sessionsKey = "sessions"
    private static let currentKey = "currentSession"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Self.sessionsKey),
           let stored = try? JSONDecoder().decode([Session].self, from: data)
        {
            // A session whose token is gone (a restored backup without its
            // keychain) cannot be used, so it is not offered.
            sessions = stored.filter { Keychain.string(for: $0.id) != nil }
        }
        let currentID = defaults.string(forKey: Self.currentKey)
        current = sessions.first { $0.id == currentID }
    }

    func client(for session: Session) -> MeleteClient? {
        guard let token = Keychain.string(for: session.id) else { return nil }
        return MeleteClient(baseURL: session.server, token: token)
    }

    func add(server: URL, login: LoginResponse) {
        let session = Session(server: server, user: login.user)
        Keychain.set(login.token, for: session.id)
        sessions.removeAll { $0.id == session.id }
        sessions.append(session)
        current = session
        save()
    }

    func switchTo(_ session: Session) {
        current = session
        save()
    }

    /// Forgets the session and its token. The server is told separately, by
    /// whoever has a client for it.
    func remove(_ session: Session) {
        Keychain.remove(session.id)
        sessions.removeAll { $0.id == session.id }
        if current?.id == session.id {
            current = nil
        }
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(sessions), forKey: Self.sessionsKey)
        defaults.set(current?.id, forKey: Self.currentKey)
    }
}
