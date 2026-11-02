//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI
import UIKit

/// The night the app's pages sit on: a sky of faint stars, constellations in
/// the corners and a violet haze rising from below, with now and then a
/// shooting star. Its dark top is the page colour, so pictures that fade into
/// the page meet it without an edge.
///
/// It has depth: as focus moves, the sky eases a little the other way, as
/// something far behind would. And it follows the hour, faintly, in its lower
/// part. Neither moves with Reduce Motion on.
struct PageBackground: View {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(ArtworkColours.self)
    private var colours: ArtworkColours?

    /// How far the sky has eased against where focus is.
    @State
    private var drift = CGSize.zero

    /// How much the sky moves for each point focus is off the screen's centre.
    private static let depth: CGFloat = 0.02

    var body: some View {
        // On a clear view that takes the room it is offered, so the picture
        // never asks the page for more.
        Color.mnemePageBackground
            .overlay {
                ZStack {
                    Image("NightSky")
                        .resizable()
                        .scaledToFill()
                    SkyTint()
                    // The colour of the title with focus, glowing up from below.
                    if let glow = colours?.current {
                        RadialGradient(
                            colors: [glow.opacity(0.3), glow.opacity(0.08), .clear],
                            center: UnitPoint(x: 0.5, y: 1.1),
                            startRadius: 0,
                            endRadius: 1200
                        )
                        .transition(.opacity)
                    }
                    ShootingStars()
                }
                // A little larger than the screen, so easing never shows an edge.
                .animation(.easeInOut(duration: 1.2), value: colours?.current)
                .scaleEffect(1.04)
                .offset(drift)
            }
            .clipped()
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onReceive(NotificationCenter.default.publisher(for: UIFocusSystem.didUpdateNotification)) { note in
                guard !reduceMotion,
                      let context = note.userInfo?[UIFocusSystem.focusUpdateContextUserInfoKey] as? UIFocusUpdateContext,
                      let (point, screen) = Self.centre(of: context.nextFocusedItem)
                else { return }
                withAnimation(.easeOut(duration: 1.2)) {
                    drift = CGSize(width: -(point.x - screen.midX) * Self.depth, height: -(point.y - screen.midY) * Self.depth)
                }
            }
    }

    /// The middle of what has focus, and the screen, in the screen's points.
    private static func centre(of item: UIFocusItem?) -> (CGPoint, CGRect)? {
        guard let item, let space = item.parentFocusEnvironment?.focusItemContainer?.coordinateSpace,
              let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen
        else { return nil }
        let frame = space.convert(item.frame, to: screen.coordinateSpace)
        return (CGPoint(x: frame.midX, y: frame.midY), screen.bounds)
    }
}

/// The lower sky follows the hour: a dawn glow early in the morning, a cooler
/// light by day, a rose dusk in the evening, and the plain night after. Only
/// the lower part is tinted, so the top stays the page colour.
private struct SkyTint: View {

    var body: some View {
        TimelineView(.periodic(from: .now, by: 300)) { context in
            let tint = Self.tint(at: context.date)
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.35),
                    .init(color: tint.colour.opacity(tint.strength), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .animation(.easeInOut(duration: 3), value: tint.strength)
        }
    }

    static func tint(at date: Date) -> (colour: Color, strength: Double) {
        switch Calendar.current.component(.hour, from: date) {
        case 5 ..< 9: (Color(red: 1.0, green: 0.55, blue: 0.4), 0.22)
        case 9 ..< 17: (Color(red: 0.45, green: 0.7, blue: 1.0), 0.12)
        case 17 ..< 21: (Color(red: 0.95, green: 0.4, blue: 0.65), 0.2)
        default: (.clear, 0)
        }
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
