//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import AetherEngine
import Foundation
import MeleteKit
import UIKit

/// The last few hundred things playback did, kept in memory and sent to
/// Melete when the viewer asks.
///
/// A report is usually sent after the fact, so what matters is
/// the run-up: what was played, every stall with the engine's measurements at
/// that moment, and the same measurements every ten seconds while playing.
@MainActor
final class PlaybackDiagnostics {

    static let shared = PlaybackDiagnostics()

    private var lines: [String] = []

    /// Melete refuses a report over 64 KiB, so the log is kept well under.
    private static let maxLines = 250
    private static let maxLineLength = 200

    private let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter
    }()

    /// The engine's own word on subtitles it couldn't load, which it says
    /// only to its log.
    private init() {
        EngineLog.handler = { line in
            guard let line = Self.subtitleFailure(in: line) else { return }
            Task { @MainActor in PlaybackDiagnostics.shared.record("engine", line) }
        }
    }

    /// A line of the engine's about a subtitle failing, with any address
    /// taken out: Melete's stream links carry their token. Nil for any other
    /// line.
    nonisolated static func subtitleFailure(in line: String) -> String? {
        let lowered = line.lowercased()
        guard lowered.contains("subtitle") || lowered.contains("sidecar"),
              lowered.contains("fail") || lowered.contains("error") || lowered.contains("refus")
        else { return nil }
        return line
            .replacingOccurrences(of: "[AetherEngine] ", with: "")
            .replacingOccurrences(of: #"[a-z]+://\S+"#, with: "<address>", options: .regularExpression)
    }

    func record(_ event: String, _ detail: String = "", seconds: Double? = nil) {
        let at = seconds.map { " @\(Int($0))s" } ?? ""
        let line = "\(clock.string(from: .now)) \(event)\(at) \(detail)"
        lines.append(String(line.prefix(Self.maxLineLength)))
        if lines.count > Self.maxLines {
            lines.removeFirst(lines.count - Self.maxLines)
        }
    }

    /// The engine's measurements in one line: how far ahead it has buffered,
    /// how fast the source arrives against what the video needs, whether
    /// audio is being converted, and how far audio and video have drifted.
    static func summary(_ telemetry: LiveTelemetry?) -> String {
        guard let telemetry else { return "no telemetry" }

        func mbps(_ value: Double?) -> String? {
            value.map { String(format: "%.1f", $0) }
        }

        return [
            telemetry.forwardBufferSeconds.map { String(format: "ahead %.1fs", $0) },
            mbps(telemetry.networkThroughputMbps).map { "network \($0) Mbps" },
            mbps(telemetry.instantBitrateMbps).map { "video \($0) Mbps" },
            mbps(telemetry.averageBitrateMbps).map { "avg \($0) Mbps" },
            mbps(telemetry.audioBridgeBitrateMbps).map { "audio converted \($0) Mbps" },
            telemetry.avSyncGapMs.map { String(format: "av gap %.0fms", $0) },
            telemetry.droppedFrameCount.map { "dropped \($0)" },
            "restarts \(telemetry.producerRestartCount)",
            "mem \(telemetry.rssMb)MB",
        ]
            .compactMap(\.self)
            .joined(separator: ", ")
    }

    /// Sends what has been recorded. Melete keeps it 30 days, for admins to
    /// read under Diagnostics.
    func send(with client: MeleteClient, note: String) async throws(MeleteError) {
        let info = Bundle.main.infoDictionary
        let version = [info?["CFBundleShortVersionString"], info?["CFBundleVersion"]]
            .compactMap { $0 as? String }
            .joined(separator: " (") + ")"
        let device = UIDevice.current

        _ = try await client.sendDiagnostics(DiagnosticsReport(
            app: "Mneme",
            appVersion: version,
            platform: "\(device.systemName) \(device.systemVersion)",
            level: "info",
            summary: note,
            details: ["playback": lines]
        ))
    }
}
