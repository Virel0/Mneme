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

/// One of the viewer's requests on a touch screen: what was asked for, who
/// decided, and how it is getting on, step by step and season by season. The
/// touch counterpart of `RequestDetailView`, with the same words and actions:
/// it follows the live list, and a request still waiting can be taken back,
/// or a series' season changed.
struct TouchRequestDetailView: View {

    @Environment(\.dismiss)
    private var dismiss
    @Environment(Library.self)
    private var library
    @Environment(\.horizontalSizeClass)
    private var sizeClass

    let request: MediaRequest
    /// Search's model, told of changes made here; nil elsewhere.
    let model: SearchModel?

    @State
    private var isWorking = false
    @State
    private var error: String?
    @State
    private var confirmsTakeBack = false

    /// The request as the live list has it now.
    private var current: MediaRequest {
        library.requests?.first { $0.id == request.id }
            ?? model?.requests.first { $0.id == request.id }
            ?? request
    }

    private var posterWidth: CGFloat {
        sizeClass == .regular ? 180 : 120
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20) {
                header

                state

                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
            .padding(TouchLayout.edge)
            // A line of reading length on a wide iPad.
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.mnemePageBackground.ignoresSafeArea())
        .navigationTitle(current.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            TouchPosterImage(poster: current.poster, title: current.title)
                .frame(width: posterWidth, height: posterWidth * 3 / 2)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(current.title)
                    .font(.title2.bold())
                Text(RequestDetailView.whatWasAsked(current))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - State

    @ViewBuilder
    private var state: some View {
        switch current.state {
        case "requested":
            waiting
        case "declined":
            VStack(alignment: .leading, spacing: 6) {
                Text("Declined")
                    .font(.headline)
                Text(RequestDetailView.decision(current, verb: "Declined"))
                    .foregroundStyle(.secondary)
                if let reason = current.reason, !reason.isEmpty {
                    Text(reason)
                        .padding(.top, 6)
                }
            }
        default:
            approved
        }
    }

    private var waiting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Waiting for approval")
                .font(.headline)
            Text("Asked for \(RequestDetailView.when(current.createdAt))")
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                if current.kind == "series" {
                    // A menu rather than the Apple TV's dialog: twenty-odd
                    // choices read better as a list that scrolls.
                    Menu {
                        SeasonChoices { season in change(to: season) }
                    } label: {
                        Label("Change Season", systemImage: "list.number")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Button(role: .destructive) {
                    confirmsTakeBack = true
                } label: {
                    Label("Take Back", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                // On the button, so an iPad points its popover at it.
                .confirmationDialog("Take back this request?", isPresented: $confirmsTakeBack, titleVisibility: .visible) {
                    Button("Take Back", role: .destructive, action: takeBack)
                }
            }
            .controlSize(.large)
            .disabled(isWorking)
            .padding(.top, 14)
        }
    }

    @ViewBuilder
    private var approved: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(RequestDetailView.decision(current, verb: "Approved"))
                .foregroundStyle(.secondary)
            if current.progress == nil {
                Text("Melete isn't reporting how it's getting on.")
                    .foregroundStyle(.secondary)
            }
        }

        if let progress = current.progress {
            TouchStepTrack(step: progress.step)

            if let fraction = TouchRequestRow.fraction(of: current) {
                ProgressView(value: fraction)
                    .tint(Color.mnemeCyan)
                    .accessibilityHidden(true)
            }
            if let detail = RequestDetailView.detail(of: progress) {
                Text(detail)
            }
            if let origin = RequestDetailView.origin(of: progress) {
                Text(origin)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }

        if let seasons = current.seasons, !seasons.isEmpty {
            TouchSeasonGrid(seasons: seasons)
                .padding(.top, 8)
        }
    }

    // MARK: - Actions

    private func takeBack() {
        isWorking = true
        error = nil
        Task {
            if let failure = await RequestDetailView.takeBack(current.id, library: library, model: model) {
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
            error = await RequestDetailView.change(current.id, to: season, library: library, model: model)
            isWorking = false
        }
    }
}

/// The steps from asked-for to watchable, down the page: a phone is too
/// narrow for the Apple TV's track across it.
private struct TouchStepTrack: View {

    let step: String

    var body: some View {
        if step == "failed" {
            Label("It couldn't be found or fetched", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        } else {
            let steps = StepTrack.steps
            let reached = steps.firstIndex { $0.key == step } ?? 0
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 10) {
                        Image(systemName: index < reached ? "checkmark.circle.fill" : index == reached ? "circle.inset.filled" : "circle")
                            .foregroundStyle(index <= reached ? Color.mnemeCyan : .secondary)
                        Text(item.name)
                            .font(index == reached ? .body.bold() : .body)
                            .foregroundStyle(index == reached ? Color.mnemeCyan : index < reached ? .primary : .secondary)
                    }
                }
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(reached + 1) of \(steps.count): \(steps[reached].name)")
        }
    }
}

/// An approved series, season by season, as many to a row as fit.
private struct TouchSeasonGrid: View {

    let seasons: [RequestSeason]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 200), spacing: 16, alignment: .leading)],
            alignment: .leading,
            spacing: 14
        ) {
            ForEach(seasons, id: \.season) { season in
                VStack(alignment: .leading, spacing: 2) {
                    Text(season.season == 0 ? "Specials" : "Season \(season.season)")
                        .font(.subheadline.bold())
                    Text(SeasonGrid.line(season))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .opacity(season.monitored ? 1 : 0.5)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
#endif
