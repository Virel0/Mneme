//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit
import SwiftUI

/// A backdrop leans in a little and back out, over half a minute each way,
/// around the picture's subject, so a picture that sits a while is not a
/// still: a title's page, and the hero and spotlight while their clip loads
/// or when clips are off. A clip plays over it, not drifting itself.
struct SlowDrift: ViewModifier {

    let focus: Focus?

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            // Keyframes rather than a repeating animation: an animation's
            // transaction also caught the picture's own fade-in and stretched
            // it over the half minute.
            content.keyframeAnimator(initialValue: 1.0, repeating: true) { view, scale in
                view.scaleEffect(scale, anchor: UnitPoint(x: focus?.x ?? 0.5, y: focus?.y ?? 0.35))
            } keyframes: { _ in
                CubicKeyframe(1.07, duration: 30)
                CubicKeyframe(1.0, duration: 30)
            }
        }
    }
}
