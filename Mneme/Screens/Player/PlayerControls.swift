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

                SeekBar(session: session, previews: previews, scrubTarget: scrubTarget, select: select)
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

    private var shown: Double {
        scrubTarget ?? session.shownPosition
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
                        Capsule().fill(.white).frame(width: width * fraction(session.shownPosition))
                        if let scrubTarget {
                            Capsule()
                                .fill(.white)
                                .frame(width: 4, height: 28)
                                .offset(x: width * fraction(scrubTarget) - 2)
                            preview(at: scrubTarget)
                                .offset(
                                    x: min(max(0, width * fraction(scrubTarget) - Self.previewWidth / 2), width - Self.previewWidth),
                                    y: -(Self.previewWidth / (previews?.aspectRatio ?? 16 / 9)) - 40
                                )
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
    }

    @ViewBuilder
    private func preview(at seconds: Double) -> some View {
        if let image = previews?.image(at: seconds) {
            Image(decorative: image, scale: 1)
                .resizable()
                .interpolation(.high)
                // A fixed size, not one that fits the space offered: the
                // preview is drawn inside the seek bar, which is ten points
                // tall, and fitted there a picture came out ten points high.
                .frame(width: Self.previewWidth, height: Self.previewWidth / (previews?.aspectRatio ?? 16 / 9))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.6), radius: 20, y: 8)
        }
    }

    /// Melete's previews are 320 pixels wide; drawn larger, they are still
    /// clear enough to find a scene by.
    static let previewWidth: CGFloat = 560

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

/// "Skip Intro". Takes focus when it appears, so Select presses it.
struct SkipButton: View {

    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "forward.end.fill")
                .font(.system(size: 26, weight: .semibold))
                .padding(.horizontal, 32)
                .padding(.vertical, 18)
        }
        .buttonStyle(OfferButtonStyle())
    }
}

/// The next episode, counting down over the credits. Takes focus when it
/// appears: Select plays it now, Menu turns it away.
struct NextUpButton: View {

    let next: PlayTarget
    let secondsLeft: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: "play.fill")
                    .font(.system(size: 30, weight: .bold))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Next Episode in \(secondsLeft)")
                        .font(.headline)
                    Text(next.label)
                        .font(.callout)
                        .opacity(0.75)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 22)
            .frame(width: 580, alignment: .leading)
        }
        .buttonStyle(OfferButtonStyle())
    }
}

/// White when focused, as every focused button in the player is; a dark
/// plate otherwise, so the offer is still readable over the picture.
private struct OfferButtonStyle: ButtonStyle {

    @Environment(\.isFocused)
    private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isFocused ? .black : .white)
            .background(
                isFocused ? Color.white : Color.black.opacity(0.7),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.04 : 1))
            .shadow(color: .black.opacity(0.5), radius: 14, y: 6)
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}
