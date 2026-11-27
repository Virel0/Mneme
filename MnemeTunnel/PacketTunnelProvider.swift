//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation
import Network
import NetworkExtension
import os
import Tunnel

/// Melete's own WireGuard tunnel, for this device away from home. Only
/// Melete's address in the tunnel is routed through it: everything else the
/// device does goes as it always does. Packets for Melete go through
/// WireGuard (`TunnelPeer`) to the tunnel's endpoint over UDP, and what comes
/// back goes to the device. Everything runs on one queue.
final class PacketTunnelProvider: NEPacketTunnelProvider, @unchecked Sendable {

    private enum Problem: LocalizedError {
        case notSetUp

        var errorDescription: String? {
            "Mneme's tunnel isn't set up on this device. Set it up again in Mneme's settings."
        }
    }

    /// What the app saved for the tunnel, and the keys from the keychain.
    private struct Configuration {
        let address: String
        let serverAddress: String
        let host: String
        let endpoint: NWEndpoint
        let serverPublicKey: Data
        let privateKey: Data
        let presharedKey: Data

        init(_ saved: NEVPNProtocol?) throws {
            guard let saved = (saved as? NETunnelProviderProtocol)?.providerConfiguration,
                  let address = saved[TunnelSettings.Key.address] as? String,
                  let serverAddress = saved[TunnelSettings.Key.serverAddress] as? String,
                  let endpoint = saved[TunnelSettings.Key.endpoint] as? String,
                  let serverKey = (saved[TunnelSettings.Key.serverPublicKey] as? String).flatMap({ Data(base64Encoded: $0) }),
                  let privateKey = TunnelSettings.secret(.privateKey),
                  let presharedKey = TunnelSettings.secret(.presharedKey),
                  let colon = endpoint.lastIndex(of: ":"),
                  let port = NWEndpoint.Port(String(endpoint[endpoint.index(after: colon)...]))
            else { throw Problem.notSetUp }
            // `[2001:db8::1]:51820` as well as `home.example:51820`.
            let host = String(endpoint[..<colon]).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            self.address = address
            self.serverAddress = serverAddress
            self.host = host
            self.endpoint = .hostPort(host: NWEndpoint.Host(host), port: port)
            serverPublicKey = serverKey
            self.privateKey = privateKey
            self.presharedKey = presharedKey
        }

        func makePeer() -> TunnelPeer? {
            TunnelPeer(
                privateKey: privateKey,
                peerPublicKey: serverPublicKey,
                presharedKey: presharedKey,
                keepalive: TunnelSettings.keepalive
            )
        }
    }

    private let queue = DispatchQueue(label: "mneme.tunnel")
    private let log = Logger(subsystem: "mneme", category: "tunnel")
    private var configuration: Configuration?
    private var peer: TunnelPeer?
    private var connection: NWConnection?
    private var timer: DispatchSourceTimer?

    override func startTunnel(options _: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let configuration: Configuration
        do {
            configuration = try Configuration(protocolConfiguration)
        } catch {
            completionHandler(error)
            return
        }

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: configuration.host)
        let ipv4 = NEIPv4Settings(addresses: [configuration.address], subnetMasks: ["255.255.255.255"])
        ipv4.includedRoutes = [NEIPv4Route(destinationAddress: configuration.serverAddress, subnetMask: "255.255.255.255")]
        settings.ipv4Settings = ipv4
        settings.mtu = NSNumber(value: TunnelSettings.mtu)

        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self else { return }
            if let error {
                completionHandler(error)
                return
            }
            queue.async {
                self.configuration = configuration
                self.peer = configuration.makePeer()
                self.connect()
                self.startTimer()
                self.readPackets()
                self.log.info("tunnel up to \(configuration.serverAddress, privacy: .public)")
                completionHandler(nil)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        queue.async {
            self.timer?.cancel()
            self.timer = nil
            self.connection?.cancel()
            self.connection = nil
            self.peer = nil
            self.log.info("tunnel down: \(reason.rawValue, privacy: .public)")
            completionHandler()
        }
    }

    // MARK: - Packets

    /// From the device: through WireGuard to Melete.
    private func readPackets() {
        packetFlow.readPackets { [weak self] packets, _ in
            guard let self else { return }
            queue.async {
                guard let peer = self.peer else { return }
                for packet in packets {
                    self.handle(peer.send(packet))
                }
                self.readPackets()
            }
        }
    }

    /// From Melete: opened, for the device, or a reply; then whatever was
    /// held while a handshake ran.
    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] datagram, _, _, error in
            guard let self, connection === self.connection else { return }
            if let datagram, let peer {
                handle(peer.receive(datagram))
                while let held = peer.nextQueued() {
                    connection.send(content: held, completion: .idempotent)
                }
            }
            if error == nil {
                receive(on: connection)
            }
        }
    }

    private func handle(_ output: TunnelPeer.Output) {
        switch output {
        case let .toNetwork(datagram):
            connection?.send(content: datagram, completion: .idempotent)
        case let .toDevice(packet):
            packetFlow.writePackets([packet], withProtocols: [NSNumber(value: AF_INET)])
        case .nothing, .failed:
            break
        }
    }

    // MARK: - The connection and the timers

    /// UDP to the tunnel's endpoint, made again when it fails or a better
    /// path comes (Wi-Fi after mobile data, say).
    private func connect() {
        guard let configuration else { return }
        connection?.cancel()
        let connection = NWConnection(to: configuration.endpoint, using: .udp)
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection, connection === self.connection else { return }
            switch state {
            case .ready:
                receive(on: connection)
            case let .failed(error):
                log.error("connection failed: \(error.localizedDescription, privacy: .public)")
                queue.asyncAfter(deadline: .now() + 1) { [weak self] in
                    guard let self, connection === self.connection else { return }
                    connect()
                }
            default:
                break
            }
        }
        connection.betterPathUpdateHandler = { [weak self, weak connection] better in
            guard better, let self, let connection, connection === self.connection else { return }
            connect()
        }
        self.connection = connection
        connection.start(queue: queue)
    }

    /// WireGuard's timers: handshake retries and keepalives. A session that
    /// has expired is started afresh from the same keys.
    private func startTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .milliseconds(250), repeating: .milliseconds(250))
        timer.setEventHandler { [weak self] in
            guard let self, let peer else { return }
            let output = peer.tick()
            if output == .failed {
                self.peer = configuration?.makePeer()
            } else {
                handle(output)
            }
        }
        timer.resume()
        self.timer = timer
    }
}
