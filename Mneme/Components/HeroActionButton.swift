//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI

/// A translucent capsule, a shade lighter when it is the main action, and
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

    /// Only focus is white. A lighter Play at rest read as focused, so it is
    /// a shade above the others and no more.
    private var background: Color {
        if isFocused {
            .white
        } else if isProminent {
            .white.opacity(0.32)
        } else {
            .white.opacity(0.22)
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isFocused ? .black : .white)
            .background(background, in: Capsule())
            // A lift as well as a fill: one signal can be missed on a bright
            // backdrop, two cannot.
            .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.06 : 1))
            .shadow(color: .black.opacity(isFocused ? 0.5 : 0), radius: 14, y: 6)
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}
