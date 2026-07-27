#!/usr/bin/env python3
"""Validate local image resources referenced by a Pandoc document."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Iterator
from urllib.parse import unquote, urlparse


def image_targets(node: Any) -> Iterator[str]:
    """Yield every image target from a Pandoc JSON tree."""
    if isinstance(node, dict):
        if node.get("t") == "Image":
            content = node.get("c")
            if (
                isinstance(content, list)
                and len(content) == 3
                and isinstance(content[2], list)
                and content[2]
                and isinstance(content[2][0], str)
            ):
                yield content[2][0]
            else:
                raise ValueError("malformed Pandoc Image node")
        for value in node.values():
            yield from image_targets(value)
    elif isinstance(node, list):
        for value in node:
            yield from image_targets(value)


def validate_assets(document: Any, root: Path) -> list[str]:
    """Return deterministic diagnostics for invalid local image targets."""
    resolved_root = root.resolve()
    errors: list[str] = []
    for target in sorted(set(image_targets(document))):
        parsed = urlparse(target)
        if parsed.scheme or parsed.netloc:
            continue

        relative = Path(unquote(parsed.path))
        candidate = (resolved_root / relative).resolve()
        try:
            candidate.relative_to(resolved_root)
        except ValueError:
            errors.append(f"paper image escapes workspace: {target}")
            continue

        if not candidate.is_file() or candidate.stat().st_size == 0:
            errors.append(f"paper image is missing or empty: {target}")
    return errors


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate local image resources in a Pandoc JSON document."
    )
    parser.add_argument("document", type=Path, help="Pandoc JSON document.")
    parser.add_argument(
        "--root",
        type=Path,
        required=True,
        help="Root used to resolve local image targets.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        document = json.loads(args.document.read_text(encoding="utf-8"))
        errors = validate_assets(document, args.root)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"[o2i|error] Cannot validate paper assets: {error}", file=sys.stderr)
        return 1

    for error in errors:
        print(f"[o2i|error] {error}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
