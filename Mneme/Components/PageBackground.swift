//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI

/// The night the app's pages sit on: the page colour, a soft violet light
/// rising from below as in the app's pictures, a scatter of faint stars, and
/// two constellations in the top corners beside the tab strip, where no page
/// puts anything: Cassiopeia, and Lyra, the Muses' lyre. The scattered stars
/// thin out towards the top, where pictures fade into the page.
struct PageBackground: View {

    var showsStars = true

    var body: some View {
        ZStack {
            Color.mnemePageBackground

            RadialGradient(
                colors: [Color.mnemeViolet.opacity(0.16), Color.mnemeViolet.opacity(0.05), .clear],
                center: UnitPoint(x: 0.3, y: 1.1),
                startRadius: 0,
                endRadius: 1300
            )

            if showsStars {
                Canvas { context, size in
                    for star in Self.stars {
                        let rect = CGRect(x: star.x * size.width, y: star.y * size.height, width: star.size, height: star.size)
                        context.fill(Path(ellipseIn: rect), with: .color(star.colour.opacity(star.brightness)))
                    }
                }
                // The stars thin out towards the top, where pictures fade
                // into the page.
                .mask {
                    LinearGradient(colors: [.clear, .black.opacity(0.6), .black], startPoint: .top, endPoint: .bottom)
                }

                Canvas { context, size in
                    let scale = size.width * 0.085
                    Self.draw(Self.cassiopeia, at: CGPoint(x: size.width * 0.02, y: size.height * 0.035), scale: scale, in: &context)
                    Self.draw(Self.lyra, at: CGPoint(x: size.width * 0.905, y: size.height * 0.03), scale: scale * 0.8, in: &context)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// Stars in a unit box, and the lines between them by index.
    private struct Constellation {
        let stars: [CGPoint]
        let lines: [(Int, Int)]
    }

    private static let cassiopeia = Constellation(
        stars: [CGPoint(x: 0, y: 0.32), CGPoint(x: 0.24, y: 0), CGPoint(x: 0.5, y: 0.42), CGPoint(x: 0.76, y: 0.12), CGPoint(x: 1, y: 0.5)],
        lines: [(0, 1), (1, 2), (2, 3), (3, 4)]
    )

    /// Vega at the top, the little triangle, and the lyre's frame below.
    private static let lyra = Constellation(
        stars: [
            CGPoint(x: 0.5, y: 0), CGPoint(x: 0.78, y: 0.1), CGPoint(x: 0.42, y: 0.34),
            CGPoint(x: 0.66, y: 0.42), CGPoint(x: 0.6, y: 1), CGPoint(x: 0.34, y: 0.92),
        ],
        lines: [(0, 1), (0, 2), (1, 2), (2, 3), (3, 4), (4, 5), (5, 2)]
    )

    private static func draw(_ constellation: Constellation, at origin: CGPoint, scale: CGFloat, in context: inout GraphicsContext) {
        let points = constellation.stars.map { CGPoint(x: origin.x + $0.x * scale, y: origin.y + $0.y * scale) }
        var path = Path()
        for (from, to) in constellation.lines {
            path.move(to: points[from])
            path.addLine(to: points[to])
        }
        context.stroke(path, with: .color(Color(red: 0.8, green: 0.78, blue: 1.0).opacity(0.16)), lineWidth: 1.5)
        for (index, point) in points.enumerated() {
            let radius: CGFloat = index == 0 ? 3.5 : 2.5
            let glow = CGRect(x: point.x - radius * 3, y: point.y - radius * 3, width: radius * 6, height: radius * 6)
            context.fill(Path(ellipseIn: glow), with: .color(Color.mnemeCyan.opacity(0.08)))
            let core = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: core), with: .color(Color(red: 0.88, green: 0.86, blue: 1.0).opacity(0.6)))
        }
    }

    private struct Star {
        let x: Double
        let y: Double
        let size: Double
        let brightness: Double
        let colour: Color
    }

    /// The same sky every launch: placed by a fixed sequence, not at random.
    private static let stars: [Star] = {
        var seed: UInt64 = 0x4D_6E65_6D65
        func next() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 11) / Double(1 << 53)
        }
        return (0 ..< 160).map { _ in
            let size = next() < 0.85 ? 1.5 + next() * 1.5 : 3 + next() * 1.5
            return Star(
                x: next(),
                y: next(),
                size: size,
                brightness: 0.08 + next() * 0.22,
                colour: next() < 0.8 ? Color(red: 0.85, green: 0.82, blue: 1.0) : .mnemeCyan
            )
        }
    }()
}
