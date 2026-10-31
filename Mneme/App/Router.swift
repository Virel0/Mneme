//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Observation
import SwiftUI

/// Somewhere to go from a page.
enum Route: Hashable {
    case title(TitleSummary)
    case play(PlayTarget)
    case person(Int)
}

/// The signed-in app's navigation: one stack over the tabs, so a title's
/// page and the player cover the tab strip, and Menu walks back.
@MainActor
@Observable
final class Router {

    var path: [Route] = []

    /// Black over everything while the player is put in.
    private(set) var isCurtainDown = false

    /// The tile just pressed. Pages are opened through the rows' and grids'
    /// own actions, which know nothing of tiles, so the tile notes itself
    /// here first.
    var pressedTile: TileZoom?

    /// The tile growing into the page it opened, while it does.
    private(set) var zoom: TileZoom?

    func open(_ summary: TitleSummary) {
        zoom = pressedTile
        pressedTile = nil
        path.append(.title(summary))
    }

    func endZoom() {
        zoom = nil
    }

    /// Fades to black, puts the player in without the slide, then lifts the
    /// black over a player that is itself black until the picture comes.
    func play(_ target: PlayTarget) {
        pressedTile = nil
        guard !isCurtainDown else { return }
        Task {
            withAnimation(.easeIn(duration: Self.curtainFall)) { isCurtainDown = true }
            try? await Task.sleep(for: .seconds(Self.curtainFall))
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) { path.append(.play(target)) }
            // The push finishes under the black, slide or not.
            try? await Task.sleep(for: .seconds(0.6))
            isCurtainDown = false
        }
    }

    func person(_ id: Int) {
        pressedTile = nil
        path.append(.person(id))
    }

    private static let curtainFall: TimeInterval = 0.35
}

/// A tile's picture and where it sat on the screen, to grow from.
struct TileZoom: Equatable {
    let id = UUID()
    let picture: String?
    let frame: CGRect
}
