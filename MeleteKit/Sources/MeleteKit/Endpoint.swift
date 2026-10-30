//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

/// One operation of the Melete API and the type it answers with.
public struct Endpoint<Response: Decodable & Sendable>: Sendable {

    public let method: HTTPMethod
    /// Relative to the server's address, e.g. `api/v1/home`.
    public let path: String
    public let query: [URLQueryItem]
    public let body: Data?

    init(_ method: HTTPMethod, _ path: String, query: [URLQueryItem] = [], body: Data? = nil) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
    }

    init(_ method: HTTPMethod, _ path: String, query: [URLQueryItem] = [], json: some Encodable) {
        // Encoding the API's own request types cannot fail: they hold only
        // strings, numbers and booleans.
        // swiftlint:disable:next force_try
        self.init(method, path, query: query, body: try! JSONEncoder.melete.encode(json))
    }
}

extension JSONDecoder {
    static let melete: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}

extension JSONEncoder {
    static let melete: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
}
