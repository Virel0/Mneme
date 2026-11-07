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

/// Download for a film or an episode, and then how it is coming: a ring
/// while the server makes the copy and while it comes over, a filled arrow
/// once it is here. Pressed again, it offers to stop or remove it.
struct DownloadButton: View {

    enum Look {
        /// An icon over a short title, beside My List.
        case stacked
        /// The icon alone, at the end of an episode's row.
        case icon
    }

    @Environment(SessionStore.self)
    private var sessions

    let subject: DownloadSubject
    var look: Look = .stacked

    @State
    private var asking: DownloadAsk?
    @State
    private var managing = false

    private var store: DownloadStore {
        .shared
    }

    private var download: Download? {
        sessions.current.flatMap { store.download(of: subject.fileID, in: $0.id) }
    }

    var body: some View {
        Button {
            if download == nil {
                asking = DownloadAsk(subjects: [subject])
            } else {
                managing = true
            }
        } label: {
            switch look {
            case .stacked:
                Label { Text(title) } icon: { DownloadIcon(download: download) }
            case .icon:
                DownloadIcon(download: download)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .accessibilityLabel(look == .icon ? "\(title), \(subject.name)" : title)
        .downloadSizes($asking)
        .confirmationDialog(subject.name, isPresented: $managing, titleVisibility: .visible) {
            if let download {
                DownloadActions(download: download)
            }
        }
    }

    private var title: String {
        switch download?.phase {
        case nil: "Download"
        case .preparing: "Preparing"
        case .downloading: "Downloading"
        case .ready: "Downloaded"
        case .failed: "Download Failed"
        }
    }
}

/// What can be done to a download from its button or its row.
struct DownloadActions: View {

    let download: Download

    var body: some View {
        if case .failed = download.phase {
            Button("Try Again") {
                DownloadStore.shared.retry(download.id)
            }
        }
        Button(download.isReady ? "Remove Download" : "Stop Download", role: .destructive) {
            DownloadStore.shared.remove(download.id)
        }
    }
}

/// The arrow, a ring as it comes, or a mark that it failed.
struct DownloadIcon: View {

    let download: Download?

    var body: some View {
        switch download?.phase {
        case nil:
            Image(systemName: "arrow.down.circle")
        case let .preparing(fraction), let .downloading(fraction):
            DownloadRing(fraction: fraction, isPreparing: download?.phase == .preparing(fraction))
        case .ready:
            Image(systemName: "arrow.down.circle.fill")
        case .failed:
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.orange)
        }
    }
}

/// How far a download has come. While the server is still making the copy
/// the ring is dashed: nothing is coming to the device yet.
struct DownloadRing: View {

    let fraction: Double
    let isPreparing: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 2.5, dash: isPreparing ? [3, 3] : []))
            Circle()
                .trim(from: 0, to: max(0.03, fraction))
                .stroke(.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 20, height: 20)
        .animation(.easeOut(duration: 0.2), value: fraction)
        .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
    }
}

// MARK: - Choosing a size

/// Films or episodes about to be asked for, and once known, the sizes the
/// server could make them at.
struct DownloadAsk: Identifiable {
    let id = UUID()
    let subjects: [DownloadSubject]
    var choices: [OfflineChoices.Choice] = []
}

private struct DownloadSizes: ViewModifier {

    @Environment(SessionStore.self)
    private var sessions

    @Binding
    var asking: DownloadAsk?

    @State
    private var showsSizes = false
    @State
    private var failure: String?

    func body(content: Content) -> some View {
        content
            .task(id: asking?.id) {
                await loadChoices()
            }
            .confirmationDialog(dialogTitle, isPresented: $showsSizes, titleVisibility: .visible) {
                if let asking {
                    ForEach(asking.choices, id: \.maxHeight) { choice in
                        Button(label(for: choice, count: asking.subjects.count)) {
                            Task { await ask(asking.subjects, maxHeight: choice.maxHeight) }
                        }
                    }
                }
            } message: {
                Text(
                    "The server makes a copy to fit this device first, which can take a while. It is deleted from the server once it is here."
                )
            }
            .onChange(of: showsSizes) { _, showing in
                if !showing {
                    asking = nil
                }
            }
            .alert("Couldn't Download", isPresented: Binding(get: { failure != nil }, set: {
                if !$0 {
                    failure = nil
                }
            })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
    }

    private var dialogTitle: String {
        let count = asking?.subjects.count ?? 1
        return count > 1 ? "Download \(count) Episodes" : "Download"
    }

    /// "720p · 2.1 GB", or for a season "720p · about 21 GB" from the first
    /// episode's size.
    private func label(for choice: OfflineChoices.Choice, count: Int) -> String {
        let size = Int64(choice.estimatedBytes * count).formatted(.byteCount(style: .file))
        return "\(choice.maxHeight)p · " + (count > 1 ? "about \(size)" : size)
    }

    private func loadChoices() async {
        guard let asking, asking.choices.isEmpty, let first = asking.subjects.first, let session = sessions.current else { return }
        do {
            let choices = try await DownloadStore.shared.choices(for: first.fileID, sessionID: session.id)
            guard choices.on else {
                failure = "Downloads are turned off on this server."
                self.asking = nil
                return
            }
            self.asking?.choices = choices.choices
            showsSizes = true
        } catch {
            failure = error.localizedDescription
            self.asking = nil
        }
    }

    private func ask(_ subjects: [DownloadSubject], maxHeight: Int) async {
        guard let session = sessions.current else { return }
        for subject in subjects {
            do {
                try await DownloadStore.shared.ask(for: subject, maxHeight: maxHeight, sessionID: session.id)
            } catch {
                // The server's limit, most likely: the rest would be refused too.
                failure = error.localizedDescription
                return
            }
        }
    }
}

extension View {

    /// Asks the server for the sizes it could make a download at, offers
    /// them, then asks for the copies.
    func downloadSizes(_ asking: Binding<DownloadAsk?>) -> some View {
        modifier(DownloadSizes(asking: asking))
    }
}
#endif
