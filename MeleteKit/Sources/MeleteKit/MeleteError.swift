//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

public enum MeleteError: Error, Equatable, Sendable {

    /// The token is missing, ended or revoked: sign in again.
    case unauthorized
    /// Signed in, but not allowed (an admin-only operation, or a key whose
    /// scope does not reach it).
    case forbidden(String)
    case notFound(String)
    case tooManyRequests(String)
    /// Any other error the server answered, with its `error` text.
    case server(status: Int, message: String)
    /// The server could not be reached, or did not answer HTTP.
    case transport(String)
    /// The answer was not the shape this app expects.
    case decoding(String)

    init(status: Int, data: Data) {
        // Every Melete error has the `Error` shape: `{"error": "..."}`.
        let message = (try? JSONDecoder.melete.decode(ErrorBody.self, from: data))?.error
            ?? HTTPURLResponse.localizedString(forStatusCode: status)

        switch status {
        case 401: self = .unauthorized
        case 403: self = .forbidden(message)
        case 404: self = .notFound(message)
        case 429: self = .tooManyRequests(message)
        default: self = .server(status: status, message: message)
        }
    }

    private struct ErrorBody: Decodable {
        let error: String
    }
}

extension MeleteError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .unauthorized: "Signed out. Sign in again."
        case let .forbidden(message),
             let .notFound(message),
             let .tooManyRequests(message),
             let .server(_, message): message
        case let .transport(message): message
        case .decoding: "The server answered in a way this version of Mneme does not understand."
        }
    }
}
