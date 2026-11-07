//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import AetherEngine
import MeleteKit
import SwiftUI

/// A list of audio or subtitle tracks over the right side of the picture.
struct TrackPicker: View {

    enum Kind {
        case audio
        case subtitles
        case speed
    }

    static let speeds: [Float] = [0.5, 0.75, 1, 1.25, 1.5, 2]

    /// "1.25×", "Normal".
    static func speedTitle(_ rate: Float) -> String {
        rate == 1 ? "Normal" : "\(rate.formatted(.number.precision(.fractionLength(0 ... 2))))×"
    }

    let kind: Kind
    let session: PlayerSession
    let close: () -> Void

    /// The row with the remote's focus, by its place in the list.
    @FocusState
    private var focusedRow: Int?

    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 24)

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            self.row(row)
                                .focused($focusedRow, equals: index)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.vertical, 60)
            .frame(width: 640)
            .frame(maxHeight: .infinity)
            .background(.regularMaterial)
            .focusSection()
        }
        .ignoresSafeArea()
        .onExitCommand(perform: close)
        // Focus goes straight to the choice in use, so the list answers the
        // remote as soon as it opens. A moment later, once the rows are on
        // screen: set in the same instant, tvOS drops the move.
        .task {
            try? await Task.sleep(for: .milliseconds(60))
            focusedRow = rows.firstIndex(where: \.isOn) ?? 0
        }
    }

    private var title: String {
        switch kind {
        case .audio: "Audio"
        case .subtitles: "Subtitles"
        case .speed: "Speed"
        }
    }

    private struct Row {
        let title: String
        let isOn: Bool
        let action: () -> Void
    }

    private var rows: [Row] {
        switch kind {
        case .audio: audioRows
        case .subtitles: subtitleRows
        case .speed: speedRows
        }
    }

    private var speedRows: [Row] {
        Self.speeds.map { rate in
            Row(title: Self.speedTitle(rate), isOn: session.rate == rate) {
                session.setRate(rate)
                close()
            }
        }
    }

    private var audioRows: [Row] {
        session.audioTracks.map { track in
            Row(title: Self.title(of: track), isOn: session.activeAudio == track.id) {
                session.selectAudio(track)
                close()
            }
        }
    }

    private var subtitleRows: [Row] {
        let off = Row(title: "Off", isOn: session.subtitleTrack == nil) {
            session.selectSubtitle(nil)
            close()
        }
        // Picture tracks beside the video cannot be fetched as text.
        let tracks = session.subtitles.filter { $0.text || $0.embeddedIndex != nil }.map { track in
            Row(title: Self.title(of: track), isOn: session.subtitleTrack == track.track) {
                session.selectSubtitle(track)
                close()
            }
        }
        return [off] + tracks
    }

    private func row(_ row: Row) -> some View {
        Button(action: row.action) {
            HStack {
                Text(row.title)
                    .lineLimit(1)
                Spacer()
                if row.isOn {
                    Image(systemName: "checkmark")
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .buttonStyle(TrackRowStyle())
    }

    /// "English · 5.1 · TrueHD".
    static func title(of track: TrackInfo) -> String {
        let language = track.language.flatMap { Locale.current.localizedString(forLanguageCode: $0) }
        let channels: String? = switch track.channels {
        case 0: nil
        case 1: "Mono"
        case 2: "Stereo"
        case 6: "5.1"
        case 8: "7.1"
        default: "\(track.channels) ch"
        }
        return [language ?? track.name, channels, track.codec.uppercased()]
            .compactMap(\.self)
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// "English · Forced", "French · SDH · external".
    static func title(of track: SubtitleTrack) -> String {
        let language = track.language.flatMap { Locale.current.localizedString(forLanguageCode: $0) } ?? track.title ?? "Unknown"
        var parts = [language]
        if track.forced {
            parts.append("Forced")
        }
        if track.hearingImpaired {
            parts.append("SDH")
        }
        if let title = track.title, title != language {
            parts.append(title)
        }
        if track.source != "embedded" {
            parts.append(track.source == "external" ? "File" : "OpenSubtitles")
        }
        return parts.joined(separator: " · ")
    }
}

private struct TrackRowStyle: ButtonStyle {

    @Environment(\.isFocused)
    private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isFocused ? .black : .white)
            .background(isFocused ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 12)
    }
}
