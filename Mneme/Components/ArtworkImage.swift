//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit
import Nuke
import NukeUI
import SwiftUI

extension EnvironmentValues {
    /// The signed-in client, for views that load artwork.
    @Entry
    var melete: MeleteClient?
}

/// A picture from the server's artwork, filling its frame.
///
/// Melete's artwork needs the session's token like any other request, and its
/// URLs never change meaning, so Nuke's cache can keep them as long as it
/// likes.
struct ArtworkImage: View {

    @Environment(\.melete)
    private var client

    let path: String?
    var contentMode: ContentMode = .fill

    var body: some View {
        LazyImage(request: request) { state in
            if let image = state.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Color.white.opacity(0.06)
            }
        }
    }

    private var request: ImageRequest? {
        guard let client, let path, let url = client.url(for: path) else { return nil }
        var request = URLRequest(url: url)
        if let header = client.authorizationHeader {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }
        return ImageRequest(urlRequest: request)
    }
}
