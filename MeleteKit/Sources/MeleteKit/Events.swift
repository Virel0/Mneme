//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

/// One message from Melete's event stream: its kind and its JSON.
public struct ServerEvent: Sendable, Equatable {
    public let name: String
    public let data: Data

    /// The message's JSON as one of the API's types, or nil if it is not one.
    public func decode<T: Decodable>(_ type: T.Type) -> T? {
        try? JSONDecoder.melete.decode(type, from: data)
    }
}

/// Reads Server-Sent Events a line at a time.
///
/// A message is its `event:` and `data:` lines up to a blank line; several
/// `data:` lines join with newlines; lines starting with `:` are keep-alive
/// comments.
public struct EventStreamParser: Sendable {

    private var name = "message"
    private var data: [String] = []

    public init() {}

    /// Takes one line, without its newline, and returns the message it
    /// completes, if it does.
    public mutating func feed(_ line: String) -> ServerEvent? {
        if line.isEmpty {
            defer {
                name = "message"
                data = []
            }
            guard !data.isEmpty else { return nil }
            return ServerEvent(name: name, data: Data(data.joined(separator: "\n").utf8))
        }
        if line.hasPrefix(":") {
            return nil
        }

        let (field, value) = Self.split(line)
        switch field {
        case "event": name = value
        case "data": data.append(value)
        default: break
        }
        return nil
    }

    /// "field: value", the one space after the colon not being part of the
    /// value.
    private static func split(_ line: String) -> (String, String) {
        guard let colon = line.firstIndex(of: ":") else { return (line, "") }
        var value = line[line.index(after: colon)...]
        if value.first == " " {
            value = value.dropFirst()
        }
        return (String(line[..<colon]), String(value))
    }
}

/// The parts of the stream Mneme reads.
public struct LibraryVersion: Codable, Sendable {
    /// Changes whenever a title is added or goes.
    public let version: Int
}

public struct FavouritesVersion: Codable, Sendable {
    public let version: Int
    public let total: Int
}

public extension MeleteClient {

    /// Melete's events for this device, as they happen. Each kind is sent
    /// once at the start and again whenever it changes. The stream ends
    /// after ten minutes, or when the session signs out; the caller
    /// reconnects.
    func events() -> AsyncThrowingStream<ServerEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await readEvents(into: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func readEvents(into continuation: AsyncThrowingStream<ServerEvent, any Error>.Continuation) async throws {
        var request = URLRequest(url: baseURL.appending(path: "api/v1/events"))
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        // Longer than the ten minutes Melete keeps a stream open.
        request.timeoutInterval = 60 * 15
        if let authorizationHeader {
            request.setValue(authorizationHeader.value, forHTTPHeaderField: authorizationHeader.name)
        }

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        if let status = (response as? HTTPURLResponse)?.statusCode, !(200 ..< 300).contains(status) {
            throw MeleteError(status: status, data: Data())
        }

        var parser = EventStreamParser()
        for try await line in bytes.lines {
            if let event = parser.feed(line) {
                continuation.yield(event)
            }
        }
    }
}
