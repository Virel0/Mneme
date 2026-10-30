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

    func open(_ summary: TitleSummary) {
        path.append(.title(summary))
    }

    func play(_ target: PlayTarget) {
        path.append(.play(target))
    }

    func person(_ id: Int) {
        path.append(.person(id))
    }
}
