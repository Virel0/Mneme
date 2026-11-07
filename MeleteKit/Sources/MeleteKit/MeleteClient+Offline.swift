//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

/// Offline copies: asked for, followed while the server makes them, then a
/// link to download each one, and deleted once the device has it.
public extension MeleteClient {

    /// The sizes a copy of the file could be made at, whether copies are on,
    /// and the copies already made of it.
    func offlineChoices(file id: Int) async throws(MeleteError) -> OfflineChoices {
        try await send(Endpoint(.get, "api/v1/files/\(id)/offline"))
    }

    /// Asks for a copy, made in the background; it comes back queued.
    func askOfflineCopy(file id: Int, _ request: OfflineRequest) async throws(MeleteError) -> OfflineCopy {
        try await send(Endpoint(.post, "api/v1/files/\(id)/offline", json: request))
    }

    /// The viewer's copies, newest first.
    func offlineCopies() async throws(MeleteError) -> [OfflineCopy] {
        try await send(Endpoint(.get, "api/v1/offline"))
    }

    func offlineCopy(_ id: Int) async throws(MeleteError) -> OfflineCopy {
        try await send(Endpoint(.get, "api/v1/offline/\(id)"))
    }

    /// Deletes a copy on the server, or stops one being made.
    func deleteOfflineCopy(_ id: Int) async throws(MeleteError) {
        _ = try await send(Endpoint<NoContent>(.delete, "api/v1/offline/\(id)"))
    }

    /// A download link for a ready copy.
    func offlineLink(_ id: Int) async throws(MeleteError) -> OfflineLink {
        try await send(Endpoint(.post, "api/v1/offline/\(id)/link"))
    }
}
