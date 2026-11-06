//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import AetherEngine
import AssRendering
import Foundation
import MeleteKit
import Observation
import UIKit

/// One sitting of playback: a file, then whatever plays after it.
///
/// AetherEngine demuxes the file on the device and decodes it with
/// VideoToolbox, so the file direct plays and every track in it is local:
/// switching audio is a call into the engine, not a new stream from the
/// server. Melete is told where the viewer is every ten seconds and when they
/// stop; it marks the file watched at 90%.
@MainActor
@Observable
final class PlayerSession {

    enum Phase: Equatable {
        case loading
        case playing
        case failed(String)
        case finished
    }

    let engine: AetherEngine?
    private let library: Library
    var client: MeleteClient {
        library.client
    }

    private(set) var target: PlayTarget
    private(set) var phase: Phase = .loading
    private(set) var play: PlayResponse?
    private(set) var subtitles: [SubtitleTrack] = []
    private(set) var trickplay: Trickplay?
    /// Whether Melete is converting this file to fit a bitrate limit.
    private(set) var isConverted = false
    /// The file's own chapters, for ticks on the seek bar.
    private(set) var chapters: [Chapter] = []
    /// Playback speed, 1 for normal.
    private(set) var rate: Float = 1

    /// The subtitle track showing, as Melete names it; nil for none.
    var subtitleTrack: String?

    /// The playhead, in seconds, from the engine's clock.
    var position: Double = 0
    var duration: Double = 0
    var isPaused = false

    /// What plays after this, once known.
    private(set) var next: PlayTarget?
    /// Seconds left before the next episode starts, while it is counting down.
    private(set) var nextCountdown: Int?
    /// The viewer turned the next-episode offer away for this file.
    var isNextDismissed = false
    /// The parts already skipped on their own, so one is skipped once and
    /// not again on every tick while the seek lands.
    @ObservationIgnored
    var autoSkipped: Set<SkipOffer.Kind> = []

    @ObservationIgnored
    private var lastReport: Date?
    @ObservationIgnored
    var tasks: [Task<Void, Never>] = []
    @ObservationIgnored
    private var countdownTask: Task<Void, Never>?
    /// The picture track the conversion playing has drawn into its picture.
    private(set) var burnedSubtitle: String?
    /// The ASS/SSA track showing, drawn by Mneme as it was made; nil while
    /// it loads, and for every other kind of track.
    var assRenderer: AssRenderer?
    /// The ASS track loading or drawn, and its load.
    @ObservationIgnored
    var assTrack: String?
    @ObservationIgnored
    var assLoad: Task<Void, Never>?
    /// Looks, once a subtitle is chosen, at whether it came.
    @ObservationIgnored
    var subtitleCheck: Task<Void, Never>?

    /// How far ahead to buffer, in segments of about four seconds. The
    /// engine stops early at its own budget, a quarter of the free space, so
    /// a large number asks for as much as safely fits.
    private static let forwardBufferSegments = 600

    init(target: PlayTarget, library: Library) {
        self.target = target
        self.library = library
        // Building the engine can throw; the player has to say so rather than
        // take the app down.
        engine = try? AetherEngine()
    }

    var guide: SegmentGuide? {
        play.map { SegmentGuide(segments: $0.segments, duration: duration > 0 ? duration : $0.durationSeconds) }
    }

    var skipOffer: SkipOffer? {
        guide?.skip(at: position)
    }

    // MARK: - Starting

    func start() async {
        guard let engine else {
            phase = .failed("The player could not start on this device.")
            return
        }
        observe(engine)
        await load(target)
    }

    /// `reloading` opens the same title again where it is, with a subtitle
    /// the stream playing couldn't show.
    private func load(_ target: PlayTarget, reloading: (at: Double, subtitle: String?)? = nil) async {
        guard let engine else { return }
        phase = .loading
        next = nil
        // A countdown still running would play whatever comes after this
        // file the moment it is known.
        countdownTask?.cancel()
        nextCountdown = nil
        isNextDismissed = false
        autoSkipped = []
        lastReport = nil
        // Another title's styled track, even under the same id, is another
        // script; reopening the same title keeps the one drawn.
        if reloading == nil {
            assLoad?.cancel()
            assTrack = nil
            assRenderer = nil
        }

        // Asked for beside the play link; the stream chosen waits on it only
        // when a subtitle is on.
        async let listed = client.subtitles(file: target.fileID)

        do {
            let play = try await client.play(file: target.fileID)
            guard let url = client.url(for: play.streamUrl) else {
                phase = .failed("Melete gave an address the player cannot open.")
                return
            }
            self.play = play
            PlaybackDiagnostics.shared.record("play", "file \(target.fileID) · \(target.label) · resume \(Int(play.resumeSeconds))s")

            let subtitle = reloading.map(\.subtitle) ?? play.tracks?.subtitle
            if subtitle != nil {
                subtitles = await (try? listed) ?? []
            }
            let source = try await PlaybackSource.choose(
                for: target.fileID,
                play: play,
                pictureSubtitle: pictureTrack(subtitle),
                client: client
            )
            isConverted = source.isConverted
            burnedSubtitle = source.burnedSubtitle

            var options = LoadOptions()
            options.forwardBufferSegments = Self.forwardBufferSegments
            // A conversion is HLS, which Apple's own player mounts best.
            options.nativeRemoteHLS = source.isConverted

            try await engine.load(
                url: source.url,
                startPosition: reloading?.at ?? startPosition(resume: play.resumeSeconds, restarts: target.restarts),
                options: options,
                // The chosen audio from the first frame, rather than a switch
                // a second in. A conversion already carries only that one.
                audioSourceStreamIndex: source.isConverted ? nil : play.tracks?.audio.map(Int32.init)
            )

            if subtitle == nil {
                subtitles = await (try? listed) ?? []
            }
            // Text tracks come from the stream link, which serves them
            // whichever way the picture is delivered.
            applySubtitle(subtitle, stream: url)
            engine.play()
            applyRate()
            isPaused = false
            phase = .playing
            recordDisplay()

            Task { await loadExtras(for: target, stream: url) }
        } catch let error as MeleteError {
            fail(error.localizedDescription)
        } catch {
            fail(error.localizedDescription)
        }
    }

    /// The film's frame rate against the television's: a film at 24 frames
    /// on a television left at 60 stutters, however well it plays. Whether
    /// the television follows the film is Match Content, in the Apple TV's
    /// settings.
    private func recordDisplay() {
        guard let engine else { return }
        let window = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first
        #if os(tvOS)
        let matching = window.map { $0.avDisplayManager.isDisplayCriteriaMatchingEnabled ? "on" : "off" } ?? "unknown"
        #else
        // A phone or tablet's screen follows the film by itself.
        let matching = "n/a"
        #endif
        let screen = window.map { "\($0.screen.maximumFramesPerSecond) Hz" } ?? "unknown"
        let film = engine.sourceVideoFrameRate.map { String(format: "%.3f fps", $0) } ?? "unknown"
        PlaybackDiagnostics.shared.record("display", "film \(film) · Match Content \(matching) · screen \(screen)")
    }

    /// Where to open: where it was left, backed up by the resume offset so
    /// the viewer rejoins before the line they left on; or the start.
    private func startPosition(resume: Double, restarts: Bool) -> Double? {
        guard !restarts, resume > 0 else { return nil }
        return max(0, resume - PlaybackPreferences.resumeOffset)
    }

    /// What can wait until the picture is up: seek-bar previews, and what
    /// plays next.
    private func loadExtras(for target: PlayTarget, stream: URL) async {
        chapters = await (try? client.fileInfo(target.fileID).chapters) ?? []
        trickplay = try? await client.trickplay(file: target.fileID)
        next = await NextUp.find(after: target, client: client)
    }

    func fail(_ message: String) {
        PlaybackDiagnostics.shared.record("play.failed", message)
        phase = .failed(message)
    }

    // MARK: - Transport

    func togglePause() {
        guard let engine, phase == .playing else { return }
        if isPaused {
            engine.play()
            applyRate()
        } else {
            engine.pause()
            Task { await report() }
        }
        isPaused.toggle()
    }

    /// Where the playhead is going, while a seek is on its way. The clock
    /// still reports the old place until the seek lands, so jumps add up from
    /// here and the seek bar shows it.
    private(set) var seekGoal: Double?

    @ObservationIgnored
    private var pendingSeek: Double?
    @ObservationIgnored
    private var seekTask: Task<Void, Never>?

    /// Where the viewer is, as far as they are concerned: where a seek is
    /// heading, else the playhead.
    var shownPosition: Double {
        seekGoal ?? position
    }

    /// Seeks one at a time, the latest target winning. Five quick presses
    /// were five seeks queued in the engine, each starting from a picture
    /// the last one had already moved away from.
    func seek(to seconds: Double) {
        guard let engine else { return }
        let target = min(max(0, seconds), max(0, duration - 1))
        seekGoal = target
        pendingSeek = target
        guard seekTask == nil else { return }

        seekTask = Task {
            while let target = pendingSeek {
                pendingSeek = nil
                let started = Date.now
                let from = position
                await engine.seek(to: target)
                PlaybackDiagnostics.shared.record(
                    "seek",
                    String(format: "%.0fs to %.0fs in %.2fs", from, target, Date.now.timeIntervalSince(started)),
                    seconds: engine.clock.currentTime
                )
            }
            seekGoal = nil
            seekTask = nil
        }
    }

    /// The engine resumes at normal speed after a pause or a new file, so
    /// the chosen speed is set again each time it starts.
    func setRate(_ rate: Float) {
        self.rate = rate
        engine?.setRate(rate)
    }

    private func applyRate() {
        guard rate != 1 else { return }
        engine?.setRate(rate)
    }

    /// The chapter a time falls in.
    func chapter(at seconds: Double) -> Chapter? {
        chapters.last { $0.startSeconds <= seconds }
    }

    func jump(by seconds: Double) {
        seek(to: shownPosition + seconds)
    }

    func skip(_ offer: SkipOffer) {
        PlaybackDiagnostics.shared.record("skip", offer.kind.rawValue)
        seek(to: offer.end)
    }

    /// Leaving the player: the last position goes to Melete, and the home's
    /// rows are asked for again, since Continue Watching and Next Up moved.
    func stop() async {
        for task in tasks {
            task.cancel()
        }
        countdownTask?.cancel()
        await report(force: true)
        engine?.stop()
        PlaybackDiagnostics.shared.record("stop", "at \(Int(position))s of \(Int(duration))s")
        await library.load()
    }

    // MARK: - Progress

    func report(force: Bool = false) async {
        guard play != nil, position > 0 else { return }
        guard force || ProgressCadence.isDue(lastReport: lastReport, now: .now) else { return }
        lastReport = .now
        _ = try? await client.reportProgress(
            file: target.fileID,
            ProgressReport(positionSeconds: position, durationSeconds: duration > 0 ? duration : nil, restart: target.restarts)
        )
    }

    // MARK: - Next episode

    var isOfferingNext: Bool {
        nextCountdown != nil
    }

    func dismissNext() {
        countdownTask?.cancel()
        nextCountdown = nil
        isNextDismissed = true
    }

    /// Opens the title again where it is, for a subtitle the stream playing
    /// can't show.
    func reload(showing track: String?) {
        Task {
            await report(force: true)
            await load(target, reloading: (position, track))
        }
    }

    func playNext() {
        guard let next else { return }
        countdownTask?.cancel()
        nextCountdown = nil
        // Let go of at once: while the last position is sent, the credits
        // would start the countdown again and the end of the file would
        // play it again, and the stray countdown then skipped the episode
        // just opened.
        self.next = nil
        phase = .loading
        Task {
            await report(force: true)
            target = next
            await load(next)
        }
    }

    /// Starts the countdown once the credits begin, if there is a next
    /// episode and the viewer has not turned it away.
    func considerNext() {
        guard next != nil, nextCountdown == nil, !isNextDismissed, !isPaused,
              library.autoplayNext,
              let start = guide?.nextUpStart, position >= start
        else { return }

        nextCountdown = library.countdownSeconds
        countdownTask = Task { [weak self] in
            while let self, let left = nextCountdown, left > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                // The count holds while paused.
                if !isPaused {
                    nextCountdown = left - 1
                }
            }
            guard !Task.isCancelled else { return }
            self?.playNext()
        }
    }

    func ended() {
        PlaybackDiagnostics.shared.record("ended", "file \(target.fileID)")
        // The next file is already on its way.
        guard phase == .playing else { return }
        if next != nil, library.autoplayNext, !isNextDismissed {
            playNext()
        } else {
            phase = .finished
        }
    }
}
