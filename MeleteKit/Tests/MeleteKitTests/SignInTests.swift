//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation
@testable import MeleteKit
import Testing

/// Answers every request with one canned response, and remembers the last
/// request's path and body.
final class CannedResponse: URLProtocol, @unchecked Sendable {

    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var lastPath: String?
    nonisolated(unsafe) static var lastBody: [String: Any]?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastPath = request.url?.path
        if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                if read <= 0 {
                    break
                }
                data.append(buffer, count: read)
            }
            stream.close()
            Self.lastBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        } else {
            Self.lastBody = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite(.serialized)
struct SignInTests {

    private let client: MeleteClient = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CannedResponse.self]
        return MeleteClient(baseURL: URL(string: "http://melete.test")!, session: URLSession(configuration: configuration))
    }()

    private static let login = #"{"token":"mlt_abc","user":{"id":1,"username":"ada","is_admin":false}}"#

    private func answer(_ status: Int, _ json: String) {
        CannedResponse.status = status
        CannedResponse.body = Data(json.utf8)
    }

    @Test
    func `a right password without two-factor signs in`() async throws {
        answer(200, Self.login)
        guard case let .signedIn(login) = try await client.signIn(username: "ada", password: "pw", deviceName: "TV") else {
            Issue.record("expected a session")
            return
        }
        #expect(login.token == "mlt_abc")
    }

    @Test
    func `a right password with two-factor on asks for a code`() async throws {
        answer(401, #"{"error":"A code is needed","second_factor":"totp","challenge":"m2f_xyz","expires_in":300}"#)
        guard case let .codeNeeded(challenge) = try await client.signIn(username: "ada", password: "pw", deviceName: "TV") else {
            Issue.record("expected a challenge")
            return
        }
        #expect(challenge.challenge == "m2f_xyz")
        #expect(challenge.expiresIn == 300)
    }

    @Test
    func `a wrong password is unauthorized, not a challenge`() async {
        answer(401, #"{"error":"wrong username or password"}"#)
        await #expect(throws: MeleteError.unauthorized) {
            _ = try await client.signIn(username: "ada", password: "nope", deviceName: "TV")
        }
    }

    @Test
    func `the code finishes the sign-in with the challenge`() async throws {
        answer(200, Self.login)
        let login = try await client.finishSignIn(challenge: "m2f_xyz", code: "123456")
        #expect(login.token == "mlt_abc")
        #expect(CannedResponse.lastPath == "/api/v1/auth/login/second-factor")
        #expect(CannedResponse.lastBody?["challenge"] as? String == "m2f_xyz")
        #expect(CannedResponse.lastBody?["code"] as? String == "123456")
    }

    @Test
    func `a wrong code is unauthorized`() async {
        answer(401, #"{"error":"that code isn't right"}"#)
        await #expect(throws: MeleteError.unauthorized) {
            _ = try await client.finishSignIn(challenge: "m2f_xyz", code: "000000")
        }
    }

    @Test
    func `a challenge that ran out is a 410`() async {
        answer(410, #"{"error":"start again"}"#)
        await #expect(throws: MeleteError.server(status: 410, message: "start again")) {
            _ = try await client.finishSignIn(challenge: "m2f_xyz", code: "123456")
        }
    }
}
