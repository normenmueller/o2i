#!/usr/bin/env python3
"""Verify White Paper source binding and structural render consistency."""

from __future__ import annotations

import argparse
from hashlib import sha256
import json
from pathlib import Path
import re
import subprocess
import sys
import unicodedata
from typing import Optional, Sequence


MANIFEST_SCHEMA = "o2i.paper-freshness/v2"
RENDERER_CONTRACT = Path("acc/md2pdf.json")
RENDERER_CONTRACT_SCHEMA = "o2i.publication-renderer/v1"
STATIC_INPUTS = (
    "o2i.md",
    "README.md",
    "ACKNOWLEDGEMENTS.md",
    "toPDF.sh",
    "utl/render-archimate-profile.py",
    "utl/render-paper-figures.sh",
)


class PdfFreshnessError(ValueError):
    """A publication cannot be inspected or is not bound to current sources."""


def _validated_renderer_contract(payload: object, origin: str) -> dict[str, str]:
    """Validate the release identity and immutable CI acquisition revision."""
    expected_keys = {"acquisition_revision", "schema", "tool", "version"}
    if not isinstance(payload, dict) or set(payload) != expected_keys:
        raise PdfFreshnessError(f"{origin} has an invalid shape")
    if payload.get("schema") != RENDERER_CONTRACT_SCHEMA:
        raise PdfFreshnessError(f"{origin} has an unsupported schema")
    if payload.get("tool") != "md2pdf":
        raise PdfFreshnessError(f"{origin} identifies an unsupported tool")
    version = payload.get("version")
    if (
        not isinstance(version, str)
        or re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version) is None
    ):
        raise PdfFreshnessError(f"{origin} has an invalid version")
    revision = payload.get("acquisition_revision")
    if not isinstance(revision, str) or re.fullmatch(r"[0-9a-f]{40}", revision) is None:
        raise PdfFreshnessError(f"{origin} has an invalid acquisition revision")
    return {
        "acquisition_revision": revision,
        "schema": RENDERER_CONTRACT_SCHEMA,
        "tool": "md2pdf",
        "version": version,
    }


def read_renderer_contract(root: Path) -> dict[str, str]:
    """Read the sole repository-owned md2pdf release and acquisition contract."""
    path = root.resolve() / RENDERER_CONTRACT
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise PdfFreshnessError(f"cannot read renderer contract: {error}") from error
    return _validated_renderer_contract(payload, "renderer contract")


def _validated_manifest_renderer(payload: object) -> dict[str, str]:
    """Validate the renderer identity that a local build can prove."""
    if not isinstance(payload, dict) or set(payload) != {"tool", "version"}:
        raise PdfFreshnessError("publication manifest renderer has an invalid shape")
    if payload.get("tool") != "md2pdf":
        raise PdfFreshnessError("publication manifest renderer has an unsupported tool")
    version = payload.get("version")
    if (
        not isinstance(version, str)
        or re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version) is None
    ):
        raise PdfFreshnessError("publication manifest renderer has an invalid version")
    return {"tool": "md2pdf", "version": version}


def renderer_identity(root: Path) -> dict[str, str]:
    """Project the locally verifiable renderer identity from the contract."""
    contract = read_renderer_contract(root)
    return {"tool": contract["tool"], "version": contract["version"]}


def installed_renderer_version() -> str:
    """Return the semantic version reported by the installed md2pdf."""
    completed = subprocess.run(
        ["md2pdf", "--version"],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        detail = completed.stderr.strip() or "md2pdf --version failed"
        raise PdfFreshnessError(f"cannot inspect installed md2pdf: {detail}")
    match = re.search(
        r"(?:^|,\s*)v([0-9]+\.[0-9]+\.[0-9]+)(?:,|$)",
        completed.stdout.strip(),
    )
    if match is None:
        raise PdfFreshnessError("cannot read installed md2pdf version")
    return match.group(1)


def renderer_version_errors(root: Path) -> list[str]:
    """Return a diagnostic when installed md2pdf differs from the contract."""
    contract = read_renderer_contract(root)
    installed = installed_renderer_version()
    if installed == contract["version"]:
        return []
    return [
        f"installed md2pdf version {installed} differs from required "
        f"{contract['version']}"
    ]


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


def file_digest(path: Path) -> str:
    """Return one SHA-256 digest without interpreting file contents."""
    return sha256(path.read_bytes()).hexdigest()


def publication_inputs(root: Path) -> tuple[Path, ...]:
    """Return the closed, deterministic source set of the White Paper."""
    resolved_root = root.resolve()
    relative_inputs = {Path(name) for name in STATIC_INPUTS}
    article = resolved_root / "o2i.md"
    if not article.is_file():
        raise PdfFreshnessError(f"missing publication source: {article}")
    source = article.read_text(encoding="utf-8")

    for match in re.finditer(r"(?m)^!include(?:`[^`]*`)?\s+(.+?)\s*$", source):
        relative_inputs.add(Path(match.group(1)))
    for match in re.finditer(
        r"!\[[^\]]*\]\((?:<([^>]+)>|([^\s)]+))\)",
        source,
    ):
        relative_inputs.add(Path(match.group(1) or match.group(2)))
    for match in re.finditer(r"\\includegraphics(?:\[[^\]]*\])?\{([^}]+)\}", source):
        relative_inputs.add(Path(match.group(1)))

    acc = resolved_root / "acc"
    if acc.is_dir():
        relative_inputs.update(
            path.relative_to(resolved_root)
            for path in acc.rglob("*")
            if path.is_file() and path.name != ".DS_Store"
        )

    inputs = []
    for relative in sorted(relative_inputs, key=lambda path: path.as_posix()):
        candidate = (resolved_root / relative).resolve()
        try:
            candidate.relative_to(resolved_root)
        except ValueError as error:
            raise PdfFreshnessError(
                f"publication source escapes repository: {relative}"
            ) from error
        if not candidate.is_file() or candidate.stat().st_size == 0:
            raise PdfFreshnessError(f"missing publication source: {relative}")
        inputs.append(candidate)
    return tuple(inputs)


def publication_source_digest(root: Path) -> str:
    """Hash exact source paths and bytes with collision-free length framing."""
    resolved_root = root.resolve()
    digest = sha256()
    for path in publication_inputs(resolved_root):
        relative = path.relative_to(resolved_root).as_posix().encode("utf-8")
        content = path.read_bytes()
        for value in (relative, content):
            digest.update(str(len(value)).encode("ascii"))
            digest.update(b":")
            digest.update(value)
    return digest.hexdigest()


def publication_manifest(root: Path, pdf: Path) -> dict[str, object]:
    """Bind one PDF to its exact sources and renderer identity."""
    return {
        "pdf_sha256": file_digest(pdf),
        "renderer": renderer_identity(root),
        "schema": MANIFEST_SCHEMA,
        "source_sha256": publication_source_digest(root),
    }


def write_manifest(root: Path, pdf: Path, manifest: Path) -> None:
    """Write one canonical publication binding."""
    payload = publication_manifest(root, pdf)
    manifest.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def read_manifest(path: Path) -> dict[str, object]:
    """Read and validate the closed publication-manifest schema."""
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise PdfFreshnessError(f"cannot read publication manifest: {error}") from error
    if not isinstance(payload, dict) or set(payload) != {
        "pdf_sha256",
        "renderer",
        "schema",
        "source_sha256",
    }:
        raise PdfFreshnessError("publication manifest has an invalid shape")
    if payload.get("schema") != MANIFEST_SCHEMA:
        raise PdfFreshnessError("publication manifest has an unsupported schema")
    for name in ("pdf_sha256", "source_sha256"):
        value = payload.get(name)
        if not isinstance(value, str) or re.fullmatch(r"[0-9a-f]{64}", value) is None:
            raise PdfFreshnessError(f"publication manifest has invalid {name}")
    payload["renderer"] = _validated_manifest_renderer(payload.get("renderer"))
    return payload


def source_binding_errors(
    root: Path,
    versioned: Path,
    manifest: Path,
) -> list[str]:
    """Return stale-source or PDF-integrity diagnostics."""
    payload = read_manifest(manifest)
    errors = []
    current_source = publication_source_digest(root)
    if payload["source_sha256"] != current_source:
        errors.append("publication source fingerprint differs")
    if payload["renderer"] != renderer_identity(root):
        errors.append("publication renderer identity differs")
    current_pdf = file_digest(versioned)
    if payload["pdf_sha256"] != current_pdf:
        errors.append("versioned PDF digest differs from its publication manifest")
    return errors


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


def rendered_publication_errors(versioned: Path, rendered: Path) -> list[str]:
    """Return platform-stable structural and textual render differences."""
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
    return errors


def freshness_errors(
    root: Path,
    versioned: Path,
    rendered: Path,
    manifest: Path,
) -> list[str]:
    """Return source-binding and fresh-render differences."""
    return source_binding_errors(root, versioned, manifest) + (
        rendered_publication_errors(versioned, rendered)
    )


def _arguments(argv: Optional[Sequence[str]]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Seal or verify the versioned O2I White Paper.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    contract = subparsers.add_parser("contract")
    contract.add_argument("--root", type=Path, required=True)
    contract.add_argument(
        "--field",
        choices=("acquisition-revision", "version"),
        required=True,
    )

    renderer = subparsers.add_parser("renderer")
    renderer.add_argument("--root", type=Path, required=True)

    seal = subparsers.add_parser("seal")
    seal.add_argument("--root", type=Path, required=True)
    seal.add_argument("--pdf", type=Path, required=True)
    seal.add_argument("--manifest", type=Path, required=True)

    check = subparsers.add_parser("check")
    check.add_argument("--root", type=Path, required=True)
    check.add_argument("--versioned", type=Path, required=True)
    check.add_argument("--rendered", type=Path, required=True)
    check.add_argument("--manifest", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    """Seal or verify the versioned White Paper."""
    arguments = _arguments(argv)
    try:
        if arguments.command == "contract":
            field = arguments.field.replace("-", "_")
            print(read_renderer_contract(arguments.root)[field])
            return 0
        renderer_errors = renderer_version_errors(arguments.root)
        if renderer_errors:
            for error in renderer_errors:
                print(
                    f"[o2i|error] Publication renderer is invalid: {error}.",
                    file=sys.stderr,
                )
            return 1
        if arguments.command == "renderer":
            print("[o2i|info] Publication renderer identity is current.")
            return 0
        if arguments.command == "seal":
            write_manifest(arguments.root, arguments.pdf, arguments.manifest)
            print(
                "[o2i|info] White Paper source and renderer binding is current."
            )
            return 0
        errors = freshness_errors(
            arguments.root,
            arguments.versioned,
            arguments.rendered,
            arguments.manifest,
        )
    except (OSError, PdfFreshnessError) as error:
        print(f"[o2i|error] {error}", file=sys.stderr)
        return 1
    if errors:
        for error in errors:
            print(
                f"[o2i|error] White Paper source binding is invalid: {error}.",
                file=sys.stderr,
            )
        return 1
    print(
        "[o2i|info] White Paper source, renderer, and structural render "
        "bindings are current."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
