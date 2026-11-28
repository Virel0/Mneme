//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit
@preconcurrency import NetworkExtension
import SwiftUI

/// Mneme's own VPN in Settings: set up, on or off, its status, and
/// removing it. Shown only where Melete has its tunnel on, or this device
/// already has one.
struct AwayFromHomeSection: View {

    @Environment(Library.self)
    private var library
    @Environment(SessionStore.self)
    private var sessions
    @Environment(AwayFromHome.self)
    private var away

    @State
    private var devices: TunnelDevices?
    @State
    private var isWorking = false
    @State
    private var problem: String?
    @State
    private var confirmsRemoval = false

    private var device: String {
        SettingsView.device
    }

    private var home: URL? {
        sessions.current?.server
    }

    private var isSetUp: Bool {
        away.place != nil && away.place?.home == home
    }

    var body: some View {
        Group {
            if isSetUp || devices?.enabled == true {
                Section {
                    if isSetUp {
                        setUp
                    } else {
                        Button("Set Up Away From Home", action: setUpTunnel)
                            .disabled(isWorking || isFull)
                    }
                } header: {
                    Text("Away From Home")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(footer)
                        if let note = problem ?? away.removalNote {
                            Text(note).foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .task {
            await away.load()
            devices = try? await library.client.tunnelDevices()
        }
        .confirmationDialog("Remove Mneme's tunnel from this \(device)?", isPresented: $confirmsRemoval, titleVisibility: .visible) {
            Button("Remove", role: .destructive, action: removeTunnel)
        } message: {
            Text("Melete stops letting this \(device) in through its tunnel. You can set it up again later.")
        }
    }

    @ViewBuilder
    private var setUp: some View {
        Toggle("Connect away from home", isOn: Binding(
            get: { away.place?.connectsAway ?? false },
            set: { on in run { try await away.setConnectsAway(on) } }
        ))
        .disabled(isWorking)
        LabeledContent("Status", value: status)
        Button("Remove From This \(device)", role: .destructive) {
            confirmsRemoval = true
        }
        .disabled(isWorking)
    }

    /// Melete takes only so many devices from one person.
    private var isFull: Bool {
        guard let devices else { return false }
        return devices.devices.count >= devices.limit
    }

    private var footer: String {
        if !isSetUp, isFull, let devices {
            return "You have \(devices.limit) devices on Melete's tunnel, the most it takes. Remove one in Melete to add this \(device)."
        }
        return "Reaches your Melete server through its own WireGuard tunnel when this \(device) isn't at home. Only Mneme's way to Melete goes through it; everything else this \(device) does stays as it is. Setting up asks to add a VPN configuration."
    }

    private var status: String {
        switch away.status {
        case .connected: "Connected"
        case .connecting, .reasserting: "Connecting…"
        case .disconnecting: "Disconnecting…"
        case .disconnected: "Not connected"
        case .invalid: "Not set up"
        @unknown default: "Unknown"
        }
    }

    private func setUpTunnel() {
        guard let home else { return }
        run { try await away.setUp(with: library.client, home: home) }
    }

    private func removeTunnel() {
        isWorking = true
        problem = nil
        Task {
            await away.remove(with: library.client)
            devices = try? await library.client.tunnelDevices()
            isWorking = false
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        isWorking = true
        problem = nil
        Task {
            do {
                try await work()
            } catch {
                problem = error.localizedDescription
            }
            isWorking = false
        }
    }
}
