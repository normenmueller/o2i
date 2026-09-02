#!/usr/bin/env python3
"""Verify the exact target package graph and complete Inspection retirement."""

from __future__ import annotations

import argparse
from pathlib import Path
import re


TARGET_PACKAGES = (
    ("lib/core", "o2i-core", frozenset()),
    ("ctr/archimate", "o2i-archimate-profile", frozenset({"o2i-core"})),
    (
        "lib/operation",
        "o2i-operation",
        frozenset({"o2i-core", "o2i-archimate-profile"}),
    ),
    (
        "lib/adapter/amx",
        "o2i-amx",
        frozenset({"o2i-operation", "o2i-archimate-profile"}),
    ),
    ("cli", "o2i-cli", frozenset({"o2i-operation", "o2i-amx"})),
)
TARGET_NAMES = frozenset(name for _, name, _ in TARGET_PACKAGES)
LEGACY_DIRECTORY = Path("spc/lib") / "inspection"
LEGACY_MARKERS = (
    b"o2i-" + b"inspection",
    b"spc/lib/" + b"inspection",
    b"O2I." + b"Inspection",
    b"o2i." + b"inspection.",
)
LEGACY_CLI_TERM = re.compile(rb"(?<![A-Za-z0-9_-])inspect(?:ion)?(?![A-Za-z0-9_-])", re.I)


def read_text(path: Path) -> str:
    """Read one contract surface as strict UTF-8."""
    return path.read_text(encoding="utf-8")


def project_packages(path: Path) -> tuple[str, ...]:
    """Return the one indented packages stanza from a Cabal project."""
    lines = read_text(path).splitlines()
    starts = [index for index, line in enumerate(lines) if line == "packages:"]
    if len(starts) != 1:
        raise ValueError(f"{path}: expected exactly one packages stanza")
    packages: list[str] = []
    for line in lines[starts[0] + 1 :]:
        if line and not line[0].isspace():
            break
        value = line.strip()
        if value and not value.startswith("--"):
            packages.append(value.removeprefix("./").rstrip("/"))
    if not packages:
        raise ValueError(f"{path}: packages stanza is empty")
    return tuple(packages)


def first_library_stanza(path: Path) -> str:
    """Return the first production library stanza from one Cabal file."""
    lines = read_text(path).splitlines()
    starts = [
        index
        for index, line in enumerate(lines)
        if line == "library" or line.startswith("library ")
    ]
    if not starts:
        raise ValueError(f"{path}: missing production library stanza")
    start = starts[0]
    body: list[str] = []
    for line in lines[start + 1 :]:
        if line and not line[0].isspace() and not line.startswith("--"):
            break
        body.append(line)
    return "\n".join(body)


def local_dependencies(path: Path) -> frozenset[str]:
    """Return target-package dependencies of the production library."""
    stanza = first_library_stanza(path)
    return frozenset(
        name
        for name in TARGET_NAMES
        if re.search(rf"(?<![A-Za-z0-9-]){re.escape(name)}(?![A-Za-z0-9-])", stanza)
    )


def scanned_files(root: Path) -> tuple[Path, ...]:
    """Return runtime and registration surfaces that may retain legacy bytes."""
    paths: list[Path] = []
    for directory in (root / "spc", root / ".github" / "workflows"):
        if not directory.exists():
            continue
        paths.extend(
            path
            for path in directory.rglob("*")
            if path.is_file() and "dist-newstyle" not in path.parts
        )
    for relative in (
        "utl/verify.sh",
        "utl/haskell/check-package-licenses.sh",
        "utl/haskell/check_haskell_api_contracts.py",
    ):
        path = root / relative
        if path.is_file():
            paths.append(path)
    return tuple(sorted(set(paths)))


def check(root: Path) -> None:
    """Reject any incomplete package cutover or legacy registration."""
    project = root / "spc" / "cabal.project"
    expected_paths = tuple(path for path, _, _ in TARGET_PACKAGES)
    actual_paths = project_packages(project)
    if actual_paths != expected_paths:
        raise ValueError(
            f"{project}: target packages={expected_paths!r}, found={actual_paths!r}"
        )

    legacy = root / LEGACY_DIRECTORY
    if legacy.exists() or legacy.is_symlink():
        raise ValueError(f"legacy Inspection package still exists: {legacy}")

    for relative, name, expected_dependencies in TARGET_PACKAGES:
        cabal_file = root / "spc" / relative / f"{name}.cabal"
        if not cabal_file.is_file():
            raise ValueError(f"missing target package metadata: {cabal_file}")
        actual_dependencies = local_dependencies(cabal_file)
        if actual_dependencies != expected_dependencies:
            raise ValueError(
                f"{cabal_file}: target dependencies="
                f"{tuple(sorted(expected_dependencies))!r}, "
                f"found={tuple(sorted(actual_dependencies))!r}"
            )

    findings: list[str] = []
    cli_root = root / "spc" / "cli"
    for path in scanned_files(root):
        content = path.read_bytes()
        for marker in LEGACY_MARKERS:
            if marker in content:
                findings.append(f"{path}: legacy marker {marker.decode('ascii')!r}")
        if path.is_relative_to(cli_root) and LEGACY_CLI_TERM.search(content):
            findings.append(f"{path}: legacy CLI command or wording")
    if findings:
        raise ValueError("legacy Inspection surfaces remain:\n" + "\n".join(findings))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    arguments = parser.parse_args()
    try:
        check(arguments.root.resolve())
    except (OSError, UnicodeError, ValueError) as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
