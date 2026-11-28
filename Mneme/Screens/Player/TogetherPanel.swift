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

/// Watch Together, over the right side of the picture: start a watch party
/// on what's playing, or join one with its code; in one, its code, who's in
/// it, and leaving it.
struct TogetherPanel: View {

    let session: PlayerSession
    let close: () -> Void

    @State
    private var code = ""
    @State
    private var isWorking = false
    @State
    private var problem: String?

    private var parties: WatchParties {
        session.parties
    }

    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .leading, spacing: 24) {
                Text("Watch Together")
                    .font(.title3.weight(.semibold))

                if let party = parties.party {
                    inParty(party)
                } else {
                    notInParty
                }

                if let problem {
                    Text(problem)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
                Spacer()
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 60)
            .frame(width: 640, alignment: .leading)
            .frame(maxHeight: .infinity)
            .background(.regularMaterial)
            .focusSection()
        }
        .ignoresSafeArea()
        .onExitCommand(perform: close)
        .disabled(isWorking)
    }

    @ViewBuilder
    private var notInParty: some View {
        if let note = parties.endedNote {
            Text(note)
                .foregroundStyle(.secondary)
        }
        Text("Play this in step with others: anyone in the party can play, pause and seek, and every player follows.")
            .font(.callout)
            .foregroundStyle(.secondary)

        Button("Start a Watch Party") {
            run { try await session.startParty() }
        }

        VStack(alignment: .leading, spacing: 12) {
            Text("Or join one with its code")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("Code", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("Join") {
                let code = code
                run { try await parties.join(code: code) }
            }
            .disabled(code.trimmingCharacters(in: .whitespaces).count < 6)
        }
    }

    @ViewBuilder
    private func inParty(_ party: WatchParty) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Code")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(party.code)
                .font(.system(size: 56, weight: .bold, design: .monospaced))
            Text("Others join with it here or on Melete's web page.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if !party.waiting.isEmpty {
            Text("Waiting for \(ListFormatter.localizedString(byJoining: party.waiting))…")
        }

        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(party.members.enumerated()), id: \.offset) { _, member in
                Text(member.you ? "\(member.username) · this Apple TV" : "\(member.username) · \(member.device)")
                    .font(.callout)
            }
            ForEach(party.guests) { guest in
                Text("\(guest.name) · guest")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }

        if parties.isHost {
            Button("End for Everyone") {
                run { await parties.endForEveryone() }
            }
        }
        Button("Leave") {
            run { await parties.leave() }
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        isWorking = true
        problem = nil
        Task {
            do {
                try await work()
            } catch let error as MeleteError {
                problem = Self.words(for: error)
            } catch {
                problem = error.localizedDescription
            }
            isWorking = false
        }
    }

    private static func words(for error: MeleteError) -> String {
        switch error {
        case .notFound: "There's no watch party with that code."
        case .forbidden: "This account can't watch what that party is playing."
        case .tooManyRequests: "Too many wrong codes. Try again in a few minutes."
        default: error.localizedDescription
        }
    }
}
