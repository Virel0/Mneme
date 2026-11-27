//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

/// A part of Melete a device on its WireGuard tunnel reaches.
public enum TunnelDevicePart: String, Codable, Hashable, Sendable {
    case video
    case music
    case requests
    case admin
}

/// The user's devices on Melete's own WireGuard tunnel, and whether the
/// server has the tunnel set up at all.
public struct TunnelDevices: Codable, Hashable, Sendable {
    /// Whether a device can be added: Melete's own tunnel is on.
    public let enabled: Bool
    /// The most devices one user has.
    public let limit: Int
    public let devices: [TunnelDevice]
}

public struct TunnelDevice: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    /// 1 to 60 characters, e.g. "Living room Apple TV".
    public let name: String
    public let parts: [TunnelDevicePart]
    /// Its own address in the tunnel, such as `10.73.0.2`.
    public let address: String?
    /// Unix seconds.
    public let createdAt: Int
}

/// A device to add, with its own WireGuard public key: the private key
/// never leaves it.
public struct NewTunnelDevice: Codable, Sendable {
    public let name: String
    public let parts: [TunnelDevicePart]
    /// 32 bytes in base64.
    public let publicKey: String?

    public init(name: String, parts: [TunnelDevicePart], publicKey: String) {
        self.name = name
        self.parts = parts
        self.publicKey = publicKey
    }
}

/// A device just added, with what it needs to connect. The preshared key is
/// shown this once.
public struct TunnelDeviceAdded: Codable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let parts: [TunnelDevicePart]
    /// The device's address in the tunnel, and the only one its packets may
    /// come from.
    public let address: String
    public let createdAt: Int
    /// Melete's WireGuard public key, base64.
    public let serverPublicKey: String
    /// Melete's address in the tunnel, such as `10.73.0.1`: the only one the
    /// device's peer allows.
    public let serverAddress: String
    /// Melete through the tunnel, such as `http://10.73.0.1`.
    public let server: String
    /// Where the device reaches the tunnel, `host:port`.
    public let endpoint: String
    /// Base64.
    public let presharedKey: String
    /// A whole config, only when Melete made the key pair; never for Mneme,
    /// which sends its own public key.
    public let wireguardConfig: String?
}
