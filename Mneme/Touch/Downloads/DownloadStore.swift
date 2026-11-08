//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

#if os(iOS)
import Foundation
import MeleteKit
import Nuke
import Observation

/// The films and episodes kept on this device, and their way here.
///
/// Melete makes a copy of a file to fit a phone, in the background and
/// behind anyone watching, so a download first waits for the server, then
/// comes over a background session that carries on with the app closed.
/// Once the whole copy is here the server's is deleted, so it takes no room
/// there. Each one lives in a folder of its own: the video, its subtitles
/// as WebVTT, its seek-bar previews and its picture, left out of backups.
@MainActor
@Observable
final class DownloadStore {

    static let shared = DownloadStore()

    private(set) var downloads: [Download] = []

    /// Whether the server signed in to makes copies, once asked.
    private(set) var copiesOn: [String: Bool] = [:]

    @ObservationIgnored
    private var clients: [String: MeleteClient] = [:]
    @ObservationIgnored
    private var watching: Task<Void, Never>?
    @ObservationIgnored
    private let transfer = DownloadTransfer()

    /// How often a copy being made is looked at.
    private static let pollInterval: Duration = .seconds(15)

    private init() {
        // The transfer's session, opened here, reattaches to downloads
        // running from before and hears those that ended while the app was
        // gone.
        downloads = Self.loadIndex()
    }

    // MARK: - Asking

    func downloads(for sessionID: String) -> [Download] {
        downloads.filter { $0.sessionID == sessionID }
    }

    func download(of fileID: Int, in sessionID: String) -> Download? {
        downloads.first { $0.fileID == fileID && $0.sessionID == sessionID }
    }

    func download(_ id: UUID) -> Download? {
        downloads.first { $0.id == id }
    }

    /// The episode to play after this one from the device: the next one
    /// downloaded of the same series, in order. Specials play on into
    /// nothing, as they do streamed.
    func episode(after download: Download) -> Download? {
        guard download.title.kind == .series, let season = download.season, season > 0, let episode = download.episode
        else { return nil }
        let place = { (other: Download) in (other.season ?? 0, other.episode ?? 0) }
        return downloads
            .filter { $0.sessionID == download.sessionID && $0.title == download.title && $0.isReady }
            .filter { ($0.season ?? 0) > 0 && place($0) > (season, episode) }
            .min { place($0) < place($1) }
    }

    /// The session's client, for the server calls a download makes; also
    /// sends what waited for it: progress made offline, and server copies
    /// to delete.
    func attach(_ client: MeleteClient, sessionID: String) {
        clients[sessionID] = client
        Task { await catchUp(sessionID) }
        watchPreparing()
    }

    /// Whether the session's server makes copies, from any file on it: the
    /// setting is the server's, not the file's.
    func checkCopiesOn(fileID: Int, sessionID: String) async {
        guard copiesOn[sessionID] == nil, let client = clients[sessionID] else { return }
        if let choices = try? await client.offlineChoices(file: fileID) {
            copiesOn[sessionID] = choices.on
        }
    }

    func choices(for fileID: Int, sessionID: String) async throws(MeleteError) -> OfflineChoices {
        guard let client = clients[sessionID] else { throw .transport("Not signed in.") }
        return try await client.offlineChoices(file: fileID)
    }

    /// Asks the server for a copy at this height, with the file's text
    /// subtitles beside it.
    func ask(for subject: DownloadSubject, maxHeight: Int, sessionID: String) async throws(MeleteError) {
        guard download(of: subject.fileID, in: sessionID) == nil else { return }
        guard let client = clients[sessionID] else { throw .transport("Not signed in.") }
        // The parts to skip, kept for playing without the server.
        async let info = try? client.fileInfo(subject.fileID)
        // Only text tracks come as WebVTT; a picture track can't be kept.
        let listed = await (try? client.subtitles(file: subject.fileID)) ?? []
        let kept = Array(listed.filter { $0.text && ($0.track.hasPrefix("s") || $0.track.hasPrefix("x")) }
            .prefix(OfflineRequest.subtitleLimit))
        let copy = try await client.askOfflineCopy(
            file: subject.fileID,
            // HEVC: HDR kept, and a sharper picture than H.264 at the same
            // size. The sound keeps up to its own 7.1 rather than stereo,
            // for headphones with spatial audio and AirPlay to a receiver.
            OfflineRequest(maxHeight: maxHeight, videoCodec: "hevc", audioChannels: 8, subtitles: kept.map(\.track))
        )
        let segments = await info?.segments
        let download = Download(
            id: UUID(),
            sessionID: sessionID,
            copyID: copy.id,
            fileID: subject.fileID,
            title: subject.title,
            name: subject.name,
            seriesName: subject.seriesName,
            season: subject.season,
            episode: subject.episode,
            artwork: subject.artwork,
            maxHeight: maxHeight,
            addedAt: .now,
            subtitles: kept.filter { copy.subtitles.contains($0.track) },
            segments: segments,
            phase: .preparing(copy.progress),
            estimatedBytes: copy.estimatedBytes
        )
        downloads.insert(download, at: 0)
        save()
        Task { await saveArtwork(of: download, client: client) }
        watchPreparing()
    }

    /// Removes it from the device, stops it coming, and deletes the server's
    /// copy if there still is one.
    func remove(_ id: UUID) {
        guard let download = download(id) else { return }
        transfer.cancel(id)
        downloads.removeAll { $0.id == id }
        save()
        try? FileManager.default.removeItem(at: Self.folder(of: id))
        if download.serverCopyKept, let client = clients[download.sessionID] {
            Task { try? await client.deleteOfflineCopy(download.copyID) }
        }
    }

    /// Tries again after a failure, from the server's copy: a new link, and
    /// the download from the start.
    func retry(_ id: UUID) {
        guard let download = download(id), case .failed = download.phase else { return }
        update(id) { $0.phase = .preparing(0) }
        watchPreparing()
    }

    // MARK: - Where things are

    func videoURL(of download: Download) -> URL? {
        let url = Self.folder(of: download.id).appending(path: "video.mp4")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func subtitleURL(of download: Download, track: String) -> URL? {
        let url = Self.folder(of: download.id).appending(path: "\(track).vtt")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func artworkURL(of download: Download) -> URL? {
        let url = Self.folder(of: download.id).appending(path: "artwork.jpg")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Where a download's preview sheets are: `0.jpg`, `1.jpg`…
    nonisolated static func previewsFolder(of id: UUID) -> URL {
        folder(of: id).appending(path: "trickplay", directoryHint: .isDirectory)
    }

    nonisolated static var root: URL {
        URL.applicationSupportDirectory.appending(path: "Downloads", directoryHint: .isDirectory)
    }

    nonisolated static func folder(of id: UUID) -> URL {
        root.appending(path: id.uuidString, directoryHint: .isDirectory)
    }

    // MARK: - Watching

    /// Where the viewer is in a download, kept here and sent to the server
    /// when it can be.
    func record(position: Double, duration: Double?, of id: UUID) {
        update(id) {
            $0.position = position
            $0.duration = duration ?? $0.duration
            $0.positionUnsent = true
        }
        guard let download = download(id) else { return }
        Task { await sendPosition(of: download) }
    }

    private func sendPosition(of download: Download) async {
        guard download.positionUnsent, let client = clients[download.sessionID] else { return }
        let report = ProgressReport(positionSeconds: download.position, durationSeconds: download.duration, restart: false)
        guard await (try? client.reportProgress(file: download.fileID, report)) != nil else { return }
        // Only if nothing newer came while it was on its way.
        if self.download(download.id)?.position == download.position {
            update(download.id) { $0.positionUnsent = false }
        }
    }

    // MARK: - The server's side

    /// What waited for the session's client.
    private func catchUp(_ sessionID: String) async {
        for download in downloads(for: sessionID) {
            await sendPosition(of: download)
            if download.isReady, download.serverCopyKept {
                await deleteServerCopy(of: download.id)
            }
        }
    }

    /// Looks at copies being made, while there are any, and starts each
    /// download once its copy is ready.
    private func watchPreparing() {
        guard watching == nil else { return }
        watching = Task { [weak self] in
            while let self, !Task.isCancelled {
                let preparing = self.downloads.filter {
                    if case .preparing = $0.phase {
                        self.clients[$0.sessionID] != nil
                    } else {
                        false
                    }
                }
                if preparing.isEmpty {
                    break
                }
                for download in preparing {
                    await self.follow(download)
                }
                try? await Task.sleep(for: Self.pollInterval)
            }
            self?.watching = nil
        }
    }

    private func follow(_ download: Download) async {
        guard let client = clients[download.sessionID] else { return }
        let copy: OfflineCopy
        do {
            copy = try await client.offlineCopy(download.copyID)
        } catch {
            if case .notFound = error {
                update(download.id) {
                    $0.phase = .failed("The server no longer has this copy. Remove it and download it again.")
                    $0.serverCopyKept = false
                }
            }
            // Anything else is asked again next time round.
            return
        }
        switch copy.status {
        case .queued, .making:
            update(download.id) {
                $0.phase = .preparing(copy.progress)
                $0.estimatedBytes = copy.estimatedBytes
            }
        case .failed:
            update(download.id) { $0.phase = .failed(copy.error ?? "The server couldn't make the copy.") }
        case .ready:
            update(download.id) { $0.bytes = copy.bytes }
            await startTransfer(of: download, client: client)
        }
    }

    private func startTransfer(of download: Download, client: MeleteClient) async {
        do {
            let link = try await client.offlineLink(download.copyID)
            guard let video = client.url(for: link.downloadUrl) else {
                update(download.id) { $0.phase = .failed("The server gave an address the app can't open.") }
                return
            }
            try FileManager.default.createDirectory(at: Self.folder(of: download.id), withIntermediateDirectories: true)
            Self.excludeFromBackup()
            // The subtitles are small: they come now, beside the video.
            for subtitle in link.subtitles {
                guard let url = client.url(for: subtitle.url),
                      let (data, _) = try? await URLSession.shared.data(from: url)
                else { continue }
                try? data.write(to: Self.folder(of: download.id).appending(path: "\(subtitle.track).vtt"))
            }
            let previews = await savePreviews(link.trickplay, of: download.id, client: client)
            update(download.id) {
                $0.trickplay = previews
                $0.phase = .downloading(0)
            }
            transfer.start(download.id, from: video)
        } catch {
            update(download.id) { $0.phase = .failed(error.localizedDescription) }
        }
    }

    /// The seek bar's previews, a few small sheets, kept beside the video.
    /// All of them or none: a missing sheet would leave part of the bar
    /// blank.
    private func savePreviews(_ previews: OfflineLink.Previews?, of id: UUID, client: MeleteClient) async -> Trickplay? {
        guard let previews, previews.sheetUrls.count == previews.index.sheets else { return nil }
        let folder = Self.previewsFolder(of: id)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (sheet, address) in previews.sheetUrls.enumerated() {
            guard let url = client.url(for: address),
                  let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  (try? data.write(to: folder.appending(path: "\(sheet).jpg"))) != nil
            else {
                try? FileManager.default.removeItem(at: folder)
                return nil
            }
        }
        return previews.index
    }

    private func deleteServerCopy(of id: UUID) async {
        guard let download = download(id), download.serverCopyKept, let client = clients[download.sessionID] else { return }
        do {
            try await client.deleteOfflineCopy(download.copyID)
            update(id) { $0.serverCopyKept = false }
        } catch {
            if case .notFound = error {
                update(id) { $0.serverCopyKept = false }
            }
        }
    }

    private func saveArtwork(of download: Download, client: MeleteClient) async {
        let kind: ArtworkKind = download.title.kind == .series && download.episode != nil ? .still : .poster
        guard let request = client.artworkRequest(ArtworkSlot(path: download.artwork, kind: kind, width: 200)),
              let image = try? await ImagePipeline.shared.image(for: request),
              let data = image.jpegData(compressionQuality: 0.85)
        else { return }
        try? FileManager.default.createDirectory(at: Self.folder(of: download.id), withIntermediateDirectories: true)
        try? data.write(to: Self.folder(of: download.id).appending(path: "artwork.jpg"))
        // Seen again, now that there is a picture on the device.
        update(download.id) { _ in }
    }

    // MARK: - The transfer's news

    func transferProgressed(_ id: UUID, fraction: Double) {
        guard let download = download(id), case .downloading = download.phase else { return }
        // A hundred steps is all a ring can show.
        let rounded = (fraction * 100).rounded() / 100
        if download.phase != .downloading(rounded) {
            update(id, saving: false) { $0.phase = .downloading(rounded) }
        }
    }

    func transferFinished(_ id: UUID, bytes: Int) {
        // Removed while its last bytes came: the file it left goes too.
        guard download(id) != nil else {
            try? FileManager.default.removeItem(at: Self.folder(of: id))
            return
        }
        update(id) {
            $0.phase = .ready
            $0.bytes = bytes
        }
        Task { await deleteServerCopy(of: id) }
    }

    func transferFailed(_ id: UUID, message: String) {
        update(id) { $0.phase = .failed(message) }
    }

    // MARK: - Keeping the list

    private func update(_ id: UUID, saving: Bool = true, _ change: (inout Download) -> Void) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        change(&downloads[index])
        if saving {
            save()
        }
    }

    private static var index: URL {
        root.appending(path: "downloads.json")
    }

    private static func loadIndex() -> [Download] {
        guard let data = try? Data(contentsOf: index) else { return [] }
        return (try? JSONDecoder().decode([Download].self, from: data)) ?? []
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: Self.root, withIntermediateDirectories: true)
            Self.excludeFromBackup()
            try JSONEncoder().encode(downloads).write(to: Self.index, options: .atomic)
        } catch {
            PlaybackDiagnostics.shared.record("downloads.save", error.localizedDescription)
        }
    }

    /// Films are large, and can be downloaded again: they stay out of the
    /// device's backups.
    private static func excludeFromBackup() {
        var root = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? root.setResourceValues(values)
    }
}
#endif
