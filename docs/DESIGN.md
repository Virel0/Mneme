# Mneme design

Mneme is the Apple TV app for [Melete](https://github.com/Virel0/Melete). This file records the
decisions behind it and the reasons, newest last. A decision changes by adding a row that
replaces it, not by editing the old one.

| # | Decision | Because | Date |
|---|---|---|---|
| 1 | Mneme talks only to Melete, through its documented API (`/api/v1`, contract in Melete's `src/api/openapi.json`). No Jellyfin support | One server to follow means one set of types and no compatibility layer; Melete's API was written with this app as a client | 2026-10-30 |
| 2 | Built new rather than adapted from Swiftfin, the Jellyfin app the previous Mneme was a fork of. Mneme's own screens (hero, tile rows, the focused title's spotlight, tab strip) are carried across and rebuilt on Melete's types | About four fifths of the fork was Swiftfin's Jellyfin plumbing, and Melete answers most of what that plumbing assembled (`/home` is the whole home in one request) | 2026-10-30 |
| 3 | Apple TV first. iOS and iPadOS come after the Apple TV app replaces the Jellyfin one | The television is where the app is used; the fork's iOS app was Swiftfin's, unchanged | 2026-10-30 |
| 4 | The API client is its own package, `MeleteKit`, with hand-written models. Its tests read `src/api/openapi.json` from a Melete checkout beside this repository (or `MELETE_OPENAPI`), build a full value from each schema, decode it, encode it again and require the same keys back, so a model that drifts from the contract fails `swift test` | Hand-written models stay readable and small; a generator would add a dependency for the same guarantee. Melete keeps its contract the same way | 2026-10-30 |
| 5 | The Xcode project uses synchronized folders: files under `Mneme/` belong to the app without being listed in the project file | A project file that lists nothing rarely conflicts, and needs no generator tool | 2026-10-30 |
| 6 | Signing in is Quick Connect first, a password second. Each person who signs in on the device keeps a session: the session in user defaults, its token only in the keychain | Typing a password with a remote is the worst part of a TV app. Melete issues a token per device, so profiles on one Apple TV are separate sessions | 2026-10-30 |
| 7 | Mneme stays under the Mozilla Public License 2.0 | Files carried across from the fork were published under it, and it sits well beside Melete's GPL | 2026-10-30 |
| 8 | The bundle identifier and build numbers carry on from the Jellyfin app (first build 10) | TestFlight testers get the new app as an update, not a second app | 2026-10-30 |
