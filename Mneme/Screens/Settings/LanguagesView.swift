//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit
import SwiftUI

/// The viewer's audio and subtitle languages, kept by Melete for every
/// device they use: what Play picks tracks from.
struct LanguagesView: View {

    @Environment(Library.self)
    private var library

    @State
    private var languages: Languages?
    @State
    private var error: String?

    /// ISO 639-2 codes, as files tag their tracks, most common first.
    private static let choices = [
        "eng", "spa", "fra", "deu", "ita", "por", "jpn", "kor", "zho", "rus", "ara", "hin",
        "nld", "swe", "nor", "dan", "fin", "pol", "tur", "ces", "hun", "ell", "heb", "tha", "vie", "ind",
    ]

    private static let modes: [(String, String)] = [
        ("off", "Off"),
        ("forced", "Forced Only"),
        ("foreign", "When the Audio Isn't Mine"),
        ("always", "Always"),
    ]

    var body: some View {
        Form {
            if let languages {
                Section {
                    picker("Audio", selection: first(\.audioLanguages), current: languages.audioLanguages.first)
                } footer: {
                    Text("The first of these a file has is played.")
                }

                Section {
                    picker("Subtitles", selection: first(\.subtitleLanguages), current: languages.subtitleLanguages.first)
                    Picker("Show Subtitles", selection: binding(\.subtitleMode)) {
                        ForEach(Self.modes, id: \.0) { mode in
                            Text(mode.1).tag(mode.0)
                        }
                    }
                } footer: {
                    Text("Kept by Melete, so every device you sign in on plays with the same choices.")
                }
            } else if let error {
                Text(error).foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Languages")
        .task {
            do {
                languages = try await library.client.languages()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func picker(_ title: String, selection: Binding<String>, current: String?) -> some View {
        Picker(title, selection: selection) {
            Text("None").tag("")
            ForEach(Self.choices, id: \.self) { code in
                Text(Self.name(code)).tag(code)
            }
            // A language set elsewhere that is not in the list stays shown.
            if let current, !Self.choices.contains(current) {
                Text(Self.name(current)).tag(current)
            }
        }
    }

    /// The first language of a list, replaced in place: the rest of the list,
    /// set on the web, is kept.
    private func first(_ keyPath: WritableKeyPath<Languages, [String]>) -> Binding<String> {
        Binding {
            languages?[keyPath: keyPath].first ?? ""
        } set: { code in
            guard var updated = languages else { return }
            var list = updated[keyPath: keyPath].filter { $0 != code }
            if !code.isEmpty {
                list.insert(code, at: 0)
            }
            updated[keyPath: keyPath] = list
            save(updated)
        }
    }

    private func binding(_ keyPath: WritableKeyPath<Languages, String>) -> Binding<String> {
        Binding {
            languages?[keyPath: keyPath] ?? ""
        } set: { value in
            guard var updated = languages else { return }
            updated[keyPath: keyPath] = value
            save(updated)
        }
    }

    private func save(_ updated: Languages) {
        languages = updated
        Task {
            if let saved = try? await library.client.setLanguages(updated) {
                languages = saved
            }
        }
    }

    static func name(_ code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code) ?? code
    }
}
