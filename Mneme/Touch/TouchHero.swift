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

/// The hero's picks as cards to swipe through, the next one showing at the
/// edge so it is plain there are more. Two to a screen on a wide iPad.
struct TouchHero: View {

    @Environment(\.horizontalSizeClass)
    private var sizeClass

    let picks: [TitleSummary]

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(picks) { pick in
                    TouchHeroCard(pick: pick)
                        .containerRelativeFrame(.horizontal, count: sizeClass == .regular ? 2 : 1, spacing: 12)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, TouchLayout.edge, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
    }
}

private struct TouchHeroCard: View {

    @Environment(Library.self)
    private var library
    @Environment(Router.self)
    private var router
    @Environment(\.melete)
    private var client

    let pick: TitleSummary

    /// What Play plays, once it is known: at once for a title the home
    /// describes fully, else looked up.
    @State
    private var target: PlayTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                router.open(pick)
            } label: {
                artwork
            }
            .buttonStyle(.plain)
            .accessibilityLabel(pick.title)
            .accessibilityHint("Opens the title")

            Text(pick.facts)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 10) {
                Button {
                    if let target {
                        router.play(target)
                    } else {
                        router.open(pick)
                    }
                } label: {
                    Label(target?.label ?? "Play", systemImage: "play.fill")
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)

                // A glyph alone, so Play keeps the width for what it says
                // it will do: "Resume S1:E3 · 11m left".
                Button {
                    Task { await library.toggleFavourite(pick.ref) }
                } label: {
                    Label(
                        library.isFavourite(pick.ref) ? "Remove from My List" : "Add to My List",
                        systemImage: library.isFavourite(pick.ref) ? "checkmark" : "plus"
                    )
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
            }
            .controlSize(.large)
        }
        .task(id: pick.ref) {
            target = PlayTarget.known(for: pick)
            guard target == nil, let client else { return }
            let found = try? await PlayTarget.lookUp(for: pick, client: client)
            guard !Task.isCancelled else { return }
            target = found
        }
    }

    private var artwork: some View {
        Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                ArtworkImage(ArtworkSlot(path: pick.backdrop, kind: .backdrop, width: 800)) {
                    Color(white: 0.12)
                }
            }
            .overlay {
                // Dark where the logo sits, so it reads over any picture.
                LinearGradient(
                    colors: [.clear, .black.opacity(0.35), .black.opacity(0.85)],
                    startPoint: .init(x: 0.5, y: 0.4),
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                TitleLogo(entry: pick, maxWidth: 200, maxHeight: 64, fontSize: 24)
                    .padding(14)
            }
            .overlay(alignment: .topTrailing) {
                if let badge = pick.badge(isWatching: library.watching.contains(pick.ref)) {
                    BadgeChip(kind: badge.0, title: badge.1)
                        .padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
#endif
