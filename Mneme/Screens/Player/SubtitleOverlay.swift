//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import AetherEngine
import SwiftUI

/// Draws the engine's subtitle cues over the video.
///
/// AetherEngine decodes subtitles but leaves painting them to the host,
/// except in Picture in Picture. The published cues are a window around the
/// playhead, so they are filtered against the clock here; cue times are
/// source times, which is what `clock.sourceTime` reports — `currentTime` can
/// differ, and comparing against it shows nothing.
struct SubtitleOverlay: View {

    @ObservedObject
    var engine: AetherEngine

    @ObservedObject
    private var clock: PlaybackClock

    init(engine: AetherEngine) {
        self.engine = engine
        clock = engine.clock
    }

    /// Chosen in Settings; 46 is close to what tvOS uses for its captions.
    private let fontSize = CGFloat(PlaybackPreferences.subtitleSize)

    private var activeCues: [SubtitleCue] {
        let playhead = clock.sourceTime
        return engine.subtitleCues.filter { $0.startTime <= playhead && playhead < $0.endTime }
    }

    private var textCues: [SubtitleCue] {
        activeCues.filter { $0.text?.isEmpty == false }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(activeCues) { cue in
                    if case let .image(image) = cue.body {
                        bitmap(image, in: proxy.size)
                    }
                }

                if !textCues.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(textCues) { cue in
                            line(for: cue)
                        }
                    }
                    .frame(maxWidth: proxy.size.width * 0.9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                    .padding(.vertical, proxy.size.height * 0.06)
                }
            }
        }
        .allowsHitTesting(false)
        .animation(nil, value: clock.sourceTime)
    }

    /// ASS alignments 7 to 9 sit at the top of the frame, everything else at
    /// the bottom. Only the vertical half is followed: a cue pinned to a
    /// corner reads worse than one centred.
    private var alignment: Alignment {
        let isTop = textCues.contains { cue in
            guard let value = cue.placement?.alignment else { return false }
            return (7 ... 9).contains(value)
        }
        return isTop ? .top : .bottom
    }

    @ViewBuilder
    private func line(for cue: SubtitleCue) -> some View {
        Group {
            if case let .richText(runs) = cue.body {
                runs.reduce(Text("")) { partial, run in Text("\(partial)\(styled(run))") }
            } else if let text = cue.text {
                Text(text)
            }
        }
        .font(.system(size: fontSize, weight: .semibold))
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        // Subtitles land on whatever the picture is doing, so they carry their
        // own contrast.
        .shadow(color: .black.opacity(0.9), radius: 4, x: 0, y: 2)
        .shadow(color: .black.opacity(0.6), radius: 1)
    }

    private func styled(_ run: SubtitleTextRun) -> Text {
        var text = Text(run.text)
        if run.isBold {
            text = text.bold()
        }
        if run.isItalic {
            text = text.italic()
        }
        if run.isUnderlined {
            text = text.underline()
        }
        if run.isStruckThrough {
            text = text.strikethrough()
        }
        if let color = run.color {
            text = text.foregroundColor(Color(red: Double(color.r) / 255, green: Double(color.g) / 255, blue: Double(color.b) / 255))
        }
        return text
    }

    /// Picture subtitles (PGS and the like) come with a position normalised
    /// against the canvas they were authored on.
    @ViewBuilder
    private func bitmap(_ image: SubtitleImage, in size: CGSize) -> some View {
        let position = image.position
        Image(decorative: image.cgImage, scale: 1)
            .resizable()
            .frame(width: position.width * size.width, height: position.height * size.height)
            .position(x: position.midX * size.width, y: position.midY * size.height)
    }
}
