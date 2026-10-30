//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation
import MeleteKit
import Observation

/// Which of the Watch pages: the home, or the home narrowed to one kind.
enum WatchKind: String, CaseIterable, Hashable, Sendable {
    case home
    case shows
    case anime
    case movies

    var title: String {
        switch self {
        case .home: "Home"
        case .shows: "Shows"
        case .anime: "Anime"
        case .movies: "Movies"
        }
    }
}

/// What the signed-in user's pages share: the home, which series are anime,
/// what is on My List, and the titles looked up so far.
///
/// One per session, so switching tabs never asks the server twice for what a
/// page has already shown.
@MainActor
@Observable
final class Library {

    enum HomeState {
        case loading
        case loaded(WatchHome)
        case failed(MeleteError)
    }

    let client: MeleteClient

    private(set) var home: HomeState = .loading
    /// Every anime series' id; nil until known.
    private(set) var animeIDs: Set<Int>?
    private(set) var favourites: Set<TitleRef> = []
    /// The series in Continue Watching or Next Up: the ones being watched.
    private(set) var watching: Set<TitleRef> = []
    /// Raised by every change to My List, so its page knows to reload.
    private(set) var favouritesVersion = 0

    /// Raised when titles come or go, so lists of everything reload.
    private(set) var libraryVersion = 0
    /// The viewer's requests as the event stream last sent them; nil until
    /// it has.
    private(set) var requests: [MediaRequest]?

    private var completed: [TitleRef: TitleSummary] = [:]
    private var lastLibraryVersion: Int?
    private var lastFavouritesVersion: Int?

    init(client: MeleteClient) {
        self.client = client
    }

    // MARK: - Home

    func load() async {
        async let home = client.home()
        async let anime = client.animeSeriesIDs()
        async let favourites = client.favourites(limit: 500)

        do {
            let home = try await home
            self.home = .loaded(home)
            let client = client
            Task { await TopShelfPublisher.publish(home, client: client) }
            watching = Set(
                home.rows
                    .filter { $0.key == .continueWatching || $0.key == .nextUp }
                    .flatMap(\.items)
                    .filter { $0.kind == .series }
                    .map { TitleRef(kind: $0.kind, id: $0.id) }
            )
        } catch {
            // `async let` drops the typed throw; every error here is Melete's.
            self.home = .failed(error as? MeleteError ?? .transport(error.localizedDescription))
        }
        // The pages work without these, so a failure leaves them as they were.
        if let anime = try? await anime {
            animeIDs = anime
        }
        if let favourites = try? await favourites {
            self.favourites = Set(favourites.items.map { TitleRef(kind: $0.kind, id: $0.id) })
        }
    }

    func kind(of ref: TitleRef) -> WatchKind {
        switch ref.kind {
        case .movie: .movies
        case .series: animeIDs?.contains(ref.id) == true ? .anime : .shows
        }
    }

    /// The home's word on a title being watched: its entry in Continue
    /// Watching or Next Up, which says the episode to play and how far
    /// through it is.
    func watchingEntry(for ref: TitleRef) -> TitleSummary? {
        guard case let .loaded(home) = home else { return nil }
        for key in [WatchHomeRow.Key.continueWatching, .nextUp] {
            if let item = home.rows.first(where: { $0.key == key })?.items.first(where: { $0.kind == ref.kind && $0.id == ref.id }) {
                return TitleSummary(item)
            }
        }
        return nil
    }

    // MARK: - Live updates

    /// Follows Melete's event stream for as long as the session is up,
    /// reconnecting when it ends (Melete closes it every ten minutes) or
    /// fails. Pages work without it; it saves them going stale.
    func listen() async {
        while !Task.isCancelled {
            do {
                for try await event in client.events() {
                    await handle(event)
                }
            } catch {
                // Down or refused: wait longer before trying again.
                try? await Task.sleep(for: .seconds(20))
            }
            try? await Task.sleep(for: .seconds(2))
        }
    }

    /// Each kind arrives once at the start, which only sets where things
    /// stand, and again on every change.
    private func handle(_ event: ServerEvent) async {
        switch event.name {
        case "library":
            guard let library = event.decode(LibraryVersion.self) else { return }
            defer { lastLibraryVersion = library.version }
            guard let last = lastLibraryVersion, last != library.version else { return }
            libraryVersion += 1
            await load()

        case "favourites":
            guard let favourites = event.decode(FavouritesVersion.self) else { return }
            defer { lastFavouritesVersion = favourites.version }
            guard let last = lastFavouritesVersion, last != favourites.version,
                  let list = try? await client.favourites(limit: 500)
            else { return }
            self.favourites = Set(list.items.map { TitleRef(kind: $0.kind, id: $0.id) })
            favouritesVersion += 1

        case "requests":
            requests = event.decode([MediaRequest].self)

        default:
            break
        }
    }

    // MARK: - My List

    func isFavourite(_ ref: TitleRef) -> Bool {
        favourites.contains(ref)
    }

    /// Flips My List at once and tells the server after, putting it back if
    /// the server says no.
    func toggleFavourite(_ ref: TitleRef) async {
        let wanted = !favourites.contains(ref)
        setLocally(ref, wanted)

        do {
            let state = try await client.setFavourite(ref.kind, ref.id, wanted)
            setLocally(ref, state.favourite)
        } catch {
            setLocally(ref, !wanted)
        }
    }

    private func setLocally(_ ref: TitleRef, _ isFavourite: Bool) {
        guard favourites.contains(ref) != isFavourite else { return }
        if isFavourite {
            favourites.insert(ref)
        } else {
            favourites.remove(ref)
        }
        favouritesVersion += 1
    }

    // MARK: - Titles

    /// A list entry with its facts and artwork filled in, from its page.
    /// Asked once per title for the session.
    func complete(_ summary: TitleSummary) async -> TitleSummary {
        if summary.isComplete {
            return summary
        }
        if let known = completed[summary.ref] {
            return known
        }

        let full: TitleSummary? = switch summary.kind {
        case .movie: try? await summary.completed(with: client.movie(summary.ref.id))
        case .series: try? await summary.completed(with: client.series(summary.ref.id))
        }
        guard let full else { return summary }
        completed[summary.ref] = full
        return full
    }
}
