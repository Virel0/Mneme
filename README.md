<div align="center">

<img src="docs/brand/banner.png" alt="Mneme" width="100%">

**The Apple TV app for [Melete](https://github.com/Virel0/Melete).**

[![tvOS 26.1+](https://img.shields.io/badge/tvOS-26.1%2B-7C5CFF?logo=apple&logoColor=white)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-SwiftUI-5EE7F0?logo=swift&logoColor=white)](https://developer.apple.com/swift/)
[![License: MPL-2.0](https://img.shields.io/badge/license-MPL--2.0-5EE7F0)](LICENSE.md)

[Features](#features) · [Requirements](#requirements) · [Build it](#build-it) · [Design](docs/DESIGN.md) · [Changelog](CHANGELOG.md)

</div>

## Why "Mneme"

Mneme was one of the three original Muses: the Muse of memory. Melete, the server, is named for
another of them. The app is built around remembering: it opens on what you were part-way through,
shows the next episode before you ask, and picks up at the second you stopped.

## Features

- **Home**: a hero for one title at a time with Play that says what it will do ("Resume S2:E4 ·
  23m left"), then Continue Watching, Next Up, My List and the latest arrivals.
- **Shows, Anime and Movies**: the home narrowed to each, then every title A to Z.
- **The spotlight**: a focused tile lifts, and its title's backdrop, logo, facts and logline
  appear at the top of the screen, so the whole row stays in view.
- **Title pages**: a series' seasons and episodes in two panes that hold still while you move.
- **Playback** with [AetherEngine](https://github.com/superuser404notfound/AetherEngine)
  (FFmpeg into VideoToolbox): direct play, your audio and subtitle languages, Skip Intro, the
  next episode at the credits, seek-bar previews, and a diagnostics report for every stall.
- **Search**: titles in the library as you type, the rest from TMDB ready to request, and finding
  titles by describing them when the server has AI on.
- **Profiles** for everyone who signs in on the Apple TV, with Quick Connect, and a **Top Shelf**
  on the home screen.

## Requirements

- An Apple TV on tvOS 26.1 or later.
- A Melete server. Artwork, AI search and requests are set up on the server; the app needs only
  its address.

## Build it

1. Check out [Melete](https://github.com/Virel0/Melete) beside this repository: the API client's
   tests read its `src/api/openapi.json`.
2. Copy your team and bundle identifier into `XcodeConfig/DevelopmentTeam.xcconfig` (gitignored):

   ```
   DEVELOPMENT_TEAM = ABCDE12345
   MNEME_APP_ID = com.example.mneme
   ```

3. Open `Mneme.xcodeproj` and run the Mneme scheme, or test the client with
   `cd MeleteKit && swift test`.

## License

[Mozilla Public License 2.0](LICENSE.md).
