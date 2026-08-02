#!/usr/bin/env python3
"""Check the structural integrity of O2I's path-based licensing contract."""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
from typing import Iterable, Sequence

from reuse.global_licensing import AnnotationsItem, ReuseTOML


SPDX_MARKERS = (
    b"SPDX-File" + b"CopyrightText:",
    b"SPDX-License-" + b"Identifier:",
)


def repository_paths(root: Path) -> tuple[str, ...]:
    """Return the current repository inventory in stable path order."""
    if (root / ".git").exists():
        result = subprocess.run(
            ["git", "-C", str(root), "ls-files", "-z"],
            check=True,
            capture_output=True,
        )
        candidates = (
            value.decode("utf-8", errors="surrogateescape")
            for value in result.stdout.split(b"\0")
            if value
        )
        return tuple(
            sorted(
                path
                for path in candidates
                if (root / path).is_file() or (root / path).is_symlink()
            )
        )
    return tuple(
        sorted(
            path.relative_to(root).as_posix()
            for path in root.rglob("*")
            if path.is_file() or path.is_symlink()
        )
    )


def is_canonical_license_text(path: str) -> bool:
    """Return whether path is a canonical legal notice managed by REUSE."""
    candidate = Path(path)
    return (
        len(candidate.parts) == 2
        and candidate.parts[0] == "LICENSES"
        and candidate.suffix == ".txt"
    )


def assignment_patterns(
    config: ReuseTOML,
) -> tuple[tuple[str, AnnotationsItem], ...]:
    """Return every configured path expression with REUSE's own matcher."""
    return tuple(
        (pattern, AnnotationsItem(paths={pattern}))
        for annotation in config.annotations
        for pattern in sorted(annotation.paths)
    )


def validate_repository(
    root: Path,
    paths: Iterable[str] | None = None,
) -> tuple[str, ...]:
    """Return deterministic violations of the single-assignment contract."""
    inventory = tuple(paths) if paths is not None else repository_paths(root)
    config = ReuseTOML.from_file(root / "REUSE.toml")
    patterns = assignment_patterns(config)
    violations: list[str] = []

    nested_configs = sorted(
        path for path in inventory if path.endswith("/REUSE.toml")
    )
    for path in nested_configs:
        violations.append(f"nested licensing authority is not allowed: {path}")

    for path in sorted(inventory):
        if is_canonical_license_text(path):
            continue

        matches = [
            pattern for pattern, matcher in patterns if matcher.matches(path)
        ]
        if len(matches) != 1:
            rendered = ", ".join(matches) if matches else "none"
            violations.append(
                f"expected exactly one REUSE.toml path assignment for {path}; "
                f"matched: {rendered}"
            )

        if path != "REUSE.toml":
            try:
                content = (root / path).read_bytes()
            except OSError as error:
                violations.append(f"cannot read {path}: {error}")
            else:
                if any(marker in content for marker in SPDX_MARKERS):
                    violations.append(
                        "embedded SPDX declaration competes with the path-based "
                        f"assignment for {path}"
                    )

    return tuple(violations)


def main(argv: Sequence[str] | None = None) -> int:
    """Run the repository licensing-assignment check."""
    parser = argparse.ArgumentParser(
        description="Check exact path-based licensing assignments."
    )
    parser.add_argument("--root", type=Path, default=Path.cwd())
    arguments = parser.parse_args(argv)

    violations = validate_repository(arguments.root.resolve())
    for violation in violations:
        print(f"[o2i|error] {violation}")
    if violations:
        return 1
    print(
        "[o2i|info] Every repository path has exactly one licensing "
        "assignment."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
