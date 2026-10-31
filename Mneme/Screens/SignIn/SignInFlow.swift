//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI

/// Server address, then Quick Connect with a password as the alternative.
struct SignInFlow: View {

    @Environment(SessionStore.self)
    private var sessions

    @State
    private var model = SignInModel()

    var body: some View {
        ZStack(alignment: .leading) {
            Color.black.ignoresSafeArea()
            ArtBackdrop(art: "ArtSignIn")

            // On the picture's dark left side, as on the app's other full-page
            // pictures.
            VStack(alignment: .leading, spacing: 48) {
                Image("MnemeWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 90)

                switch model.step {
                case .address:
                    ServerAddressView(model: model)
                case let .signIn(server, version):
                    SignInView(model: model, server: server, version: version)
                }

                if let error = model.error {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.leading, RowLayout.edge)
        }
        .onAppear {
            model.signedIn = { server, login in
                sessions.add(server: server, login: login)
            }
        }
        .onDisappear {
            model.stop()
        }
    }
}

private struct ServerAddressView: View {

    let model: SignInModel

    @State
    private var address = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("Connect to your Melete server")
                .font(.title2)

            TextField("Server address", text: $address)
                .textContentType(.URL)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit(connect)

            Button(action: connect) {
                if model.isWorking {
                    ProgressView()
                } else {
                    Text("Connect")
                }
            }
            .disabled(model.isWorking)
        }
    }

    private func connect() {
        Task { await model.connect(to: address) }
    }
}

private struct SignInView: View {

    let model: SignInModel
    let server: URL
    let version: String

    @State
    private var usesPassword = false
    @State
    private var username = ""
    @State
    private var password = ""
    @State
    private var code = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("\(server.host() ?? server.absoluteString) · Melete \(version)")
                .font(.callout)
                .foregroundStyle(.secondary)

            if usesPassword, model.codeChallenge != nil {
                Text("Enter the six-digit code from your authenticator app.")

                TextField("Code", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .onSubmit(finishSignIn)

                Button(action: finishSignIn) {
                    if model.isWorking {
                        ProgressView()
                    } else {
                        Text("Verify")
                    }
                }
                .disabled(model.isWorking || code.trimmingCharacters(in: .whitespaces).count < 6)

                Button("Back") {
                    code = ""
                    model.cancelCode()
                }
            } else if usesPassword {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .onSubmit(signIn)

                Button(action: signIn) {
                    if model.isWorking {
                        ProgressView()
                    } else {
                        Text("Sign In")
                    }
                }
                .disabled(model.isWorking || username.isEmpty)

                Button("Use Quick Connect instead") {
                    usesPassword = false
                }
            } else {
                Text("In Melete on a phone or computer, open Your account, then Quick Connect, and enter this code.")

                Group {
                    if let code = model.quickConnectCode {
                        Text(code)
                            .font(.system(size: 96, weight: .bold, design: .monospaced))
                            .kerning(12)
                    } else {
                        LoadingMark()
                    }
                }
                .frame(height: 140)

                Button("Sign in with a password") {
                    usesPassword = true
                }
            }

            Button("Change server") {
                model.changeServer()
            }
        }
    }

    private func signIn() {
        Task { await model.signIn(server: server, username: username, password: password) }
    }

    private func finishSignIn() {
        Task { await model.finishSignIn(server: server, code: code) }
    }
}
