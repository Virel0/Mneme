//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit
import SwiftUI

/// Playback choices for this Apple TV, sending a diagnostics report, and
/// which build this is.
struct SettingsView: View {

    @Environment(Library.self)
    private var library
    @Environment(SessionStore.self)
    private var sessions

    @AppStorage(PlaybackPreferences.autoPlayNextKey)
    private var autoPlayNext = true
    @AppStorage(PlaybackPreferences.autoSkipIntrosKey)
    private var autoSkipIntros = false
    @AppStorage(PlaybackPreferences.maxBitrateKey)
    private var maxBitrate = 0
    @AppStorage(PlaybackPreferences.resumeOffsetKey)
    private var resumeOffset = 5.0
    @AppStorage(PlaybackPreferences.subtitleSizeKey)
    private var subtitleSize = 46.0
    @AppStorage(PlaybackPreferences.previewClipsKey)
    private var previewClips = true
    @AppStorage(SessionStore.asksWhoIsWatchingKey)
    private var asksWhoIsWatching = true

    @State
    private var diagnostics: DiagnosticsState = .idle

    private enum DiagnosticsState: Equatable {
        case idle
        case sending
        case sent
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Play the next episode", isOn: $autoPlayNext)
                    Toggle("Skip intros, recaps and previews", isOn: $autoSkipIntros)
                    Picker("Quality", selection: $maxBitrate) {
                        ForEach(PlaybackPreferences.bitrateChoices, id: \.self) { bitrate in
                            Text(bitrate == 0 ? "Original" : "Up to \(bitrate / 1_000_000) Mbps").tag(bitrate)
                        }
                    }
                    Picker("Resume", selection: $resumeOffset) {
                        ForEach([0.0, 5, 10, 15, 30], id: \.self) { seconds in
                            Text(seconds == 0 ? "Where I Stopped" : "\(Int(seconds)) Seconds Earlier").tag(seconds)
                        }
                    }
                    Picker("Subtitle Size", selection: $subtitleSize) {
                        Text("Small").tag(38.0)
                        Text("Medium").tag(46.0)
                        Text("Large").tag(56.0)
                        Text("Extra Large").tag(68.0)
                    }
                    Toggle("Preview clips on Home", isOn: $previewClips)
                } header: {
                    Text("Playback")
                } footer: {
                    Text(
                        "Credits are never skipped: the next episode is offered there instead. Over the quality chosen, Melete converts the film to fit. Preview clips play only on your home network. These are kept on this Apple TV."
                    )
                }

                Section {
                    NavigationLink("Languages") { LanguagesView() }
                    NavigationLink("Sign In Another Device") { ApproveDeviceView() }
                    Toggle("Ask Who's Watching at Launch", isOn: $asksWhoIsWatching)
                } header: {
                    Text("Account")
                } footer: {
                    Text("Who's watching is asked only when more than one person is signed in on this Apple TV.")
                }

                Section {
                    Button(action: sendDiagnostics) {
                        HStack {
                            Text("Send Diagnostics")
                            Spacer()
                            diagnosticsStatus
                        }
                    }
                    .disabled(diagnostics == .sending)
                } header: {
                    Text("Help")
                } footer: {
                    Text(
                        "Sends what playback did lately, including every pause to buffer, to your Melete server, where an admin can read it under Diagnostics."
                    )
                }

                Section {
                    LabeledContent("Version", value: Self.version)
                    if let session = sessions.current {
                        LabeledContent("Server", value: session.server.host() ?? session.server.absoluteString)
                        LabeledContent("Signed in as", value: session.user.username)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
        }
        // A full-screen cover is see-through on tvOS without a ground of its own.
        .background(Color.mnemePageBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private var diagnosticsStatus: some View {
        switch diagnostics {
        case .idle: EmptyView()
        case .sending: ProgressView()
        case .sent: Label("Sent", systemImage: "checkmark").foregroundStyle(.secondary)
        case let .failed(message): Text(message).foregroundStyle(.red).lineLimit(1)
        }
    }

    private func sendDiagnostics() {
        diagnostics = .sending
        Task {
            do {
                try await PlaybackDiagnostics.shared.send(with: library.client, note: "Sent from Settings")
                diagnostics = .sent
            } catch {
                diagnostics = .failed(error.localizedDescription)
            }
        }
    }

    /// "1.0 (10)".
    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
