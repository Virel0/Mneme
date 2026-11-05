//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

/// The kinds of picture Melete serves. Answers give each at a small size;
/// the same file can be asked for at any other size of its kind, for a large
/// screen.
public enum ArtworkKind: Hashable, Sendable {
    case poster
    case backdrop
    case still
    case logo
    /// People's pictures.
    case profile

    /// Smallest first, with the width each is at most; nil for `original`,
    /// the image as it was uploaded, up to 3840 wide.
    private var sizes: [(name: String, width: Double?)] {
        switch self {
        case .poster: [("w342", 342), ("w500", 500), ("w780", 780)]
        case .backdrop: [("w1280", 1280), ("original", nil)]
        case .still: [("w300", 300), ("original", nil)]
        case .logo: [("w500", 500), ("original", nil)]
        // A height: people's pictures are 2:3, so about 421 wide.
        case .profile: [("w185", 185), ("h632", 421)]
        }
    }

    /// The picture at `path` at the smallest size of this kind at least
    /// `pixels` wide, else the largest, and whether that size is the image as
    /// uploaded, which can be far wider than asked.
    ///
    /// Only for the library's own pictures: a title not in the library is
    /// served at w342 alone. A path that isn't Melete's artwork at a size of
    /// this kind comes back as it is.
    public func path(_ path: String, filling pixels: Double) -> (path: String, isOriginal: Bool) {
        guard let marker = path.range(of: "api/v1/artwork/"),
              let slash = path[marker.upperBound...].firstIndex(of: "/")
        else { return (path, false) }
        let given = path[marker.upperBound ..< slash]
        guard sizes.contains(where: { $0.name == given }), let largest = sizes.last else { return (path, false) }
        let chosen = sizes.first { ($0.width ?? .infinity) >= pixels } ?? largest
        return (path.replacingCharacters(in: marker.upperBound ..< slash, with: chosen.name), chosen.width == nil)
    }
}
