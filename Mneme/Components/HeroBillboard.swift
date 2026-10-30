//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import AetherEngine
import MeleteKit
import Nuke
import SwiftUI

/// The top of a Watch page: one card the width of the screen for one pick
/// at a time, with Play, More Info and My List on the artwork.
///
/// Steps to the next pick every 16 seconds unless somebody is on the card,
/// and by hand with Left from Play and Right from My List.
struct HeroBillboard: View {

    @Environment(\.melete)
    private var client

    @State
    private var index = 0

    /// The rotation holds while somebody is looking at the card.
    @State
    private var isFocused = false

    @State
    private var prefetcher = ImagePrefetcher(destination: .diskCache)

    let picks: [TitleSummary]
    let open: (TitleSummary) -> Void
    let play: (PlayTarget) -> Void

    /// Long enough to read the lockup; short enough that the picks are seen
    /// inside a couple of minutes.
    private static let rotation: Duration = .seconds(16)

    private var pick: TitleSummary? {
        picks.indices.contains(index) ? picks[index] : picks.first
    }

    private func step(_ delta: Int) {
        guard picks.count > 1 else { return }
        index = (index + delta + picks.count) % picks.count
    }

    var body: some View {
        if let pick {
            HeroCard(
                pick: pick,
                position: picks.count < 2 ? nil : (index + 1, picks.count),
                onFocusChange: { isFocused = $0 },
                onPrevious: { step(-1) },
                onNext: { step(1) },
                open: open,
                play: play
            )
            .frame(height: HeroLayout.cardHeight)
            .padding(.horizontal, RowLayout.edge)
            // The whole card is what Down from the strip finds. The focus
            // engine picks what sits under the pill you are on, and the lockup
            // alone sat under Home but not under the tabs to its right, so on
            // those pages Down skipped the hero.
            .focusSection()
            .task(id: picks.map(\.ref)) {
                // Every pick's backdrop before anybody steps to it: the hero
                // is the largest picture in the app.
                guard let client else { return }
                prefetcher.startPrefetching(with: picks.compactMap { client.artworkRequest($0.backdrop) })
            }
            .task(id: picks.count) {
                guard picks.count > 1 else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: Self.rotation)
                    guard !Task.isCancelled else { return }
                    // Never change the title under a finger about to press Play.
                    if !isFocused {
                        withAnimation { step(1) }
                    }
                }
            }
        }
    }
}

// MARK: - Card

private struct HeroCard: View {

    @Environment(\.melete)
    private var client
    @Environment(Library.self)
    private var library

    @FocusState
    private var focusedAction: Action?

    private enum Action: Hashable {
        case play
        case info
        case list
        /// The two invisible targets at the ends of the buttons; see `stepTarget`.
        case stepBack
        case stepForward
    }

    /// Play's target, looked up when the pick does not say.
    @State
    private var target: PlayTarget?
    /// The pick's clip, while the card has focus.
    @State
    private var clip = PreviewClip()

    let pick: TitleSummary
    /// "2 of 5" while there are picks to step through.
    let position: (Int, Int)?
    let onFocusChange: (Bool) -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let open: (TitleSummary) -> Void
    let play: (PlayTarget) -> Void

    private var isFocused: Bool {
        focusedAction != nil
    }

    var body: some View {
        artwork
            .overlay(alignment: .bottomLeading) {
                lockup
                    .padding(HeroLayout.inset)
                    // Its own section, so the remote walks the buttons before
                    // it leaves the card.
                    .focusSection()
            }
            .overlay(alignment: .bottomTrailing) {
                if let badge = pick.badge(isWatching: library.watching.contains(pick.ref)) {
                    BadgeChip(kind: badge.0, title: badge.1)
                        .padding(HeroLayout.inset)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: HeroLayout.radius, style: .continuous)
                    .strokeBorder(.white.opacity(isFocused ? 0.9 : 0), lineWidth: 3)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: HeroLayout.radius, style: .continuous))
            .animation(.easeOut(duration: 0.2), value: isFocused)
            .onChange(of: isFocused) {
                onFocusChange(isFocused)
                if isFocused, let client {
                    clip.start(for: pick, client: client)
                } else {
                    clip.stop()
                }
            }
            .onDisappear {
                clip.stop()
            }
            // Stepping keeps this card and changes the title under it. A card
            // rebuilt per title threw away its focus, so a second Left walked
            // the buttons instead of stepping again.
            .task(id: pick.ref) {
                // A step changes the title under a focused card; its clip
                // follows.
                if isFocused, let client {
                    clip.start(for: pick, client: client)
                }
                target = PlayTarget.known(for: pick)
                guard target == nil, let client else { return }
                let found = try? await PlayTarget.lookUp(for: pick, client: client)
                guard !Task.isCancelled else { return }
                target = found
            }
    }

    @ViewBuilder
    private var artwork: some View {
        FocusedBackdrop(path: pick.backdrop, focus: pick.backdropFocus)
            // Keyed on the title, so a step is a crossfade of the picture alone.
                .id(pick.ref)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.5), value: pick.ref)
                .overlay {
                    // Over the still once it plays, so a clip that is slow to
                    // start never shows an empty card.
                    if let engine = clip.engine, clip.isPlaying {
                        AetherPlayerSurface(engine: engine)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.6), value: clip.isPlaying)
                .overlay {
                    // Two ramps, opaque at the corner the text sits in, so the
                    // logo and facts never read against whatever the picture does.
                    LinearGradient(
                        colors: [.black.opacity(0.85), .black.opacity(0.45), .clear],
                        startPoint: .leading,
                        endPoint: .init(x: 0.6, y: 0.5)
                    )
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.35), .black.opacity(0.9)],
                        startPoint: .init(x: 0.5, y: 0.45),
                        endPoint: .bottom
                    )
                }
    }

    @ViewBuilder
    private var lockup: some View {
        VStack(alignment: .leading, spacing: 14) {
            TitleLogo(entry: pick, maxWidth: HeroLayout.logoMaxWidth, maxHeight: HeroLayout.logoMaxHeight, fontSize: 60)

            Text(pick.facts)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.9))

            if let overview = pick.overview, !overview.isEmpty {
                Text(overview)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
                    .frame(maxWidth: 900, alignment: .leading)
            }

            actions
                .padding(.top, 12)
        }
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 18) {
            stepTarget(.stepBack, armedBy: .play) {
                onPrevious()
                focusedAction = .play
            }

            HeroActionButton(title: target?.label ?? "Play", systemImage: "play.fill", isProminent: true) {
                if let target {
                    play(target)
                } else {
                    open(pick)
                }
            }
            .focused($focusedAction, equals: .play)

            HeroActionButton(title: "More Info", systemImage: "info.circle", isProminent: false) {
                open(pick)
            }
            .focused($focusedAction, equals: .info)

            HeroActionButton(
                title: nil,
                systemImage: library.isFavourite(pick.ref) ? "checkmark" : "plus",
                isProminent: false
            ) {
                Task { await library.toggleFavourite(pick.ref) }
            }
            .focused($focusedAction, equals: .list)

            stepTarget(.stepForward, armedBy: .list) {
                onNext()
                focusedAction = .list
            }

            pager
                .padding(.leading, 10)
        }
        // Play is the point of the card, so focus arriving lands there.
        // `defaultFocus` does not do this: a move into the card is resolved
        // by geometry first. Arrival is the one change from nil.
        .onChange(of: focusedAction) { previous, current in
            if previous == nil, let current, current != .play {
                focusedAction = .play
            }
        }
    }

    /// One of the two places at the ends of the buttons that step the picks.
    ///
    /// Invisible, and focusable only while its neighbour has focus: Left from
    /// More Info finds Play, because the target beyond Play is not a
    /// candidate yet; the next Left finds the target, which steps and hands
    /// focus straight back. A move command would be simpler, but on the
    /// device it arrives after focus has already moved, so one press both
    /// moved and stepped.
    @ViewBuilder
    private func stepTarget(_ action: Action, armedBy neighbour: Action, perform: @escaping () -> Void) -> some View {
        Color.clear
            .frame(width: 1, height: 1)
            .focusable(focusedAction == neighbour || focusedAction == action)
            .focused($focusedAction, equals: action)
            .onChange(of: focusedAction) { _, current in
                if current == action {
                    withAnimation { perform() }
                }
            }
    }

    /// One dot per pick, between chevrons that say Left and Right step them.
    @ViewBuilder
    private var pager: some View {
        if let position {
            HStack(spacing: 10) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))

                ForEach(0 ..< position.1, id: \.self) { dot in
                    Circle()
                        .fill(.white.opacity(dot == position.0 - 1 ? 0.95 : 0.35))
                        .frame(width: 10, height: 10)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
    }
}

enum HeroLayout {
    /// Clears the tab strip, so the card starts below it.
    static let top: CGFloat = 130
    /// Backdrops are 16:9 and the card is wider, so some of every picture is
    /// thrown away; at this height it is about a quarter.
    static let cardHeight: CGFloat = 740
    static let radius: CGFloat = 24
    static let inset: CGFloat = 48
    static let logoMaxWidth: CGFloat = 520
    static let logoMaxHeight: CGFloat = 150
}
