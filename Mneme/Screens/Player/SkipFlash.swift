//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI

/// A jump made with a click, shown as the circular arrow with its seconds
/// on that side of the picture, while the film keeps playing. Clicks in a
/// row add up: ten, twenty, thirty.
struct SkipFlash: Equatable {

    let isForward: Bool
    let seconds: Int
    /// Each click counts as new, so the same total twice still shows.
    let id = UUID()

    /// The next flash after a click: added to this one if it went the same
    /// way, else starting again.
    func adding(_ step: Int, forward: Bool) -> SkipFlash {
        guard forward == isForward else { return SkipFlash(isForward: forward, seconds: step) }
        return SkipFlash(isForward: forward, seconds: seconds + step)
    }
}

struct SkipFlashView: View {

    let flash: SkipFlash

    /// The amounts SF Symbols draws inside the arrow; anything else is the
    /// plain arrow with the number set inside it.
    private static let drawn: Set<Int> = [5, 10, 15, 30, 45, 60, 75, 90]

    private var symbol: String {
        let base = flash.isForward ? "goforward" : "gobackward"
        return Self.drawn.contains(flash.seconds) ? "\(base).\(flash.seconds)" : base
    }

    var body: some View {
        ZStack {
            Image(systemName: symbol)
                .font(.system(size: 64, weight: .semibold))
            // The number inside the plain arrow, where the drawn ones have it.
            if !Self.drawn.contains(flash.seconds) {
                Text("\(flash.seconds)")
                    .font(.system(size: 22, weight: .heavy).monospacedDigit())
                    .offset(y: 3)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.7), radius: 12)
        .padding(28)
        .background(.black.opacity(0.35), in: Circle())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: flash.isForward ? .trailing : .leading)
        .padding(.horizontal, 180)
        .allowsHitTesting(false)
    }
}
