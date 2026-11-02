//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit
import SwiftUI

/// Signs another device in as this viewer: type the Quick Connect code it
/// shows, see which device it is, and approve it.
struct ApproveDeviceView: View {

    @Environment(Library.self)
    private var library

    @State
    private var code = ""
    @State
    private var state: ApproveState = .entering

    private enum ApproveState: Equatable {
        case entering
        case looking
        case found(device: String, address: String)
        case approved(String)
        case failed(String)
    }

    var body: some View {
        Form {
            Section {
                TextField("Code", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onSubmit(lookUp)
                    .onChange(of: code) { state = .entering }
            } footer: {
                Text("The six letters and digits the other device shows. It is signed in as you once you approve it.")
            }

            Section {
                switch state {
                case .entering:
                    Button("Look Up", action: lookUp)
                        .disabled(code.count < 6)
                case .looking:
                    ProgressView()
                case let .found(device, address):
                    LabeledContent("Device", value: device)
                    LabeledContent("From", value: address)
                    Button("Approve", action: approve)
                case let .approved(device):
                    Label("\(device) is signed in", systemImage: "checkmark.circle.fill")
                case let .failed(message):
                    Text(message).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Sign In Another Device")
    }

    private func lookUp() {
        let code = code
        state = .looking
        Task {
            do {
                let found = try await library.client.lookUpQuickConnect(code: code)
                state = .found(device: found.deviceName, address: found.address)
            } catch MeleteError.notFound {
                state = .failed("No device is showing that code. Codes last five minutes.")
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    private func approve() {
        let code = code
        state = .looking
        Task {
            do {
                let approved = try await library.client.approveQuickConnect(code: code)
                state = .approved(approved.deviceName)
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }
}
