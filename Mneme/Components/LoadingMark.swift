//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI

/// Mneme's sign for "on its way": the rule from under the wordmark, with its
/// diamond breathing and a light running out from it along the rule. With
/// Reduce Motion on, the light stays put and only the glow breathes.
struct LoadingMark: View {

    var width: CGFloat = 240

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    /// One breath of the diamond, and one run of the light to the rule's ends.
    private static let period: TimeInterval = 1.6

    var body: some View {
        TimelineView(.animation) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: Self.period) / Self.period
            mark(phase: phase)
        }
        .frame(width: width, height: 30)
        .accessibilityElement()
        .accessibilityLabel("Loading")
    }

    private func mark(phase: Double) -> some View {
        // 0 at the start of a run, 1 halfway, back to 0.
        let breath = 0.5 - 0.5 * cos(phase * 2 * .pi)

        return ZStack {
            Capsule()
                .fill(LinearGradient(colors: [.clear, .mnemeCyan.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 2)

            if !reduceMotion {
                ForEach([-1.0, 1.0], id: \.self) { side in
                    Capsule()
                        .fill(Color.mnemeCyan)
                        .frame(width: width * 0.16, height: 2)
                        .shadow(color: .mnemeCyan, radius: 6)
                        .offset(x: side * phase * width * 0.42)
                        .opacity(1 - phase)
                }
            }

            Rectangle()
                .fill(Color.mnemeCyan)
                .frame(width: 13, height: 13)
                .rotationEffect(.degrees(45))
                .scaleEffect(reduceMotion ? 1 : 0.85 + 0.3 * breath)
                .shadow(color: .mnemeCyan.opacity(0.35 + 0.55 * breath), radius: 6 + 10 * breath)
        }
    }
}
