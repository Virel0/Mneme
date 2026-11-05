//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import CoreGraphics
import Foundation
import Libass

/// An ASS/SSA script drawn as it was made: its styles, positions, signs and
/// karaoke, in the fonts given with it, through libass.
///
/// One renderer is one script. It can be used from any one thread at a time;
/// calls from several are serialised.
public final class AssRenderer: @unchecked Sendable {

    /// A font to draw with: one the video carries, by the name it was stored
    /// under.
    public struct Font: Sendable {
        public let name: String
        public let data: Data

        public init(name: String, data: Data) {
            self.name = name
            self.data = data
        }
    }

    /// What is on screen at a moment: one picture over the part of the frame
    /// the subtitles cover, in the frame's pixels, top-left origin.
    public struct Frame: @unchecked Sendable {
        public let image: CGImage
        public let rect: CGRect
    }

    private let library: OpaquePointer
    private let renderer: OpaquePointer
    private let track: UnsafeMutablePointer<ASS_Track>
    private let lock = NSLock()
    private var frameSize = (width: 0, height: 0)
    private var last: Frame?

    /// Nil when libass can't start or the script has nothing in it it can
    /// read.
    public init?(script: String, fonts: [Font] = []) {
        guard let library = ass_library_init() else { return nil }
        for font in fonts {
            font.data.withUnsafeBytes { bytes in
                ass_add_font(library, font.name, bytes.baseAddress?.assumingMemoryBound(to: CChar.self), Int32(bytes.count))
            }
        }
        guard let renderer = ass_renderer_init(library) else {
            ass_library_done(library)
            return nil
        }
        // The fonts above first; then the Apple TV's own, for any a script
        // names that the video doesn't carry.
        ass_set_fonts(renderer, nil, "sans-serif", Int32(ASS_FONTPROVIDER_CORETEXT.rawValue), nil, 1)

        var bytes = Array(script.utf8CString)
        guard let track = bytes.withUnsafeMutableBufferPointer({
            ass_read_memory(library, $0.baseAddress, $0.count - 1, nil)
        }), track.pointee.n_events > 0 || track.pointee.n_styles > 0 else {
            ass_renderer_done(renderer)
            ass_library_done(library)
            return nil
        }
        self.library = library
        self.renderer = renderer
        self.track = track
    }

    deinit {
        ass_free_track(track)
        ass_renderer_done(renderer)
        ass_library_done(library)
    }

    /// How many dialogue lines the script has.
    public var eventCount: Int {
        lock.withLock { Int(track.pointee.n_events) }
    }

    /// The pixels to draw into, and the video's own size, which says how the
    /// script's coordinates stretch. Changing either draws the next frame
    /// afresh.
    public func setFrame(width: Int, height: Int, videoWidth: Int, videoHeight: Int) {
        lock.withLock {
            guard frameSize != (width, height) || last == nil else { return }
            frameSize = (width, height)
            ass_set_frame_size(renderer, Int32(width), Int32(height))
            ass_set_storage_size(renderer, Int32(videoWidth), Int32(videoHeight))
            last = nil
        }
    }

    /// The subtitles at `seconds` into the video; nil while none show. The
    /// same frame as last time is handed back, without drawing, when libass
    /// says nothing changed.
    public func frame(at seconds: Double) -> Frame? {
        lock.withLock {
            guard frameSize.width > 0, frameSize.height > 0 else { return nil }
            var change: Int32 = 0
            let images = ass_render_frame(renderer, track, Int64((seconds * 1000).rounded()), &change)
            if change == 0, images != nil {
                return last
            }
            last = images.flatMap(Self.composite)
            return last
        }
    }

    /// libass's pictures are masks with one colour each, in a list; this lays
    /// them over one another into a single premultiplied RGBA picture over
    /// the box they cover together.
    private static func composite(_ first: UnsafeMutablePointer<ASS_Image>) -> Frame? {
        let pieces = sequence(first: first) { $0.pointee.next }.map(\.pointee).filter { $0.w > 0 && $0.h > 0 }
        let bounds = pieces.reduce(CGRect.null) {
            $0.union(CGRect(x: Int($1.dst_x), y: Int($1.dst_y), width: Int($1.w), height: Int($1.h)))
        }
        guard !bounds.isNull else { return nil }

        var canvas = Canvas(bounds: bounds)
        for piece in pieces {
            canvas.blend(piece)
        }
        return canvas.image().map { Frame(image: $0, rect: bounds) }
    }
}

/// Premultiplied RGBA pixels over a box of the frame.
private struct Canvas {

    let originX: Int
    let originY: Int
    let width: Int
    let height: Int
    var pixels: [UInt8]

    init(bounds: CGRect) {
        originX = Int(bounds.minX)
        originY = Int(bounds.minY)
        width = Int(bounds.width)
        height = Int(bounds.height)
        pixels = [UInt8](repeating: 0, count: width * height * 4)
    }

    /// One of libass's masks in its colour, over what is there.
    mutating func blend(_ piece: ASS_Image) {
        guard let bitmap = piece.bitmap else { return }
        // RGBA, where A is how transparent the colour is.
        let red = UInt32(piece.color >> 24 & 0xFF)
        let green = UInt32(piece.color >> 16 & 0xFF)
        let blue = UInt32(piece.color >> 8 & 0xFF)
        let opacity = 255 - UInt32(piece.color & 0xFF)
        guard opacity > 0 else { return }

        let (width, originX, originY) = (width, originX, originY)
        pixels.withUnsafeMutableBufferPointer { out in
            for row in 0 ..< Int(piece.h) {
                let source = bitmap + row * Int(piece.stride)
                var at = ((Int(piece.dst_y) - originY + row) * width + Int(piece.dst_x) - originX) * 4
                for column in 0 ..< Int(piece.w) {
                    let alpha = UInt32(source[column]) * opacity / 255
                    if alpha > 0 {
                        let keep = 255 - alpha
                        out[at] = UInt8((red * alpha + UInt32(out[at]) * keep) / 255)
                        out[at + 1] = UInt8((green * alpha + UInt32(out[at + 1]) * keep) / 255)
                        out[at + 2] = UInt8((blue * alpha + UInt32(out[at + 2]) * keep) / 255)
                        out[at + 3] = UInt8(alpha + UInt32(out[at + 3]) * keep / 255)
                    }
                    at += 4
                }
            }
        }
    }

    func image() -> CGImage? {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
