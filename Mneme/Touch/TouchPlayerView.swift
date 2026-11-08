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
import AVFoundation
import MeleteKit
import SwiftUI

/// The player on a touch screen: the same `PlayerSession` and engine as the
/// Apple TV's, under controls for a hand. A tap shows or hides them, a
/// double tap on either half jumps ten seconds, and the bar is dragged to
/// scrub.
struct TouchPlayerView: View {

    @Environment(Library.self)
    private var library
    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.scenePhase)
    private var scenePhase

    let target: PlayTarget

    @State
    private var session: PlayerSession?
    @State
    private var previews: TrickplayPreviews?
    @State
    private var controlsVisible = true
    @State
    private var lastInput = Date.now
    /// Where the bar is being dragged to, while it is.
    @State
    private var scrubTarget: Double?
    @State
    private var skipFlash: SkipFlash?
    @State
    private var pictureInPicture = PictureInPicture()

    /// How long the controls stay up untouched, while playing.
    private static let controlsTimeout: TimeInterval = 4
    private static let jump: Double = 10

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let session {
                content(session)
            }
        }
        .task {
            let session = PlayerSession(target: target, library: library)
            self.session = session
            session.prepareNowPlaying()
            await session.start()
        }
        .task(id: session?.trickplay) {
            guard let session, let trickplay = session.trickplay, let sheetURL = session.previewSheetURL else { return }
            previews = TrickplayPreviews(trickplay: trickplay, sheetURL: sheetURL)
        }
        .task(id: controlsVisible) {
            await hideControlsWhenIdle()
        }
        // Unlike the Apple TV's player, nothing pauses here on the way to
        // the background: the film carries on as sound, or in Picture in
        // Picture, and the engine looks after itself there.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await session?.restoreAfterBackground() }
            }
        }
        .onChange(of: session?.phase) { _, phase in
            if phase == .finished {
                leave()
            }
        }
        .onAppear(perform: PlayerScreen.enter)
        .onDisappear {
            pictureInPicture.detach()
            PlayerScreen.leave()
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .statusBarHidden(!controlsVisible)
        .persistentSystemOverlays(.hidden)
    }

    @ViewBuilder
    private func content(_ session: PlayerSession) -> some View {
        if let engine = session.engine {
            PictureFadeIn(engine: engine) {
                AetherPlayerSurface(engine: engine)
            }
            .ignoresSafeArea()
            // Each load can draw into another layer, or take the other path.
            .onReceive(engine.$videoRoute) { _ in
                pictureInPicture.attach(to: engine)
                session.registerRemoteCommands()
            }
            .onReceive(engine.$softwarePiPSource) { _ in
                pictureInPicture.attach(to: engine)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
                engine.setScreenMirrored(PlayerScreen.isMirrored)
            }
            SubtitleOverlay(engine: engine)
                .ignoresSafeArea()
            if let renderer = session.assRenderer {
                AssSubtitleOverlay(renderer: renderer, engine: engine)
                    .ignoresSafeArea()
            }
            ActivitySpinner(engine: engine)
        }

        if case let .failed(message) = session.phase {
            PlaybackFailure(message: message, leave: leave)
        } else {
            surface(session)

            if let skipFlash {
                SkipFlashView(flash: skipFlash)
                    .id(skipFlash.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    .allowsHitTesting(false)
            }

            if controlsVisible {
                TouchPlayerControls(
                    session: session,
                    previews: previews,
                    scrubTarget: $scrubTarget,
                    pictureInPicture: pictureInPicture,
                    jump: { jump(forward: $0) },
                    touched: touch,
                    close: leave
                )
                .transition(.opacity)
            }

            offers(session)
        }
    }

    /// The picture as a place to tap: once for the controls, twice on one
    /// half to jump that way.
    private func surface(_ session: PlayerSession) -> some View {
        GeometryReader { proxy in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture(count: 2)
                        .onEnded { value in
                            jump(forward: value.location.x > proxy.size.width / 2)
                        }
                        .exclusively(before: TapGesture().onEnded {
                            touch()
                            withAnimation(.easeOut(duration: 0.2)) { controlsVisible.toggle() }
                        })
                )
        }
        .ignoresSafeArea()
        .accessibilityElement()
        .accessibilityLabel(session.target.label)
        .accessibilityHint("Shows the controls")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }

    /// Skip Intro, and the next episode over the credits, in the corner
    /// above the bar.
    @ViewBuilder
    private func offers(_ session: PlayerSession) -> some View {
        Group {
            if let next = session.next, let left = session.nextCountdown {
                HStack(spacing: 10) {
                    Button("Not Now") {
                        session.dismissNext()
                    }
                    .buttonStyle(.bordered)

                    Button {
                        session.playNext()
                    } label: {
                        Label("Next Episode in \(left)", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    .accessibilityHint(next.label)
                }
            } else if let offer = session.skipOffer {
                Button {
                    touch()
                    session.skip(offer)
                } label: {
                    Label(offer.title, systemImage: "forward.end.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
            }
        }
        .controlSize(.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.horizontal, 24)
        .padding(.bottom, controlsVisible ? 110 : 32)
        .animation(.easeOut(duration: 0.2), value: controlsVisible)
    }

    private func jump(forward: Bool) {
        guard let session else { return }
        touch()
        session.jump(by: forward ? Self.jump : -Self.jump)
        let step = Int(Self.jump)
        let flash = skipFlash?.adding(step, forward: forward) ?? SkipFlash(isForward: forward, seconds: step)
        withAnimation(.easeOut(duration: 0.15)) { skipFlash = flash }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard skipFlash?.id == flash.id else { return }
            withAnimation(.easeIn(duration: 0.3)) { skipFlash = nil }
        }
    }

    private func touch() {
        lastInput = .now
    }

    private func hideControlsWhenIdle() async {
        while controlsVisible, !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            let isIdle = Date.now.timeIntervalSince(lastInput) > Self.controlsTimeout
            if isIdle, scrubTarget == nil, session?.isPaused == false {
                withAnimation(.easeOut(duration: 0.3)) { controlsVisible = false }
            }
        }
    }

    private func leave() {
        let session = session
        Task {
            await session?.stop()
            dismiss()
        }
    }
}

/// What the device does around the player: films play with sound even with
/// the ringer switched off, the screen stays on, and a phone turns to
/// landscape, then back.
@MainActor
private enum PlayerScreen {

    static func enter() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        UIApplication.shared.isIdleTimerDisabled = true
        turn(to: .landscape)
    }

    static func leave() {
        UIApplication.shared.isIdleTimerDisabled = false
        turn(to: .portrait)
    }

    /// Whether the screen is being shown elsewhere too, as when mirrored to
    /// a television, which then carries a picture the engine draws itself.
    /// Recording the screen reads the same; the engine only keeps its
    /// picture where it is in that case.
    static var isMirrored: Bool {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.isCaptured ?? false
    }

    private static func turn(to orientations: UIInterfaceOrientationMask) {
        guard UIDevice.current.userInterfaceIdiom == .phone,
              let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { _ in }
    }
}
#endif
