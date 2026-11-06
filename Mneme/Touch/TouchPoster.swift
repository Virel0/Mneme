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

/// A heading over a sideways row of posters, for titles not (yet) in the
/// library: requests and TMDB's.
struct TouchPosterRow<Item: Identifiable, Card: View>: View {

    let title: String
    let items: [Item]
    @ViewBuilder
    let card: (Item) -> Card

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.bold())
                .padding(.horizontal, TouchLayout.edge)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 10) {
                    ForEach(items) { item in
                        card(item)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, TouchLayout.edge, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }
}

/// A poster with its title and a line under it. The artwork of a title not
/// in the library may be missing, so the name is always written.
struct TouchPoster: View {

    @Environment(\.horizontalSizeClass)
    private var sizeClass

    let poster: String?
    let title: String
    let caption: String?

    /// The same widths as the library's posters in `TouchTileRow`.
    private var width: CGFloat {
        sizeClass == .regular ? 150 : 112
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TouchPosterImage(poster: poster, title: title)
                .frame(width: width, height: width * 3 / 2)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(caption ?? " ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// A poster as the server gave it, or the title on grey.
struct TouchPosterImage: View {

    let poster: String?
    let title: String

    var body: some View {
        ArtworkImage(path: poster) {
            ZStack {
                Color(white: 0.12)
                Text(title)
                    .font(.caption2.bold())
                    .multilineTextAlignment(.center)
                    .padding(4)
            }
        }
    }
}
#endif
