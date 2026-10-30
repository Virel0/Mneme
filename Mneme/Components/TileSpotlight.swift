//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import AetherEngine
import Observation
import SwiftUI

/// The title a row tile is resting on, shown large at the top of the page.
///
/// Tiles stay the size they are and lift a little; what a title is — the
/// artwork, the name, the facts, the logline — is said here, above the rows,
/// where it has the room and moves nothing. A card that grew in place left
/// most of the row off the screen whenever you were on it.
@MainActor
@Observable
final class TileSpotlight {

    private(set) var entry: TitleSummary?

    /// Counts each tile gaining focus. A departure clears only the showing
    /// it began: the same title can sit in two rows (Continue Watching and
    /// Next Up), and matching by title let leaving one clear the other.
    @ObservationIgnored
    private var showing = 0

    /// Where the focused row's tiles start, in window points. Set by the row
    /// as it scrolls into place, so the page's fade follows a tall row up.
    private(set) var rowTop: CGFloat = TileSpotlightLayout.preferredRowTop

    /// How far above the focused row the fade ends: past the row's heading
    /// for a row, closer for a grid, whose rows have none.
    private(set) var fadeLift: CGFloat = TileSpotlightLayout.rowFadeLift

    func rest(at top: CGFloat, fadeLift: CGFloat) {
        if abs(rowTop - top) > 1 {
            rowTop = top
        }
        if self.fadeLift != fadeLift {
            self.fadeLift = fadeLift
        }
    }

    /// A change of title waiting out the follow delay.
    @ObservationIgnored
    private var pendingShow: Task<Void, Never>?

    /// A clear waiting to see whether focus lands on another tile.
    ///
    /// Two tasks, not one. Focus moving between tiles reports the old tile
    /// leaving and the new one arriving in either order, and with a single
    /// task whichever came second cancelled the other.
    @ObservationIgnored
    private var pendingClear: Task<Void, Never>?

    /// Whether something that belongs to a row, but is not a tile, has
    /// focus. A flag rather than a cancel: the tile leaving and the heading
    /// arriving are reported in either order.
    @ObservationIgnored
    private var isHeld = false

    /// A beat before the spotlight follows focus: enough that a sweep across
    /// a row does not ask for six backdrops on the way past.
    private static let followDelay: Duration = .milliseconds(160)

    /// How long the spotlight outlives the tile that lit it. Moving between
    /// two tiles clears focus and sets it again a frame later, and the page
    /// should not flash back to the hero for it.
    private static let holdDelay: Duration = .milliseconds(300)

    /// Shows a title; returns the showing, for `leave`.
    @discardableResult
    func show(_ entry: TitleSummary) -> Int {
        pendingClear?.cancel()
        pendingShow?.cancel()
        isHeld = false
        showing += 1

        // The first tile lights the spotlight at once: there is nothing on
        // screen to protect from churn.
        guard self.entry != nil else {
            self.entry = entry
            return showing
        }

        pendingShow = Task { [weak self] in
            try? await Task.sleep(for: Self.followDelay)
            guard !Task.isCancelled else { return }
            self?.entry = entry
            self?.pendingShow = nil
        }
        return showing
    }

    /// The tile of this showing lost focus. Clears unless another tile has
    /// taken focus since.
    func leave(_ shown: Int) {
        pendingClear?.cancel()
        pendingClear = Task { [weak self] in
            try? await Task.sleep(for: Self.holdDelay)
            guard !Task.isCancelled, let self else { return }
            guard showing == shown, pendingShow == nil, !isHeld else { return }
            entry = nil
        }
    }

    /// Something in a row that is not a tile has focus, such as its heading.
    /// The title stays up, so the page does not swap between two layouts on
    /// every row on the way down.
    func hold() {
        isHeld = true
        pendingClear?.cancel()
    }

    func release() {
        isHeld = false
        guard entry != nil else { return }
        leave(showing)
    }

    /// A list entry's facts arrived after it was shown.
    func update(_ completed: TitleSummary) {
        guard entry?.ref == completed.ref else { return }
        entry = completed
    }
}

extension EnvironmentValues {

    /// The page's spotlight, where there is one. Tiles outside such a page
    /// simply lift.
    @Entry
    var tileSpotlight: TileSpotlight?
}

/// Where things sit while the spotlight is up, in window points on a 1080p
/// frame.
enum TileSpotlightLayout {

    /// Where the focused tile's top edge rests when the row is short enough.
    static let preferredRowTop: CGFloat = 660

    /// How much of the screen's bottom the focused tile stays clear of.
    ///
    /// tvOS scrolls a focused view it thinks is too near the edge, after the
    /// row has put itself in place. It wants about 180 points under the
    /// focused tile: resting with less, tvOS lifted the row on one press of
    /// Right and the row put it back on the next. Resting where tvOS already
    /// wants it leaves it nothing to do.
    static let bottomClearance: CGFloat = 180

    static func restingTop(forTileHeight height: CGFloat) -> CGFloat {
        min(preferredRowTop, UIScreen.main.bounds.height - bottomClearance - height)
    }

    /// The page fades out over a band above the focused row, so rows
    /// scrolled up past it do not draw over the spotlight's text.
    static func fade(forRowTop rowTop: CGFloat, lift: CGFloat) -> ClosedRange<CGFloat> {
        let bottom = rowTop - lift
        return (bottom - 55) ... bottom
    }

    /// Clears a row's heading.
    static let rowFadeLift: CGFloat = 85

    /// Clears a lifted grid tile's top edge but not the row above it, given
    /// `gridRowSpacing` between them.
    static let gridFadeLift: CGFloat = 30
    static let gridRowSpacing: CGFloat = 90

    static let backdropHeight: CGFloat = 780
    static let logoMaxWidth: CGFloat = 520
    static let logoMaxHeight: CGFloat = 120
    static let infoTop: CGFloat = 140
    static let infoWidth: CGFloat = 820
}

/// The backdrop and lockup for the spotlight's title.
struct TileSpotlightView: View {

    @Environment(Library.self)
    private var library

    let spotlight: TileSpotlight

    @State
    private var clip = PreviewClip()

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let entry = spotlight.entry {
                backdrop(for: entry)
                    .id(entry.ref)
                    .transition(.opacity)

                lockup(for: entry)
                    .id(entry.ref)
                    .padding(.leading, RowLayout.edge)
                    .padding(.top, TileSpotlightLayout.infoTop)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.35), value: spotlight.entry?.ref)
        .allowsHitTesting(false)
        .task(id: spotlight.entry?.ref) {
            clip.stop()
            guard var entry = spotlight.entry else { return }
            if !entry.isComplete {
                entry = await library.complete(entry)
                guard !Task.isCancelled else { return }
                spotlight.update(entry)
            }
            clip.start(for: entry, client: library.client)
        }
        .onDisappear {
            clip.stop()
        }
    }

    @ViewBuilder
    private func backdrop(for entry: TitleSummary) -> some View {
        FocusedBackdrop(path: entry.backdrop, focus: entry.backdropFocus)
            .frame(height: TileSpotlightLayout.backdropHeight)
            .frame(maxWidth: .infinity)
            .overlay {
                if let engine = clip.engine, clip.isPlaying {
                    AetherPlayerSurface(engine: engine)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.6), value: clip.isPlaying)
            .overlay {
                // Dark on the left for the text and at the bottom where the
                // rows sit, so neither has to fight the picture.
                LinearGradient(
                    stops: [
                        .init(color: Color.mnemePageBackground.opacity(0.95), location: 0),
                        .init(color: Color.mnemePageBackground.opacity(0.6), location: 0.35),
                        .init(color: .clear, location: 0.65),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.45),
                        .init(color: Color.mnemePageBackground.opacity(0.85), location: 0.78),
                        .init(color: Color.mnemePageBackground, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
    }

    @ViewBuilder
    private func lockup(for entry: TitleSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TitleLogo(entry: entry, maxWidth: TileSpotlightLayout.logoMaxWidth, maxHeight: TileSpotlightLayout.logoMaxHeight)

            Text(entry.facts)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.9))

            if let overview = entry.overview, !overview.isEmpty {
                Text(overview)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
            }
        }
        .frame(width: TileSpotlightLayout.infoWidth, alignment: .leading)
        .shadow(color: .black.opacity(0.5), radius: 12)
    }
}

/// A title's logo, or its name set large where it has none.
struct TitleLogo: View {

    let entry: TitleSummary
    let maxWidth: CGFloat
    let maxHeight: CGFloat
    var fontSize: CGFloat = 54

    var body: some View {
        Group {
            if entry.logo != nil {
                ArtworkImage(path: entry.logo, contentMode: .fit) { Color.clear }
            } else {
                Text(entry.title)
                    .font(.system(size: fontSize, weight: .heavy))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: maxWidth, maxHeight: maxHeight, alignment: .bottomLeading)
    }
}
