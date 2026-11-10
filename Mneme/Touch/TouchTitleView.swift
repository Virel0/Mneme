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

/// A title's page on a touch screen: the backdrop with the logo over it,
/// what Play will do, My List and Mark Watched, the overview, a series'
/// episodes, then the rest of what the Apple TV's page has, as rows to
/// swipe along. The same `TitleModel` as the Apple TV's `TitleView`.
///
/// No trailer plays behind the header, as none does behind Home's cards: on
/// a phone it would cost data and sound nobody asked for.
struct TouchTitleView: View {

    @Environment(Library.self)
    private var library
    @Environment(SessionStore.self)
    private var sessions

    @State
    private var model: TitleModel?

    let summary: TitleSummary

    var body: some View {
        // A ZStack, not a Group: an empty Group is no view at all, so before
        // the model existed nothing carried the task that makes it, and the
        // page stayed blank.
        ZStack {
            if let model {
                if let error = model.error {
                    FailureView(title: "Couldn't load \(summary.title)", error: error) {
                        Task { await model.load() }
                    }
                } else {
                    page(model)
                }
            } else {
                LoadingMark()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.mnemePageBackground.ignoresSafeArea())
        .navigationTitle(model?.summary.title ?? summary.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let model = TitleModel(summary: summary, library: library)
            self.model = model
            await model.load()
            // Whether Download shows, once per server.
            if let file = model.target?.fileID, let session = sessions.current {
                await DownloadStore.shared.checkCopiesOn(fileID: file, sessionID: session.id)
            }
        }
    }

    private func page(_ model: TitleModel) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 32) {
                TouchTitleHeader(model: model)

                if model.summary.kind == .series {
                    TouchEpisodeList(model: model)
                }

                TouchTitleMore(model: model)
            }
            .padding(.bottom, 32)
        }
    }
}

/// The backdrop and logo, the facts, the buttons and the overview: stacked
/// on a phone, the backdrop beside the rest on a wide iPad.
private struct TouchTitleHeader: View {

    @Environment(\.horizontalSizeClass)
    private var sizeClass

    let model: TitleModel

    var body: some View {
        if sizeClass == .regular {
            HStack(alignment: .top, spacing: 24) {
                backdrop
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .containerRelativeFrame(.horizontal) { width, _ in width * 0.55 }
                info
            }
            .padding(.horizontal, TouchLayout.edge)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                backdrop
                info
                    .padding(.horizontal, TouchLayout.edge)
            }
        }
    }

    private var backdrop: some View {
        Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                ArtworkImage(FocusedBackdrop.slot(model.summary.backdrop)) {
                    Color(white: 0.12)
                }
            }
            .overlay {
                // Dark where the logo sits, so it reads over any picture; on a
                // phone the picture fades into the page beneath it as well.
                LinearGradient(
                    colors: [.clear, .black.opacity(0.35), sizeClass == .regular ? .black.opacity(0.85) : Color.mnemePageBackground],
                    startPoint: .init(x: 0.5, y: 0.4),
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                TitleLogo(entry: model.summary, maxWidth: 240, maxHeight: 80, fontSize: 28)
                    .padding(TouchLayout.edge)
            }
            .clipped()
            .accessibilityElement()
            .accessibilityLabel(model.summary.title)
            .accessibilityAddTraits(.isHeader)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(TitleHeader(model: model).facts)
                .font(.footnote)
                .foregroundStyle(.secondary)

            TouchTitleButtons(model: model)

            if let overview = model.summary.overview, !overview.isEmpty {
                TouchOverview(text: overview)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Play, saying what it will do, and From the Start beside a Resume, as on
/// the Apple TV; then My List and Mark Watched as smaller buttons under them.
private struct TouchTitleButtons: View {

    @Environment(Library.self)
    private var library
    @Environment(Router.self)
    private var router
    @Environment(SessionStore.self)
    private var sessions

    let model: TitleModel

    private var summary: TitleSummary {
        model.summary
    }

    /// A movie's file, to download, on a server that makes copies.
    private var downloadSubject: DownloadSubject? {
        guard summary.kind == .movie, let movie = model.movie, let file = model.target?.fileID,
              let session = sessions.current, DownloadStore.shared.copiesOn[session.id] == true
        else { return nil }
        return DownloadSubject(
            fileID: file, title: summary.ref, name: movie.title,
            seriesName: nil, season: nil, episode: nil, artwork: movie.poster
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                if let target = model.target {
                    router.play(target)
                }
            } label: {
                Label(model.target?.label ?? "Play", systemImage: "play.fill")
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
            // Grey like the buttons beside it: white read as already chosen.
            .buttonStyle(.bordered)
            .disabled(model.target == nil)

            if let restart = model.restartTarget {
                Button {
                    router.play(restart)
                } label: {
                    Label(restart.label, systemImage: "backward.end.fill")
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 8) {
                let isFavourite = library.isFavourite(summary.ref)
                Button {
                    Task { await library.toggleFavourite(summary.ref) }
                } label: {
                    Label("My List", systemImage: isFavourite ? "checkmark" : "plus")
                }
                .accessibilityLabel(isFavourite ? "Remove from My List" : "Add to My List")

                Button {
                    Task { await model.setTitleWatched(!model.isTitleWatched) }
                } label: {
                    Label(
                        model.isTitleWatched ? "Watched" : (summary.kind == .series ? "Mark All Watched" : "Mark Watched"),
                        systemImage: model.isTitleWatched ? "checkmark.circle.fill" : "checkmark.circle"
                    )
                }
                .accessibilityHint(model.isTitleWatched ? "Marks it unwatched" : "")

                if let downloadSubject {
                    DownloadButton(subject: downloadSubject)
                }
            }
            .buttonStyle(.plain)
            .labelStyle(StackedLabelStyle())
            .padding(.top, 4)
        }
        .controlSize(.large)
    }
}

/// An icon over a short title, for the buttons under Play: two of them fit
/// a phone's width at any text size, where two bordered buttons would not.
private struct StackedLabelStyle: LabelStyle {

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 6) {
            configuration.icon
                .font(.title3)
                .frame(height: 24)
            configuration.title
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(minWidth: 88, minHeight: 44)
        .contentShape(Rectangle())
    }
}

/// The overview, three lines of it until More is tapped; More shows only
/// when there is more to show.
private struct TouchOverview: View {

    let text: String

    @State
    private var isExpanded = false
    @State
    private var fullHeight: CGFloat = 0
    @State
    private var shownHeight: CGFloat = 0

    private var isCut: Bool {
        fullHeight > shownHeight + 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text)
                .font(.subheadline)
                .lineLimit(isExpanded ? nil : 3)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { shownHeight = $0 }
                // The whole text laid out unseen at the same width, to know
                // whether three lines cut it short at this text size.
                .background(alignment: .topLeading) {
                    Text(text)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fullHeight = $0 }
                }

            if isCut || isExpanded {
                Button(isExpanded ? "Less" : "More") {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                }
                .font(.subheadline.bold())
                .frame(minHeight: 44)
                .accessibilityHint(isExpanded ? "Shows less of the overview" : "Shows all of the overview")
            }
        }
    }
}
#endif
