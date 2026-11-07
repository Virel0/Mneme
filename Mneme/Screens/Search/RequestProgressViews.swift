//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit
import SwiftUI

/// The steps from asked-for to watchable, with the one it is on lit.
struct StepTrack: View {

    let step: String

    static let steps: [(key: String, name: String)] = [
        ("wanted", "Waiting"),
        ("searching", "Searching"),
        ("downloading", "Downloading"),
        ("transferring", "Copying Home"),
        ("importing", "Importing"),
        ("in_library", "In the Library"),
    ]

    var body: some View {
        if step == "failed" {
            Label("It couldn't be found or fetched", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        } else {
            let reached = Self.steps.firstIndex { $0.key == step } ?? 0
            HStack(spacing: 14) {
                ForEach(Array(Self.steps.enumerated()), id: \.offset) { index, item in
                    if index > 0 {
                        Capsule()
                            .fill(index <= reached ? Color.mnemeCyan : .white.opacity(0.2))
                            .frame(width: 36, height: 3)
                    }
                    Text(item.name)
                        .font(.callout.weight(index == reached ? .bold : .regular))
                        .foregroundStyle(index == reached ? Color.mnemeCyan : index < reached ? .primary : .secondary)
                }
            }
        }
    }
}

/// An approved series, season by season.
struct SeasonGrid: View {

    let seasons: [RequestSeason]

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 30, alignment: .leading), count: 3),
            alignment: .leading,
            spacing: 18
        ) {
            ForEach(seasons, id: \.season) { season in
                VStack(alignment: .leading, spacing: 4) {
                    Text(season.season == 0 ? "Specials" : "Season \(season.season)")
                        .font(.callout.bold())
                    Text(Self.line(season))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .opacity(season.monitored ? 1 : 0.5)
            }
        }
        .frame(maxWidth: 1100, alignment: .leading)
    }

    /// "8 of 10 episodes · Downloading 40%", or "Not looked for".
    static func line(_ season: RequestSeason) -> String {
        guard season.monitored else { return "Not looked for" }
        let episodes = season.episodes.map { "\(season.inLibrary) of \($0) episodes" } ?? "\(season.inLibrary) episodes"
        let step: String? = switch season.step {
        case "in_library": nil
        case "downloading": season.percent.map { "Downloading \(Int($0))%" } ?? "Downloading"
        case "wanted": "Waiting"
        case "transferring": "Copying home"
        case "failed": "Failed"
        default: season.step.capitalized
        }
        return [episodes, step].compactMap(\.self).joined(separator: " · ")
    }
}

/// "All Seasons" and season numbers, for choosing which season a series
/// request asks for. Melete doesn't know how many a series has until it is
/// in the library, so it checks the number.
struct SeasonChoices: View {

    let choose: (Int?) -> Void

    var body: some View {
        Button("All Seasons") { choose(nil) }
        ForEach(1 ... 20, id: \.self) { season in
            Button("Season \(season)") { choose(season) }
        }
        Button("Specials") { choose(0) }
    }
}
