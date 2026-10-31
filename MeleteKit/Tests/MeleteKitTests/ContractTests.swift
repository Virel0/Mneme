//
// Mneme is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation
@testable import MeleteKit
import Testing

/// Holds the models to Melete's API contract, `src/api/openapi.json` in a
/// checkout of Melete beside this repository, or wherever `MELETE_OPENAPI`
/// points.
///
/// For each model, a JSON value with every property of its schema filled in
/// (none of them null) is built from the schema and decoded: a model field the
/// schema does not have, or has with another type, fails the decode. The
/// value is then encoded again and must come back with exactly the sample's
/// keys, at every level. A misspelt optional field decodes to nil without
/// complaint; it shows here as a key that went missing. A field a model leaves
/// out on purpose is listed in `skipped`.
struct ContractTests {

    nonisolated(unsafe) static let spec: [String: Any] = {
        let url = if let path = ProcessInfo.processInfo.environment["MELETE_OPENAPI"] {
            URL(filePath: path)
        } else {
            // This file is <repo>/MeleteKit/Tests/MeleteKitTests/; Melete is
            // a sibling of <repo>.
            URL(filePath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "Melete/src/api/openapi.json")
        }
        // swiftlint:disable:next force_try force_cast
        return try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    }()

    static var schemas: [String: Any] {
        // swiftlint:disable:next force_cast
        (spec["components"] as! [String: Any])["schemas"] as! [String: Any]
    }

    /// Schema name, model, and the schema's fields the model leaves out on
    /// purpose, as paths below the model ("episode.still").
    nonisolated(unsafe) static let models: [(String, any Codable.Type, Set<String>)] = [
        ("Health", Health.self, []),
        ("User", User.self, []),
        ("LoginRequest", LoginRequest.self, []),
        ("LoginResponse", LoginResponse.self, []),
        ("SecondFactorNeeded", SecondFactorNeeded.self, []),
        ("SecondFactorRequest", SecondFactorRequest.self, []),
        ("QuickConnectRequest", QuickConnectRequest.self, []),
        ("QuickConnectCode", QuickConnectCode.self, []),
        ("QuickConnectPoll", QuickConnectPoll.self, []),
        ("WatchHome", WatchHome.self, []),
        ("WatchHomeRow", WatchHomeRow.self, []),
        ("WatchHomeItem", WatchHomeItem.self, []),
        ("File", MediaFile.self, []),
        ("MovieDetail", MovieDetail.self, []),
        ("SeriesDetail", SeriesDetail.self, []),
        ("SeasonSummary", SeasonSummary.self, []),
        ("Season", Season.self, []),
        ("Episode", Episode.self, []),
        ("TitleArtwork", TitleArtwork.self, []),
        ("ListItem", ListItem.self, []),
        ("Page", Page<ListItem>.self, []),
        ("Genre", Genre.self, []),
        ("ProgressEntry", ProgressEntry.self, []),
        ("Progress", Progress.self, []),
        ("WatchedRequest", WatchedRequest.self, []),
        ("SeriesWatched", SeriesWatched.self, []),
        ("Favourite", Favourite.self, []),
        ("FavouriteList", FavouriteList.self, []),
        ("FavouriteState", FavouriteState.self, []),
        ("FileSegments", FileSegments.self, []),
        ("TrackPick", TrackPick.self, []),
        ("PlayResponse", PlayResponse.self, []),
        ("ProgressReport", ProgressReport.self, []),
        ("SubtitleTrack", SubtitleTrack.self, []),
        ("TrackChoice", TrackChoice.self, []),
        ("Trickplay", Trickplay.self, []),
        ("DiagnosticsKept", DiagnosticsKept.self, []),
        ("AiAbout", AiAbout.self, []),
        ("AiSearchRequest", AiSearchRequest.self, []),
        ("AiSuggestion", AiSuggestion.self, []),
        ("AiSearch", AiSearch.self, []),
        ("DiscoverItem", DiscoverItem.self, []),
        (
            "NewRequest",
            NewRequest.self,
            [
                "mb_artist_id", "mb_release_group_id", "mb_recording_id", "title", "artist", "library_id",
                "profile_id", "music_profile_id", "monitored", "search_now", "seasons",
            ]
        ),
        ("CastMember", CastMember.self, []),
        ("CrewMember", CrewMember.self, []),
        ("Credits", Credits.self, []),
        ("Extra", Extra.self, []),
        ("Collection", MovieCollection.self, []),
        ("Person", Person.self, []),
        ("VideoStream", VideoStream.self, ["dolby_vision"]),
        ("AudioStream", AudioStream.self, []),
        ("MediaInfo", MediaInfo.self, ["subtitles", "video[].dolby_vision"]),
        (
            "FileInfo",
            FileInfo.self,
            ["modified_at", "segments", "trickplay", "subtitle_search", "offline", "media.subtitles", "media.video[].dolby_vision"]
        ),
        ("TranscodeRequest", TranscodeRequest.self, ["audio_mode", "burn_subtitle"]),
        ("TranscodeResponse", TranscodeResponse.self, []),
        ("Languages", Languages.self, []),
        ("PlaybackPreferences", PlaybackSettings.self, []),
        ("SimilarTitles", SimilarTitles.self, []),
        ("AiPick", AiPick.self, []),
        ("QuickConnectApproveRequest", QuickConnectApproveRequest.self, []),
        ("QuickConnectLookup", QuickConnectLookup.self, []),
        ("QuickConnectApproved", QuickConnectApproved.self, []),
        ("WantedProgress", WantedProgress.self, ["kind", "wanted_id", "title", "download_id", "source", "updated_at"]),
        (
            "Request",
            MediaRequest.self,
            [
                "user_id", "username", "service", "mb_artist_id", "mb_release_group_id", "mb_recording_id",
                "artist", "decided_at", "decided_by", "wanted_id", "seasons", "search_started",
                "progress.kind", "progress.wanted_id", "progress.title", "progress.download_id",
                "progress.source", "progress.updated_at",
            ]
        ),
    ]

    @Test(arguments: models.map(\.0))
    func `model matches schema`(_ name: String) throws {
        let (_, type, skipped) = try #require(Self.models.first { $0.0 == name })
        let schema = try #require(Self.schemas[name] as? [String: Any], "\(name) is not in openapi.json")

        let sample = Self.sample(schema)
        let decoded = try JSONDecoder.melete.decode(type, from: JSONSerialization.data(withJSONObject: sample))
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder.melete.encode(decoded))

        Self.expectSameKeys(encoded, sample, skipped: skipped, at: "")
    }

    // MARK: - Sample values

    static func resolve(_ schema: [String: Any]) -> [String: Any] {
        if let ref = schema["$ref"] as? String, let name = ref.split(separator: "/").last {
            return resolve(schemas[String(name)] as? [String: Any] ?? [:])
        }
        for key in ["anyOf", "oneOf"] {
            if let options = schema[key] as? [[String: Any]] {
                // The first option that is not null.
                let option = options.first { ($0["type"] as? String) != "null" } ?? [:]
                return resolve(option)
            }
        }
        return schema
    }

    static func type(of schema: [String: Any]) -> String? {
        if let type = schema["type"] as? String {
            return type
        }
        return (schema["type"] as? [String])?.first { $0 != "null" }
    }

    static func sample(_ schema: [String: Any]) -> Any {
        let schema = resolve(schema)

        if let values = schema["enum"] as? [Any], let first = values.first(where: { !($0 is NSNull) }) {
            return first
        }

        switch type(of: schema) {
        case "object":
            let properties = schema["properties"] as? [String: [String: Any]] ?? [:]
            return properties.mapValues { sample($0) }
        case "array":
            return [sample(schema["items"] as? [String: Any] ?? [:])]
        case "integer": return 1
        case "number": return 0.5
        case "boolean": return true
        default: return "text"
        }
    }

    static func expectSameKeys(_ encoded: Any, _ sample: Any, skipped: Set<String>, at path: String) {
        if let sample = sample as? [String: Any] {
            let encoded = encoded as? [String: Any] ?? [:]
            for (key, value) in sample {
                let keyPath = path.isEmpty ? key : "\(path).\(key)"
                guard !skipped.contains(keyPath) else { continue }
                guard let encodedValue = encoded[key] else {
                    Issue.record("\(keyPath) is in the schema but did not survive decoding: misnamed, or missing from the model")
                    continue
                }
                expectSameKeys(encodedValue, value, skipped: skipped, at: keyPath)
            }
            for key in encoded.keys where sample[key] == nil {
                Issue.record("\(path.isEmpty ? key : "\(path).\(key)") is in the model but not in the schema")
            }
        } else if let sample = sample as? [Any], let first = sample.first {
            for element in encoded as? [Any] ?? [] {
                expectSameKeys(element, first, skipped: skipped, at: "\(path)[]")
            }
        }
    }
}
