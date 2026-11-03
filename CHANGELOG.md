# Changelog

Every TestFlight build of Mneme, newest first, in the
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. The marketing version is 1.0;
builds are numbered, and each one is tagged `v1.0-build.N` when it ships. Builds 1 to 9 were
the Jellyfin app this one replaces. Each entry lists what a viewer would notice, not every
commit.

## [Unreleased]

## [1.0 build 12] - 2026-11-02

### Added
- A Requests tab: every film and series you've asked for, by where it has got to, each opening
  its progress.
- Top Shelf shows each title's logo, details and overview on its picture.
- Shows, Anime and Movies have their own rows from Melete, Because You Watched included, and
  Home gains New Episodes, Next in the Collection, Highly Rated and Watch Again, when the server
  has them.
- Your Melete profile picture on the profile button and on Who's Watching, when the server has
  profile pictures.

### Changed
- The tabs run Home, Movies, Shows, Anime, My List, Requests, Search.
- The playback engine is AetherEngine 7.54.0, up from 7.42.0.

### Fixed
- Opening a title no longer flashes a stretched poster over the page.
- A title's page plays its trailer only when it's sharp enough for the film (1080p, or as sharp
  as the film itself); otherwise a clip of the film.

## [1.0 build 11] - 2026-11-02

### Changed
- Mneme is now under the GNU General Public License, version 3 or later, as Melete is.
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
- Because You Watched on Home, sorting and genres on Shows, Anime and Movies, and a clip of the
  title in the hero and the spotlight on the home network, at full quality and with its sound.
- Find by Description on Search, when the server has AI on.
- Audio and subtitle languages kept by Melete, approving another device's Quick Connect code, and
  Who's Watching at launch.
- Home and My List follow changes made elsewhere as they happen, and the home is drawn at once
  from the copy kept on the device.
- An intro when the app opens, skipped by any press.
- Opening a title grows its tile into the page, title pages drift slowly, playback fades up from
  black, and loading shows Mneme's own mark.
- Pictures of the Muses in neon line on the sign-in screen, an empty My List, a failed load, a file
  that can't be played and a search with no matches, and in the Top Shelf.
- Drifting light behind "Who's Watching?".
- Pages sit on a night sky, with now and then a shooting star. It moves gently against the focus,
  and its colour follows the time of day.
- The screen takes the colour of the title you're on.
- Left alone on Home, Mneme shows the hero's titles full screen with their trailers.
- A title's page plays its trailer behind the header, and the hero and spotlight drift slowly.
- The Top Shelf shows the hero's titles as a full-width carousel with muted trailer previews.
- The hero plays the title's trailer when its folder has one, as Melete's hero trailers setting says.
- Tabs crossfade, and the home comes up out of the intro.
- Two-factor sign-in: an account with it on is asked for the authenticator's code.
- Featured for You and Melete's Because You Watched rows on Home, and More Like This on a title's page.
- "Melete converts surround sound" in Settings, for TrueHD and DTS soundtracks.
- Playing the next episode, and its countdown, follow your choice in Melete on every device.
- A request being copied home shows how far it has got.
- Each request has its own page: who decided, every step it has been through, Melete's latest word,
  and a series season by season. A waiting request can be taken back or changed, and a series can be
  asked for one season.

### Not yet back
- The iPhone and iPad app.

[Unreleased]: https://github.com/Virel0/Mneme/compare/v1.0-build.12...main
[1.0 build 12]: https://github.com/Virel0/Mneme/commits/v1.0-build.12
[1.0 build 11]: https://github.com/Virel0/Mneme/commits/v1.0-build.11
