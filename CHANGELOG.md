# Changelog

Every TestFlight build of Mneme, newest first, in the
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. The marketing version is 1.0;
builds are numbered, and each one is tagged `v1.0-build.N` when it ships. Builds 1 to 9 were
the Jellyfin app this one replaces. Each entry lists what a viewer would notice, not every
commit.

## [Unreleased]

### Changed
- Mneme is now the app for Melete. It signs in to a Melete server (Quick Connect, or a
  password) instead of Jellyfin, and everyone signs in again once.
- Artwork, AI search and requests come from Melete: nothing to set up on the Apple TV.
- Requests are Melete's own, from Search, and show how each is getting on as it downloads.

### Added
- Play says what it will do: "Resume S2:E4 · 23m left", "Play S3:E1", "Play Again", and From
  the Start beside Resume.
- A click on the remote's edge jumps ten seconds; a swipe scrubs over seek-bar previews; a tap
  brings up the controls.
- Skip Intro and Next Episode are buttons that take focus when they appear.
- A quality limit, chapters, playback speed, subtitle size, and resuming a few seconds early.
- Cast and crew with a page per person, extras, collections and file details on a title's page.
- Because You Watched on Home, sorting and genres on Shows, Anime and Movies, and a quiet clip of
  the title in the hero and the spotlight on the home network.
- Find by Description on Search, when the server has AI on.
- Audio and subtitle languages kept by Melete, approving another device's Quick Connect code, and
  Who's Watching at launch.
- Home and My List follow changes made elsewhere as they happen, and the home is drawn at once
  from the copy kept on the device.

### Not yet back
- Featured for You, which needs a recommendations endpoint in Melete.
- The iPhone and iPad app.

[Unreleased]: https://github.com/Virel0/Mneme/commits/main
