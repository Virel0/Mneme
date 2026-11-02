//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI

/// The night the app's pages sit on: a sky of faint stars, constellations in
/// the corners and a violet haze rising from below, with now and then a
/// shooting star. Its dark top is the page colour, so pictures that fade into
/// the page meet it without an edge.
struct PageBackground: View {

    var body: some View {
        // On a clear view that takes the room it is offered, so the picture
        // never asks the page for more.
        Color.mnemePageBackground
            .overlay {
                Image("NightSky")
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
            .overlay {
                ShootingStars()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

/// A shooting star across the upper sky every 15 to 40 seconds, at a moment
/// and a place of its own each time, so it never reads as a loop. None with
/// Reduce Motion on.
private struct ShootingStars: View {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @State
    private var streak: Streak?
    @State
    private var hasCrossed = false

    private struct Streak: Equatable {
        /// Where it starts and the direction it falls, as fractions of the
        /// screen and an angle.
        let start: CGPoint
        let angle: Angle
    }

    private static let travel: CGFloat = 460
    private static let crossing: Duration = .milliseconds(900)

    var body: some View {
        GeometryReader { proxy in
            if let streak {
                let start = CGPoint(x: streak.start.x * proxy.size.width, y: streak.start.y * proxy.size.height)
                let along = CGPoint(x: cos(streak.angle.radians) * Self.travel, y: sin(streak.angle.radians) * Self.travel)
                Capsule()
                    .fill(LinearGradient(colors: [.clear, .white.opacity(0.9)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 170, height: 2.5)
                    .shadow(color: Color.mnemeCyan.opacity(0.7), radius: 5)
                    .rotationEffect(streak.angle)
                    .position(x: start.x + (hasCrossed ? along.x : 0), y: start.y + (hasCrossed ? along.y : 0))
                    .opacity(hasCrossed ? 0 : 1)
            }
        }
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 15 ... 40)))
                guard !Task.isCancelled else { return }
                let falling = Double.random(in: 18 ... 32)
                hasCrossed = false
                streak = Streak(
                    start: CGPoint(x: .random(in: 0.15 ... 0.75), y: .random(in: 0.05 ... 0.35)),
                    // Down to the right, or down to the left.
                    angle: .degrees(Bool.random() ? falling : 180 - falling)
                )
                try? await Task.sleep(for: .milliseconds(30))
                withAnimation(.easeIn(duration: 0.9)) { hasCrossed = true }
                try? await Task.sleep(for: Self.crossing + .milliseconds(100))
                streak = nil
            }
        }
    }
}
