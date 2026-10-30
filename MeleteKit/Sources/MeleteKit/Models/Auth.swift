//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

public struct Health: Codable, Sendable {
    public let status: String
    public let version: String
}

public struct User: Codable, Hashable, Sendable {
    public let id: Int
    public let username: String
    public let isAdmin: Bool
}

public struct LoginRequest: Codable, Sendable {
    public let username: String
    public let password: String
    public let deviceName: String
}

public struct LoginResponse: Codable, Sendable {
    /// Starts with `mlt_`. The server shows it only once.
    public let token: String
    public let user: User
}

public struct QuickConnectRequest: Codable, Sendable {
    public let deviceName: String
}

public struct QuickConnectCode: Codable, Sendable {
    /// Six letters and digits to show on screen.
    public let code: String
    /// Sent only to the poll. Starts with `mqc_`.
    public let secret: String
    public let expiresIn: Int
}

public struct QuickConnectPoll: Codable, Sendable {
    public let secret: String
}

public enum QuickConnectState: Sendable {
    case waiting
    case approved(LoginResponse)
}

public extension MeleteClient {

    func health() async throws(MeleteError) -> Health {
        try await send(Endpoint(.get, "api/v1/health"))
    }

    func signIn(username: String, password: String, deviceName: String) async throws(MeleteError) -> LoginResponse {
        try await send(Endpoint(
            .post,
            "api/v1/auth/login",
            json: LoginRequest(username: username, password: password, deviceName: deviceName)
        ))
    }

    func signOut() async throws(MeleteError) {
        _ = try await send(Endpoint<NoContent>(.post, "api/v1/auth/logout"))
    }

    func me() async throws(MeleteError) -> User {
        try await send(Endpoint(.get, "api/v1/me"))
    }

    func startQuickConnect(deviceName: String) async throws(MeleteError) -> QuickConnectCode {
        try await send(Endpoint(.post, "api/v1/auth/quick-connect", json: QuickConnectRequest(deviceName: deviceName)))
    }

    /// Answers `.waiting` until someone approves the code, then the session,
    /// once. Throws `.notFound` when the code has run out.
    func pollQuickConnect(secret: String) async throws(MeleteError) -> QuickConnectState {
        let (data, status) = try await sendReturningStatus(Endpoint<LoginResponse>(
            .post,
            "api/v1/auth/quick-connect/poll",
            json: QuickConnectPoll(secret: secret)
        ))
        guard status == 200 else { return .waiting }
        do {
            return try .approved(JSONDecoder.melete.decode(LoginResponse.self, from: data))
        } catch {
            throw .decoding(String(describing: error))
        }
    }
}
