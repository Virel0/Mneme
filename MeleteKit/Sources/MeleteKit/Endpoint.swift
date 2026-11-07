//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
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
    /// What the body is: JSON, but for the few calls that send a file as it is.
    public let contentType: String

    init(
        _ method: HTTPMethod,
        _ path: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        contentType: String = "application/json"
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
        self.contentType = contentType
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
