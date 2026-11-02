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
