//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation
import TunnelCore

/// WireGuard to one peer, Melete's tunnel. The caller moves the packets: IP
/// packets from and to the device, datagrams from and to the peer. Used from
/// one queue at a time.
public final class TunnelPeer {

    /// What a step made.
    public enum Output: Equatable, Sendable {
        case nothing
        /// A datagram to send to the peer.
        case toNetwork(Data)
        /// An IP packet for the device.
        case toDevice(Data)
        /// Refused: not WireGuard, a stale session, or too large.
        case failed
    }

    private let core: OpaquePointer
    /// Room for any packet the tunnel's MTU lets through, and its overhead.
    private var buffer = [UInt8](repeating: 0, count: 65536)

    /// Keys are 32 bytes each, as WireGuard writes them (base64 decoded).
    /// `keepalive` is in seconds, 0 for none. Nil for a key of another length.
    public init?(privateKey: Data, peerPublicKey: Data, presharedKey: Data? = nil, keepalive: UInt16 = 0) {
        guard privateKey.count == 32, peerPublicKey.count == 32, presharedKey.map({ $0.count == 32 }) ?? true else { return nil }
        let made: OpaquePointer? = privateKey.withUnsafeBytes { privateKey in
            peerPublicKey.withUnsafeBytes { peer in
                if let presharedKey {
                    return presharedKey.withUnsafeBytes { psk in
                        tunnel_core_new(
                            privateKey.bindMemory(to: UInt8.self).baseAddress,
                            peer.bindMemory(to: UInt8.self).baseAddress,
                            psk.bindMemory(to: UInt8.self).baseAddress,
                            keepalive
                        )
                    }
                }
                return tunnel_core_new(
                    privateKey.bindMemory(to: UInt8.self).baseAddress,
                    peer.bindMemory(to: UInt8.self).baseAddress,
                    nil,
                    keepalive
                )
            }
        }
        guard let made else { return nil }
        core = made
    }

    deinit {
        tunnel_core_free(core)
    }

    /// An IP packet from the device. Without a session it is held, and the
    /// handshake that starts one is what goes out.
    public func send(_ packet: Data) -> Output {
        step(packet) { tunnel_core_send(core, $0, $1, $2, $3) }
    }

    /// A datagram from the peer. Afterwards, take `nextQueued()` until it
    /// is nil: packets held during a handshake go once it completes.
    public func receive(_ datagram: Data) -> Output {
        step(datagram) { tunnel_core_receive(core, $0, $1, $2, $3) }
    }

    /// The next packet held during a handshake, as a datagram to send.
    public func nextQueued() -> Data? {
        if case let .toNetwork(datagram) = step(Data(), { tunnel_core_next_queued(core, $2, $3) }) {
            return datagram
        }
        return nil
    }

    /// Every quarter second or so: a handshake retry or a keepalive to send,
    /// when one is due. `.failed` once the session has expired.
    public func tick() -> Output {
        step(Data()) { tunnel_core_tick(core, $2, $3) }
    }

    private func step(
        _ input: Data,
        _ call: (UnsafePointer<UInt8>?, Int, UnsafeMutablePointer<UInt8>?, Int) -> TunnelCoreResult
    ) -> Output {
        let capacity = buffer.count
        let result = input.withUnsafeBytes { input in
            buffer.withUnsafeMutableBufferPointer { out in
                call(input.bindMemory(to: UInt8.self).baseAddress, input.count, out.baseAddress, capacity)
            }
        }
        switch result.op {
        case TUNNEL_CORE_TO_NETWORK: return .toNetwork(Data(buffer[..<result.len]))
        case TUNNEL_CORE_TO_DEVICE: return .toDevice(Data(buffer[..<result.len]))
        case TUNNEL_CORE_DONE: return .nothing
        default: return .failed
        }
    }
}
