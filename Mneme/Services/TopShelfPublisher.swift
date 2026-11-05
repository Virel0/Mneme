//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import CryptoKit
import Foundation
import MeleteKit
import Nuke
import TVServices
import UIKit

/// Puts the hero's picks on the Apple TV home screen as a full-width
/// carousel: each title's backdrop with its logo, facts and overview drawn
/// on (see `TopShelfCard`), Play to start it and Select to open it, and, where it has a trailer in its folder, a muted
/// preview the system plays while it is highlighted.
@MainActor
enum TopShelfPublisher {

    /// Melete's links last 24 hours; one younger than this is used again
    /// rather than a new one made at every home load.
    private static let previewKeptFor: TimeInterval = 20 * 3600

    /// `trailers` is whether the hero may play trailers: the viewer's choice
    /// in Melete, and this Apple TV's preview clip setting.
    static func publish(_ home: WatchHome, client: MeleteClient, trailers: Bool) async {
        guard let folder = TopShelfSnapshot.imagesFolder else {
            PlaybackDiagnostics.shared.record("topshelf", "no app group container")
            return
        }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            PlaybackDiagnostics.shared.record("topshelf", "cannot make the picture folder: \(error.localizedDescription)")
        }

        let previous = Dictionary(
            (TopShelfSnapshot.load()?.features ?? []).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var features: [TopShelfSnapshot.Feature] = []
        for item in home.hero {
            let summary = TitleSummary(item)
            let id = "\(item.kind.rawValue)-\(item.id)"
            let trailerFile = trailers && item.trailer?.source == .folder ? item.trailer?.fileId : nil
            let preview = await previewLink(for: trailerFile, reusing: previous[id], client: client)
            await features.append(TopShelfSnapshot.Feature(
                id: id,
                title: item.title,
                summary: item.overview,
                genre: item.genres.first,
                duration: item.runtimeMinutes.map { Double($0) * 60 },
                year: item.year,
                imageURL: card(for: item, facts: summary.facts, into: folder, client: client),
                previewURL: preview?.url,
                previewMadeAt: preview?.madeAt,
                previewFile: trailerFile,
                displayURL: DeepLink.title(summary),
                playURL: PlayTarget.known(for: summary).flatMap(DeepLink.play)
            ))
        }

        PlaybackDiagnostics.shared.record(
            "topshelf",
            "\(features.count(where: { $0.imageURL != nil })) of \(features.count) pictures saved, \(features.count(where: { $0.previewURL != nil })) previews"
        )
        TopShelfSnapshot(features: features, updatedAt: .now).save()
        prune(folder, keeping: Set(features.compactMap(\.imageURL?.lastPathComponent)))
        TVTopShelfContentProvider.topShelfContentDidChange()
    }

    /// A stream of the trailer the system player can open: Melete's HLS
    /// copy of it, the video as it is, or a conversion where the video
    /// can't be copied. Melete makes nothing until it is played. The link
    /// from last time is used again while it is young and for the same
    /// trailer.
    private static func previewLink(
        for file: Int?,
        reusing previous: TopShelfSnapshot.Feature?,
        client: MeleteClient
    ) async -> (url: URL, madeAt: Date)? {
        guard let file else { return nil }
        if let previous, previous.previewFile == file, let url = previous.previewURL, let madeAt = previous.previewMadeAt,
           Date.now.timeIntervalSince(madeAt) < previewKeptFor
        {
            return (url, madeAt)
        }
        let copied = try? await client.transcode(file: file, TranscodeRequest(audioChannels: 2, videoCodec: "copy"))
        let stream: TranscodeResponse? = if let copied {
            copied
        } else {
            try? await client.transcode(file: file, TranscodeRequest(maxHeight: 1080, videoCodec: "h264"))
        }
        guard let stream, let url = client.url(for: stream.playlistUrl) else {
            PlaybackDiagnostics.shared.record("topshelf", "no preview for trailer file \(file)")
            return nil
        }
        return (url, .now)
    }

    static func clear() {
        TopShelfSnapshot.remove()
        TVTopShelfContentProvider.topShelfContentDidChange()
    }

    /// The title's picture drawn and saved under a name made from everything
    /// drawn on it, whose paths never change meaning: a picture already saved
    /// is not drawn again.
    private static func card(for item: WatchHomeItem, facts: String, into folder: URL, client: MeleteClient) async -> URL? {
        guard let backdropPath = item.textlessBackdrop ?? item.backdrop else { return nil }
        let drawn = ["\(TopShelfCard.version)", backdropPath, item.logo ?? "", item.title, facts, item.overview ?? ""]
            .joined(separator: "\n")
        let name = SHA256.hash(data: Data(drawn.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined() + ".jpg"
        let file = folder.appending(path: name)
        if FileManager.default.fileExists(atPath: file.path()) {
            return file
        }

        // As wide as the card draws them, at its scale of 2.
        guard let backdrop = await image(ArtworkSlot(path: backdropPath, kind: .backdrop, width: 1920), client: client) else { return nil }
        let logo = await image(ArtworkSlot(path: item.logo, kind: .logo, width: 600), client: client)
        guard let data = TopShelfCard.render(backdrop: backdrop, logo: logo, title: item.title, facts: facts, overview: item.overview),
              (try? data.write(to: file, options: .atomic)) != nil
        else { return nil }
        return file
    }

    private static func image(_ slot: ArtworkSlot, client: MeleteClient) async -> UIImage? {
        guard let request = client.artworkRequest(slot) else { return nil }
        return try? await ImagePipeline.shared.image(for: request)
    }

    private static func prune(_ folder: URL, keeping names: Set<String>) {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for file in files where !names.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
