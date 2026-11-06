//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI

#if !os(tvOS)
/// The Siri Remote's buttons and the focus engine's sections have nothing to
/// do on a touch screen. Here they do nothing, so views shared with the
/// Apple TV build unchanged until each has a touch layout of its own.
extension View {
    func focusSection() -> some View {
        self
    }

    func onExitCommand(perform _: (() -> Void)?) -> some View {
        self
    }

    func onPlayPauseCommand(perform _: (() -> Void)?) -> some View {
        self
    }
}
#endif
