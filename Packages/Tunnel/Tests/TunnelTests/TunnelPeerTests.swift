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
import Testing
import Tunnel

struct TunnelPeerTests {

    /// A UDP packet from 10.73.0.2 to 10.73.0.1, with a valid header checksum.
    private func ipv4Packet(_ payload: [UInt8]) -> Data {
        let total = 20 + 8 + payload.count
        var header: [UInt8] = [0x45, 0, UInt8(total >> 8), UInt8(total & 0xFF), 0, 0, 0x40, 0, 64, 17, 0, 0, 10, 73, 0, 2, 10, 73, 0, 1]
        var sum: UInt32 = 0
        for index in stride(from: 0, to: header.count, by: 2) {
            sum += UInt32(header[index]) << 8 | UInt32(header[index + 1])
        }
        let checksum = ~UInt16((sum & 0xFFFF) + (sum >> 16))
        header[10] = UInt8(checksum >> 8)
        header[11] = UInt8(checksum & 0xFF)
        let udpLength = 8 + payload.count
        return Data(header + [0x30, 0x39, 0x00, 0x50, UInt8(udpLength >> 8), UInt8(udpLength & 0xFF), 0, 0] + payload)
    }

    @Test
    func `a packet crosses after a handshake made with CryptoKit keys`() throws {
        // The device's keys made as the app makes them; the server's too.
        let device = Curve25519.KeyAgreement.PrivateKey()
        let server = Curve25519.KeyAgreement.PrivateKey()
        let psk = Data(repeating: 7, count: 32)
        let phone = try #require(TunnelPeer(
            privateKey: device.rawRepresentation,
            peerPublicKey: server.publicKey.rawRepresentation,
            presharedKey: psk,
            keepalive: 25
        ))
        let melete = try #require(TunnelPeer(
            privateKey: server.rawRepresentation,
            peerPublicKey: device.publicKey.rawRepresentation,
            presharedKey: psk
        ))

        let packet = ipv4Packet(Array("hello melete".utf8))
        guard case let .toNetwork(initiation) = phone.send(packet) else {
            Issue.record("no handshake")
            return
        }
        guard case let .toNetwork(response) = melete.receive(initiation) else {
            Issue.record("no response")
            return
        }
        guard case let .toNetwork(keepalive) = phone.receive(response) else {
            Issue.record("no keepalive")
            return
        }
        #expect(melete.receive(keepalive) == .nothing)

        let held = try #require(phone.nextQueued())
        #expect(phone.nextQueued() == nil)
        guard case let .toDevice(opened) = melete.receive(held) else {
            Issue.record("not opened")
            return
        }
        #expect(opened.prefix(packet.count) == packet)
    }

    @Test
    func `refuses what isn't WireGuard, and keys of the wrong length`() throws {
        let key = Curve25519.KeyAgreement.PrivateKey()
        #expect(TunnelPeer(privateKey: Data(count: 31), peerPublicKey: key.publicKey.rawRepresentation) == nil)
        let peer = try #require(TunnelPeer(privateKey: key.rawRepresentation, peerPublicKey: key.publicKey.rawRepresentation))
        #expect(peer.receive(Data([1, 2, 3])) == .failed)
        #expect(peer.tick() == .nothing)
    }
}
