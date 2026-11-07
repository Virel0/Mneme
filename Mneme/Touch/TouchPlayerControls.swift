//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

#if os(iOS)
import AetherEngine
import MeleteKit
import SwiftUI

/// What shows over the picture on a tap: Close and the title along the top,
/// back, play and forward in the middle, and the bar with Audio, Subtitles
/// and Speed along the bottom.
struct TouchPlayerControls: View {

    let session: PlayerSession
    let previews: TrickplayPreviews?
    @Binding
    var scrubTarget: Double?
    let pictureInPicture: PictureInPicture
    let jump: (_ forward: Bool) -> Void
    /// Any touch on the controls, which keeps them up.
    let touched: () -> Void
    let close: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.7), location: 0),
                    .init(color: .clear, location: 0.3),
                    .init(color: .clear, location: 0.6),
                    .init(color: .black.opacity(0.8), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomBar
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            middle
        }
        .foregroundStyle(.white)
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button("Close", systemImage: "xmark", action: close)
                .labelStyle(.iconOnly)
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())

            Text(session.target.label)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            if pictureInPicture.isPossible {
                Button("Picture in Picture", systemImage: pictureInPicture.isActive ? "pip.exit" : "pip.enter") {
                    touched()
                    pictureInPicture.toggle()
                }
                .labelStyle(.iconOnly)
                .font(.title3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }

            AirPlayButton()
                .frame(width: 44, height: 44)
                .accessibilityLabel("AirPlay")
        }
    }

    private var middle: some View {
        HStack(spacing: 56) {
            Button {
                jump(false)
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 30, weight: .semibold))
                    .frame(width: 56, height: 56)
            }
            .accessibilityLabel("Back 10 seconds")

            Button {
                touched()
                session.togglePause()
            } label: {
                Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .frame(width: 72, height: 72)
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(session.isPaused ? "Play" : "Pause")

            Button {
                jump(true)
            } label: {
                Image(systemName: "goforward.10")
                    .font(.system(size: 30, weight: .semibold))
                    .frame(width: 56, height: 56)
            }
            .accessibilityLabel("Forward 10 seconds")
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if let engine = session.engine {
                AirPlaySoundOnlyNotice(engine: engine)
            }

            TouchSeekBar(session: session, previews: previews, scrubTarget: $scrubTarget, touched: touched)

            HStack(spacing: 8) {
                Spacer()
                menus
            }
        }
    }

    @ViewBuilder
    private var menus: some View {
        Menu {
            Picker("Audio", selection: Binding(
                get: { session.activeAudio },
                set: { id in
                    if let track = session.audioTracks.first(where: { $0.id == id }) {
                        session.selectAudio(track)
                    }
                }
            )) {
                ForEach(session.audioTracks, id: \.id) { track in
                    Text(TrackPicker.title(of: track)).tag(Optional(track.id))
                }
            }
        } label: {
            Label("Audio", systemImage: "speaker.wave.2")
        }

        Menu {
            Picker("Subtitles", selection: Binding(
                get: { session.subtitleTrack },
                set: { track in
                    session.selectSubtitle(session.subtitles.first { $0.track == track })
                }
            )) {
                Text("Off").tag(String?.none)
                // Picture tracks beside the video cannot be fetched as text.
                ForEach(session.subtitles.filter { $0.text || $0.embeddedIndex != nil }) { track in
                    Text(TrackPicker.title(of: track)).tag(Optional(track.track))
                }
            }
        } label: {
            Label("Subtitles", systemImage: "captions.bubble")
        }

        Menu {
            Picker("Speed", selection: Binding(
                get: { session.rate },
                set: { session.setRate($0) }
            )) {
                ForEach(TrackPicker.speeds, id: \.self) { rate in
                    Text(TrackPicker.speedTitle(rate)).tag(rate)
                }
            }
        } label: {
            Label(session.rate == 1 ? "Speed" : TrackPicker.speedTitle(session.rate), systemImage: "gauge.with.dots.needle.67percent")
        }
    }
}

/// Where the film is, dragged to scrub: the times follow the finger and a
/// preview of the scene shows above it; the film moves when it lets go.
private struct TouchSeekBar: View {

    let session: PlayerSession
    let previews: TrickplayPreviews?
    @Binding
    var scrubTarget: Double?
    let touched: () -> Void

    private static let previewWidth: CGFloat = 200

    private var shown: Double {
        scrubTarget ?? session.shownPosition
    }

    private func fraction(_ seconds: Double) -> CGFloat {
        guard session.duration > 0 else { return 0 }
        return CGFloat(min(max(seconds / session.duration, 0), 1))
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.3))
                        .frame(height: scrubTarget == nil ? 4 : 8)
                    Capsule().fill(.white)
                        .frame(width: width * fraction(shown), height: scrubTarget == nil ? 4 : 8)
                    Circle().fill(.white)
                        .frame(width: 14, height: 14)
                        .offset(x: width * fraction(shown) - 7)
                }
                .frame(maxHeight: .infinity)
                .overlay(alignment: .topLeading) {
                    if let scrubTarget, let image = previews?.image(at: scrubTarget) {
                        let height = Self.previewWidth / (previews?.aspectRatio ?? 16 / 9)
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .frame(width: Self.previewWidth, height: height)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .shadow(color: .black.opacity(0.6), radius: 10, y: 4)
                            .offset(
                                x: min(max(0, width * fraction(scrubTarget) - Self.previewWidth / 2), width - Self.previewWidth),
                                y: -height - 12
                            )
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            touched()
                            let point = min(max(value.location.x / max(width, 1), 0), 1)
                            scrubTarget = Double(point) * session.duration
                        }
                        .onEnded { _ in
                            if let scrubTarget {
                                session.seek(to: scrubTarget)
                            }
                            scrubTarget = nil
                        }
                )
            }
            .frame(height: 28)
            .animation(.easeOut(duration: 0.15), value: scrubTarget == nil)

            HStack {
                Text(PlaybackTime.text(shown))
                if let title = session.chapter(at: shown)?.title, !title.isEmpty {
                    Text("· \(title)")
                        .lineLimit(1)
                }
                Spacer()
                Text("-" + PlaybackTime.text(max(0, session.duration - shown)))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.85))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Position")
        .accessibilityValue("\(PlaybackTime.text(shown)) of \(PlaybackTime.text(session.duration))")
        .accessibilityAdjustableAction { direction in
            touched()
            session.jump(by: direction == .increment ? 10 : -10)
        }
    }
}
#endif
