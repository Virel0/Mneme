//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit
import SwiftUI

/// Titles from TMDB that are not in the library, each marked as asked for
/// or not.
struct DiscoverRow: View {

    let title: String
    let items: [DiscoverItem]
    let select: (DiscoverItem) -> Void

    var body: some View {
        PosterStrip(title: title, items: items) { item in
            Button {
                select(item)
            } label: {
                PosterCard(
                    poster: item.poster,
                    title: item.title,
                    caption: item.state == .requested ? "Requested" : item.year.map(String.init)
                )
            }
            .buttonStyle(PosterCardStyle())
        }
    }
}

/// The viewer's requests and how each is getting on.
struct RequestRow: View {

    let title: String
    let requests: [MediaRequest]

    var body: some View {
        PosterStrip(title: title, items: requests) { request in
            Button {} label: {
                PosterCard(poster: request.poster, title: request.title, caption: Self.status(of: request))
            }
            .buttonStyle(PosterCardStyle())
        }
    }

    /// "Asked For", "Downloading · 45%", "Declined: not on any tracker".
    static func status(of request: MediaRequest) -> String {
        switch request.state {
        case "declined":
            return request.reason.map { "Declined: \($0)" } ?? "Declined"
        case "approved":
            guard let progress = request.progress else { return "Approved" }
            if progress.step == "downloading", let percent = progress.percent {
                return "\(stepName(progress.step)) · \(Int(percent))%"
            }
            return stepName(progress.step)
        default:
            return "Asked For"
        }
    }

    private static func stepName(_ step: String) -> String {
        switch step {
        case "wanted": "Waiting"
        case "searching": "Searching"
        case "downloading": "Downloading"
        case "transferring": "Copying"
        case "importing": "Importing"
        case "in_library": "In the Library"
        case "failed": "Failed"
        default: step.capitalized
        }
    }
}

/// A heading over a sideways row of poster cards.
private struct PosterStrip<Item: Identifiable, Card: View>: View {

    let title: String
    let items: [Item]
    let card: (Item) -> Card

    var body: some View {
        VStack(alignment: .leading, spacing: RowLayout.headingSpacing) {
            Text(title)
                .font(.title3.weight(.semibold))
                .padding(.horizontal, RowLayout.edge)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: RowLayout.spacing) {
                    ForEach(items) { item in
                        card(item)
                    }
                }
                .padding(.vertical, RowLayout.verticalPadding)
            }
            .safeAreaPadding(.horizontal, RowLayout.edge)
            .scrollClipDisabled()
            .focusSection()
        }
    }
}

/// A poster with its title and a line under it, for titles that are not
/// in the library: their artwork may be missing, so the name is always shown.
struct PosterCard: View {

    @Environment(\.isFocused)
    private var isFocused

    let poster: String?
    let title: String
    let caption: String?
    /// Off where the title is already written large beside the poster.
    var showsLabel = true

    static let width = RowLayout.baseWidth(columns: RowLayout.defaultColumns(for: .portrait))

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArtworkImage(path: poster) {
                ZStack {
                    Color(white: 0.12)
                    Text(title)
                        .font(.caption.bold())
                        .multilineTextAlignment(.center)
                        .padding(12)
                }
            }
            .frame(width: Self.width, height: Self.width * 3 / 2)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if showsLabel {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.footnote)
                    Text(caption ?? " ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .frame(width: Self.width, alignment: .leading)
            }
        }
    }
}

private struct PosterCardStyle: ButtonStyle {

    @Environment(\.isFocused)
    private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : (isFocused ? TitleTile.liftScale : 1), anchor: .bottom)
            .shadow(color: .black.opacity(isFocused ? 0.6 : 0), radius: 20, y: 10)
            .animation(RowLayout.motion, value: isFocused)
    }
}
