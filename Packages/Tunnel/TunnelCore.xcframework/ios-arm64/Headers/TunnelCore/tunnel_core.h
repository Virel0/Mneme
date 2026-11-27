//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//
// WireGuard for one peer, by gotatun. Not thread-safe: one tunnel is used
// from one queue at a time.

#ifndef TUNNEL_CORE_H
#define TUNNEL_CORE_H

#include <stddef.h>
#include <stdint.h>

typedef struct TunnelCore TunnelCore;

typedef enum {
    /// Nothing to do.
    TUNNEL_CORE_DONE = 0,
    /// `out` holds a datagram to send to the peer.
    TUNNEL_CORE_TO_NETWORK = 1,
    /// `out` holds an IP packet for the device.
    TUNNEL_CORE_TO_DEVICE = 2,
    /// The input was refused, or the session expired.
    TUNNEL_CORE_ERROR = 3,
    /// `out` is too small for what was made; it is dropped.
    TUNNEL_CORE_TOO_SMALL = 4,
} TunnelCoreOp;

typedef struct {
    TunnelCoreOp op;
    /// Bytes written to `out`.
    size_t len;
} TunnelCoreResult;

/// A tunnel to the peer. Keys are 32 bytes; `preshared_key` may be NULL;
/// `keepalive` is in seconds, 0 for none. NULL when a key is missing.
TunnelCore *tunnel_core_new(const uint8_t *private_key, const uint8_t *peer_public_key,
                            const uint8_t *preshared_key, uint16_t keepalive);

void tunnel_core_free(TunnelCore *tunnel);

/// An IP packet from the device. Without a session it is held, and the
/// handshake that starts one is the datagram to send.
TunnelCoreResult tunnel_core_send(TunnelCore *tunnel, const uint8_t *packet, size_t len,
                                  uint8_t *out, size_t capacity);

/// A datagram from the peer: a packet for the device, or a reply to send. A
/// keepalive is done. After each, call `tunnel_core_next_queued` until it is
/// done: packets held during a handshake go once it completes.
TunnelCoreResult tunnel_core_receive(TunnelCore *tunnel, const uint8_t *datagram, size_t len,
                                     uint8_t *out, size_t capacity);

/// The next packet held while the handshake ran, as a datagram to send.
TunnelCoreResult tunnel_core_next_queued(TunnelCore *tunnel, uint8_t *out, size_t capacity);

/// Called every quarter second or so: a handshake retry or a keepalive,
/// when one is due.
TunnelCoreResult tunnel_core_tick(TunnelCore *tunnel, uint8_t *out, size_t capacity);

#endif
