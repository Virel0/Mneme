//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

#if os(iOS)
import MeleteKit
import SwiftUI

/// Someone from a title's cast or crew: their picture and name, then their
/// titles in the library as posters, each with the part they played or the
/// job they did.
///
/// Melete lists only the titles in the library that the viewer may see, so
/// every one of them opens, as on the Apple TV (`PersonView`).
struct TouchPersonView: View {

    @Environment(Library.self)
    private var library
    @Environment(Router.self)
    private var router
    @Environment(\.horizontalSizeClass)
    private var sizeClass

    let id: Int

    @State
    private var person: Person?
    @State
    private var failure: MeleteError?

    private var pictureSize: CGFloat {
        sizeClass == .regular ? 160 : 112
    }

    var body: some View {
        content
            .background(Color.mnemePageBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await load()
            }
    }

    @ViewBuilder
    private var content: some View {
        if let person {
            page(person)
        } else if let failure {
            FailureView(title: "Couldn't load this person", error: failure) {
                Task { await load() }
            }
        } else {
            LoadingMark()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func page(_ person: Person) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 16) {
                    ArtworkImage(ArtworkSlot(path: person.profile, kind: .profile, width: pictureSize)) {
                        Color(white: 0.15)
                    }
                    .frame(width: pictureSize, height: pictureSize)
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(person.name)
                            .font(.title.bold())
                        Text(person.titles.count == 1 ? "1 title in the library" : "\(person.titles.count) titles in the library")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                }
                .padding(.horizontal, TouchLayout.edge)

                TouchPosterGrid { width in
                    ForEach(person.titles, id: \.self) { title in
                        tile(title, width: width)
                    }
                }
            }
            .padding(.vertical, 16)
        }
    }

    private func tile(_ title: Person.Title, width: CGFloat) -> some View {
        let summary = TitleSummary(
            placeholder: TitleRef(kind: title.kind, id: title.id),
            title: title.title,
            poster: title.poster,
            year: title.year
        )
        let part = title.characters.first ?? title.jobs.first

        return Button {
            router.open(summary)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                TouchTile(summary: summary, shape: .portrait, width: width)
                // A line kept even when empty, so the posters stay level.
                Text(part ?? " ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: width, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel([title.title, part].compactMap(\.self).joined(separator: ", "))
    }

    private func load() async {
        failure = nil
        do {
            person = try await library.client.person(id)
        } catch {
            failure = error
        }
    }
}
#endif
