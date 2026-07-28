#!/usr/bin/env python3
"""Compare a versioned PDF with one freshly rendered publication."""

from __future__ import annotations

import argparse
from hashlib import sha256
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unicodedata
from typing import Optional, Sequence


class PdfFreshnessError(ValueError):
    """A PDF cannot be inspected or differs from the current publication."""


def normalized_pdf_text(path: Path) -> str:
    """Return metadata-independent PDF text with normalized word boundaries."""
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
    return " ".join(normalized.split())


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


def pdf_page_raster_digests(
    path: Path,
    expected_pages: int,
) -> tuple[tuple[int, str], ...]:
    """Return deterministic per-page digests of a fixed-resolution rendering."""
    with tempfile.TemporaryDirectory(prefix="o2i-pdf-raster.") as directory:
        prefix = Path(directory) / "page"
        completed = subprocess.run(
            [
                "pdftoppm",
                "-q",
                "-r",
                "96",
                str(path),
                str(prefix),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        if completed.returncode != 0:
            detail = completed.stderr.strip() or "pdftoppm failed"
            raise PdfFreshnessError(f"cannot rasterize {path}: {detail}")

        numbered_pages = []
        for page_path in Path(directory).glob("page-*.ppm"):
            match = re.fullmatch(r"page-([0-9]+)\.ppm", page_path.name)
            if match is not None:
                numbered_pages.append((int(match.group(1)), page_path))
        numbered_pages.sort(key=lambda item: item[0])
        actual_pages = tuple(page for page, _ in numbered_pages)
        required_pages = tuple(range(1, expected_pages + 1))
        if actual_pages != required_pages:
            raise PdfFreshnessError(
                f"cannot read complete page raster sequence from {path}: "
                f"expected {required_pages}, found {actual_pages}"
            )
        return tuple(
            (page, sha256(page_path.read_bytes()).hexdigest())
            for page, page_path in numbered_pages
        )


def _first_text_difference(versioned: str, rendered: str) -> str:
    """Describe the first differing normalized text token."""
    versioned_tokens = versioned.split()
    rendered_tokens = rendered.split()
    shared = min(len(versioned_tokens), len(rendered_tokens))
    index = next(
        (
            position
            for position in range(shared)
            if versioned_tokens[position] != rendered_tokens[position]
        ),
        shared,
    )
    versioned_token = (
        versioned_tokens[index] if index < len(versioned_tokens) else "<end>"
    )
    rendered_token = (
        rendered_tokens[index] if index < len(rendered_tokens) else "<end>"
    )
    return (
        f"normalized publication text differs at token {index + 1}: "
        f"versioned {versioned_token!r}, rendered {rendered_token!r}"
    )


def freshness_errors(versioned: Path, rendered: Path) -> list[str]:
    """Return semantic and visual differences between two PDFs."""
    errors = []
    versioned_pages = pdf_page_count(versioned)
    rendered_pages = pdf_page_count(rendered)
    if versioned_pages != rendered_pages:
        errors.append(
            f"page count differs: versioned {versioned_pages}, "
            f"rendered {rendered_pages}"
        )
    versioned_text = normalized_pdf_text(versioned)
    rendered_text = normalized_pdf_text(rendered)
    if versioned_text != rendered_text:
        errors.append(_first_text_difference(versioned_text, rendered_text))
    if versioned_pages == rendered_pages:
        versioned_rasters = pdf_page_raster_digests(
            versioned,
            versioned_pages,
        )
        rendered_rasters = pdf_page_raster_digests(
            rendered,
            rendered_pages,
        )
        changed_pages = [
            page
            for (page, versioned_digest), (_, rendered_digest) in zip(
                versioned_rasters,
                rendered_rasters,
            )
            if versioned_digest != rendered_digest
        ]
        if changed_pages:
            pages = ", ".join(str(page) for page in changed_pages)
            errors.append(f"visual content differs on pages: {pages}")
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
