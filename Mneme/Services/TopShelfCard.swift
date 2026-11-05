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

/// A title's picture for the Top Shelf carousel: its backdrop with its logo,
/// facts and overview drawn on, as the idle screen shows them.
///
/// tvOS 26 draws a carousel item's picture, its arrows and its page dots,
/// and none of the title, summary or details the item carries; so what the
/// title is goes into the picture. It sits in the upper left: below the
/// clock, above the arrow tvOS draws at the left edge halfway down, and clear
/// of the row of apps that covers the lower part until the shelf is opened
/// full screen.
@MainActor
enum TopShelfCard {

    /// Raised when the drawing changes, so pictures already saved are drawn
    /// again.
    /// 2: the backdrop and logo at the sizes a 4K television needs.
    static let version = 2

    /// The picture as a JPEG at 3840 by 2160, the size tvOS draws the shelf
    /// at on a 4K television.
    static func render(backdrop: UIImage, logo: UIImage?, title: String, facts: String, overview: String?) -> Data? {
        let renderer = ImageRenderer(content: Card(backdrop: backdrop, logo: logo, title: title, facts: facts, overview: overview))
        renderer.scale = 2
        return renderer.uiImage?.jpegData(compressionQuality: 0.85)
    }

    private struct Card: View {

        let backdrop: UIImage
        let logo: UIImage?
        let title: String
        let facts: String
        let overview: String?

        var body: some View {
            ZStack(alignment: .topLeading) {
                Image(uiImage: backdrop)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 1920, height: 1080)
                    .clipped()

                // Darker behind the words, so they read on any picture.
                LinearGradient(
                    colors: [.black.opacity(0.7), .black.opacity(0.3), .clear],
                    startPoint: .leading,
                    endPoint: UnitPoint(x: 0.65, y: 0.5)
                )
                LinearGradient(colors: [.black.opacity(0.4), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.55))

                VStack(alignment: .leading, spacing: 18) {
                    Group {
                        if let logo {
                            Image(uiImage: logo)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Text(title)
                                .font(.system(size: 72, weight: .heavy))
                                .lineLimit(2)
                                .minimumScaleFactor(0.6)
                        }
                    }
                    .frame(maxWidth: 600, maxHeight: 180, alignment: .bottomLeading)

                    Text(facts)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))

                    if let overview {
                        Text(overview)
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(3)
                            .frame(maxWidth: 820, alignment: .leading)
                    }
                }
                .foregroundStyle(.white)
                .padding(.leading, 110)
                .padding(.top, 110)
            }
            .frame(width: 1920, height: 1080)
        }
    }
}
