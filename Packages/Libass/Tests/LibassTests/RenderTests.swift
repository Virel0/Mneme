//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import Libass
import Testing

/// The whole stack at work: the script parsed, a font found through
/// CoreText, the line shaped by HarfBuzz and drawn by FreeType.
struct RenderTests {

    static let script = """
    [Script Info]
    ScriptType: v4.00+
    PlayResX: 1920
    PlayResY: 1080

    [V4+ Styles]
    Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
    Style: Default,Helvetica,64,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,3,0,2,40,40,60,1

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.00,0:00:04.00,Default,,0,0,0,,{\\an8\\pos(960,200)}Hello, مرحبا
    """

    @Test
    func `a dialogue line is drawn while it is up and not after`() throws {
        let library = try #require(ass_library_init())
        defer { ass_library_done(library) }
        let renderer = try #require(ass_renderer_init(library))
        defer { ass_renderer_done(renderer) }
        ass_set_frame_size(renderer, 1920, 1080)
        ass_set_fonts(renderer, nil, "sans-serif", Int32(ASS_FONTPROVIDER_CORETEXT.rawValue), nil, 0)

        var bytes = Array(Self.script.utf8CString)
        let track = try #require(bytes.withUnsafeMutableBufferPointer {
            ass_read_memory(library, $0.baseAddress, $0.count - 1, nil)
        })
        defer { ass_free_track(track) }
        #expect(track.pointee.n_events == 1)

        var change: Int32 = 0
        let shown = try #require(ass_render_frame(renderer, track, 2000, &change))
        #expect(shown.pointee.w > 0 && shown.pointee.h > 0)
        // Placed by \pos: centred on x 960, its top at y 200.
        #expect(abs(Int(shown.pointee.dst_x) + Int(shown.pointee.w) / 2 - 960) < 80)
        #expect(abs(Int(shown.pointee.dst_y) - 200) < 40)

        #expect(ass_render_frame(renderer, track, 5000, &change) == nil)
    }
}
