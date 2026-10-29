#!/usr/bin/env python3
"""Render O2I inline-code regression cases and verify their PDF text."""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys
import tempfile
import unicodedata
from typing import Sequence


CASES = (
    "upper Strategy",
    "xübergeordnet",
    "übergeordnete Strategy",
    r"über_wert%{x}#&\path",
    "ü = value + 1!",
)


def run(command: Sequence[str], directory: Path, subject: str) -> str:
    """Return command output or report the failing integration step."""
    completed = subprocess.run(
        command,
        cwd=directory,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if completed.returncode != 0:
        detail = "\n".join(
            value.strip()
            for value in (completed.stdout, completed.stderr)
            if value.strip()
        )
        raise ValueError(
            f"{subject} failed with exit {completed.returncode}"
            + (f":\n{detail}" if detail else "")
        )
    return completed.stdout


def normalized_text(value: str) -> str:
    """Ignore layout whitespace while preserving the rendered characters."""
    return " ".join(unicodedata.normalize("NFC", value).split())


def check_inline_code(root: Path) -> None:
    """Exercise the contracted renderer with the actual O2I paper header."""
    root = root.resolve()
    header = root / "doc/resources/o2i.icl"
    if not header.is_file() or header.stat().st_size == 0:
        raise ValueError(f"missing or empty O2I paper header: {header}")
    run(
        [
            sys.executable,
            "-B",
            str(root / "utl/paper/check-pdf-freshness.py"),
            "renderer",
            "--root",
            str(root),
        ],
        root,
        "renderer identity check",
    )

    with tempfile.TemporaryDirectory(prefix="o2i-inline-code-") as temporary:
        directory = Path(temporary)
        source = directory / "inline-code.md"
        pdf = directory / "inline-code.pdf"
        source.write_text(
            "\n\n".join(
                f"Case {number}: `{value}`."
                for number, value in enumerate(CASES, start=1)
            )
            + "\n",
            encoding="utf-8",
        )
        run(
            ["md2pdf", "-o", str(pdf), "--", str(source), "-H", str(header)],
            directory,
            "inline-code PDF rendering",
        )
        if not pdf.is_file() or pdf.stat().st_size == 0:
            raise ValueError("inline-code rendering produced no nonempty PDF")
        actual = normalized_text(
            run(
                ["pdftotext", "-raw", "-enc", "UTF-8", str(pdf), "-"],
                directory,
                "inline-code PDF text extraction",
            )
        )
        for number, value in enumerate(CASES, start=1):
            expected = normalized_text(f"Case {number}: {value}.")
            count = actual.count(expected)
            if count != 1:
                raise ValueError(
                    f"inline-code case {number} is missing, changed or duplicated: "
                    f"expected {expected!r} once, found {count} occurrences"
                )


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help="O2I repository root (defaults to this script's repository).",
    )
    arguments = parser.parse_args(argv)
    try:
        check_inline_code(arguments.root)
    except (OSError, UnicodeError, ValueError) as error:
        print(f"[o2i|error] {error}", file=sys.stderr)
        return 1
    print("[o2i|info] Inline code compiles and preserves all five PDF text cases.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
