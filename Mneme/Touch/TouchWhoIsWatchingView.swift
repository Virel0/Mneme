//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

#if os(iOS)
import SwiftUI

/// The first screen when more than one person is signed in on the device:
/// pick who is watching, and the app opens as them.
///
/// On the night sky of the app's pages, without the Apple TV's clip: a phone
/// or tablet opens without the intro too, and comes up still and at once.
struct TouchWhoIsWatchingView: View {

    let onChosen: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Text("Who's watching?")
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)

                TouchProfileGrid(chosen: onChosen)
            }
            .padding(.horizontal, TouchLayout.edge)
            .padding(.vertical, 40)
        }
        // Few profiles sit in the middle of the screen; many scroll.
        .defaultScrollAnchor(.center, for: .alignment)
        .background { PageBackground() }
    }
}
#endif
