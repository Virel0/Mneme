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
                        LicenceView(library: library)
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
        }
        .navigationTitle("Acknowledgements")
    }
}

/// A licence's full text. Each paragraph takes focus, so the remote scrolls
/// through it.
private struct LicenceView: View {

    let library: Acknowledgements.Library

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
        .navigationTitle("\(library.name) · \(library.licence)")
        #if os(iOS)
        // A long title, too long for the large one.
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var paragraphs: [String] {
        library.text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
