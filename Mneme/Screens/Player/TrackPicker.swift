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

    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 24)

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        switch kind {
                        case .audio: audioRows
                        case .subtitles: subtitleRows
                        case .speed: speedRows
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.vertical, 60)
            .frame(width: 640)
            .frame(maxHeight: .infinity)
            .background(.regularMaterial)
        }
        .ignoresSafeArea()
        .onExitCommand(perform: close)
    }

    private var title: String {
        switch kind {
        case .audio: "Audio"
        case .subtitles: "Subtitles"
        case .speed: "Speed"
        }
    }

    @ViewBuilder
    private var speedRows: some View {
        ForEach(Self.speeds, id: \.self) { rate in
            row(title: Self.speedTitle(rate), isOn: session.rate == rate) {
                session.setRate(rate)
                close()
            }
        }
    }

    @ViewBuilder
    private var audioRows: some View {
        ForEach(session.audioTracks, id: \.id) { track in
            row(title: Self.title(of: track), isOn: session.activeAudio == track.id) {
                session.selectAudio(track)
                close()
            }
        }
    }

    @ViewBuilder
    private var subtitleRows: some View {
        row(title: "Off", isOn: session.subtitleTrack == nil) {
            session.selectSubtitle(nil)
            close()
        }
        // Picture tracks beside the video cannot be fetched as text.
        ForEach(session.subtitles.filter { $0.text || $0.embeddedIndex != nil }) { track in
            row(title: Self.title(of: track), isOn: session.subtitleTrack == track.track) {
                session.selectSubtitle(track)
                close()
            }
        }
    }

    private func row(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .lineLimit(1)
                Spacer()
                if isOn {
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
