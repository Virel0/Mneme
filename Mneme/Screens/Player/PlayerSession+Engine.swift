//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import AetherEngine
import Foundation
import MeleteKit

extension PlayerSession {

    /// Follows the engine for the life of the session: one task per thing
    /// watched, all cancelled when the session stops.
    func observe(_ engine: AetherEngine) {
        tasks += [
            Task { [weak self] in await self?.followClock(of: engine) },
            Task { [weak self] in await self?.followState(of: engine) },
            Task { await Self.recordStalls(of: engine) },
            Task { await Self.sampleTelemetry(of: engine) },
        ]
    }

    private func followClock(of engine: AetherEngine) async {
        for await time in engine.clock.$currentTime.values {
            position = time
            duration = engine.duration
            autoSkipIfWanted()
            considerNext()
            if !isPaused {
                await report()
            }
        }
    }

    private func autoSkipIfWanted() {
        guard PlaybackPreferences.autoSkipIntros, let offer = skipOffer, !autoSkipped.contains(offer.kind) else { return }
        autoSkipped.insert(offer.kind)
        skip(offer)
    }

    private func followState(of engine: AetherEngine) async {
        for await state in engine.$state.values {
            PlaybackDiagnostics.shared.record("engine.state", String(describing: state), seconds: engine.clock.currentTime)
            if case .ended = state {
                ended()
            }
        }
    }

    /// A stall is what a viewer notices and cannot describe afterwards, so
    /// each is recorded with the engine's measurements at the time.
    private static func recordStalls(of engine: AetherEngine) async {
        for await isBuffering in engine.$isBuffering.removeDuplicates().values {
            PlaybackDiagnostics.shared.record(
                isBuffering ? "buffering.start" : "buffering.end",
                PlaybackDiagnostics.summary(engine.liveTelemetry),
                seconds: engine.clock.currentTime
            )
        }
    }

    /// The same measurements every ten seconds while playing: the trend
    /// leading up to a stall, not only the moment of it.
    private static func sampleTelemetry(of engine: AetherEngine) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(10))
            guard engine.state == .playing || engine.isBuffering else { continue }
            PlaybackDiagnostics.shared.record(
                "telemetry",
                PlaybackDiagnostics.summary(engine.liveTelemetry),
                seconds: engine.clock.currentTime
            )
        }
    }

    // MARK: - Background

    /// tvOS tears the decoder down when the app goes to the background; the
    /// session is rebuilt where it stopped, paused, when it comes back.
    func enterBackground() {
        guard phase == .playing, !isPaused else { return }
        togglePause()
    }

    func enterForeground() async {
        guard let engine, phase == .playing else { return }
        do {
            try await engine.reloadAtCurrentPosition()
            engine.pause()
            isPaused = true
        } catch {
            fail(error.localizedDescription)
        }
    }
}
