//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

@testable import MeleteKit
import Testing

struct ArtworkKindTests {

    @Test
    func `asks for the smallest size that fills the picture`() {
        #expect(ArtworkKind.poster.path("/api/v1/artwork/w342/a.jpg", filling: 300) == ("/api/v1/artwork/w342/a.jpg", false))
        #expect(ArtworkKind.poster.path("/api/v1/artwork/w342/a.jpg", filling: 443) == ("/api/v1/artwork/w500/a.jpg", false))
        #expect(ArtworkKind.poster.path("/api/v1/artwork/w500/a.jpg", filling: 700) == ("/api/v1/artwork/w780/a.jpg", false))
        #expect(ArtworkKind.profile.path("/api/v1/artwork/w185/p.jpg", filling: 360) == ("/api/v1/artwork/h632/p.jpg", false))
    }

    @Test
    func `asks for the largest size when none is wide enough`() {
        #expect(ArtworkKind.poster.path("/api/v1/artwork/w342/a.jpg", filling: 2000) == ("/api/v1/artwork/w780/a.jpg", false))
        #expect(ArtworkKind.backdrop.path("/api/v1/artwork/w1280/b.jpg", filling: 3840) == ("/api/v1/artwork/original/b.jpg", true))
        #expect(ArtworkKind.still.path("/api/v1/artwork/w300/s.jpg", filling: 797) == ("/api/v1/artwork/original/s.jpg", true))
        #expect(ArtworkKind.logo.path("/api/v1/artwork/w500/l.png", filling: 1040) == ("/api/v1/artwork/original/l.png", true))
    }

    @Test
    func `sizes a title's own picture the same way`() {
        let local = "/api/v1/artwork/w1280/local-0123456789abcdef0123456789abcdef.jpg"
        #expect(ArtworkKind.backdrop.path(local, filling: 3840)
            .path == "/api/v1/artwork/original/local-0123456789abcdef0123456789abcdef.jpg")
    }

    @Test
    func `leaves other addresses as they are`() {
        // Another kind's size, which Melete would answer with a 404.
        #expect(ArtworkKind.still.path("/api/v1/artwork/w342/a.jpg", filling: 800) == ("/api/v1/artwork/w342/a.jpg", false))
        #expect(ArtworkKind.poster.path("/api/v1/me/avatar/picture.png", filling: 800) == ("/api/v1/me/avatar/picture.png", false))
        #expect(ArtworkKind.poster.path("/api/v1/artwork/w342", filling: 800) == ("/api/v1/artwork/w342", false))
    }
}
