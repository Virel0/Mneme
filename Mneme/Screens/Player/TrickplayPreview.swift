//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit
import Nuke
import SwiftUI

/// The picture nearest a time, cut from Melete's preview sheets.
///
/// Sheets are tiled JPEGs; picture *i* is on sheet i / (columns × rows), at
/// column i % columns and row (i / columns) % rows. They load without
/// headers from the stream link, and each is fetched once.
@MainActor
@Observable
final class TrickplayPreviews {

    private let trickplay: Trickplay
    private let stream: URL
    private let client: MeleteClient

    @ObservationIgnored
    private var sheets: [Int: CGImage] = [:]
    @ObservationIgnored
    private var loading: Set<Int> = []
    /// Raised when a sheet arrives, so a preview waiting on it redraws.
    private(set) var version = 0

    init(trickplay: Trickplay, stream: URL, client: MeleteClient) {
        self.trickplay = trickplay
        self.stream = stream
        self.client = client
    }

    var aspectRatio: CGFloat {
        CGFloat(trickplay.width) / CGFloat(max(1, trickplay.height))
    }

    func image(at seconds: Double) -> CGImage? {
        _ = version
        guard let index = nearestIndex(to: seconds) else { return nil }
        let perSheet = trickplay.columns * trickplay.rows
        let sheetNumber = index / perSheet

        guard let sheet = sheets[sheetNumber] else {
            load(sheetNumber)
            return nil
        }
        let column = index % trickplay.columns
        let row = (index / trickplay.columns) % trickplay.rows
        return sheet.cropping(to: CGRect(
            x: column * trickplay.width,
            y: row * trickplay.height,
            width: trickplay.width,
            height: trickplay.height
        ))
    }

    private func nearestIndex(to seconds: Double) -> Int? {
        let times = trickplay.times
        guard !times.isEmpty else { return nil }
        // The last picture at or before the time.
        var low = 0
        var high = times.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if times[middle] <= seconds {
                low = middle
            } else {
                high = middle - 1
            }
        }
        return low
    }

    private func load(_ sheet: Int) {
        guard sheet < trickplay.sheets, !loading.contains(sheet) else { return }
        loading.insert(sheet)
        let url = client.trickplaySheetURL(stream: stream, sheet: sheet)
        Task {
            if let image = try? await ImagePipeline.shared.image(for: url).cgImage {
                sheets[sheet] = image
                version += 1
            }
            loading.remove(sheet)
        }
    }
}
