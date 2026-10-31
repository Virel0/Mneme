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
    /// The signed-in client, for views that load artwork or make requests.
    @Entry
    var melete: MeleteClient?
}

extension MeleteClient {

    /// A Nuke request for one of the server's artwork paths.
    ///
    /// Melete's artwork needs the session's token like any other request, and
    /// its URLs never change meaning, so Nuke's caches can keep them as long
    /// as they like.
    func artworkRequest(_ path: String?) -> ImageRequest? {
        guard let path, let url = url(for: path) else { return nil }
        var request = URLRequest(url: url)
        if let header = authorizationHeader {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }
        return ImageRequest(urlRequest: request)
    }
}

/// A picture from the server's artwork, filling its frame.
struct ArtworkImage<Placeholder: View>: View {

    @Environment(\.melete)
    private var client

    let path: String?
    var contentMode: ContentMode = .fill
    let placeholder: () -> Placeholder

    init(path: String?, contentMode: ContentMode = .fill, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.path = path
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    var body: some View {
        LazyImage(request: client?.artworkRequest(path)) { state in
            if let image = state.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
    }
}

extension ArtworkImage where Placeholder == Color {

    init(path: String?, contentMode: ContentMode = .fill) {
        self.init(path: path, contentMode: contentMode) { Color.white.opacity(0.06) }
    }
}

/// A wide picture cropped to its frame around the point its subject is at,
/// instead of always around its middle.
///
/// Backdrops are 16:9 and the frames they fill are often wider, so part of
/// every picture is thrown away; Melete says where the subject is, and the
/// picture slides so that part stays in view.
struct FocusedBackdrop: View {

    let path: String?
    let focus: Focus?

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let imageHeight = max(height, width * 9 / 16)
            let overflow = imageHeight - height
            // Faces sit in the upper part of most key art, so that is where a
            // picture without a focus is held.
            let offset = (0.5 - (focus?.y ?? 0.35)) * overflow

            ArtworkImage(path: path) { Color.mnemePageBackground }
                .frame(width: width, height: imageHeight)
                .offset(y: offset)
                .frame(width: width, height: height)
                .clipped()
        }
    }
}

extension Color {

    /// The near-black the whole app sits on.
    ///
    /// Declared once because a gradient that fades a picture into the page has
    /// to end on exactly the page's colour, and a slightly wrong black reads as
    /// a rectangle.
    static let mnemePageBackground = Color(red: 0.035, green: 0.035, blue: 0.045)

    /// The wordmark's two colours: the violet of its letters and the cyan of
    /// their glow and the rule beneath.
    static let mnemeViolet = Color(red: 0.49, green: 0.36, blue: 1.0)
    static let mnemeCyan = Color(red: 0.37, green: 0.91, blue: 0.94)
}
