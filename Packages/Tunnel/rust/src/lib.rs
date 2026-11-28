//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//
//! WireGuard for one peer, by gotatun, behind the C interface in
//! `include/tunnel_core.h`. The caller moves the packets: IP packets from and
//! to the device, datagrams from and to the peer. Every entry point catches a
//! panic and answers an error instead, so a fault here can't take the packet
//! tunnel down.

use std::panic::{AssertUnwindSafe, catch_unwind};
use std::sync::Arc;

use gotatun::noise::index_table::IndexTable;
use gotatun::noise::rate_limiter::RateLimiter;
use gotatun::noise::{Tunn, TunnResult};
use gotatun::packet::{Packet, WgKind};
use gotatun::tun::MtuWatcher;
use gotatun::x25519::{PublicKey, StaticSecret};

/// The tunnel's MTU: WireGuard's usual 1420, which fits its overhead inside
/// a 1500-byte link.
const MTU: u16 = 1420;

/// Handshakes answered a second before cookies are asked for: a single peer
/// never comes near it.
const HANDSHAKE_LIMIT: u64 = 100;

pub struct TunnelCore {
    tunn: Tunn,
    mtu: MtuWatcher,
}

#[repr(C)]
#[derive(Debug, PartialEq, Eq)]
pub enum TunnelCoreOp {
    Done = 0,
    ToNetwork = 1,
    ToDevice = 2,
    Error = 3,
    TooSmall = 4,
}

#[repr(C)]
#[derive(Debug, PartialEq, Eq)]
pub struct TunnelCoreResult {
    pub op: TunnelCoreOp,
    pub len: usize,
}

impl TunnelCoreResult {
    const DONE: Self = Self { op: TunnelCoreOp::Done, len: 0 };
    const ERROR: Self = Self { op: TunnelCoreOp::Error, len: 0 };
}

/// 32 bytes at `pointer`, or nothing for NULL.
unsafe fn key(pointer: *const u8) -> Option<[u8; 32]> {
    if pointer.is_null() {
        return None;
    }
    let mut key = [0u8; 32];
    // SAFETY: the header promises 32 readable bytes for a non-NULL key.
    unsafe { std::ptr::copy_nonoverlapping(pointer, key.as_mut_ptr(), 32) };
    Some(key)
}

/// `len` bytes at `pointer`; empty for NULL.
unsafe fn bytes<'a>(pointer: *const u8, len: usize) -> &'a [u8] {
    if pointer.is_null() || len == 0 {
        return &[];
    }
    // SAFETY: the caller passes `len` readable bytes.
    unsafe { std::slice::from_raw_parts(pointer, len) }
}

/// Copies what was made into `out`, saying what it is.
unsafe fn write(out: *mut u8, capacity: usize, made: &[u8], op: TunnelCoreOp) -> TunnelCoreResult {
    if out.is_null() || made.len() > capacity {
        return TunnelCoreResult { op: TunnelCoreOp::TooSmall, len: 0 };
    }
    // SAFETY: `out` has `capacity` writable bytes, and `made` fits.
    unsafe { std::ptr::copy_nonoverlapping(made.as_ptr(), out, made.len()) };
    TunnelCoreResult { op, len: made.len() }
}

unsafe fn to_network(out: *mut u8, capacity: usize, kind: WgKind) -> TunnelCoreResult {
    let packet: Packet = kind.into();
    unsafe { write(out, capacity, &packet, TunnelCoreOp::ToNetwork) }
}

/// Runs `body`, answering an error for a null tunnel or a panic.
fn guarded(tunnel: *mut TunnelCore, body: impl FnOnce(&mut TunnelCore) -> TunnelCoreResult) -> TunnelCoreResult {
    if tunnel.is_null() {
        return TunnelCoreResult::ERROR;
    }
    // SAFETY: a non-NULL tunnel came from `tunnel_core_new` and is used from
    // one queue at a time, as the header says.
    let tunnel = unsafe { &mut *tunnel };
    catch_unwind(AssertUnwindSafe(|| body(tunnel))).unwrap_or(TunnelCoreResult::ERROR)
}

/// # Safety
/// Keys are NULL or 32 readable bytes.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn tunnel_core_new(
    private_key: *const u8,
    peer_public_key: *const u8,
    preshared_key: *const u8,
    keepalive: u16,
) -> *mut TunnelCore {
    let made = catch_unwind(|| {
        let private = StaticSecret::from(unsafe { key(private_key) }?);
        let peer = PublicKey::from(unsafe { key(peer_public_key) }?);
        let public = PublicKey::from(&private);
        let tunn = Tunn::new(
            private,
            peer,
            unsafe { key(preshared_key) },
            (keepalive > 0).then_some(keepalive),
            IndexTable::from_os_rng(),
            Arc::new(RateLimiter::new(&public, HANDSHAKE_LIMIT)),
        );
        Some(Box::new(TunnelCore { tunn, mtu: MtuWatcher::new(MTU) }))
    });
    made.ok().flatten().map_or(std::ptr::null_mut(), Box::into_raw)
}

/// # Safety
/// `tunnel` is NULL or came from `tunnel_core_new`, and isn't used after.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn tunnel_core_free(tunnel: *mut TunnelCore) {
    if !tunnel.is_null() {
        // SAFETY: made by `Box::into_raw` in `tunnel_core_new`.
        drop(unsafe { Box::from_raw(tunnel) });
    }
}

/// # Safety
/// `packet` has `len` readable bytes and `out` `capacity` writable ones.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn tunnel_core_send(
    tunnel: *mut TunnelCore,
    packet: *const u8,
    len: usize,
    out: *mut u8,
    capacity: usize,
) -> TunnelCoreResult {
    guarded(tunnel, |tunnel| {
        let packet = Packet::copy_from(unsafe { bytes(packet, len) });
        match tunnel.tunn.handle_outgoing_packet(packet, Some(&mut tunnel.mtu)) {
            Some(kind) => unsafe { to_network(out, capacity, kind) },
            None => TunnelCoreResult::DONE,
        }
    })
}

/// # Safety
/// `datagram` has `len` readable bytes and `out` `capacity` writable ones.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn tunnel_core_receive(
    tunnel: *mut TunnelCore,
    datagram: *const u8,
    len: usize,
    out: *mut u8,
    capacity: usize,
) -> TunnelCoreResult {
    guarded(tunnel, |tunnel| {
        let Ok(kind) = Packet::copy_from(unsafe { bytes(datagram, len) }).try_into_wg() else {
            return TunnelCoreResult::ERROR;
        };
        match tunnel.tunn.handle_incoming_packet(kind) {
            TunnResult::Done => TunnelCoreResult::DONE,
            TunnResult::Err(_) => TunnelCoreResult::ERROR,
            TunnResult::WriteToNetwork(kind) => unsafe { to_network(out, capacity, kind) },
            // A keepalive opens to nothing: there is no packet for the device.
            TunnResult::WriteToTunnel(packet) if packet.is_empty() => TunnelCoreResult::DONE,
            TunnResult::WriteToTunnel(packet) => unsafe { write(out, capacity, &packet, TunnelCoreOp::ToDevice) },
        }
    })
}

/// # Safety
/// `out` has `capacity` writable bytes.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn tunnel_core_next_queued(tunnel: *mut TunnelCore, out: *mut u8, capacity: usize) -> TunnelCoreResult {
    guarded(tunnel, |tunnel| match tunnel.tunn.get_queued_packets(&mut tunnel.mtu).next() {
        Some(kind) => unsafe { to_network(out, capacity, kind) },
        None => TunnelCoreResult::DONE,
    })
}

/// # Safety
/// `out` has `capacity` writable bytes.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn tunnel_core_tick(tunnel: *mut TunnelCore, out: *mut u8, capacity: usize) -> TunnelCoreResult {
    guarded(tunnel, |tunnel| match tunnel.tunn.update_timers() {
        Ok(Some(kind)) => unsafe { to_network(out, capacity, kind) },
        Ok(None) => TunnelCoreResult::DONE,
        Err(_) => TunnelCoreResult::ERROR,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    const BUFFER: usize = 2048;

    /// A fixed key pair: any 32 bytes make a private key.
    fn keys(seed: u8) -> ([u8; 32], [u8; 32]) {
        let private = StaticSecret::from([seed; 32]);
        let public = PublicKey::from(&private);
        (private.to_bytes(), public.to_bytes())
    }

    /// A UDP packet from 10.73.0.2 to 10.73.0.1, with a valid header checksum.
    fn ipv4_packet(payload: &[u8]) -> Vec<u8> {
        let total = 20 + 8 + payload.len();
        let mut packet = vec![0x45, 0, (total >> 8) as u8, total as u8, 0, 0, 0x40, 0, 64, 17, 0, 0, 10, 73, 0, 2, 10, 73, 0, 1];
        let sum = packet.chunks(2).map(|w| u32::from(w[0]) << 8 | u32::from(w[1])).sum::<u32>();
        let folded = !((sum & 0xffff) + (sum >> 16)) as u16;
        packet[10] = (folded >> 8) as u8;
        packet[11] = folded as u8;
        let udp_len = 8 + payload.len();
        packet.extend_from_slice(&[0x30, 0x39, 0x00, 0x50, (udp_len >> 8) as u8, udp_len as u8, 0, 0]);
        packet.extend_from_slice(payload);
        packet
    }

    #[test]
    fn a_packet_crosses_after_the_handshake() {
        let (device_private, device_public) = keys(1);
        let (server_private, server_public) = keys(2);
        let psk = [7u8; 32];
        unsafe {
            let device = tunnel_core_new(device_private.as_ptr(), server_public.as_ptr(), psk.as_ptr(), 25);
            let server = tunnel_core_new(server_private.as_ptr(), device_public.as_ptr(), psk.as_ptr(), 0);
            assert!(!device.is_null() && !server.is_null());
            let mut out = vec![0u8; BUFFER];
            let mut back = vec![0u8; BUFFER];

            // No session yet: the packet is held and a handshake goes out.
            let packet = ipv4_packet(b"hello melete");
            let init = tunnel_core_send(device, packet.as_ptr(), packet.len(), out.as_mut_ptr(), BUFFER);
            assert_eq!(init.op, TunnelCoreOp::ToNetwork);

            // The server answers it.
            let response = tunnel_core_receive(server, out.as_ptr(), init.len, back.as_mut_ptr(), BUFFER);
            assert_eq!(response.op, TunnelCoreOp::ToNetwork);

            // The device takes the answer and confirms the session with a
            // keepalive, which the server takes quietly.
            let confirm = tunnel_core_receive(device, back.as_ptr(), response.len, out.as_mut_ptr(), BUFFER);
            assert_eq!(confirm.op, TunnelCoreOp::ToNetwork);
            let quiet = tunnel_core_receive(server, out.as_ptr(), confirm.len, back.as_mut_ptr(), BUFFER);
            assert_eq!(quiet.op, TunnelCoreOp::Done);

            // Its held packet then goes.
            let queued = tunnel_core_next_queued(device, out.as_mut_ptr(), BUFFER);
            assert_eq!(queued.op, TunnelCoreOp::ToNetwork);
            assert_eq!(tunnel_core_next_queued(device, out.as_mut_ptr(), BUFFER), TunnelCoreResult::DONE);

            // The server opens it: the same packet, give or take padding.
            let opened = tunnel_core_receive(server, out.as_ptr(), queued.len, back.as_mut_ptr(), BUFFER);
            assert_eq!(opened.op, TunnelCoreOp::ToDevice);
            assert_eq!(&back[..packet.len()], &packet[..]);

            // A datagram that isn't WireGuard is refused, not a crash.
            let junk = [1u8, 2, 3];
            assert_eq!(tunnel_core_receive(server, junk.as_ptr(), junk.len(), back.as_mut_ptr(), BUFFER), TunnelCoreResult::ERROR);
            // Too small a buffer says so.
            let small = tunnel_core_send(device, packet.as_ptr(), packet.len(), out.as_mut_ptr(), 8);
            assert_eq!(small.op, TunnelCoreOp::TooSmall);

            tunnel_core_free(device);
            tunnel_core_free(server);
        }
    }

    #[test]
    fn a_missing_key_makes_no_tunnel() {
        let (private, _) = keys(3);
        assert!(unsafe { tunnel_core_new(private.as_ptr(), std::ptr::null(), std::ptr::null(), 0) }.is_null());
    }

    #[test]
    fn a_null_tunnel_is_an_error() {
        let mut out = [0u8; 64];
        assert_eq!(unsafe { tunnel_core_tick(std::ptr::null_mut(), out.as_mut_ptr(), 64) }, TunnelCoreResult::ERROR);
    }
}
