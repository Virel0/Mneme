//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit
import SwiftUI

/// The foot of a title's page: its extras, who is in it and who made it,
/// the films it belongs with, titles like it, and what its file is.
struct TitleMoreSections: View {

    @Environment(Router.self)
    private var router

    let model: TitleModel

    @State
    private var requesting: DiscoverItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 48) {
            if !model.extras.isEmpty {
                section("Extras") {
                    ForEach(model.extras) { extra in
                        ExtraCard(extra: extra) { router.play(model.target(for: extra)) }
                    }
                }
            }

            if let credits = model.credits, !credits.cast.isEmpty || !credits.crew.isEmpty {
                section("Cast & Crew") {
                    ForEach(people(credits), id: \.key) { person in
                        PersonCard(name: person.name, role: person.role, picture: person.picture) {
                            router.person(person.id)
                        }
                    }
                }
            }

            if let collection = model.collection, collection.items.count > 1 {
                section(collection.name) {
                    ForEach(collection.items) { item in
                        Button {
                            if item.state == .playable, let id = item.libraryId {
                                router.open(TitleSummary(placeholder: TitleRef(kind: item.kind, id: id), title: item.title))
                            } else {
                                requesting = item
                            }
                        } label: {
                            PosterCard(
                                poster: item.poster,
                                title: item.title,
                                caption: item.state == .playable ? item.year.map(String.init) : "Not in the Library"
                            )
                        }
                        .buttonStyle(PosterCardStyle())
                    }
                }
            }

            if !model.similar.isEmpty {
                section("More Like This") {
                    ForEach(model.similar, id: \.self) { item in
                        Button {
                            if let id = item.id {
                                router.open(TitleSummary(
                                    placeholder: TitleRef(kind: item.kind, id: id),
                                    title: item.title,
                                    poster: item.poster,
                                    year: item.year
                                ))
                            }
                        } label: {
                            PosterCard(poster: item.poster, title: item.title, caption: item.year.map(String.init))
                        }
                        .buttonStyle(PosterCardStyle())
                    }
                }
            }

            if let media = model.fileInfo?.media {
                FileDetails(media: media, size: model.fileInfo?.size)
            }
        }
        .fullScreenCover(item: $requesting) { item in
            RequestView(item: item, model: nil)
        }
    }

    private struct Entry {
        let key: String
        let id: Int
        let name: String
        let role: String?
        let picture: String?
    }

    /// The cast in billing order, then the crew who made it: directors,
    /// writers and creators first.
    private func people(_ credits: Credits) -> [Entry] {
        let cast = credits.cast.prefix(20).map {
            Entry(key: "cast-\($0.personId)", id: $0.personId, name: $0.name, role: $0.character, picture: $0.profile)
        }
        let order = ["Director", "Creator", "Writer", "Screenplay", "Novel", "Producer"]
        let crew = credits.crew
            .filter { order.contains($0.job) }
            .sorted { (order.firstIndex(of: $0.job) ?? 99) < (order.firstIndex(of: $1.job) ?? 99) }
            .map { Entry(key: "crew-\($0.personId)-\($0.job)", id: $0.personId, name: $0.name, role: $0.job, picture: $0.profile) }
        return Array(cast) + crew
    }

    private func section(_ title: String, @ViewBuilder cards: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: RowLayout.headingSpacing) {
            Text(title)
                .font(.title3.weight(.semibold))
                .padding(.horizontal, RowLayout.edge)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: RowLayout.spacing) {
                    cards()
                }
                .padding(.vertical, RowLayout.verticalPadding)
            }
            .safeAreaPadding(.horizontal, RowLayout.edge)
            .scrollClipDisabled()
            .focusSection()
        }
    }
}

/// A person: their picture in a circle, their name, and who they play or
/// what they did.
private struct PersonCard: View {

    let name: String
    let role: String?
    let picture: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ArtworkImage(path: picture) {
                    ZStack {
                        Color(white: 0.15)
                        Text(String(name.prefix(1)))
                            .font(.system(size: 50, weight: .bold))
                    }
                }
                .frame(width: 180, height: 180)
                .clipShape(Circle())

                VStack(spacing: 2) {
                    Text(name)
                        .font(.footnote)
                    Text(role ?? " ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .frame(width: 200)
            }
        }
        .buttonStyle(PosterCardStyle())
    }
}

/// A bonus video: what kind it is, its title and length.
private struct ExtraCard: View {

    let extra: Extra
    let action: () -> Void

    private var kind: String {
        extra.kind.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Color(white: 0.12)
                    Image(systemName: extra.kind == "trailer" ? "film" : "sparkles.tv")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 384, height: 216)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(extra.title)
                        .font(.footnote)
                    Text([kind, extra.durationSeconds.flatMap { Format.runtime(minutes: Int(($0 / 60).rounded(.up))) }]
                        .compactMap(\.self).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .frame(width: 384, alignment: .leading)
            }
        }
        .buttonStyle(PosterCardStyle())
    }
}

/// What the file is: container, picture, sound and size.
private struct FileDetails: View {

    let media: MediaInfo
    let size: Int?

    private var lines: [(String, String)] {
        var lines: [(String, String)] = []
        if let video = media.video.first {
            let resolution = video.height.map { "\($0)p" }
            lines.append(("Video", [video.codec.uppercased(), resolution, video.hdr].compactMap(\.self).joined(separator: " · ")))
        }
        for audio in media.audio.prefix(4) {
            let language = audio.language.flatMap { Locale.current.localizedString(forLanguageCode: $0) }
            let channels = audio.channelLayout ?? audio.channels.map { "\($0) ch" }
            lines.append(("Audio", [language, audio.codec.uppercased(), channels].compactMap(\.self).joined(separator: " · ")))
        }
        if let size {
            let bitrate = media.bitRate.map { "\($0 / 1_000_000) Mbps" }
            lines.append((
                "File",
                [ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file), bitrate].compactMap(\.self)
                    .joined(separator: " · ")
            ))
        }
        return lines
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About the File")
                .font(.title3.weight(.semibold))
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline, spacing: 20) {
                    Text(line.0)
                        .foregroundStyle(.secondary)
                        .frame(width: 120, alignment: .leading)
                    Text(line.1)
                }
                .font(.callout)
            }
        }
        .padding(.horizontal, RowLayout.edge)
        // Not something to select, but reachable, so the page scrolls to it.
        .focusable()
    }
}
