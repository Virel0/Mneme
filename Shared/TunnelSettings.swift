//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation
import Security

/// What the app and its packet tunnel share about this device's place on
/// Melete's own WireGuard tunnel. The plain facts travel in the tunnel's
/// `providerConfiguration`; the device's private key and the preshared key
/// stay in the keychain the two share through the app group.
enum TunnelSettings {

    /// Keys of the tunnel's `providerConfiguration`.
    enum Key {
        /// This device's address in the tunnel, such as `10.73.0.2`.
        static let address = "address"
        /// Melete's address in the tunnel, such as `10.73.0.1`: the only
        /// one routed through it.
        static let serverAddress = "serverAddress"
        /// Where the tunnel is reached, `host:port`.
        static let endpoint = "endpoint"
        /// Melete's WireGuard public key, base64.
        static let serverPublicKey = "serverPublicKey"
    }

    /// Seconds between keepalives, so a home router's mapping for the
    /// tunnel stays open; Melete's peers keep the same.
    static let keepalive: UInt16 = 25

    /// The tunnel's MTU: WireGuard's usual, inside a 1500-byte link.
    static let mtu = 1420

    enum Secret: String {
        case privateKey = "tunnel.private-key"
        case presharedKey = "tunnel.preshared-key"
    }

    static func secret(_ secret: Secret) -> Data? {
        guard var query = query(secret) else { return nil }
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    /// Readable once the device has been unlocked after a restart, so an
    /// on-demand tunnel can start without anyone at it.
    static func setSecret(_ data: Data, _ secret: Secret) {
        guard let query = query(secret) else { return }
        if SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary) == errSecItemNotFound {
            var add = query
            add[kSecValueData] = data
            add[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func removeSecrets() {
        for secret in [Secret.privateKey, .presharedKey] {
            if let query = query(secret) {
                SecItemDelete(query as CFDictionary)
            }
        }
    }

    /// In the app group's keychain, which the app and the extension both
    /// belong to.
    private static func query(_ secret: Secret) -> [CFString: Any]? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "MnemeAppGroup") as? String else { return nil }
        return [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "mneme.tunnel",
            kSecAttrAccount: secret.rawValue,
            kSecAttrAccessGroup: group,
        ]
    }
}
