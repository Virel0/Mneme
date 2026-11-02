//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import TVServices

/// The hero's picks on the Apple TV home screen, as a full-width carousel,
/// from the snapshot the app last wrote: a muted preview of a title's
/// trailer plays while it is highlighted, where it has one.
final class ContentProvider: TVTopShelfContentProvider {

    override func loadTopShelfContent(completionHandler: @escaping ((any TVTopShelfContent)?) -> Void) {
        completionHandler(TopShelfSnapshot.load().flatMap(Self.content(from:)))
    }

    private static func content(from snapshot: TopShelfSnapshot) -> (any TVTopShelfContent)? {
        let items = snapshot.features.map { feature in
            let item = TVTopShelfCarouselItem(identifier: feature.id)
            item.title = feature.title
            item.summary = feature.summary
            item.genre = feature.genre
            if let duration = feature.duration {
                item.duration = duration
            }
            if let year = feature.year {
                item.creationDate = Calendar.current.date(from: DateComponents(year: year))
            }
            if let imageURL = feature.imageURL {
                item.setImageURL(imageURL, for: [.screenScale1x, .screenScale2x])
            }
            item.previewVideoURL = feature.previewURL
            if let display = feature.displayURL {
                item.displayAction = TVTopShelfAction(url: display)
            }
            if let play = feature.playURL ?? feature.displayURL {
                item.playAction = TVTopShelfAction(url: play)
            }
            return item
        }
        return items.isEmpty ? nil : TVTopShelfCarouselContent(style: .details, items: items)
    }
}
