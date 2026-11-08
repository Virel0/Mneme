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

/// The viewer's audio and subtitle languages, kept by Melete for every
/// device they use: what Play picks tracks from. Movies, shows and anime
/// follow them, or each has its own.
struct LanguagesView: View {

    @Environment(Library.self)
    private var library

    @State
    private var languages: Languages?
    @State
    private var kinds: [KindLanguages.Kind: KindLanguages] = [:]
    @State
    private var error: String?

    var body: some View {
        Form {
            if let languages {
                LanguageSections(languages: languages) { updated in
                    self.languages = updated
                    Task {
                        if let saved = try? await library.client.setLanguages(updated) {
                            self.languages = saved
                        }
                    }
                }

                // Left out by a server older than languages by kind.
                if !kinds.isEmpty {
                    Section {
                        ForEach(KindLanguages.Kind.allCases, id: \.self) { kind in
                            if kinds[kind] != nil {
                                NavigationLink {
                                    KindLanguagesView(kind: kind, kinds: $kinds)
                                } label: {
                                    LabeledContent(kind.title, value: kinds[kind]?.own == true ? "Its Own" : "Yours")
                                }
                            }
                        }
                    } header: {
                        Text("By Kind")
                    } footer: {
                        Text(
                            "Each kind plays with your languages unless it has its own: anime with Japanese audio and English subtitles, say."
                        )
                    }
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
                return
            }
            await withTaskGroup(of: KindLanguages?.self) { group in
                for kind in KindLanguages.Kind.allCases {
                    group.addTask { [client = library.client] in try? await client.languages(for: kind) }
                }
                for await answer in group {
                    if let answer {
                        kinds[answer.kind] = answer
                    }
                }
            }
        }
    }

    static func name(_ code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code) ?? code
    }
}

/// One kind's languages: the viewer's, or its own once switched on.
private struct KindLanguagesView: View {

    @Environment(Library.self)
    private var library

    let kind: KindLanguages.Kind
    @Binding
    var kinds: [KindLanguages.Kind: KindLanguages]

    private var current: KindLanguages? {
        kinds[kind]
    }

    var body: some View {
        Form {
            if let current {
                Section {
                    Toggle("Own Languages", isOn: Binding(get: { current.own }, set: { setOwn($0) }))
                } footer: {
                    Text(current.own ? "\(kind.title) play with these." : "\(kind.title) play with your languages, shown below.")
                }
                LanguageSections(languages: current.languages, save: save)
                    .disabled(!current.own)
            }
        }
        .navigationTitle(kind.title)
        .task {
            // The viewer's own may have changed since the list was read.
            if let fresh = try? await library.client.languages(for: kind) {
                kinds[kind] = fresh
            }
        }
    }

    /// On, it starts from the languages it followed; off, it follows them
    /// again.
    private func setOwn(_ own: Bool) {
        guard let current else { return }
        Task {
            let answer = own
                ? try? await library.client.setLanguages(current.languages, for: kind)
                : try? await library.client.followLanguages(for: kind)
            if let answer {
                kinds[kind] = answer
            }
        }
    }

    private func save(_ updated: Languages) {
        Task {
            if let saved = try? await library.client.setLanguages(updated, for: kind) {
                kinds[kind] = saved
            }
        }
    }
}

/// The audio and subtitle choices for one set of languages.
private struct LanguageSections: View {

    let languages: Languages
    let save: (Languages) -> Void

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
    }

    private func picker(_ title: String, selection: Binding<String>, current: String?) -> some View {
        Picker(title, selection: selection) {
            Text("None").tag("")
            ForEach(Self.choices, id: \.self) { code in
                Text(LanguagesView.name(code)).tag(code)
            }
            // A language set elsewhere that is not in the list stays shown.
            if let current, !Self.choices.contains(current) {
                Text(LanguagesView.name(current)).tag(current)
            }
        }
    }

    /// The first language of a list, replaced in place: the rest of the list,
    /// set on the web, is kept.
    private func first(_ keyPath: WritableKeyPath<Languages, [String]>) -> Binding<String> {
        Binding {
            languages[keyPath: keyPath].first ?? ""
        } set: { code in
            var updated = languages
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
            languages[keyPath: keyPath]
        } set: { value in
            var updated = languages
            updated[keyPath: keyPath] = value
            save(updated)
        }
    }
}

private extension KindLanguages.Kind {

    var title: String {
        switch self {
        case .movies: "Movies"
        case .shows: "Shows"
        case .anime: "Anime"
        }
    }
}
