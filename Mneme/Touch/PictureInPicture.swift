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

/// Picture in Picture for the film playing, from the layer the engine draws
/// it in: Apple's player layer on the usual path, or the sample-buffer layer
/// when FFmpeg decodes it. It starts by itself when the app goes to the
/// background with the film playing, as the system's setting allows.
@MainActor
@Observable
final class PictureInPicture: NSObject {

    /// Whether the button can start it now.
    private(set) var isPossible = false
    private(set) var isActive = false

    @ObservationIgnored
    private var controller: AVPictureInPictureController?
    @ObservationIgnored
    private weak var engine: AetherEngine?
    @ObservationIgnored
    private weak var attachedLayer: CALayer?
    @ObservationIgnored
    private var possibleObservation: NSKeyValueObservation?

    /// Built again when the engine draws into another layer: a new load can
    /// bring a new one, or move between the two paths.
    func attach(to engine: AetherEngine) {
        self.engine = engine
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }

        let source: AVPictureInPictureController.ContentSource
        let layer: CALayer
        if engine.videoRoute == .software, let software = engine.softwarePiPSource {
            source = .init(sampleBufferDisplayLayer: software.layer, playbackDelegate: self)
            layer = software.layer
        } else if let player = engine.nativePlayerLayer {
            source = .init(playerLayer: player)
            layer = player
        } else {
            return
        }
        guard layer !== attachedLayer else { return }
        attachedLayer = layer

        let controller = AVPictureInPictureController(contentSource: source)
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        possibleObservation = controller.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] controller, _ in
            let possible = controller.isPictureInPicturePossible
            Task { @MainActor in self?.isPossible = possible }
        }
        self.controller = controller
    }

    func toggle() {
        guard let controller else { return }
        if controller.isPictureInPictureActive {
            controller.stopPictureInPicture()
        } else {
            controller.startPictureInPicture()
        }
    }

    /// The player is going: the window goes with it.
    func detach() {
        controller?.stopPictureInPicture()
        controller = nil
        possibleObservation = nil
        attachedLayer = nil
        isPossible = false
        setActive(false)
    }

    private func setActive(_ active: Bool) {
        isActive = active
        // Keeps the engine's pipeline alive in the background, hands the
        // next episode over in the same window, and draws subtitles into it.
        engine?.pictureInPictureActive = active
    }
}

extension PictureInPicture: AVPictureInPictureControllerDelegate {

    nonisolated func pictureInPictureControllerWillStartPictureInPicture(_: AVPictureInPictureController) {
        MainActor.assumeIsolated { setActive(true) }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_: AVPictureInPictureController) {
        MainActor.assumeIsolated { setActive(false) }
    }

    nonisolated func pictureInPictureController(_: AVPictureInPictureController, failedToStartPictureInPictureWithError _: any Error) {
        MainActor.assumeIsolated { setActive(false) }
    }

    /// The player stays where it was under the window, so there is nothing
    /// to put back.
    nonisolated func pictureInPictureController(
        _: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(true)
    }
}

/// The window's own buttons, on the path where no Apple player is behind the
/// layer to answer them.
extension PictureInPicture: AVPictureInPictureSampleBufferPlaybackDelegate {

    nonisolated func pictureInPictureController(_: AVPictureInPictureController, setPlaying playing: Bool) {
        MainActor.assumeIsolated { engine?.softwarePiPSource?.setPlaying(playing) }
    }

    nonisolated func pictureInPictureControllerTimeRangeForPlayback(_: AVPictureInPictureController) -> CMTimeRange {
        MainActor.assumeIsolated {
            engine?.softwarePiPSource?.timeRange() ?? CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
        }
    }

    nonisolated func pictureInPictureControllerIsPlaybackPaused(_: AVPictureInPictureController) -> Bool {
        MainActor.assumeIsolated { engine?.softwarePiPSource?.isPaused ?? true }
    }

    nonisolated func pictureInPictureController(_: AVPictureInPictureController, didTransitionToRenderSize _: CMVideoDimensions) {}

    nonisolated func pictureInPictureController(
        _: AVPictureInPictureController,
        skipByInterval skipInterval: CMTime,
        completion completionHandler: @escaping () -> Void
    ) {
        MainActor.assumeIsolated { engine?.softwarePiPSource?.skip(by: skipInterval.seconds) }
        completionHandler()
    }
}
#endif
