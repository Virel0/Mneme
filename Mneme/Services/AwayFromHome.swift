//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import CryptoKit
import Foundation
import MeleteKit
@preconcurrency import NetworkExtension
import Observation
import UIKit

/// Mneme's own VPN: this device on Melete's WireGuard tunnel, for reaching
/// the server when the device isn't at home.
///
/// The device makes its own key pair and gives Melete only the public key.
/// The system connects the tunnel by itself, on demand: whenever the server's
/// home address doesn't answer, and never while it does.
@MainActor
@Observable
final class AwayFromHome {

    /// Where this device's tunnel goes, kept in user defaults. Nothing in it
    /// is secret: the keys are in the keychain.
    struct Place: Codable, Equatable, Sendable {
        /// The server as signed in to, at home.
        let home: URL
        /// The same server through the tunnel, such as `http://10.73.0.1`.
        let server: URL
        /// The device on Melete, to remove it by.
        let deviceID: Int
        /// The tunnel's `providerConfiguration`, to save it again if it has
        /// gone from the system's settings.
        let configuration: [String: String]
        /// Whether the system connects the tunnel away from home.
        var connectsAway: Bool
    }

    private(set) var place: Place? = AwayFromHome.saved
    private(set) var status: NEVPNStatus = .invalid
    /// Set when Melete couldn't be told the device was removed.
    private(set) var removalNote: String?

    private var manager: NETunnelProviderManager?
    private var watching: Task<Void, Never>?

    private nonisolated static let placeKey = "tunnel.place"
    /// The part of Melete a device sees through the tunnel: films, shows and
    /// requests, as Mneme does.
    private static let parts: [TunnelDevicePart] = [.video, .requests]

    /// What was saved, readable from anywhere.
    nonisolated static var saved: Place? {
        UserDefaults.standard.data(forKey: placeKey).flatMap { try? JSONDecoder().decode(Place.self, from: $0) }
    }

    /// Whether the address is Melete's through the tunnel, which isn't the
    /// home network however private it looks.
    nonisolated static func isThroughTunnel(_ url: URL) -> Bool {
        guard let host = url.host(), let tunnel = saved?.server.host() else { return false }
        return host == tunnel
    }

    /// Whether this device has a tunnel to the server signed in to at `home`
    /// and lets the system connect it.
    func goesAway(from home: URL) -> Bool {
        place?.home == home && place?.connectsAway == true
    }

    // MARK: - The way in

    /// Where to reach the server signed in to at `home` now: there, when it
    /// answers; through the tunnel otherwise, when this device has one to it.
    func address(for home: URL) async -> URL {
        guard goesAway(from: home), let place else { return home }
        return await Self.answers(home) ? home : place.server
    }

    private nonisolated static func answers(_ home: URL) async -> Bool {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        return await (try? MeleteClient(baseURL: home, session: session).health()) != nil
    }

    // MARK: - Setting up and removing

    /// The tunnel as the system has it, and its status from then on.
    func load() async {
        let managers = try? await NETunnelProviderManager.loadAllFromPreferences()
        manager = managers?.first { ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == Self.extensionID }
        watchStatus()
    }

    /// Adds this device to Melete's tunnel under the signed-in user, and
    /// the tunnel to the system, which asks first. Undone on Melete when the
    /// system's answer is no.
    func setUp(with client: MeleteClient, home: URL) async throws {
        let key = Curve25519.KeyAgreement.PrivateKey()
        let added = try await client.addTunnelDevice(NewTunnelDevice(
            name: String(UIDevice.current.name.prefix(60)),
            parts: Self.parts,
            publicKey: key.publicKey.rawRepresentation.base64EncodedString()
        ))
        do {
            guard let presharedKey = Data(base64Encoded: added.presharedKey), let server = URL(string: added.server) else {
                throw MeleteError.decoding("tunnel device")
            }
            TunnelSettings.setSecret(key.rawRepresentation, .privateKey)
            TunnelSettings.setSecret(presharedKey, .presharedKey)
            let place = Place(
                home: home,
                server: server,
                deviceID: added.id,
                configuration: [
                    TunnelSettings.Key.address: added.address,
                    TunnelSettings.Key.serverAddress: added.serverAddress,
                    TunnelSettings.Key.endpoint: added.endpoint,
                    TunnelSettings.Key.serverPublicKey: added.serverPublicKey,
                ],
                connectsAway: true
            )
            try await save(place)
        } catch {
            try? await client.removeTunnelDevice(added.id)
            TunnelSettings.removeSecrets()
            throw error
        }
    }

    /// Turns the system's connecting away from home on or off. Off, the
    /// tunnel also comes down now.
    func setConnectsAway(_ on: Bool) async throws {
        guard var place else { return }
        place.connectsAway = on
        try await save(place)
        if !on {
            manager?.connection.stopVPNTunnel()
        }
    }

    /// Takes the device off Melete's tunnel and the tunnel off the system.
    /// Done here even when Melete can't be told, with a note to remove the
    /// device there instead: its key is gone either way.
    func remove(with client: MeleteClient) async {
        removalNote = nil
        if let place {
            do {
                try await client.removeTunnelDevice(place.deviceID)
            } catch .notFound {
                // Already removed in Melete.
            } catch {
                removalNote = "Melete couldn't be told: remove \(UIDevice.current.name) from your devices in Melete. \(error.localizedDescription)"
            }
        }
        try? await manager?.removeFromPreferences()
        manager = nil
        TunnelSettings.removeSecrets()
        place = nil
        UserDefaults.standard.removeObject(forKey: Self.placeKey)
        watchStatus()
    }

    /// Saves the tunnel to the system: only Melete through it, connected on
    /// demand away from home.
    private func save(_ place: Place) async throws {
        let manager = manager ?? NETunnelProviderManager()
        let tunnel = NETunnelProviderProtocol()
        tunnel.providerBundleIdentifier = Self.extensionID
        tunnel.serverAddress = place.configuration[TunnelSettings.Key.endpoint]
        tunnel.providerConfiguration = place.configuration
        manager.protocolConfiguration = tunnel
        manager.localizedDescription = "Melete"
        manager.onDemandRules = Self.rules(home: place.home)
        manager.isOnDemandEnabled = place.connectsAway
        manager.isEnabled = true
        try await manager.saveToPreferences()
        // A manager just saved is loaded again before it can be started.
        try await manager.loadFromPreferences()
        self.manager = manager
        self.place = place
        UserDefaults.standard.set(try? JSONEncoder().encode(place), forKey: Self.placeKey)
        watchStatus()
    }

    /// At home, where the server's own address answers its health check,
    /// the tunnel is down; anywhere else it is up.
    private static func rules(home: URL) -> [NEOnDemandRule] {
        let atHome = NEOnDemandRuleDisconnect()
        atHome.probeURL = home.appending(path: "api/v1/health")
        return [atHome, NEOnDemandRuleConnect()]
    }

    private static var extensionID: String {
        (Bundle.main.bundleIdentifier ?? "") + ".tunnel"
    }

    private func watchStatus() {
        watching?.cancel()
        status = manager?.connection.status ?? .invalid
        guard let connection = manager?.connection else { return }
        watching = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .NEVPNStatusDidChange, object: connection) {
                self?.status = connection.status
            }
        }
    }
}
