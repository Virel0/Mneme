//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

#if os(iOS)
import Foundation

/// The background session the videos come over. The system carries on
/// with it while the app is suspended or closed, and wakes the app to hear
/// how each ended. Each task carries its download's id, so a task from
/// before a relaunch still finds its way.
@MainActor
final class DownloadTransfer {

    static let sessionIdentifier = "downloads"

    /// Called once every event the system woke the app for has been heard.
    private static var finishBackgroundEvents: (() -> Void)?

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        // Started now, not when the system judges a good moment: the viewer
        // asked for it.
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        session = URLSession(configuration: configuration, delegate: Delegate(), delegateQueue: nil)
    }

    /// For the system waking the app about this session: the session is
    /// opened again, its news heard, and this returns once all of it is in.
    static func hearBackgroundEvents() async {
        await withCheckedContinuation { continuation in
            // Set before the session opens, so no news comes before it.
            finishBackgroundEvents = { continuation.resume() }
            _ = DownloadStore.shared
        }
    }

    func start(_ id: UUID, from url: URL) {
        let task = session.downloadTask(with: url)
        task.taskDescription = id.uuidString
        task.resume()
    }

    func cancel(_ id: UUID) {
        session.getAllTasks { tasks in
            for task in tasks where task.taskDescription == id.uuidString {
                task.cancel()
            }
        }
    }

    // MARK: - Delegate

    /// The session's delegate, on the session's own queue; what it hears
    /// goes to the store on the main actor.
    private final class Delegate: NSObject, URLSessionDownloadDelegate {

        func urlSession(
            _: URLSession,
            downloadTask: URLSessionDownloadTask,
            didWriteData _: Int64,
            totalBytesWritten: Int64,
            totalBytesExpectedToWrite: Int64
        ) {
            guard let id = downloadTask.downloadID, totalBytesExpectedToWrite > 0 else { return }
            let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            Task { @MainActor in
                DownloadStore.shared.transferProgressed(id, fraction: fraction)
            }
        }

        /// The file is moved before this returns: the system deletes it
        /// after.
        func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
            guard let id = downloadTask.downloadID else { return }
            if let response = downloadTask.response as? HTTPURLResponse, !(200 ..< 300).contains(response.statusCode) {
                let message = response.statusCode == 404
                    ? "The download link ran out. Try again for a new one."
                    : "The server answered \(response.statusCode)."
                Task { @MainActor in
                    DownloadStore.shared.transferFailed(id, message: message)
                }
                return
            }
            let folder = DownloadStore.folder(of: id)
            let video = folder.appending(path: "video.mp4")
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try? FileManager.default.removeItem(at: video)
                try FileManager.default.moveItem(at: location, to: video)
                let bytes = (try? video.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                Task { @MainActor in
                    DownloadStore.shared.transferFinished(id, bytes: bytes)
                }
            } catch {
                let message = error.localizedDescription
                Task { @MainActor in
                    DownloadStore.shared.transferFailed(id, message: message)
                }
            }
        }

        func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
            guard let error, let id = task.downloadID else { return }
            // Removed from the device: nothing to tell.
            if (error as? URLError)?.code == .cancelled {
                return
            }
            let message = error.localizedDescription
            Task { @MainActor in
                DownloadStore.shared.transferFailed(id, message: message)
            }
        }

        func urlSessionDidFinishEvents(forBackgroundURLSession _: URLSession) {
            Task { @MainActor in
                // After the store's own tasks above, which went first.
                DownloadTransfer.finishBackgroundEvents?()
                DownloadTransfer.finishBackgroundEvents = nil
            }
        }
    }
}

private extension URLSessionTask {

    var downloadID: UUID? {
        taskDescription.flatMap(UUID.init(uuidString:))
    }
}
#endif
