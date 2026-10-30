<div align="center">

<img src="docs/brand/banner.png" alt="Mneme" width="100%">

**The Apple TV app for [Melete](https://github.com/Virel0/Melete).**

[![CI](https://github.com/Virel0/Mneme/actions/workflows/ci.yml/badge.svg)](https://github.com/Virel0/Mneme/actions/workflows/ci.yml)
[![tvOS 26.1+](https://img.shields.io/badge/tvOS-26.1%2B-7C5CFF?logo=apple&logoColor=white)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-SwiftUI-5EE7F0?logo=swift&logoColor=white)](https://developer.apple.com/swift/)
[![License: MPL-2.0](https://img.shields.io/badge/license-MPL--2.0-5EE7F0)](LICENSE.md)

[Features](#features) · [Requirements](#requirements) · [Install](#install) · [Privacy](#privacy) · [Design](docs/DESIGN.md) · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md)

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

## Install

Mneme is not on the App Store. To run it, build it:

1. Check out [Melete](https://github.com/Virel0/Melete) beside this repository: the API client's
   tests read its `src/api/openapi.json`.
2. Put your team and a bundle identifier of your own in `XcodeConfig/DevelopmentTeam.xcconfig`
   (gitignored):

   ```
   DEVELOPMENT_TEAM = ABCDE12345
   MNEME_APP_ID = com.example.mneme
   ```

3. Open `Mneme.xcodeproj`, choose your Apple TV, and run the Mneme scheme.
4. On the Apple TV, enter your Melete server's address and approve the Quick Connect code in
   Melete's web interface (Your account → Quick Connect), or sign in with a password.

## Privacy

Mneme talks to your Melete server and nothing else: no analytics, no crash reporting, and no keys
for outside services. Artwork, AI search, requests and conversions all go through Melete, which
decides what, if anything, leaves your network.

On the Apple TV it keeps each person's session token in the keychain, the server address and
user name, the last home screen per person, and your playback settings. A diagnostics report
leaves the device only when you send one from Settings, and only to your Melete server. The
details are in [SECURITY.md](SECURITY.md).

## License

[Mozilla Public License 2.0](LICENSE.md).
