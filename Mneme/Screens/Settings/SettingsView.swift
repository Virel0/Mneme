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

/// Playback choices for this device, sending a diagnostics report, and
/// which build this is.
struct SettingsView: View {

    @Environment(Library.self)
    private var library
    @Environment(SessionStore.self)
    private var sessions
    #if os(iOS)
    @Environment(\.dismiss)
    private var dismiss
    #endif

    @AppStorage(PlaybackPreferences.maxBitrateKey)
    private var maxBitrate = 0
    @AppStorage(PlaybackPreferences.resumeOffsetKey)
    private var resumeOffset = 5.0
    @AppStorage(PlaybackPreferences.subtitleSizeKey)
    private var subtitleSize = 46.0
    @AppStorage(PlaybackPreferences.meleteConvertsAudioKey)
    private var meleteConvertsAudio = false
    @AppStorage(PlaybackPreferences.previewSoundKey)
    private var previewSound = true
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
                    // Kept by Melete for every device, where the server does.
                    Toggle("Play the next episode", isOn: Binding(
                        get: { library.autoplayNext },
                        set: { on in Task { await library.setAutoplayNext(on) } }
                    ))
                    Toggle("Skip intros, recaps and previews", isOn: Binding(
                        get: { library.autoSkip },
                        set: { on in Task { await library.setAutoSkip(on) } }
                    ))
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
                    Toggle(Self.previewClipsTitle, isOn: $previewClips)
                    Toggle("Sound in preview clips", isOn: $previewSound)
                        .disabled(!previewClips)
                    Toggle("Melete converts surround sound", isOn: $meleteConvertsAudio)
                } header: {
                    Text("Playback")
                } footer: {
                    Text(
                        "Credits are never skipped: the next episode is offered there instead. Over the quality chosen, Melete converts the film to fit. Preview clips play only on your home network. With Melete converting surround sound, a TrueHD or DTS soundtrack is converted by the server, lossless, instead of by this \(Self.device); TrueHD's Atmos is lost. Playing the next episode and skipping are kept by Melete for all your devices; the rest are kept on this \(Self.device)."
                    )
                }

                Section {
                    NavigationLink("Languages") { LanguagesView() }
                    NavigationLink("Sign In Another Device") { ApproveDeviceView() }
                    Toggle("Ask Who's Watching at Launch", isOn: $asksWhoIsWatching)
                } header: {
                    Text("Account")
                } footer: {
                    Text("Who's watching is asked only when more than one person is signed in on this \(Self.device).")
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
                    NavigationLink("Acknowledgements") { AcknowledgementsView() }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            // A sheet on a touch screen, closed with a button rather
            // than the remote's Back.
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
            #endif
        }
        #if os(tvOS)
        // A full-screen cover is see-through on tvOS without a ground of its own.
        .background(PageBackground())
        #endif
    }

    /// The device the footers speak of.
    private static var device: String {
        #if os(tvOS)
        "Apple TV"
        #else
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #endif
    }

    /// Home on a touch screen plays no clips; its title pages do.
    private static var previewClipsTitle: String {
        #if os(tvOS)
        "Preview clips on Home"
        #else
        "Preview clips on title pages"
        #endif
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
