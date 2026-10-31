# Against the Jellyfin app

What the Jellyfin fork of Mneme did, and where the Melete app stands on each:

- Done: in the app.
- Melete: waits on something the server does not offer yet.
- Not built: the app's own work still to do.

## Home and browsing

| Feature | Melete app | Note |
|---|---|---|
| Hero: logo, facts, Play that says what it does, More Info, My List, stepping and rotation | Done | |
| A quiet clip of the title in the hero and the spotlight | Done | Melete's 720p conversion of the title itself, on the home network only |
| Continue Watching, Next Up, My List, latest per library | Done | From `/home` |
| Because You Watched | Done | Melete's rows, one for each finished title; Mneme's own for a server before 0.2.0 |
| Featured for You (picks by a language model) | Done | Melete's row, when an admin has AI picks on |
| Popular Right Now | Done, moved | Trending, on Search |
| Tiles lift, the spotlight shows the focused title above the rows | Done | |
| Home drawn at once from a copy on the device | Done | |
| Shows, Anime and Movies with their own hero and an A to Z grid | Done | |
| Sorting and genres on the browse tabs | Done | A to Z, newest, recently added; one genre at a time |
| Two-pane season and episode picker that holds still | Done | |
| Cast and crew, with a page per person | Done | |
| Extras and collections on a title's page | Done | |
| File details on a title's page | Done | |
| Start over instead of resuming | Done | |
| Profiles: switching and adding from the chip | Done | |
| "Who's watching?" at launch | Done | With more than one person signed in; can be turned off |
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
| A language model finds titles from a description | Done | Find by Description, on Melete's key |
| Requests for titles not in the library | Done | Melete's own requests, not Jellyseerr |
| Your requests and how they are getting on | Done | Live, from the event stream |

## Playback

| Feature | Melete app | Note |
|---|---|---|
| AetherEngine, direct play, resume | Done | |
| A quality limit, converted to fit | Done | Melete's conversion; also when a connection from outside has a limit |
| Audio and subtitle choice, remembered for the series | Done | Melete's track pick and track choice |
| Audio and subtitle languages | Done | Kept by Melete, for every device |
| Skip recap, intro, preview; next episode at the credits | Done | |
| Auto play next and auto skip | Done | Auto play and its countdown kept by Melete per person; auto skip a setting of the device |
| Seek-bar previews | Done | Melete's trickplay sheets |
| Chapters on the seek bar | Done | |
| Playback speed | Done | |
| Subtitle size | Done | |
| Resume a few seconds early | Done | |
| Diagnostics report with the engine's timings | Done | Sent to Melete |

## Account

| Feature | Melete app | Note |
|---|---|---|
| Quick Connect and password sign-in | Done | With a two-factor code for an account that has it on |
| Approve another device's Quick Connect code | Done | |

## Not carried across

| Feature | Why |
|---|---|
| Server administration: users, devices, logs, tasks, metadata editing | Melete's web interface does these |
| Live TV and the programme guide | Melete has no live TV |
| Poster styles, accent colour, indicator choices | Mneme has one look |
| Touch gestures and toolbar buttons of the iPhone player | Not on a television |
| The iPhone and iPad app | After the Apple TV app replaces the Jellyfin one |
