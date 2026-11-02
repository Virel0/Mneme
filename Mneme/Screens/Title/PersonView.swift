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

/// Someone from a title's cast or crew, and their titles in the library.
struct PersonView: View {

    @Environment(Library.self)
    private var library
    @Environment(Router.self)
    private var router

    let id: Int

    @State
    private var person: Person?

    private static let columns: CGFloat = 7

    private var tileWidth: CGFloat {
        RowLayout.baseWidth(columns: Self.columns)
    }

    var body: some View {
        ScrollView(.vertical) {
            if let person {
                VStack(alignment: .leading, spacing: 48) {
                    HStack(spacing: 40) {
                        ArtworkImage(path: person.profile) { Color(white: 0.15) }
                            .frame(width: 220, height: 220)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 8) {
                            Text(person.name)
                                .font(.system(size: 56, weight: .heavy))
                            Text(person.titles.count == 1 ? "1 title in the library" : "\(person.titles.count) titles in the library")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, RowLayout.edge)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(tileWidth), spacing: RowLayout.spacing), count: Int(Self.columns)),
                        alignment: .leading,
                        spacing: TileSpotlightLayout.gridRowSpacing
                    ) {
                        ForEach(person.titles, id: \.self) { title in
                            Button {
                                router.open(TitleSummary(placeholder: TitleRef(kind: title.kind, id: title.id), title: title.title))
                            } label: {
                                PosterCard(poster: title.poster, title: title.title, caption: title.characters.first ?? title.jobs.first)
                            }
                            .buttonStyle(PosterCardStyle())
                        }
                    }
                    .padding(.horizontal, RowLayout.edge)
                    .focusSection()
                }
                .padding(.vertical, 80)
            } else {
                LoadingMark()
                    .frame(maxWidth: .infinity, minHeight: 600)
            }
        }
        .background(Color.mnemePageBackground.ignoresSafeArea())
        .task {
            person = try? await library.client.person(id)
        }
    }
}
