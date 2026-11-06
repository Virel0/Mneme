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

/// The foot of a title's page on a touch screen, as `TitleMoreSections` is
/// on the Apple TV: its extras, who is in it and who made it, the films it
/// belongs with, titles like it, and what its file is.
struct TouchTitleMore: View {

    @Environment(\.horizontalSizeClass)
    private var sizeClass
    @Environment(Router.self)
    private var router

    let model: TitleModel

    /// The widths of `TouchTileRow`'s posters, so these rows match Home's.
    private var posterWidth: CGFloat {
        sizeClass == .regular ? 150 : 112
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if !model.extras.isEmpty {
                TouchShelf(title: "Extras") {
                    ForEach(model.extras) { extra in
                        Button {
                            router.play(model.target(for: extra))
                        } label: {
                            TouchExtraCard(extra: extra, width: sizeClass == .regular ? 260 : 200)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let credits = model.credits, !credits.cast.isEmpty || !credits.crew.isEmpty {
                TouchShelf(title: "Cast & Crew") {
                    ForEach(TitleMoreSections.people(credits), id: \.key) { person in
                        Button {
                            router.person(person.id)
                        } label: {
                            TouchPersonCard(
                                name: person.name,
                                role: person.role,
                                picture: person.picture,
                                size: sizeClass == .regular ? 100 : 80
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let collection = model.collection, collection.items.count > 1 {
                TouchShelf(title: collection.name) {
                    ForEach(collection.items) { item in
                        collectionItem(item)
                    }
                }
            }

            if !model.similar.isEmpty {
                TouchTileRow(
                    title: "More Like This",
                    items: model.similar.compactMap { item in
                        item.id.map {
                            TitleSummary(
                                placeholder: TitleRef(kind: item.kind, id: $0),
                                title: item.title,
                                poster: item.poster,
                                year: item.year
                            )
                        }
                    },
                    shape: .portrait,
                    open: { router.open($0) }
                )
            }

            if let media = model.fileInfo?.media {
                TouchFileDetails(
                    lines: FileDetails(media: media, size: model.fileInfo?.size, highFrameRate: model.movie?.highFrameRate).lines
                )
            }
        }
    }

    /// A film of the collection in the library opens; one that is not is
    /// shown so the set reads whole, but has nothing to open. Asking for it
    /// is Search's to offer.
    @ViewBuilder
    private func collectionItem(_ item: DiscoverItem) -> some View {
        let card = TouchPosterCard(
            poster: item.poster,
            title: item.title,
            caption: item.state == .playable ? item.year.map(String.init) : "Not in the Library",
            width: posterWidth
        )
        if item.state == .playable, let id = item.libraryId {
            Button {
                router.open(TitleSummary(placeholder: TitleRef(kind: item.kind, id: id), title: item.title))
            } label: {
                card
            }
            .buttonStyle(.plain)
        } else {
            card
                .opacity(0.6)
        }
    }
}

/// A titled row to swipe along, laid out as `TouchTileRow` is, for cards
/// that are not title tiles.
private struct TouchShelf<Cards: View>: View {

    let title: String
    @ViewBuilder
    let cards: () -> Cards

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, TouchLayout.edge)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 12) {
                    cards()
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, TouchLayout.edge, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }
}

/// A bonus video: what kind it is, its title and length.
private struct TouchExtraCard: View {

    let extra: Extra
    let width: CGFloat

    private var caption: String {
        let kind = extra.kind.replacingOccurrences(of: "_", with: " ").capitalized
        let length = extra.durationSeconds.flatMap { Format.runtime(minutes: Int(($0 / 60).rounded(.up))) }
        return [kind, length].compactMap(\.self).joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Color(white: 0.12)
                Image(systemName: extra.kind == "trailer" ? "film" : "sparkles.tv")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
            .frame(width: width, height: width * 9 / 16)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(extra.title)
                    .font(.subheadline.weight(.semibold))
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        }
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// A person: their picture in a circle, their name, and who they play or
/// what they did.
private struct TouchPersonCard: View {

    let name: String
    let role: String?
    let picture: String?
    let size: CGFloat

    var body: some View {
        VStack(spacing: 8) {
            ArtworkImage(ArtworkSlot(path: picture, kind: .profile, width: size)) {
                ZStack {
                    Color(white: 0.15)
                    Text(String(name.prefix(1)))
                        .font(.title2.bold())
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())

            VStack(spacing: 1) {
                Text(name)
                    .font(.caption.weight(.semibold))
                // A space keeps the names level when some have no role.
                Text(role ?? " ")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .multilineTextAlignment(.center)
        }
        .frame(width: size + 20)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// A poster with its title and a caption under it. Asked for as the server
/// gives the path, as on the Apple TV: a film not in the library has only
/// that size.
private struct TouchPosterCard: View {

    let poster: String?
    let title: String
    let caption: String?
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArtworkImage(path: poster) {
                ZStack {
                    Color(white: 0.12)
                    Text(title)
                        .font(.caption.bold())
                        .multilineTextAlignment(.center)
                        .padding(8)
                }
            }
            .frame(width: width, height: width * 3 / 2)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(caption ?? " ")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        }
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// What the file is, a name and a value to a line: the lines the Apple TV's
/// `FileDetails` makes, in a grid that keeps the values level at any text
/// size.
private struct TouchFileDetails: View {

    let lines: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About the File")
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    GridRow {
                        Text(line.0)
                            .foregroundStyle(.secondary)
                        Text(line.1)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .font(.footnote)
        }
        .padding(.horizontal, TouchLayout.edge)
    }
}
#endif
