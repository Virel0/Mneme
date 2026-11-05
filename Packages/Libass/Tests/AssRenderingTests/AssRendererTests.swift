//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import AssRendering
import CoreGraphics
import Foundation
import Testing

struct AssRendererTests {

    /// Yellow (ASS colours are &HAABBGGRR), with no outline or shadow, so
    /// every drawn pixel is the line's own colour.
    static let script = """
    [Script Info]
    ScriptType: v4.00+
    PlayResX: 1920
    PlayResY: 1080

    [V4+ Styles]
    Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
    Style: Sign,Helvetica,80,&H0000FFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.00,0:00:04.00,Sign,,0,0,0,,{\\pos(300,200)}SIGN
    """

    private func renderer() throws -> AssRenderer {
        let renderer = try #require(AssRenderer(script: Self.script))
        renderer.setFrame(width: 1920, height: 1080, videoWidth: 1920, videoHeight: 1080)
        return renderer
    }

    @Test
    func `a placed line is drawn where it was put, in its colour`() throws {
        let frame = try #require(try renderer().frame(at: 2))
        // \an7 with \pos: the top-left corner at 300, 200.
        #expect(abs(frame.rect.minX - 300) < 20)
        #expect(abs(frame.rect.minY - 200) < 30)

        let pixels = try #require(Self.pixels(of: frame.image))
        let solid = stride(from: 0, to: pixels.count, by: 4).filter { pixels[$0 + 3] == 255 }
        #expect(!solid.isEmpty)
        for at in solid {
            #expect(pixels[at] == 255 && pixels[at + 1] == 255 && pixels[at + 2] == 0)
        }
    }

    @Test
    func `nothing is drawn once the line is over`() throws {
        let renderer = try renderer()
        #expect(renderer.frame(at: 2) != nil)
        #expect(renderer.frame(at: 5) == nil)
    }

    @Test
    func `a frame that hasn't changed is handed back without drawing again`() throws {
        let renderer = try renderer()
        let first = try #require(renderer.frame(at: 2))
        let second = try #require(renderer.frame(at: 2.5))
        #expect(first.image === second.image)
    }

    @Test
    func `a script with nothing in it gives no renderer`() {
        #expect(AssRenderer(script: "not a subtitle script") == nil)
    }

    @Test
    func `the licences come with the package`() {
        #expect(Acknowledgements.libraries.map(\.name) == ["libass", "FreeType", "HarfBuzz", "FriBidi"])
        for library in Acknowledgements.libraries {
            #expect(library.text.count > 200, "\(library.name)")
        }
        #expect(Acknowledgements.libraries.contains { $0.credit?.contains("FreeType Project") == true })
    }

    private static func pixels(of image: CGImage) -> [UInt8]? {
        guard let data = image.dataProvider?.data as Data? else { return nil }
        return Array(data)
    }
}
