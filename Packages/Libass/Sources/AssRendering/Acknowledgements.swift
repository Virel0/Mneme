//
// Mneme is free software: you can redistribute it and/or modify it under the
// terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version. See LICENSE.md.
//
// Copyright (c) 2026 Mneme contributors
//

import Foundation

/// The libraries built into this package, each with the licence it is used
/// under, for an app that ships them to show.
public enum Acknowledgements {

    public struct Library: Identifiable, Sendable {
        public let name: String
        public let licence: String
        /// The licence's full text, as it came with the library's source.
        public let text: String
        /// A credit the licence asks for in a product's documentation.
        public let credit: String?

        public var id: String {
            name
        }
    }

    public static let libraries: [Library] = [
        library("libass", licence: "ISC", file: "libass-ISC"),
        library(
            "FreeType",
            licence: "FreeType License",
            file: "freetype-FTL",
            credit: "Portions of this software are copyright © 2026 The FreeType Project (https://freetype.org). All rights reserved."
        ),
        library("HarfBuzz", licence: "MIT (Old MIT)", file: "harfbuzz-MIT"),
        library("FriBidi", licence: "GNU LGPL 2.1 or later", file: "fribidi-LGPL-2.1"),
    ]

    private static func library(_ name: String, licence: String, file: String, credit: String? = nil) -> Library {
        let url = Bundle.module.url(forResource: file, withExtension: "txt", subdirectory: "Licenses")
        let text = url.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        return Library(name: name, licence: licence, text: text, credit: credit)
    }
}
