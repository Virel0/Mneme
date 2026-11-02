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
