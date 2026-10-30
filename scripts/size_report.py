#!/usr/bin/env python3
# Mneme is subject to the terms of the Mozilla Public License, v2.0.
#
# Warns about Swift files over 800 lines and functions over 100, as GitHub
# Actions annotations. A report, not a gate: it always exits 0.

import pathlib
import re
import sys

FILE_LIMIT = 800
FUNCTION_LIMIT = 100
FUNCTION = re.compile(r"^\s*(?:@\w+\s+)*(?:(?:public|private|fileprivate|internal|static|override|nonisolated|mutating|final|class)\s+)*func\s+(\w+)")


def functions(lines):
    """Yields (name, first line, length) for each function body, by counting braces."""
    index = 0
    while index < len(lines):
        match = FUNCTION.match(lines[index])
        if not match:
            index += 1
            continue
        depth, start, opened = 0, index, False
        while index < len(lines):
            line = lines[index].split("//")[0]
            depth += line.count("{") - line.count("}")
            opened = opened or "{" in line
            index += 1
            if opened and depth <= 0:
                break
        yield match.group(1), start + 1, index - start


def main(root):
    for path in sorted(pathlib.Path(root).rglob("*.swift")):
        if any(part in {".build", ".spm", "build"} for part in path.parts):
            continue
        lines = path.read_text(encoding="utf-8").splitlines()
        if len(lines) > FILE_LIMIT:
            print(f"::warning file={path},line=1::{len(lines)} lines, over {FILE_LIMIT}")
        for name, line, length in functions(lines):
            if length > FUNCTION_LIMIT:
                print(f"::warning file={path},line={line}::{name}() is {length} lines, over {FUNCTION_LIMIT}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
