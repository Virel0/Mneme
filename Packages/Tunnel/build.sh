#!/bin/bash
#
# Mneme is free software: you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version. See LICENSE.md.
#
# Copyright (c) 2026 Mneme contributors
#
# Builds tunnel-core (rust/: WireGuard by Mullvad's gotatun, behind the C
# interface in rust/include/tunnel_core.h) into TunnelCore.xcframework beside
# this script, gathers the licences of every crate in it, and writes
# BUILD-INFO.txt saying what went in.
#
# Needs Xcode and a Rust toolchain from rustup with the targets below
# (`rustup target add aarch64-apple-tvos aarch64-apple-tvos-sim
# aarch64-apple-ios aarch64-apple-ios-sim`). Crates come at the versions in
# rust/Cargo.lock, checked against its hashes. To move gotatun on, change its
# version in rust/Cargo.toml, run `cargo update -p gotatun` in rust/, run this
# script, and commit what it writes.
#
# arm64 only: Rust has no ready-made tvOS simulator for Intel Macs.
#
# Usage: Packages/Tunnel/build.sh

set -euo pipefail

export ZERO_AR_DATE=1

here=$(cd "$(dirname "$0")" && pwd)
crate="$here/rust"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The app's own floors, so nothing links newer than Mneme runs on.
export TVOS_DEPLOYMENT_TARGET=26.1
export IPHONEOS_DEPLOYMENT_TARGET=26.1
export MACOSX_DEPLOYMENT_TARGET=15.0

# No paths from this machine in what is committed: Rust's and the C code's
# file names are rewritten to fixed ones.
cargo_home="${CARGO_HOME:-$HOME/.cargo}"
rustup_home="${RUSTUP_HOME:-$HOME/.rustup}"
export RUSTFLAGS="--remap-path-prefix=$cargo_home=/cargo --remap-path-prefix=$rustup_home=/rustup --remap-path-prefix=$crate=/tunnel-core --remap-path-prefix=$work=/build"
export CFLAGS="-ffile-prefix-map=$cargo_home=/cargo -ffile-prefix-map=$work=/build"
export CARGO_TARGET_DIR="$work/target"

# slice, Rust target
slices=(
    "tvos aarch64-apple-tvos"
    "tvos-sim aarch64-apple-tvos-sim"
    "ios aarch64-apple-ios"
    "ios-sim aarch64-apple-ios-sim"
    "macos aarch64-apple-darwin"
)

echo "Testing tunnel-core"
(cd "$crate" && cargo test --locked --release --quiet)

for entry in "${slices[@]}"; do
    read -r slice target <<<"$entry"
    echo "Building $slice ($target)"
    (cd "$crate" && cargo build --locked --release --quiet --target "$target")
    mkdir -p "$work/lib/$slice"
    # Local symbols and debug notes go; what the app links against stays.
    strip -S -x "$work/target/$target/release/libtunnel_core.a" -o "$work/lib/$slice/libTunnelCore.a"
done

# Refuse to write anything that still names this machine's folders.
for entry in "${slices[@]}"; do
    read -r slice _ <<<"$entry"
    if strings "$work/lib/$slice/libTunnelCore.a" | grep -q -e "$HOME" -e "$work"; then
        echo "error: $slice names a local folder; not written" >&2
        exit 1
    fi
done

headers="$work/headers"
mkdir -p "$headers/TunnelCore"
cp "$crate/include/tunnel_core.h" "$headers/TunnelCore/"
cat >"$headers/TunnelCore/module.modulemap" <<'EOF'
module TunnelCore {
    header "tunnel_core.h"
    export *
}
EOF

rm -rf "$here/TunnelCore.xcframework"
args=()
for entry in "${slices[@]}"; do
    read -r slice _ <<<"$entry"
    args+=(-library "$work/lib/$slice/libTunnelCore.a" -headers "$headers")
done
xcodebuild -create-xcframework "${args[@]}" -output "$here/TunnelCore.xcframework" >/dev/null

# Shipped with the app, which shows them under Acknowledgements: each crate
# linked into the tvOS build, its licence, and the licence texts it carries.
licenses="$here/Sources/Tunnel/Licenses"
mkdir -p "$licenses"
(cd "$crate" && cargo metadata --locked --format-version 1 --filter-platform aarch64-apple-tvos) >"$work/metadata.json"
python3 - "$work/metadata.json" "$licenses/rust-crates.txt" <<'EOF'
import json, os, sys
meta = json.load(open(sys.argv[1]))
by_id = {p["id"]: p for p in meta["packages"]}
nodes = {n["id"]: n for n in meta["resolve"]["nodes"]}
root = meta["resolve"]["root"]
# Normal dependencies only: what is linked, not what builds it.
seen, todo = set(), [root]
while todo:
    node = nodes[todo.pop()]
    for dep in node["deps"]:
        if any(k["kind"] is None for k in dep["dep_kinds"]) and dep["pkg"] not in seen:
            seen.add(dep["pkg"])
            todo.append(dep["pkg"])
with open(sys.argv[2], "w") as out:
    out.write("Rust crates in Mneme's WireGuard tunnel, with their licences.\n")
    for pkg in sorted((by_id[i] for i in seen), key=lambda p: (p["name"], p["version"])):
        out.write("\n" + "=" * 78 + "\n")
        out.write(f"{pkg['name']} {pkg['version']}  {pkg.get('license') or pkg.get('license_file')}\n")
        if pkg.get("repository"):
            out.write(f"Source: {pkg['repository']}\n")
        folder = os.path.dirname(pkg["manifest_path"])
        for name in sorted(os.listdir(folder)):
            if name.upper().startswith(("LICENSE", "LICENCE", "COPYING", "NOTICE")) and os.path.isfile(os.path.join(folder, name)):
                out.write(f"\n--- {name}\n\n")
                out.write(open(os.path.join(folder, name), encoding="utf-8", errors="replace").read())
EOF

{
    echo "# TunnelCore build record"
    echo
    echo "Written by build.sh."
    echo
    echo "Xcode    $(xcodebuild -version | tr '\n' ' ')"
    echo "rustc    $(rustc --version)"
    echo "cargo    $(cargo --version)"
    echo "build.sh sha256 $(shasum -a 256 "$here/build.sh" | cut -d' ' -f1)"
    echo "Cargo.lock sha256 $(shasum -a 256 "$crate/Cargo.lock" | cut -d' ' -f1)"
    echo
    echo "## Sources"
    echo "gotatun $(cd "$crate" && cargo metadata --locked --format-version 1 | python3 -c 'import json,sys; print(next(p["version"] for p in json.load(sys.stdin)["packages"] if p["name"] == "gotatun"))')  https://github.com/mullvad/gotatun  (crates.io, checked against Cargo.lock)"
    echo "Floors   tvOS $TVOS_DEPLOYMENT_TARGET, iOS $IPHONEOS_DEPLOYMENT_TARGET, macOS $MACOSX_DEPLOYMENT_TARGET"
    echo "Profile  release, LTO, one codegen unit, debug info and local symbols stripped, paths remapped"
    echo "Crypto   ring (gotatun feature \"ring\")"
    echo
    echo "## Output"
    for entry in "${slices[@]}"; do
        read -r slice target <<<"$entry"
        echo "$slice  $target  $(lipo -archs "$work/lib/$slice/libTunnelCore.a")  sha256 $(shasum -a 256 "$work/lib/$slice/libTunnelCore.a" | cut -d' ' -f1)"
    done
} >"$here/BUILD-INFO.txt"
echo "Wrote $here/TunnelCore.xcframework"
