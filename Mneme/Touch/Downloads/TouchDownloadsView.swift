//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

#if os(iOS)
import MeleteKit
import SwiftUI

/// The Downloads tab: what is on the device and what is on its way, films
/// first, then each series with its episodes in order. A ready one plays
/// from the device, with or without a connection; a swipe removes it.
struct TouchDownloadsView: View {

    @Environment(SessionStore.self)
    private var sessions
    @Environment(Router.self)
    private var router

    private var downloads: [Download] {
        sessions.current.map { DownloadStore.shared.downloads(for: $0.id) } ?? []
    }

    private var movies: [Download] {
        downloads.filter { $0.title.kind == .movie }.sorted { $0.name < $1.name }
    }

    /// Each series' episodes, the series in name order.
    private var series: [(name: String, episodes: [Download])] {
        let episodes = downloads.filter { $0.title.kind == .series }
        return Dictionary(grouping: episodes) { $0.title.id }
            .values
            .map { group in
                (
                    name: group.first?.seriesName ?? "",
                    episodes: group.sorted { ($0.season ?? 0, $0.episode ?? 0) < ($1.season ?? 0, $1.episode ?? 0) }
                )
            }
            .sorted { $0.name < $1.name }
    }

    private var onDevice: Int64 {
        Int64(downloads.filter(\.isReady).compactMap(\.bytes).reduce(0, +))
    }

    var body: some View {
        List {
            if !movies.isEmpty {
                Section("Movies") {
                    ForEach(movies) { row($0) }
                }
            }
            ForEach(series, id: \.name) { group in
                Section(group.name) {
                    ForEach(group.episodes) { row($0) }
                }
            }
            if onDevice > 0 {
                Section {} footer: {
                    Text("\(onDevice.formatted(.byteCount(style: .file))) on this device")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.mnemePageBackground.ignoresSafeArea())
        .navigationTitle("Downloads")
        .overlay {
            if downloads.isEmpty {
                ContentUnavailableView(
                    "No Downloads",
                    systemImage: "arrow.down.circle",
                    description: Text("Download a film or an episode from its page to watch it without a connection.")
                )
            }
        }
    }

    private func row(_ download: Download) -> some View {
        Button {
            guard download.isReady else { return }
            router.play(download.playTarget)
        } label: {
            DownloadRow(download: download)
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button(download.isReady ? "Remove" : "Stop", systemImage: "trash", role: .destructive) {
                DownloadStore.shared.remove(download.id)
            }
            // The app's white tint would make it a blank white button.
            .tint(.red)
            if case .failed = download.phase {
                Button("Try Again", systemImage: "arrow.clockwise") {
                    DownloadStore.shared.retry(download.id)
                }
                .tint(.blue)
            }
        }
        .contextMenu {
            DownloadActions(download: download)
        }
        .accessibilityHint(download.isReady ? "Plays from this device" : "")
    }
}

/// A download's picture, name, and where it is: its size once here, how
/// far along before, or why it failed.
private struct DownloadRow: View {

    let download: Download

    private var status: String {
        switch download.phase {
        case let .preparing(fraction):
            fraction > 0 ? "Preparing on the server · \(Int((fraction * 100).rounded()))%" : "Waiting for the server"
        case let .downloading(fraction):
            "Downloading · \(Int((fraction * 100).rounded()))% of \(size)"
        case .ready:
            [size, watchedLine].compactMap(\.self).joined(separator: " · ")
        case let .failed(message):
            message
        }
    }

    private var size: String {
        Int64(download.bytes ?? download.estimatedBytes).formatted(.byteCount(style: .file))
    }

    private var watchedLine: String? {
        guard download.position > 0, let duration = download.duration, duration > 0 else { return nil }
        return Format.timeLeft(position: download.position, duration: duration, watched: download.position / duration >= 0.9)
    }

    var body: some View {
        HStack(spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 4) {
                Text(download.label)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(download.phase.isFailed ? .orange : .secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if download.isReady {
                Image(systemName: "play.circle")
                    .font(.title2)
                    .accessibilityHidden(true)
            } else {
                DownloadIcon(download: download)
                    .font(.title3)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// From the device, so it shows offline too.
    private var artwork: some View {
        let isStill = download.title.kind == .series
        let width: CGFloat = isStill ? 112 : 56
        return Group {
            if let url = DownloadStore.shared.artworkURL(of: download), let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(white: 0.12)
                    Image(systemName: "film")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: width, height: isStill ? width * 9 / 16 : width * 3 / 2)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private extension Download.Phase {

    var isFailed: Bool {
        if case .failed = self {
            true
        } else {
            false
        }
    }
}
#endif
