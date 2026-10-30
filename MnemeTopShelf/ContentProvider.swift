//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import TVServices

/// Mneme's rows on the Apple TV home screen, from the snapshot the app last
/// wrote.
final class ContentProvider: TVTopShelfContentProvider {

    override func loadTopShelfContent(completionHandler: @escaping ((any TVTopShelfContent)?) -> Void) {
        completionHandler(TopShelfSnapshot.load().flatMap(Self.content(from:)))
    }

    private static func content(from snapshot: TopShelfSnapshot) -> (any TVTopShelfContent)? {

        let sections = snapshot.sections.compactMap { section -> TVTopShelfItemCollection<TVTopShelfSectionedItem>? in
            let items = section.items.map { item in
                let shelfItem = TVTopShelfSectionedItem(identifier: item.id)
                shelfItem.title = item.title
                shelfItem.imageShape = section.isLandscape ? .hdtv : .poster
                if let imageURL = item.imageURL {
                    shelfItem.setImageURL(imageURL, for: [.screenScale1x, .screenScale2x])
                }
                if let display = item.displayURL {
                    shelfItem.displayAction = TVTopShelfAction(url: display)
                }
                if let play = item.playURL ?? item.displayURL {
                    shelfItem.playAction = TVTopShelfAction(url: play)
                }
                return shelfItem
            }
            guard !items.isEmpty else { return nil }

            let collection = TVTopShelfItemCollection(items: items)
            collection.title = section.title
            return collection
        }

        return sections.isEmpty ? nil : TVTopShelfSectionedContent(sections: sections)
    }
}
