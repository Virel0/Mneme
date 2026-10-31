//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
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
        ZStack(alignment: .leading) {
            ArtBackdrop(art: art)

            VStack(alignment: .leading, spacing: 20) {
                Text(title)
                    .font(.title2.bold())
                if let message {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
                actions()
                    .padding(.top, 20)
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.leading, RowLayout.edge)
            .focusSection()
        }
    }
}

/// One of the app's pictures filling the screen, darkened on the left where
/// words go. Each picture is drawn with that side kept clear.
struct ArtBackdrop: View {

    /// The picture's name in the asset catalog.
    let art: String

    var body: some View {
        ZStack {
            Image(art)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

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
