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

/// One of the viewer's requests: what was asked for, what was decided, and
/// how it is getting on, step by step and season by season. It follows the
/// live list, so it moves on as Melete does. A request still waiting can be
/// taken back, or a series' season changed.
struct RequestDetailView: View {

    @Environment(\.dismiss)
    private var dismiss
    @Environment(Library.self)
    private var library

    let request: MediaRequest
    /// Search's model, told of changes made here; nil elsewhere.
    let model: SearchModel?

    @State
    private var isWorking = false
    @State
    private var error: String?
    @State
    private var choosesSeason = false
    @State
    private var confirmsTakeBack = false

    /// The request as the live list has it now.
    private var current: MediaRequest {
        library.requests?.first { $0.id == request.id }
            ?? model?.requests.first { $0.id == request.id }
            ?? request
    }

    var body: some View {
        ZStack {
            PageBackground()

            HStack(alignment: .top, spacing: 70) {
                PosterCard(poster: current.poster, title: current.title, caption: nil, showsLabel: false)
                    .scaleEffect(1.6, anchor: .topLeading)
                    .frame(width: PosterCard.width * 1.6, height: PosterCard.width * 2.4, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 24) {
                    Text(current.title)
                        .font(.system(size: 60, weight: .heavy))
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    Text(Self.whatWasAsked(current))
                        .foregroundStyle(.secondary)

                    state
                        .padding(.top, 12)

                    if let error {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(100)
        }
        .confirmationDialog("Which season?", isPresented: $choosesSeason) {
            SeasonChoices { season in change(to: season) }
        }
        .confirmationDialog("Take back this request?", isPresented: $confirmsTakeBack) {
            Button("Take Back", role: .destructive, action: takeBack)
        }
    }

    // MARK: - State

    @ViewBuilder
    private var state: some View {
        switch current.state {
        case "requested":
            Text("Waiting for approval")
                .font(.title3.bold())
            Text("Asked for \(Self.when(current.createdAt))")
                .foregroundStyle(.secondary)
            HStack(spacing: 18) {
                HeroActionButton(title: "Take Back", systemImage: "xmark.circle", isProminent: false) {
                    confirmsTakeBack = true
                }
                if current.kind == "series" {
                    HeroActionButton(title: "Change Season", systemImage: "list.number", isProminent: false) {
                        choosesSeason = true
                    }
                }
            }
            .disabled(isWorking)
            .padding(.top, 12)
            .focusSection()

        case "declined":
            Text("Declined")
                .font(.title3.bold())
            Text(Self.decision(current, verb: "Declined"))
                .foregroundStyle(.secondary)
            if let reason = current.reason, !reason.isEmpty {
                Text(reason)
                    .frame(maxWidth: 900, alignment: .leading)
            }

        default:
            Text(Self.decision(current, verb: "Approved"))
                .foregroundStyle(.secondary)
            if current.progress == nil {
                Text("Melete isn't reporting how it's getting on.")
                    .foregroundStyle(.secondary)
            }
            if let progress = current.progress {
                StepTrack(step: progress.step)
                    .padding(.vertical, 8)
                if let detail = Self.detail(of: progress) {
                    Text(detail)
                        .frame(maxWidth: 900, alignment: .leading)
                }
                if let origin = Self.origin(of: progress) {
                    Text(origin)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            if let seasons = current.seasons, !seasons.isEmpty {
                SeasonGrid(seasons: seasons)
                    .padding(.top, 12)
            }
        }
    }

    // MARK: - Actions

    private func takeBack() {
        isWorking = true
        error = nil
        Task {
            if let failure = await Self.takeBack(current.id, library: library, model: model) {
                error = failure
            } else {
                dismiss()
            }
            isWorking = false
        }
    }

    private func change(to season: Int?) {
        isWorking = true
        error = nil
        Task {
            error = await Self.change(current.id, to: season, library: library, model: model)
            isWorking = false
        }
    }

    /// Takes a waiting request back, and out of the lists that show it.
    /// Returns what to say when it can't be.
    static func takeBack(_ id: Int, library: Library, model: SearchModel?) async -> String? {
        do throws(MeleteError) {
            try await library.client.takeBack(request: id)
            library.removeRequest(id)
            model?.removeRequest(id)
            return nil
        } catch .server(status: 409, _) {
            return "It has already been decided, so it can't be taken back."
        } catch {
            return error.localizedDescription
        }
    }

    /// Changes which season a waiting series request asks for, in the lists
    /// that show it too. Returns what to say when it can't be.
    static func change(_ id: Int, to season: Int?, library: Library, model: SearchModel?) async -> String? {
        do throws(MeleteError) {
            let changed = try await library.client.changeRequest(id, season: season)
            library.replaceRequest(changed)
            model?.replaceRequest(changed)
            return nil
        } catch .server(status: 409, _) {
            return "It has already been decided, so it can't be changed."
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: - Words

    /// "Series · Season 2 · 2019", "Movie · 2024", "Album by Radiohead".
    static func whatWasAsked(_ request: MediaRequest) -> String {
        switch request.kind {
        case "series":
            let season = request.season.map { $0 == 0 ? "Specials" : "Season \($0)" } ?? "All Seasons"
            return ["Series", season, request.year.map(String.init)].compactMap(\.self).joined(separator: " · ")
        case "movie":
            return ["Movie", request.year.map(String.init)].compactMap(\.self).joined(separator: " · ")
        default:
            let what = request.kind.capitalized
            return request.artist.map { "\(what) by \($0)" } ?? what
        }
    }

    static func when(_ seconds: Int) -> String {
        Date(timeIntervalSince1970: TimeInterval(seconds)).formatted(.relative(presentation: .named))
    }

    /// "Approved by ada 2 days ago", or, approved as it was made, "Approved
    /// as soon as it was asked for".
    static func decision(_ request: MediaRequest, verb: String) -> String {
        guard let decidedBy = request.decidedBy else {
            return verb == "Approved" ? "Approved as soon as it was asked for" : verb
        }
        return [verb, "by \(decidedBy)", request.decidedAt.map(when)].compactMap(\.self).joined(separator: " ")
    }

    /// The percent while downloading, how far a copy home has got, and
    /// Melete's latest word.
    static func detail(of progress: WantedProgress) -> String? {
        var parts: [String] = []
        if let copied = progress.copied {
            var copy = String(format: "Copying home: %.1f of %.1f GB", Double(copied.bytes) / 1e9, Double(copied.total) / 1e9)
            if let left = copied.secondsLeft {
                copy += ", about \(Duration.seconds(left).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide, maximumUnitCount: 1))) left"
            }
            parts.append(copy)
        } else if progress.step == "downloading", let percent = progress.percent {
            parts.append("\(Int(percent))% downloaded")
        }
        if let message = progress.message, !message.isEmpty {
            parts.append(message)
        }
        return parts.isEmpty ? nil : parts.joined(separator: ". ")
    }

    /// "From a torrent · changed 3 minutes ago".
    static func origin(of progress: WantedProgress) -> String? {
        let source: String? = switch progress.source {
        case "torrent": "From a torrent"
        case "soulseek": "From Soulseek"
        default: nil
        }
        let parts = [source, progress.updatedAt.map { "changed \(when($0))" }].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
