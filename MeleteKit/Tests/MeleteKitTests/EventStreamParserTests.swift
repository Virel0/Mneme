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

struct EventStreamParserTests {

    private func parse(_ lines: [String]) -> [ServerEvent] {
        var parser = EventStreamParser()
        return lines.compactMap { parser.feed($0) }
    }

    @Test
    func `reads an event and its data`() {
        let events = parse(["event: library", #"data: {"version": 3}"#, ""])
        #expect(events == [ServerEvent(name: "library", data: Data(#"{"version": 3}"#.utf8))])
    }

    @Test
    func `joins several data lines`() {
        let events = parse(["event: requests", "data: [", "data: ]", ""])
        #expect(events.first?.data == Data("[\n]".utf8))
    }

    @Test
    func `ignores keep alive comments`() {
        #expect(parse([": keep-alive", ""]).isEmpty)
    }

    @Test
    func `starts afresh after each message`() {
        let events = parse(["event: library", "data: 1", "", "data: 2", ""])
        #expect(events.map(\.name) == ["library", "message"])
    }

    @Test
    func `keeps colons inside the value`() {
        let events = parse(["event: scan", #"data: {"a":"b"}"#, ""])
        #expect(events.first?.data == Data(#"{"a":"b"}"#.utf8))
    }
}
