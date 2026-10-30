//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit
import SwiftUI

/// What the row knows and the tile needs: its shape, its width, and where
/// the row's paint stops.
struct TileSlot {

    let shape: TileShape
    let width: CGFloat

    /// The strip of the row that is painted, in the row's coordinate space.
    /// A tile hanging out of it is cut by the mask, and a picture cut in half
    /// is fine where a word is not; knowing where the paint stops lets a
    /// half-shown tile drop its caption, badge and progress bar.
    let paintedStrip: ClosedRange<CGFloat>

    /// Where the page's fade ends above this tile's row.
    var fadeLift: CGFloat = TileSpotlightLayout.rowFadeLift

    /// For a tile in a grid: nothing is ever cut, and there is no heading
    /// over its row.
    static func grid(_ shape: TileShape, width: CGFloat) -> TileSlot {
        TileSlot(
            shape: shape,
            width: width,
            paintedStrip: -CGFloat.infinity ... CGFloat.infinity,
            fadeLift: TileSpotlightLayout.gridFadeLift
        )
    }
}

/// A title's tile. Focus lifts it a little and outlines it; what the title
/// is goes to the page's `TileSpotlight` at the top of the screen.
struct TitleTile: View {

    @Environment(\.tileSpotlight)
    private var spotlight
    @Environment(Library.self)
    private var library

    @FocusState
    private var isFocused: Bool

    /// Whether the row's mask is cutting a piece off this tile.
    @State
    private var isCutOff = false

    /// Which way the tile grows when it lifts: from its middle, or away from
    /// the edge of the painted strip when it sits against one. Lifting from
    /// the middle pushed the first tile past the row's margin, where the mask
    /// cuts, so the focused tile of all of them lost its edge.
    @State
    private var liftAnchor: UnitPoint = .bottom

    let summary: TitleSummary
    let slot: TileSlot
    let action: () -> Void

    /// Enough to read as "this one" from across the room; small enough that
    /// neighbours stay whole and nothing reflows.
    static let liftScale: CGFloat = 1.08

    private var size: CGSize {
        slot.shape.size(forWidth: slot.width)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                picture
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(isFocused ? Self.liftScale : 1, anchor: liftAnchor)

                // No caption under a poster: it carries its title in the art,
                // and the spotlight names whatever is focused. A wide tile keeps
                // one, because an episode still is just a picture without it.
                if slot.shape == .landscape {
                    caption
                        .opacity(isCutOff ? 0 : 1)
                }
            }
            .frame(width: size.width, alignment: .leading)
        }
        .buttonStyle(BareButtonStyle())
        .focused($isFocused)
        .background {
            if let spotlight {
                ScrollRevealer(isFocused: isFocused, spotlight: spotlight, fadeLift: slot.fadeLift)
            }
        }
        .animation(RowLayout.motion, value: isFocused)
        .animation(.easeOut(duration: 0.2), value: isCutOff)
        // A point of tolerance either side, because the leading tile rests
        // exactly on the strip's edge and comparing equal floats flickers.
        .onGeometryChange(for: Bool.self) { proxy in
            let strip = slot.paintedStrip
            let frame = proxy.frame(in: .named(RowLayout.space))
            return frame.minX < strip.lowerBound - 1 || frame.maxX > strip.upperBound + 1
        } action: { isCutOff = $0 }
        .onGeometryChange(for: UnitPoint.self) { proxy in
            let strip = slot.paintedStrip
            let frame = proxy.frame(in: .named(RowLayout.space))
            if frame.minX < strip.lowerBound + 2 {
                return .bottomLeading
            }
            if frame.maxX > strip.upperBound - 2 {
                return .bottomTrailing
            }
            return .bottom
        } action: { liftAnchor = $0 }
        .onChange(of: isFocused) {
            guard let spotlight else { return }
            if isFocused {
                spotlight.show(summary)
            } else {
                spotlight.leave(summary.ref)
            }
        }
    }

    // MARK: - Caption

    @ViewBuilder
    private var caption: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(summary.title)
                .font(.footnote)
                .foregroundStyle(.primary)
            Text(subtitle ?? " ")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .frame(width: slot.width, alignment: .leading)
    }

    /// "S2:E4 · The Long Night", or the year for a movie.
    private var subtitle: String? {
        if let episode = summary.episode {
            return [Format.episodeCode(season: episode.season, episode: episode.episode), episode.name]
                .compactMap(\.self)
                .joined(separator: " · ")
        }
        return summary.year.map(String.init)
    }

    // MARK: - Picture

    private var picturePath: String? {
        switch slot.shape {
        case .landscape: summary.episode?.still ?? summary.backdrop ?? summary.poster
        case .portrait: summary.poster
        }
    }

    @ViewBuilder
    private var picture: some View {
        ArtworkImage(path: picturePath) {
            ZStack {
                Color(white: 0.12)
                Text(summary.title)
                    .font(.caption.bold())
                    .multilineTextAlignment(.center)
                    .padding(12)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        // Everything on the artwork goes when the tile is only half painted:
        // a progress bar sliced down the middle reads as a bar 60% full.
        .overlay(alignment: .bottomLeading) {
            if slot.shape == .landscape, !isCutOff, let progress = summary.progress {
                ProgressStrip(progress: progress)
            }
        }
        .overlay(alignment: .topLeading) {
            if let badge = summary.badge(isWatching: library.watching.contains(summary.ref), compact: slot.shape == .portrait), !isCutOff {
                BadgeChip(kind: badge.0, title: badge.1)
                    .padding(12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(isFocused ? 0.9 : 0), lineWidth: 4)
        }
        .shadow(color: .black.opacity(isFocused ? 0.6 : 0), radius: 20, y: 10)
    }
}

/// How far through, as a bar along the bottom of a wide tile with what is
/// left written over it.
private struct ProgressStrip: View {

    let progress: WatchHomeItem.Progress

    private var fraction: Double {
        guard let duration = progress.durationSeconds, duration > 0 else { return 0 }
        return min(max(progress.positionSeconds / duration, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let left = progress.timeLeft {
                Text(left)
                    .font(.caption2.bold())
                    .shadow(color: .black.opacity(0.8), radius: 4)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.3))
                    Capsule().fill(.white).frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .background(alignment: .bottom) {
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                .frame(height: 90)
        }
    }
}

/// A button that draws nothing of its own. tvOS's `.plain` paints a pale
/// plate behind a focused label, which around a picture reads as a grey card;
/// the tile draws its own border and shadow instead.
struct BareButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Scrolls the page so the focused row rests just under the spotlight.
/// UIKit, because SwiftUI cannot say "put this view at this height on the
/// screen" for a view inside two nested scroll views.
private struct ScrollRevealer: UIViewRepresentable {

    let isFocused: Bool
    let spotlight: TileSpotlight
    let fadeLift: CGFloat

    @MainActor
    final class Coordinator {
        var didReveal = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        guard isFocused else {
            context.coordinator.didReveal = false
            return
        }
        guard !context.coordinator.didReveal else { return }
        context.coordinator.didReveal = true

        // Next turn of the run loop: the view has its frame by then.
        DispatchQueue.main.async {
            guard view.window != nil else { return }
            let restingTop = TileSpotlightLayout.restingTop(forTileHeight: view.bounds.height)

            // Where the row actually lands, which the fade follows: the last
            // row on a page cannot scroll up to the resting line and sits
            // lower.
            if let landed = ScrollAnchoring.scroll(view, toWindowY: restingTop) {
                spotlight.rest(at: landed, fadeLift: fadeLift)
            }
        }
    }
}
