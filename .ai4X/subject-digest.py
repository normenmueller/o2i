#!/usr/bin/env python3
"""Compute the canonical digest of an Agent Memory review subject."""

from __future__ import annotations

import hashlib
import os
import stat
from pathlib import Path, PurePosixPath


MANIFEST = Path(".ai4X/MEMORY_SUBJECT")


def add_frame(digest: hashlib._Hash, value: bytes) -> None:
    digest.update(len(value).to_bytes(8, byteorder="big"))
    digest.update(value)


def load_paths(root: Path) -> list[PurePosixPath]:
    lines = (root / MANIFEST).read_text(encoding="utf-8").splitlines()
    paths = [PurePosixPath(line) for line in lines if line]
    if paths != sorted(set(paths), key=str):
        raise SystemExit(f"{MANIFEST} must contain unique, sorted paths")
    if any(path.is_absolute() or ".." in path.parts for path in paths):
        raise SystemExit(f"{MANIFEST} contains an unsafe path")
    return paths


def main() -> None:
    root = Path.cwd()
    digest = hashlib.sha256()

    for relative in load_paths(root):
        path = root / Path(relative)
        mode = path.lstat().st_mode
        add_frame(digest, str(relative).encode("utf-8"))

        if stat.S_ISLNK(mode):
            add_frame(digest, b"symlink")
            add_frame(digest, os.readlink(path).encode("utf-8"))
        elif stat.S_ISREG(mode):
            add_frame(digest, b"file")
            add_frame(digest, path.read_bytes())
        else:
            raise SystemExit(f"unsupported subject entry: {relative}")

    print(digest.hexdigest())


if __name__ == "__main__":
    main()
