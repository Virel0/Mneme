# Security

## Reporting a vulnerability

Please report security problems privately, through
[GitHub's private vulnerability reporting](https://github.com/Virel0/Mneme/security/advisories/new),
not in a public issue. Include what an attacker could do, the steps to reproduce it, and the
version and build from Settings → About.

Once a fix is out, the advisory is published with credit to you unless you would rather stay
anonymous.

Problems in [Melete](https://github.com/Virel0/Melete) or in
[AetherEngine](https://github.com/superuser404notfound/AetherEngine) belong to those projects;
report them there.

## What Mneme can reach

- **Your Melete server, and nothing else.** Every request goes to the address you sign in to.
  Artwork, AI search, requests and conversions all go through Melete; the app holds no key for
  any outside service, and there is no analytics or crash-reporting service.
- **The local network**, to reach a Melete server on it. tvOS asks before the first connection.
- **The app group** it shares with its Top Shelf extension: the rows the home screen shows and
  their pictures. Nothing else is written there.

## What Mneme keeps

- **Session tokens**, one per person signed in, in the keychain only. A token is Melete's to
  revoke: signing out ends it on the server too.
- **On the device**: the server address and user name of each session, the last home screen of
  each person, and the playback settings.
- **Diagnostics** are kept in memory and leave the device only when you press Send Diagnostics,
  and then only to your Melete server, which removes anything that looks like a secret.

If you find any of these not holding, that is a security report.
