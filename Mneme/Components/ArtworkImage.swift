//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
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

    /// A Nuke request for a picture at the size it is drawn at, in this
    /// screen's pixels.
    func artworkRequest(_ slot: ArtworkSlot) -> ImageRequest? {
        guard let path = slot.path else { return nil }
        guard let kind = slot.kind else { return artworkRequest(path) }
        let pixels = slot.width * UIScreen.main.scale
        let sized = kind.path(path, filling: pixels)
        guard var request = artworkRequest(sized.path) else { return nil }
        // The image as uploaded can be 3840 wide for a tile a fifth of that;
        // decoded at the size it is drawn, a row of them doesn't fill memory.
        if sized.isOriginal {
            request.thumbnail = ImageRequest.ThumbnailOptions(maxPixelSize: Float(pixels))
        }
        return request
    }
}

/// One of Melete's pictures as a screen draws it: what kind of picture it is
/// and how many points wide, so the size asked for is sharp there.
///
/// Prefetching and drawing a picture go through the same slot, so they ask
/// for the same file and decode it the same way.
struct ArtworkSlot: Hashable {
    let path: String?
    /// Nil asks for the path as the server gave it: a title not in the
    /// library has only that size.
    var kind: ArtworkKind?
    var width: CGFloat = 0
}

/// A picture from the server's artwork, filling its frame.
struct ArtworkImage<Placeholder: View>: View {

    @Environment(\.melete)
    private var client

    let slot: ArtworkSlot
    var contentMode: ContentMode = .fill
    let placeholder: () -> Placeholder

    init(_ slot: ArtworkSlot, contentMode: ContentMode = .fill, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.slot = slot
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    init(path: String?, contentMode: ContentMode = .fill, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.init(ArtworkSlot(path: path), contentMode: contentMode, placeholder: placeholder)
    }

    var body: some View {
        LazyImage(request: client?.artworkRequest(slot)) { state in
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

    init(_ slot: ArtworkSlot, contentMode: ContentMode = .fill) {
        self.init(slot, contentMode: contentMode) { Color.white.opacity(0.06) }
    }

    init(path: String?, contentMode: ContentMode = .fill) {
        self.init(ArtworkSlot(path: path), contentMode: contentMode)
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

    /// Backdrops are drawn the width of the screen, or close to it, wherever
    /// they are: the hero, a title's page, the spotlight, a tile opening.
    static func slot(_ path: String?) -> ArtworkSlot {
        ArtworkSlot(path: path, kind: .backdrop, width: UIScreen.main.bounds.width)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let imageHeight = max(height, width * 9 / 16)
            let overflow = imageHeight - height
            // Faces sit in the upper part of most key art, so that is where a
            // picture without a focus is held.
            let offset = (0.5 - (focus?.y ?? 0.35)) * overflow

            ArtworkImage(Self.slot(path)) { Color.mnemePageBackground }
                .frame(width: width, height: imageHeight)
                .offset(y: offset)
                .frame(width: width, height: height)
                .clipped()
        }
    }
}

extension Color {

    /// The near-black the whole app sits on: the violet black the app's
    /// pictures are drawn on, so they and the page meet without an edge.
    ///
    /// Declared once because a gradient that fades a picture into the page has
    /// to end on exactly the page's colour, and a slightly wrong black reads as
    /// a rectangle; on a television, which lifts near-blacks, more so.
    static let mnemePageBackground = Color(red: 0.04, green: 0.016, blue: 0.08)

    /// The wordmark's two colours: the violet of its letters and the cyan of
    /// their glow and the rule beneath.
    static let mnemeViolet = Color(red: 0.49, green: 0.36, blue: 1.0)
    static let mnemeCyan = Color(red: 0.37, green: 0.91, blue: 0.94)
}
