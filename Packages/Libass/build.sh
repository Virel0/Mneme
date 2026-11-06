#!/bin/bash
#
# Mneme is free software: you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version. See LICENSE.md.
#
# Copyright (c) 2026 Mneme contributors
#
# Builds libass, and the FreeType, HarfBuzz and FriBidi it needs, from their
# released sources into Libass.xcframework beside this script, and writes
# BUILD-INFO.txt saying what went in. Nothing is needed beyond Xcode: each
# library is compiled with its own sources and clang, not its build system.
#
# Every source is checked against the SHA-256 pinned below before it is
# unpacked. To move a library on, change its version and hash here, run this
# script, and commit what it writes.
#
# Usage: Packages/Libass/build.sh

set -euo pipefail

# No timestamps in the archives, so a rebuild from the same sources and
# Xcode makes the same bytes, and the hashes in BUILD-INFO.txt can be checked.
export ZERO_AR_DATE=1

here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# name, version, URL, SHA-256
sources=(
    "libass 0.17.5 https://github.com/libass/libass/releases/download/0.17.5/libass-0.17.5.tar.xz 2dca25c0e0c837ddf00b52011b3f82cac1e4ddd3ad018227806b0c2288864acc"
    "freetype 2.15.0 https://download.savannah.gnu.org/releases/freetype/freetype-2.15.0.tar.xz 93cd47eb719c325107f2d3cf087d06299e944c3b48a40b55537302304dea1dd5"
    "harfbuzz 15.0.0 https://github.com/harfbuzz/harfbuzz/releases/download/15.0.0/harfbuzz-15.0.0.tar.xz 968536e9abd782f07f7954044c0c4020199fcdd39b41d221ec42d2a3be4a44df"
    "fribidi 1.0.18 https://github.com/fribidi/fribidi/releases/download/v1.0.18/fribidi-1.0.18.tar.xz 1de5e8073d035388b71d0b2d452b1da1f8caeea8a7702997b401fe1b6250727f"
)

# slice, SDK, clang target
slices=(
    "tvos-arm64 appletvos arm64-apple-tvos26.1"
    "tvos-sim-arm64 appletvsimulator arm64-apple-tvos26.1-simulator"
    "tvos-sim-x86_64 appletvsimulator x86_64-apple-tvos26.1-simulator"
    "ios-arm64 iphoneos arm64-apple-ios26.1"
    "ios-sim-arm64 iphonesimulator arm64-apple-ios26.1-simulator"
    "ios-sim-x86_64 iphonesimulator x86_64-apple-ios26.1-simulator"
    "macos-arm64 macosx arm64-apple-macos15.0"
    "macos-x86_64 macosx x86_64-apple-macos15.0"
)

common_flags=(-O2 -DNDEBUG -fvisibility=hidden -Wno-everything)

for entry in "${sources[@]}"; do
    read -r name version url sha <<<"$entry"
    archive="$work/$name.tar.xz"
    echo "Fetching $name $version"
    curl -sSfL "$url" -o "$archive"
    echo "$sha  $archive" | shasum -a 256 -c --quiet
    mkdir "$work/$name"
    tar -xf "$archive" -C "$work/$name" --strip-components=1
done

src_ft="$work/freetype"
src_hb="$work/harfbuzz"
src_fb="$work/fribidi"
src_ass="$work/libass"

# FreeType with the drivers subtitle fonts need (TrueType and OpenType) and
# nothing else, so fewer parsers see fonts that come out of media files.
gen="$work/gen"
mkdir -p "$gen/freetype/config"
cat >"$gen/freetype/config/ftmodule-libass.h" <<'EOF'
FT_USE_MODULE( FT_Module_Class, autofit_module_class )
FT_USE_MODULE( FT_Driver_ClassRec, tt_driver_class )
FT_USE_MODULE( FT_Driver_ClassRec, cff_driver_class )
FT_USE_MODULE( FT_Module_Class, psaux_module_class )
FT_USE_MODULE( FT_Module_Class, psnames_module_class )
FT_USE_MODULE( FT_Module_Class, pshinter_module_class )
FT_USE_MODULE( FT_Module_Class, sfnt_module_class )
FT_USE_MODULE( FT_Renderer_Class, ft_smooth_renderer_class )
EOF
ft_sources=(
    src/base/ftsystem.c src/base/ftinit.c src/base/ftdebug.c src/base/ftbase.c
    src/base/ftbbox.c src/base/ftglyph.c src/base/ftbitmap.c src/base/ftmm.c
    src/base/ftsynth.c src/base/fttype1.c
    src/autofit/autofit.c src/truetype/truetype.c src/cff/cff.c src/sfnt/sfnt.c
    src/psaux/psaux.c src/psnames/psnames.c src/pshinter/pshinter.c
    src/smooth/smooth.c src/gzip/ftgzip.c
)

# FriBidi's version header, as its build would write it.
sed -e 's/@configure_input@/Written by build.sh/' \
    -e 's/@PACKAGE@/fribidi/' -e 's/@PACKAGE_NAME@/GNU FriBidi/' \
    -e 's|@PACKAGE_BUGREPORT@|https://github.com/fribidi/fribidi/issues/new|' \
    -e 's/@FRIBIDI_VERSION@/1.0.18/' -e 's/@FRIBIDI_MAJOR_VERSION@/1/' \
    -e 's/@FRIBIDI_MINOR_VERSION@/0/' -e 's/@FRIBIDI_MICRO_VERSION@/18/' \
    -e 's/@FRIBIDI_INTERFACE_VERSION@/4/' -e 's/@SIZEOF_INT@/4/' \
    -e 's/@FRIBIDI_MSVC_BUILD_PLACEHOLDER@//' \
    "$src_fb/lib/fribidi-config.h.in" >"$gen/fribidi-config.h"

ass_sources=(
    c/c_be_blur.c c/c_blend_bitmaps.c c/c_blur.c c/c_rasterizer.c
    ass.c ass_arabic_charmap.c ass_bitmap.c ass_bitmap_engine.c ass_blur.c
    ass_cache.c ass_drawing.c ass_filesystem.c ass_font.c ass_fontselect.c
    ass_library.c ass_outline.c ass_parse.c ass_rasterizer.c ass_render.c
    ass_render_api.c ass_shaper.c ass_string.c ass_strtod.c ass_utils.c
    ass_coretext.c
)
ass_aarch64_sources=(aarch64/asm.S aarch64/be_blur.S aarch64/blend_bitmaps.S aarch64/blur.S aarch64/rasterizer.S)

build_slice() {
    local slice=$1 sdk=$2 target=$3
    local out="$work/build/$slice"
    local sysroot
    sysroot=$(xcrun --sdk "$sdk" --show-sdk-path)
    local cc=(xcrun --sdk "$sdk" clang -target "$target" -isysroot "$sysroot" "${common_flags[@]}")
    local cxx=(xcrun --sdk "$sdk" clang++ -target "$target" -isysroot "$sysroot" "${common_flags[@]}")
    mkdir -p "$out/obj"
    echo "Building $slice"

    for file in "${ft_sources[@]}"; do
        "${cc[@]}" -DFT2_BUILD_LIBRARY -DFT_CONFIG_MODULES_H='<freetype/config/ftmodule-libass.h>' \
            -I"$gen" -I"$src_ft/include" -c "$src_ft/$file" -o "$out/obj/ft_$(basename "$file" .c).o"
    done

    "${cxx[@]}" -std=c++17 -fno-exceptions -fno-rtti -DHAVE_PTHREAD=1 \
        -c "$src_hb/src/harfbuzz.cc" -o "$out/obj/hb_harfbuzz.o"

    for file in "$src_fb"/lib/fribidi*.c; do
        "${cc[@]}" -DFRIBIDI_BUILD -DFRIBIDI_LIB_STATIC -DSTDC_HEADERS=1 -DHAVE_STDLIB_H=1 \
            -DHAVE_STRING_H=1 -DHAVE_STRINGIZE=1 -I"$gen" -I"$src_fb/lib" \
            -c "$file" -o "$out/obj/fb_$(basename "$file" .c).o"
    done

    local config="$out/config"
    mkdir -p "$config"
    {
        echo '#define CONFIG_CORETEXT 1'
        echo '#define CONFIG_LARGE_TILES 0'
        echo '#define CONFIG_SOURCEVERSION "0.17.5, Mneme Packages/Libass/build.sh"'
        echo '#define HAVE_STRDUP 1'
        echo '#define HAVE_STRNDUP 1'
        echo '#define HAVE_FSTAT 1'
        if [[ $target == arm64-* ]]; then
            echo '#define ARCH_AARCH64 1'
            echo '#define CONFIG_ASM 1'
        fi
    } >"$config/config.h"
    local ass_includes=(-DFRIBIDI_LIB_STATIC -I"$config" -I"$src_ass/libass" -I"$gen" -I"$src_ft/include" -I"$src_hb/src" -I"$src_fb/lib")
    for file in "${ass_sources[@]}"; do
        "${cc[@]}" -std=gnu11 "${ass_includes[@]}" -c "$src_ass/libass/$file" -o "$out/obj/ass_$(basename "$file" .c).o"
    done
    if [[ $target == arm64-* ]]; then
        for file in "${ass_aarch64_sources[@]}"; do
            "${cc[@]}" -DPREFIX "${ass_includes[@]}" -c "$src_ass/libass/$file" -o "$out/obj/ass_aarch64_$(basename "$file" .S).o"
        done
    fi

    xcrun libtool -static -o "$out/libLibass.a" "$out"/obj/*.o 2>/dev/null
}

for entry in "${slices[@]}"; do
    read -r slice sdk target <<<"$entry"
    build_slice "$slice" "$sdk" "$target"
done

# One library per platform, the simulator's and the Mac's for both
# architectures.
mkdir -p "$work/lib/tvos" "$work/lib/tvos-sim" "$work/lib/ios" "$work/lib/ios-sim" "$work/lib/macos"
cp "$work/build/tvos-arm64/libLibass.a" "$work/lib/tvos/"
lipo -create "$work/build/tvos-sim-arm64/libLibass.a" "$work/build/tvos-sim-x86_64/libLibass.a" -output "$work/lib/tvos-sim/libLibass.a"
cp "$work/build/ios-arm64/libLibass.a" "$work/lib/ios/"
lipo -create "$work/build/ios-sim-arm64/libLibass.a" "$work/build/ios-sim-x86_64/libLibass.a" -output "$work/lib/ios-sim/libLibass.a"
lipo -create "$work/build/macos-arm64/libLibass.a" "$work/build/macos-x86_64/libLibass.a" -output "$work/lib/macos/libLibass.a"

# libass's own interface only; the libraries under it stay out of sight. In
# a folder of its own, as every library's headers land in one include folder
# of the app's build, and a module map at its top would collide with others.
headers="$work/headers"
mkdir -p "$headers/Libass/ass"
cp "$src_ass/libass/ass.h" "$src_ass/libass/ass_types.h" "$headers/Libass/ass/"
cat >"$headers/Libass/module.modulemap" <<'EOF'
module Libass {
    header "ass/ass.h"
    link "c++"
    link framework "CoreText"
    link framework "CoreFoundation"
    export *
}
EOF

rm -rf "$here/Libass.xcframework"
xcodebuild -create-xcframework \
    -library "$work/lib/tvos/libLibass.a" -headers "$headers" \
    -library "$work/lib/tvos-sim/libLibass.a" -headers "$headers" \
    -library "$work/lib/ios/libLibass.a" -headers "$headers" \
    -library "$work/lib/ios-sim/libLibass.a" -headers "$headers" \
    -library "$work/lib/macos/libLibass.a" -headers "$headers" \
    -output "$here/Libass.xcframework" >/dev/null

# Shipped with the app, which shows them under Acknowledgements.
licenses="$here/Sources/AssRendering/Licenses"
mkdir -p "$licenses"
cp "$src_ass/COPYING" "$licenses/libass-ISC.txt"
cp "$src_ft/docs/FTL.TXT" "$licenses/freetype-FTL.txt"
cp "$src_hb/COPYING" "$licenses/harfbuzz-MIT.txt"
cp "$src_fb/COPYING" "$licenses/fribidi-LGPL-2.1.txt"

{
    echo "# Libass build record"
    echo
    echo "Written by build.sh."
    echo
    echo "Xcode    $(xcodebuild -version | tr '\n' ' ')"
    echo "clang    $(xcrun clang --version | head -1)"
    for sdk in appletvos appletvsimulator iphoneos iphonesimulator macosx; do
        echo "SDK      $sdk $(xcrun --sdk "$sdk" --show-sdk-version)"
    done
    echo "build.sh sha256 $(shasum -a 256 "$here/build.sh" | cut -d' ' -f1)"
    echo
    echo "## Sources"
    for entry in "${sources[@]}"; do
        read -r name version url sha <<<"$entry"
        echo "$name $version  $url  sha256 $sha"
    done
    echo
    echo "## Configuration"
    echo "libass   CoreText font provider; no Fontconfig, libpng, iconv or libunibreak; ARM assembly on arm64"
    echo "FreeType drivers: TrueType, CFF, SFNT, autofit, PostScript hinting, smooth renderer; bundled zlib for WOFF"
    echo "HarfBuzz single-file build, without FreeType or CoreText integration"
    echo "Flags    ${common_flags[*]}"
    echo
    echo "## Output"
    for lib in tvos tvos-sim ios ios-sim macos; do
        echo "$lib  $(lipo -archs "$work/lib/$lib/libLibass.a")  sha256 $(shasum -a 256 "$work/lib/$lib/libLibass.a" | cut -d' ' -f1)"
    done
} >"$here/BUILD-INFO.txt"

echo "Wrote $here/Libass.xcframework"
