//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

/// This user's devices on Melete's own WireGuard tunnel (Melete 0.10).
public extension MeleteClient {

    func tunnelDevices() async throws(MeleteError) -> TunnelDevices {
        try await send(Endpoint(.get, "api/v1/tunnel/devices"))
    }

    /// Adds this device by its public key. Refused when the tunnel isn't set
    /// up (503) or the user already has as many devices as allowed (409).
    func addTunnelDevice(_ device: NewTunnelDevice) async throws(MeleteError) -> TunnelDeviceAdded {
        try await send(Endpoint(.post, "api/v1/tunnel/devices", json: device))
    }

    /// Cuts the device off at once.
    func removeTunnelDevice(_ id: Int) async throws(MeleteError) {
        _ = try await send(Endpoint<NoContent>(.delete, "api/v1/tunnel/devices/\(id)"))
    }
}
