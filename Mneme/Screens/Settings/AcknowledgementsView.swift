//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import AssRendering
import SwiftUI

/// The libraries built into Mneme from source, each with its licence, and
/// the credits those licences ask for.
struct AcknowledgementsView: View {

    var body: some View {
        Form {
            Section {
                ForEach(Acknowledgements.libraries) { library in
                    NavigationLink {
                        LicenceView(name: library.name, licence: library.licence, text: library.text)
                    } label: {
                        LabeledContent(library.name, value: library.licence)
                    }
                }
            } footer: {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Built into Mneme to draw styled subtitles as they were made.")
                    ForEach(Acknowledgements.libraries.compactMap(\.credit), id: \.self) { credit in
                        Text(credit)
                    }
                }
            }
            if !TunnelCrate.all.isEmpty {
                Section {
                    NavigationLink {
                        TunnelCratesView()
                    } label: {
                        LabeledContent("WireGuard", value: "\(TunnelCrate.all.count) Rust crates")
                    }
                } footer: {
                    Text("Built into Mneme's tunnel to Melete: Mullvad's gotatun and the crates it is built with.")
                }
            }
        }
        .navigationTitle("Acknowledgements")
    }
}

/// A Rust crate in Mneme's tunnel, with its licences, as `build.sh` in
/// Packages/Tunnel wrote them into the tunnel's bundle.
private struct TunnelCrate: Identifiable {
    let name: String
    let licence: String
    let text: String

    var id: String {
        name
    }

    /// Read from the tunnel's bundle inside the app, so the licences ship
    /// once. Each crate's part starts after a line of `=`, with its name,
    /// version and licence on the first line.
    static let all: [TunnelCrate] = {
        guard let url = Bundle.main.builtInPlugInsURL?
            .appending(path: "MnemeTunnel.appex/Tunnel_Tunnel.bundle/Licenses/rust-crates.txt"),
            let file = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }
        let rule = "\n" + String(repeating: "=", count: 78) + "\n"
        return file.components(separatedBy: rule).dropFirst().compactMap { part in
            let lines = part.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            guard let first = lines.first else { return nil }
            let heading = first.components(separatedBy: "  ")
            return TunnelCrate(
                name: heading[0],
                licence: heading.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces),
                text: lines.count > 1 ? String(lines[1]) : ""
            )
        }
    }()
}

private struct TunnelCratesView: View {

    var body: some View {
        Form {
            ForEach(TunnelCrate.all) { crate in
                NavigationLink {
                    LicenceView(name: crate.name, licence: crate.licence, text: crate.text)
                } label: {
                    LabeledContent(crate.name, value: crate.licence)
                }
            }
        }
        .navigationTitle("WireGuard")
    }
}

/// A licence's full text. Each paragraph takes focus, so the remote scrolls
/// through it.
private struct LicenceView: View {

    let name: String
    let licence: String
    let text: String

    #if os(tvOS)
    private static let margins = EdgeInsets(top: 40, leading: 80, bottom: 40, trailing: 80)
    #else
    private static let margins = EdgeInsets(top: 16, leading: TouchLayout.edge, bottom: 16, trailing: TouchLayout.edge)
    #endif

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        #if os(tvOS)
                        .focusable()
                        #endif
                }
            }
            .padding(Self.margins)
        }
        .navigationTitle("\(name) · \(licence)")
        #if os(iOS)
        // A long title, too long for the large one.
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var paragraphs: [String] {
        text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
