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

@MainActor
@Observable
final class SignInModel {

    enum Step: Equatable {
        case address
        case signIn(server: URL, version: String)
    }

    private(set) var step: Step = .address
    private(set) var isWorking = false
    private(set) var error: String?
    private(set) var quickConnectCode: String?
    /// Set when the password was right and the account has two-factor
    /// sign-in on: the sign-in finishes with a code from the authenticator.
    private(set) var codeChallenge: SecondFactorNeeded?
    @ObservationIgnored
    private var challengeExpiry: Date?

    private var pollTask: Task<Void, Never>?

    /// What the device is called in the server's device list and to whoever
    /// approves a Quick Connect code.
    static let deviceName = "Mneme on Apple TV"

    // MARK: - Address

    /// Accepts what people type: `10.0.0.5:8100`, `melete.example.com`,
    /// with or without a scheme. Without one, plain http is assumed, as for a
    /// server at home.
    static func serverURL(from text: String) -> URL? {
        var text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasSuffix("/") {
            text.removeLast()
        }
        guard text.isEmpty == false else { return nil }
        if text.contains("://") == false {
            text = "http://" + text
        }
        guard let url = URL(string: text), let scheme = url.scheme, ["http", "https"].contains(scheme), url.host() != nil else {
            return nil
        }
        return url
    }

    func connect(to text: String) async {
        guard let url = Self.serverURL(from: text) else {
            error = "That isn't a server address. Try something like 10.0.0.5:8100."
            return
        }
        isWorking = true
        error = nil
        defer { isWorking = false }

        do {
            let health = try await MeleteClient(baseURL: url).health()
            step = .signIn(server: url, version: health.version)
            startQuickConnect(server: url)
        } catch {
            self.error = "No Melete server answered at \(url.absoluteString). Check the address and port."
        }
    }

    func changeServer() {
        pollTask?.cancel()
        quickConnectCode = nil
        error = nil
        step = .address
    }

    // MARK: - Quick Connect

    private func startQuickConnect(server: URL) {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            await self?.runQuickConnect(server: server)
        }
    }

    /// Shows a code, asks every few seconds whether it was approved, and
    /// starts a new code whenever one runs out, for as long as this screen is
    /// up.
    private func runQuickConnect(server: URL) async {
        let client = MeleteClient(baseURL: server)

        while Task.isCancelled == false {
            let code: QuickConnectCode
            do {
                code = try await client.startQuickConnect(deviceName: Self.deviceName)
            } catch {
                quickConnectCode = nil
                return
            }
            quickConnectCode = code.code

            let expiry = Date.now.addingTimeInterval(TimeInterval(code.expiresIn))
            while Task.isCancelled == false, Date.now < expiry {
                try? await Task.sleep(for: .seconds(3))
                guard Task.isCancelled == false else { return }

                // Gone or refused: start a new code.
                guard let state = try? await client.pollQuickConnect(secret: code.secret) else { break }

                if case let .approved(login) = state {
                    signedIn?(server, login)
                    return
                }
            }
        }
    }

    // MARK: - Password

    func signIn(server: URL, username: String, password: String) async {
        isWorking = true
        error = nil
        defer { isWorking = false }

        do {
            switch try await MeleteClient(baseURL: server)
                .signIn(username: username, password: password, deviceName: Self.deviceName)
            {
            case let .signedIn(login):
                pollTask?.cancel()
                signedIn?(server, login)
            case let .codeNeeded(challenge):
                codeChallenge = challenge
                challengeExpiry = Date.now.addingTimeInterval(TimeInterval(challenge.expiresIn))
            }
        } catch .unauthorized {
            error = "That username and password don't match."
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Two-factor code

    func finishSignIn(server: URL, code: String) async {
        guard let challenge = codeChallenge else { return }
        guard let challengeExpiry, Date.now < challengeExpiry else {
            cancelCode()
            error = "That took too long. Sign in with your password again."
            return
        }
        isWorking = true
        error = nil
        defer { isWorking = false }

        do {
            let login = try await MeleteClient(baseURL: server).finishSignIn(challenge: challenge.challenge, code: code)
            pollTask?.cancel()
            signedIn?(server, login)
        } catch .unauthorized {
            error = "That code didn't work. Enter the one your authenticator shows now."
        } catch .server(status: 410, _) {
            cancelCode()
            error = "That took too long. Sign in with your password again."
        } catch let .tooManyRequests(message) {
            error = message
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Back to the password, dropping the challenge.
    func cancelCode() {
        codeChallenge = nil
        challengeExpiry = nil
    }

    /// Set by the view, to hand the new session to the session store.
    var signedIn: ((URL, LoginResponse) -> Void)?

    func stop() {
        pollTask?.cancel()
    }
}
