//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation
@testable import MeleteKit
import Testing

/// Answers every request with one body and content type, and remembers the
/// path asked for.
final class StreamFileResponse: URLProtocol, @unchecked Sendable {

    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var contentType = "application/json"
    nonisolated(unsafe) static var lastPath: String?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastPath = request.url?.path
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": Self.contentType]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// An ASS track's script and the video's fonts, fetched under the stream
/// link as Melete serves them.
@Suite(.serialized)
struct StyledSubtitleTests {

    private let client: MeleteClient = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StreamFileResponse.self]
        return MeleteClient(baseURL: URL(string: "http://melete.test")!, session: URLSession(configuration: configuration))
    }()

    private let stream = URL(string: "http://melete.test/api/v1/stream/tok")!

    private func track(_ assURL: String?) throws -> SubtitleTrack {
        let json = """
        {"track":"s3","source":"embedded","codec":"ass","language":"jpn","title":null,"default":true,
         "forced":false,"hearing_impaired":false,"text":true,"file":null,"encoding":null,
         "ass":true,"ass_url":\(assURL.map { "\"\($0)\"" } ?? "null")}
        """
        return try JSONDecoder.melete.decode(SubtitleTrack.self, from: Data(json.utf8))
    }

    @Test
    func `the script comes from under the stream link, decoded as its charset says`() async throws {
        let script = "[Script Info]\nTitle: 雨の日\n"
        StreamFileResponse.body = try #require(script.data(using: .shiftJIS))
        StreamFileResponse.contentType = "text/x-ass; charset=Shift_JIS"

        let fetched = try await client.assScript(stream: stream, track: track("subtitles/s3.ass"))

        #expect(StreamFileResponse.lastPath == "/api/v1/stream/tok/subtitles/s3.ass")
        #expect(fetched == script)
    }

    @Test
    func `a script without a charset is read as UTF-8`() async throws {
        StreamFileResponse.body = Data("Dialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,é\n".utf8)
        StreamFileResponse.contentType = "text/x-ass"

        let fetched = try await client.assScript(stream: stream, track: track("subtitles/s3.ass"))

        #expect(fetched.hasSuffix("é\n"))
    }

    @Test
    func `a track without an ASS address isn't fetched`() async throws {
        await #expect(throws: MeleteError.self) {
            try await client.assScript(stream: stream, track: track(nil))
        }
    }

    @Test
    func `the fonts are listed under the stream link and fetched by their own address`() async throws {
        StreamFileResponse.body = Data("""
        [{"id":4,"file_name":"Signs.ttf","mime_type":"font/ttf","size":3,"url":"/api/v1/stream/tok/fonts/4"}]
        """.utf8)
        StreamFileResponse.contentType = "application/json"

        let fonts = try await client.attachedFonts(stream: stream)
        #expect(StreamFileResponse.lastPath == "/api/v1/stream/tok/fonts")
        #expect(fonts.map(\.fileName) == ["Signs.ttf"])

        StreamFileResponse.body = Data([1, 2, 3])
        let data = try await client.fontData(fonts[0])
        #expect(StreamFileResponse.lastPath == "/api/v1/stream/tok/fonts/4")
        #expect(data == Data([1, 2, 3]))
    }
}
