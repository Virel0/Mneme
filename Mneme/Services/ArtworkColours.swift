//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import CoreImage
import CoreImage.CIFilterBuiltins
import MeleteKit
import Nuke
import Observation
import SwiftUI

/// The colour of each title's backdrop, so light on the screen can follow
/// the title: the average of its picture, lifted to a colour that glows, as
/// a backdrop's plain average is mostly a muddy dark. Worked out on the
/// Apple TV from the picture already loaded, once, and kept.
///
/// Whatever has focus says whose colour is current: the page's sky glows
/// with it.
@MainActor
@Observable
final class ArtworkColours {

    /// The colour of what has focus, for the page's glow.
    private(set) var current: Color?

    private var colours: [String: Color] = [:]
    @ObservationIgnored
    private var working: Set<String> = []
    @ObservationIgnored
    private let client: MeleteClient

    init(client: MeleteClient) {
        self.client = client
    }

    /// The picture's colour when it is known; asks for it otherwise, and the
    /// view that asked draws again when it comes.
    func colour(for path: String?) -> Color? {
        guard let path else { return nil }
        if let colour = colours[path] {
            return colour
        }
        work(path, makeCurrent: false)
        return nil
    }

    /// Makes the picture's colour the current one, once it is known.
    func focus(on path: String?) {
        guard let path else { return }
        if let colour = colours[path] {
            current = colour
        } else {
            work(path, makeCurrent: true)
        }
    }

    private func work(_ path: String, makeCurrent: Bool) {
        guard !working.contains(path), let request = client.artworkRequest(path) else { return }
        working.insert(path)
        Task {
            if let image = try? await ImagePipeline.shared.image(for: request).cgImage,
               let colour = await Self.glow(of: image)
            {
                colours[path] = colour
                if makeCurrent {
                    current = colour
                }
            }
            working.remove(path)
        }
    }

    /// Shared across threads, as a Core Image context can be.
    private nonisolated(unsafe) static let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])

    /// The picture's average colour, with its brightness and saturation
    /// raised enough to glow.
    @concurrent
    private nonisolated static func glow(of image: CGImage) async -> Color? {
        let input = CIImage(cgImage: image)
        let average = CIFilter.areaAverage()
        average.inputImage = input
        average.extent = input.extent
        guard let output = average.outputImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        )

        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0
        UIColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255, blue: CGFloat(pixel[2]) / 255, alpha: 1)
            .getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        return Color(hue: hue, saturation: min(max(saturation * 1.4, 0.35), 0.9), brightness: max(brightness, 0.8))
    }
}
