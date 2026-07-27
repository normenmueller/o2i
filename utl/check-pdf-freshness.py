#!/usr/bin/env python3
"""Compare a versioned PDF with one freshly rendered publication."""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import subprocess
import sys
import unicodedata
from typing import Optional, Sequence


class PdfFreshnessError(ValueError):
    """A PDF cannot be inspected or differs from the current publication."""


def normalized_pdf_text(path: Path) -> str:
    """Return metadata-independent PDF text with layout whitespace removed."""
    completed = subprocess.run(
        ["pdftotext", "-enc", "UTF-8", "-nopgbrk", str(path), "-"],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        detail = completed.stderr.strip() or "pdftotext failed"
        raise PdfFreshnessError(f"cannot extract {path}: {detail}")
    normalized = unicodedata.normalize("NFKC", completed.stdout)
    return "".join(normalized.split())


def pdf_page_count(path: Path) -> int:
    """Return the page count reported by pdfinfo."""
    completed = subprocess.run(
        ["pdfinfo", str(path)],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        detail = completed.stderr.strip() or "pdfinfo failed"
        raise PdfFreshnessError(f"cannot inspect {path}: {detail}")
    match = re.search(r"^Pages:\s+([0-9]+)\s*$", completed.stdout, re.MULTILINE)
    if match is None:
        raise PdfFreshnessError(f"cannot read page count from {path}")
    return int(match.group(1))


def freshness_errors(versioned: Path, rendered: Path) -> list[str]:
    """Return semantic publication differences between two PDFs."""
    errors = []
    versioned_pages = pdf_page_count(versioned)
    rendered_pages = pdf_page_count(rendered)
    if versioned_pages != rendered_pages:
        errors.append(
            f"page count differs: versioned {versioned_pages}, "
            f"rendered {rendered_pages}"
        )
    if normalized_pdf_text(versioned) != normalized_pdf_text(rendered):
        errors.append("normalized publication text differs")
    return errors


def _arguments(argv: Optional[Sequence[str]]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check whether a versioned PDF matches a fresh render.",
    )
    parser.add_argument("versioned", type=Path)
    parser.add_argument("rendered", type=Path)
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    """Run the PDF freshness check."""
    arguments = _arguments(argv)
    try:
        errors = freshness_errors(arguments.versioned, arguments.rendered)
    except (OSError, PdfFreshnessError) as error:
        print(f"[o2i|error] {error}", file=sys.stderr)
        return 1
    if errors:
        for error in errors:
            print(
                f"[o2i|error] Versioned White Paper is stale: {error}.",
                file=sys.stderr,
            )
        return 1
    print("[o2i|info] Versioned White Paper is current.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
