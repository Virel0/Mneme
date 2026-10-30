//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import AetherEngine
import MeleteKit
import SwiftUI

/// What shows over the picture on a press: the title, the seek bar with its
/// times and preview, and Audio and Subtitles.
struct PlayerControls: View {

    let session: PlayerSession
    let previews: TrickplayPreviews?
    let scrubTarget: Double?
    var focus: FocusState<PlayerFocus?>.Binding
    let select: () -> Void
    let move: (MoveCommandDirection) -> Void
    let openPicker: (TrackPicker.Kind) -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.7), location: 0),
                    .init(color: .clear, location: 0.25),
                    .init(color: .clear, location: 0.6),
                    .init(color: .black.opacity(0.85), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                Text(session.target.label)
                    .font(.title3.weight(.semibold))
                    .shadow(radius: 8)

                Spacer()

                SeekBar(session: session, previews: previews, scrubTarget: scrubTarget, select: select, move: move)
                    .focused(focus, equals: .bar)

                HStack(spacing: 18) {
                    HeroActionButton(title: "Audio", systemImage: "speaker.wave.2", isProminent: false) {
                        openPicker(.audio)
                    }
                    .focused(focus, equals: .audio)

                    HeroActionButton(title: "Subtitles", systemImage: "captions.bubble", isProminent: false) {
                        openPicker(.subtitles)
                    }
                    .focused(focus, equals: .subtitles)
                }
                .padding(.top, 28)
            }
            .padding(.horizontal, 90)
            .padding(.vertical, 60)
        }
    }
}

/// The seek bar: where the film is, how much is buffered behind the scrub
/// point, the times, and a preview over the point being scrubbed to.
private struct SeekBar: View {

    @Environment(\.isFocused)
    private var isFocused

    let session: PlayerSession
    let previews: TrickplayPreviews?
    let scrubTarget: Double?
    let select: () -> Void
    let move: (MoveCommandDirection) -> Void

    private var shown: Double {
        scrubTarget ?? session.position
    }

    private func fraction(_ seconds: Double) -> CGFloat {
        guard session.duration > 0 else { return 0 }
        return CGFloat(min(max(seconds / session.duration, 0), 1))
    }

    var body: some View {
        Button(action: select) {
            VStack(spacing: 14) {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule().fill(.white).frame(width: width * fraction(session.position))
                        if let scrubTarget {
                            Capsule()
                                .fill(.white)
                                .frame(width: 4, height: 28)
                                .offset(x: width * fraction(scrubTarget) - 2)
                            preview(at: scrubTarget)
                                .offset(x: min(max(0, width * fraction(scrubTarget) - 160), width - 320), y: -220)
                        }
                    }
                }
                .frame(height: 10)

                HStack {
                    Text(Self.clock(shown))
                    Spacer()
                    if session.isPaused {
                        Image(systemName: "pause.fill")
                    }
                    Spacer()
                    Text("-" + Self.clock(max(0, session.duration - shown)))
                }
                .font(.callout.monospacedDigit())
                .foregroundStyle(.white.opacity(isFocused ? 1 : 0.7))
            }
        }
        .buttonStyle(BareButtonStyle())
        .onMoveCommand(perform: move)
    }

    @ViewBuilder
    private func preview(at seconds: Double) -> some View {
        if let image = previews?.image(at: seconds) {
            Image(decorative: image, scale: 1)
                .resizable()
                .aspectRatio(previews?.aspectRatio ?? 16 / 9, contentMode: .fit)
                .frame(width: 320)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white, lineWidth: 2))
                .shadow(radius: 12)
        }
    }

    /// "1:02:03", "4:05".
    static func clock(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}

/// "Skip Intro", drawn as the focused button it acts as: Select presses it
/// from anywhere while it shows.
struct SkipBadge: View {

    let title: String

    var body: some View {
        Label(title, systemImage: "forward.end.fill")
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 32)
            .padding(.vertical, 18)
            .background(.white, in: Capsule())
            .shadow(color: .black.opacity(0.5), radius: 14, y: 6)
    }
}

/// The next episode, counting down over the credits. Select plays it now;
/// Menu turns it away.
struct NextUpCard: View {

    let next: PlayTarget
    let secondsLeft: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Next Episode in \(secondsLeft)")
                .font(.headline)
            Text(next.label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("Select to play now · Menu to keep watching")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 560, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
