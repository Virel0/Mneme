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
import AVKit
import SwiftUI

/// The system's AirPlay button. Choosing a television moves the film there:
/// the engine follows the route by itself, sending the picture where its
/// path allows and the sound in any case.
struct AirPlayButton: UIViewRepresentable {

    func makeUIView(context _: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = true
        picker.tintColor = .white
        picker.activeTintColor = .white
        return picker
    }

    func updateUIView(_: AVRoutePickerView, context _: Context) {}
}

/// Said over the controls when AirPlay carries only the sound: a film the
/// engine decodes itself keeps its picture on this screen.
struct AirPlaySoundOnlyNotice: View {

    @ObservedObject
    var engine: AetherEngine

    var body: some View {
        if engine.airPlayPictureStaysLocal {
            Label("The sound is on the AirPlay device; the picture plays here.", systemImage: "airplayaudio")
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.6), in: Capsule())
        }
    }
}
#endif
