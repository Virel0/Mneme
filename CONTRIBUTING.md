# Contributing

Thanks for wanting to help. Mneme is the Apple TV app for [Melete](https://github.com/Virel0/Melete);
anything it shows comes from Melete's API, so a feature the server does not offer starts there.

## Before you start

- For anything larger than a small fix, open an issue first so the approach can be agreed.
- Security problems go through [private reporting](SECURITY.md), never an issue.

## Layout

| Path | What it is |
|---|---|
| `MeleteKit/` | The API client: Melete's models and endpoints, and the playback rules. A Swift package with its own tests |
| `Mneme/` | The tvOS app: screens, components, the player, services |
| `MnemeTopShelf/` | The Top Shelf extension |
| `Shared/` | Code both the app and the extension use |
| `docs/DESIGN.md` | Every decision, with its reason |

## Building

Check out Melete beside this repository (the client's tests read its `src/api/openapi.json`),
put your team and bundle identifier in `XcodeConfig/DevelopmentTeam.xcconfig` (gitignored), and
open `Mneme.xcodeproj`.

## Checks

CI runs these on every pull request; run them before you push, with SwiftFormat at the version
named at the top of `.swiftformat` (CI downloads exactly that release):

```sh
swiftformat --lint .
cd MeleteKit && swift test
```

and build the Mneme scheme for the tvOS simulator. CI also reports Swift files over 800 lines and
functions over 100, as warnings.

## Pull requests

- One change per pull request, squash-merged into `main`.
- A model added to MeleteKit goes into `ContractTests` with its schema's name, so it is held to
  Melete's contract.
- A decision a reader would ask "why?" about goes into `docs/DESIGN.md`.
- Keep the code's comments about the code: no personal details, server addresses, keys or names
  of people.
