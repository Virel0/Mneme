//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import SwiftUI

/// The app's tabs.
enum AppTab: Hashable, CaseIterable {
    case home
    case shows
    case anime
    case movies
    case myList

    var title: String {
        switch self {
        case .home: "Home"
        case .shows: "Shows"
        case .anime: "Anime"
        case .movies: "Movies"
        case .myList: "My List"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .shows: "tv"
        case .anime: "sparkles.tv"
        case .movies: "film"
        case .myList: "checkmark.circle"
        }
    }

    var watchKind: WatchKind? {
        switch self {
        case .home: .home
        case .shows: .shows
        case .anime: .anime
        case .movies: .movies
        case .myList: nil
        }
    }
}

/// Where focus is in the strip: a tab, or the profile chip.
enum NavStripFocus: Hashable {
    case tab(AppTab)
    case profile
}

/// The tab bar, as an ordinary row of buttons.
///
/// tvOS draws the current tab and the focused tab of its own bar as two
/// nearly identical pale capsules, and neither can be styled. Here they are
/// what they should be from across a room:
///
/// - the tab you are on, while focus is in the page: a translucent pill;
/// - whatever the remote is on: a solid white pill with a black label;
/// - everything else: a white label and no pill.
///
/// Every entry has the same padding with or without a pill, so moving along
/// the strip changes colours and never moves anything.
struct NavStrip: View {

    /// Owned by the page around the strip, because Menu pressed in the page
    /// has to bring focus back up here, and that press arrives at the page.
    @FocusState.Binding
    var focused: NavStripFocus?

    let selected: AppTab
    let userInitial: String
    let select: (AppTab) -> Void
    let openProfile: () -> Void

    private static let labelSize: CGFloat = 30
    private static let avatarEdge: CGFloat = 44
    /// How far the capsule rises into the top margin, clear of the hero.
    private static let lift: CGFloat = 36

    var body: some View {
        HStack(spacing: 0) {
            profileChip

            // The chip is not a tab and must not read as one: a wider gap and
            // a hairline, because on a strip of evenly spaced pills a merely
            // larger gap reads as a layout accident.
            Rectangle()
                .fill(.white.opacity(0.18))
                .frame(width: 1, height: 38)
                .padding(.horizontal, 26)

            HStack(spacing: 4) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    entry(for: tab)
                }
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 12)
        // A material rather than a colour: quiet over the page's black, opaque
        // over a row of posters scrolling under it.
        .background(.regularMaterial, in: .capsule)
        .padding(.top, 12 - Self.lift)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        // One region, the full width, so Up from anywhere in the page arrives
        // here. The capsule alone did not reach over the hero's Play button
        // at the left edge, so Up from Play found nothing.
        .focusSection()
        // A tab switches as the remote reaches it, as the system bar does.
        // The beat is so a swipe across the strip does not build every page
        // it passes.
        .onChange(of: focused) { previous, current in
            guard case let .tab(tab) = current, tab != selected else { return }

            // Arriving from the page lands on the tab you are on, wherever
            // the press lined up. Up from the hero's My List sits under
            // another tab, and with tabs switching on focus that press would
            // change the page.
            if previous == nil {
                focused = .tab(selected)
                return
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                guard focused == .tab(tab), tab != selected else { return }
                select(tab)
            }
        }
        .symbolVariant(.fill)
        .symbolRenderingMode(.monochrome)
        .fontWeight(.semibold)
    }

    @ViewBuilder
    private func entry(for tab: AppTab) -> some View {
        let isFocused = focused == .tab(tab)

        Button {
            select(tab)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tab.systemImage)
                Text(tab.title)
            }
            .font(.system(size: Self.labelSize, weight: .semibold))
            .foregroundStyle(isFocused ? Color.black : Color.white)
            .padding(.horizontal, 26)
            .padding(.vertical, 12)
            .background {
                Capsule().fill(pillFill(isFocused: isFocused, isCurrent: selected == tab))
            }
        }
        .buttonStyle(NavStripButtonStyle())
        .focused($focused, equals: .tab(tab))
    }

    private func pillFill(isFocused: Bool, isCurrent: Bool) -> Color {
        if isFocused {
            .white
        } else if isCurrent {
            // Deliberately not subtle: this is the state the system bar could
            // not draw loudly enough.
            .white.opacity(0.3)
        } else {
            .clear
        }
    }

    /// Who is watching, and the way to profiles and signing out. The chevron
    /// says it opens onto something rather than switching tabs.
    @ViewBuilder
    private var profileChip: some View {
        let isFocused = focused == .profile

        Button(action: openProfile) {
            HStack(spacing: 10) {
                Text(userInitial)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: Self.avatarEdge, height: Self.avatarEdge)
                    .background(Color(white: 0.18), in: .rect(cornerRadius: 8))

                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isFocused ? Color.black : Color.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule().fill(pillFill(isFocused: isFocused, isCurrent: false))
            }
        }
        .buttonStyle(NavStripButtonStyle())
        .focused($focused, equals: .profile)
    }
}

/// A button that draws nothing of its own: the pill says where focus is, and
/// tvOS's focus platter would be a second answer in a second shape.
private struct NavStripButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
