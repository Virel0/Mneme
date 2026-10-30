//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI

/// A capsule: light when it is the main action, translucent otherwise, and
/// solid white with a black label when focused.
struct HeroActionButton: View {

    let title: String?
    let systemImage: String
    let isProminent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .bold))

                if let title {
                    Text(title)
                        .font(.system(size: 24, weight: .semibold))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, title == nil ? 22 : 30)
            .padding(.vertical, 16)
        }
        .buttonStyle(HeroActionButtonStyle(isProminent: isProminent))
    }
}

private struct HeroActionButtonStyle: ButtonStyle {

    @Environment(\.isFocused)
    private var isFocused

    let isProminent: Bool

    private var background: Color {
        if isFocused {
            .white
        } else if isProminent {
            // Not white: if Play at rest were the same white as focus, focus
            // would be invisible on it.
            .white.opacity(0.62)
        } else {
            .white.opacity(0.22)
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isFocused || isProminent ? .black : .white)
            .background(background, in: Capsule())
            // A lift as well as a fill: one signal can be missed on a bright
            // backdrop, two cannot.
            .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.06 : 1))
            .shadow(color: .black.opacity(isFocused ? 0.5 : 0), radius: 14, y: 6)
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}
