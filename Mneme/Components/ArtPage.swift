//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI

/// A page given over to one of the app's pictures, for when there is nothing
/// else to show: the picture fills the screen, and what happened is written on
/// its dark left side, over a fade that keeps the words readable whatever is
/// drawn behind them.
struct ArtPage<Actions: View>: View {

    /// The picture's name in the asset catalog.
    let art: String
    let title: String
    let message: String?
    @ViewBuilder
    let actions: () -> Actions

    var body: some View {
        #if os(tvOS)
        ZStack(alignment: .leading) {
            ArtBackdrop(art: art)
            words
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.leading, RowLayout.edge)
                .focusSection()
        }
        #else
        // A phone held upright crops the wide picture to its middle, where
        // the drawing is, so the words go to the foot of the page instead,
        // over a fade of their own.
        ZStack(alignment: .bottomLeading) {
            ArtBackdrop(art: art)
            LinearGradient(
                colors: [.clear, Color.mnemePageBackground.opacity(0.9), Color.mnemePageBackground],
                startPoint: .init(x: 0.5, y: 0.45),
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            words
                .frame(maxWidth: 560, alignment: .leading)
                .padding(.horizontal, TouchLayout.edge * 1.5)
                .padding(.bottom, 40)
        }
        #endif
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: Self.spacing) {
            Text(title)
                .font(.title2.bold())
            if let message {
                Text(message)
                    .foregroundStyle(.secondary)
            }
            actions()
                .padding(.top, Self.spacing)
        }
    }

    #if os(tvOS)
    private static var spacing: CGFloat {
        20
    }
    #else
    private static var spacing: CGFloat {
        10
    }
    #endif
}

/// One of the app's pictures filling the screen, darkened on the left where
/// words go. Each picture is drawn with that side kept clear.
struct ArtBackdrop: View {

    /// The picture's name in the asset catalog.
    let art: String

    var body: some View {
        // On a clear view that takes whatever room it is offered: a picture
        // sized to fill, laid out directly, asked for more height than the
        // screen and pushed the tab strip off the top.
        Color.clear
            .overlay {
                Image(art)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: Color.mnemePageBackground.opacity(0.8), location: 0),
                        .init(color: Color.mnemePageBackground.opacity(0.5), location: 0.35),
                        .init(color: .clear, location: 0.55),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .ignoresSafeArea()
    }
}

extension ArtPage where Actions == EmptyView {

    init(art: String, title: String, message: String?) {
        self.init(art: art, title: title, message: message) { EmptyView() }
    }
}
