# Against the Jellyfin app

What the Jellyfin fork of Mneme did, and where the Melete app stands on each:

- Done: in the app.
- Melete: waits on something the server does not offer yet.
- Not built: the app's own work still to do.

## Home and browsing

| Feature | Melete app | Note |
|---|---|---|
| Hero: logo, facts, Play that says what it does, More Info, My List, stepping and rotation | Done | |
| Muted trailer in the hero and the spotlight | Melete | Trailers are YouTube links and off by default (`MELETE_TRAILERS_ONLINE`); the player plays files |
| Continue Watching, Next Up, My List, latest per library | Done | From `/home` |
| Featured for You (picks by a language model) | Melete | No recommendations endpoint; a marker shows in debug builds |
| Because You Watched | Not built | `/discover/similar/{id}` answers it when Melete has discovery on |
| Popular Right Now | Done, moved | Trending, on Search |
| Tiles lift, the spotlight shows the focused title above the rows | Done | Without the clip |
| Home drawn at once from a copy on disk | Not built | Home is one request now, so the wait is short |
| Shows, Anime and Movies with their own hero and an A to Z grid | Done | |
| Genre rail and unwatched shelf on the browse tabs | Not built | `/browse/genres` and `genre=` exist |
| Two-pane season and episode picker that holds still | Done | |
| Cast, crew, extras and collections on a title's page | Not built | `/credits`, `/extras`, `/collections/{id}`, `/people/{id}` exist |
| Profiles: switching and adding from the chip | Done | |
| "Who's watching?" at launch, a default profile | Not built | The app opens as whoever used it last |
| Top Shelf | Done | |

## Artwork

| Feature | Melete app | Note |
|---|---|---|
| Logos and textless backdrops from TMDB | Done | Melete chooses them; no key on the device |
| Backdrops cropped around their subject | Done | Melete's focal point, by edge strength, in place of the vision model |
| One badge per tile: new, unwatched | Done | Melete's rule: unwatched only for a series being watched |

## Finding things

| Feature | Melete app | Note |
|---|---|---|
| Search by name | Done | |
| A language model finds titles from a description | Done | Find by Description, on Melete's key; asked for rather than automatic |
| Requests for titles not in the library | Done | Melete's own requests, not Jellyseerr |
| Your requests and how they are getting on | Done | Live, from the event stream |

## Playback

| Feature | Melete app | Note |
|---|---|---|
| AetherEngine, direct play, resume | Done | |
| Audio and subtitle choice, remembered for the series | Done | Melete's track pick and track choice |
| Skip recap, intro, preview; next episode at the credits | Done | |
| Auto play next and auto skip | Done | Settings of the device until Melete keeps them per person |
| Seek-bar previews | Done | Melete's trickplay sheets |
| Diagnostics report with the engine's timings | Done | Sent to Melete |
| Playback speed | Not built | |
| Chapters on the seek bar | Not built | `/files/{id}` lists them |
| Subtitle size and style | Not built | |
| Resume a few seconds early | Not built | |

## Platforms

| Feature | Melete app | Note |
|---|---|---|
| Apple TV | Done | |
| iPhone and iPad | Not built | After the Apple TV app replaces the Jellyfin one |
