//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import MeleteKit
import SwiftUI

/// Every film and series the viewer has asked for, sorted by where it has
/// got to: what is on its way, what waits for a decision, what has arrived,
/// and what was turned down. Music asked for elsewhere is left out: nothing
/// here plays it, and it has no poster to show. It follows the live list, so
/// a download moves along and a title moves between rows as Melete works.
/// Each opens its page.
struct RequestsView: View {

    @Environment(Library.self)
    private var library

    /// Read once, for while the event stream has not yet sent its list.
    @State
    private var loaded: [MediaRequest]?

    private var requests: [MediaRequest]? {
        (library.requests ?? loaded)?.filter { $0.kind == "movie" || $0.kind == "series" }
    }

    var body: some View {
        Group {
            if let requests {
                if requests.isEmpty {
                    ArtPage(
                        art: "ArtNoMatches",
                        title: "No Requests",
                        message: "Find a movie or a show in Search that isn't in the library, and ask for it. It will be here while it's on its way."
                    )
                } else {
                    rows(requests)
                }
            } else {
                LoadingMark()
            }
        }
        .task {
            guard library.requests == nil else { return }
            loaded = await (try? library.client.requests(limit: 200))?.items ?? []
        }
    }

    private func rows(_ requests: [MediaRequest]) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 48) {
                ForEach(Stage.allCases, id: \.self) { stage in
                    let inStage = requests.filter { Stage(of: $0) == stage }
                    if !inStage.isEmpty {
                        RequestRow(title: stage.title, requests: inStage)
                    }
                }
            }
            .padding(.top, 40)
            .padding(.bottom, 80)
            // The whole width, so Down from any tab in the strip finds a row
            // even when its few posters sit at the far left.
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { PageTop() }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .modifier(ScrollsToTopOnRequest())
        // The rows keep their own margins rather than tvOS's wider safe area
        // on top of them.
        .ignoresSafeArea(edges: .horizontal)
    }

    /// Where a request has got to, in the order the page shows them.
    private enum Stage: CaseIterable {
        case onTheWay
        case waiting
        case arrived
        case declined

        init(of request: MediaRequest) {
            switch request.state {
            case "declined": self = .declined
            case "approved": self = request.progress?.step == "in_library" ? .arrived : .onTheWay
            default: self = .waiting
            }
        }

        var title: String {
            switch self {
            case .onTheWay: "On the Way"
            case .waiting: "Waiting for Approval"
            case .arrived: "In the Library"
            case .declined: "Declined"
            }
        }
    }
}
