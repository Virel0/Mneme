//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

/// Talks to one Melete server, as one signed-in device or as nobody.
///
/// Every request but the public ones carries `Authorization: Bearer <token>`.
/// The client holds no state beyond the address and token it was made with, so
/// signing in or out means making a new one.
public struct MeleteClient: Sendable {

    public let baseURL: URL
    public let token: String?

    private let session: URLSession

    public init(baseURL: URL, token: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
    }

    public func signedIn(with token: String) -> MeleteClient {
        MeleteClient(baseURL: baseURL, token: token, session: session)
    }

    /// An address the server returned (artwork, a stream) made absolute.
    /// Artwork still needs `authorizationHeader`; stream URLs carry their own
    /// token.
    public func url(for path: String) -> URL? {
        URL(string: path, relativeTo: baseURL)?.absoluteURL
    }

    public var authorizationHeader: (name: String, value: String)? {
        token.map { ("Authorization", "Bearer \($0)") }
    }

    public func send<Response: Decodable & Sendable>(_ endpoint: Endpoint<Response>) async throws(MeleteError) -> Response {
        let (data, status) = try await perform(endpoint)

        guard (200 ..< 300).contains(status) else {
            throw MeleteError(status: status, data: data)
        }

        if Response.self == NoContent.self {
            // swiftlint:disable:next force_cast
            return NoContent() as! Response
        }

        do {
            return try JSONDecoder.melete.decode(Response.self, from: data)
        } catch {
            throw .decoding(String(describing: error))
        }
    }

    /// For the few endpoints whose success has more than one shape, such as
    /// Quick Connect's poll (200 with a session, 202 while waiting).
    public func sendReturningStatus(_ endpoint: Endpoint<some Decodable & Sendable>) async throws(MeleteError) -> (Data, Int) {
        let (data, status) = try await perform(endpoint)
        guard (200 ..< 300).contains(status) else {
            throw MeleteError(status: status, data: data)
        }
        return (data, status)
    }

    /// The answer and its status, whatever the status: for the few calls
    /// that read a refusal's body.
    func perform(_ endpoint: Endpoint<some Decodable & Sendable>) async throws(MeleteError) -> (Data, Int) {
        var components = URLComponents(
            url: baseURL.appending(path: endpoint.path),
            resolvingAgainstBaseURL: false
        )
        if endpoint.query.isNotEmpty {
            components?.queryItems = endpoint.query
        }
        guard let url = components?.url else {
            throw .transport("Not a valid address: \(endpoint.path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let authorizationHeader {
            request.setValue(authorizationHeader.value, forHTTPHeaderField: authorizationHeader.name)
        }
        if let body = endpoint.body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw .transport("Not an HTTP response")
        }
        return (data, http.statusCode)
    }
}

/// The answer of an endpoint that answers nothing (204).
public struct NoContent: Decodable, Sendable {}

extension Collection {
    var isNotEmpty: Bool {
        !isEmpty
    }
}
