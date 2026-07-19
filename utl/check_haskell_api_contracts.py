#!/usr/bin/env python3

"""Check the public Haskell API from an external client boundary."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


ERROR_CODE = re.compile(r"GHC-\d+")


@dataclass(frozen=True)
class CompileFailure:
    source: str
    diagnostics: tuple[tuple[str, int], ...]


@dataclass(frozen=True)
class PackageContract:
    package: str
    compile_pass: str
    compile_failures: tuple[CompileFailure, ...]


CONTRACTS = (
    PackageContract(
        "o2i-core",
        "spc/lib/core/tst/api/compile-pass/PublicApi.hs",
        (
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "AggregateOpaqueConstructors.hs",
                (("GHC-31891", 25),),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/AggregateRecordUpdates.hs",
                (("GHC-47535", 25),),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "GraphOpaqueConstructors.hs",
                (("GHC-31891", 5),),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/GraphRecordUpdates.hs",
                (("GHC-47535", 3),),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "LanguageOpaqueConstructors.hs",
                (("GHC-31891", 9),),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/LanguageOpaquePatterns.hs",
                (("GHC-76037", 1),),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/LanguageRecordUpdates.hs",
                (("GHC-47535", 12),),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "ValidationOpaqueConstructors.hs",
                (("GHC-31891", 13),),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "ValidationRecordUpdates.hs",
                (("GHC-47535", 20),),
            ),
        ),
    ),
    PackageContract(
        "o2i-inspection",
        "spc/lib/inspection/tst/api/compile-pass/PublicApi.hs",
        (
            CompileFailure(
                "spc/lib/inspection/tst/api/compile-fail/"
                "ForeignAdapterLocation.hs",
                (("GHC-83865", 1),),
            ),
            CompileFailure(
                "spc/lib/inspection/tst/api/compile-fail/"
                "HiddenNormalization.hs",
                (("GHC-76037", 6),),
            ),
            CompileFailure(
                "spc/lib/inspection/tst/api/compile-fail/"
                "HiddenSourceBinding.hs",
                (("GHC-76037", 2),),
            ),
            CompileFailure(
                "spc/lib/inspection/tst/api/compile-fail/"
                "OpaqueConstructors.hs",
                (("GHC-31891", 21), ("GHC-47535", 12)),
            ),
        ),
    ),
)


def parse_diagnostics(output: str) -> list[dict[str, object]]:
    diagnostics = []
    for line in output.splitlines():
        if not line.startswith("{"):
            continue
        try:
            value = json.loads(line)
        except json.JSONDecodeError as error:
            raise ValueError(f"invalid GHC JSON diagnostic: {line}") from error
        if isinstance(value, dict) and "messageClass" in value:
            diagnostics.append(value)
    return diagnostics


def error_code(diagnostic: dict[str, object]) -> str | None:
    message_class = diagnostic.get("messageClass")
    if not isinstance(message_class, str) or "SevError" not in message_class:
        return None
    match = ERROR_CODE.search(message_class)
    return match.group(0) if match else None


def diagnostic_file(
    root: Path, diagnostic: dict[str, object]
) -> Path | None:
    span = diagnostic.get("span")
    if not isinstance(span, dict):
        return None
    name = span.get("file")
    if not isinstance(name, str):
        return None
    path = Path(name)
    return (path if path.is_absolute() else root / path).resolve()


def compiler_command(
    project_dir: Path,
    build_dir: Path,
    package: str,
    source: Path,
    output_dir: Path,
) -> list[str]:
    return [
        "cabal",
        "-v0",
        f"--project-dir={project_dir}",
        f"--builddir={build_dir}",
        "exec",
        "--",
        "ghc",
        "-v0",
        "-fno-code",
        "-fforce-recomp",
        "-fmax-errors=1000",
        "-ddump-json",
        f"-odir={output_dir}",
        f"-hidir={output_dir}",
        f"-stubdir={output_dir}",
        "-package",
        package,
        str(source),
    ]


def compile_source(
    root: Path,
    project_dir: Path,
    build_dir: Path,
    package: str,
    source_name: str,
) -> subprocess.CompletedProcess[str]:
    source = (root / source_name).resolve()
    with tempfile.TemporaryDirectory(prefix="o2i-api-contract.") as temporary:
        command = compiler_command(
            project_dir,
            build_dir,
            package,
            source,
            Path(temporary),
        )
        return subprocess.run(
            command,
            cwd=root,
            capture_output=True,
            text=True,
            check=False,
        )


def combined_output(result: subprocess.CompletedProcess[str]) -> str:
    return result.stdout + result.stderr


def check_compile_pass(
    root: Path,
    project_dir: Path,
    build_dir: Path,
    contract: PackageContract,
) -> None:
    result = compile_source(
        root,
        project_dir,
        build_dir,
        contract.package,
        contract.compile_pass,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"{contract.package} external client control failed:\n"
            + combined_output(result)
        )


def check_compile_failure(
    root: Path,
    project_dir: Path,
    build_dir: Path,
    package: str,
    failure: CompileFailure,
) -> None:
    result = compile_source(
        root, project_dir, build_dir, package, failure.source
    )
    output = combined_output(result)
    if result.returncode == 0:
        raise RuntimeError(f"{failure.source} unexpectedly compiled")

    diagnostics = parse_diagnostics(output)
    source = (root / failure.source).resolve()
    foreign = [
        diagnostic
        for diagnostic in diagnostics
        if diagnostic_file(root, diagnostic) != source
    ]
    if foreign:
        raise RuntimeError(
            f"{failure.source} produced non-local diagnostics:\n{output}"
        )

    actual = Counter(
        code for diagnostic in diagnostics if (code := error_code(diagnostic))
    )
    expected = Counter(dict(failure.diagnostics))
    if actual != expected:
        raise RuntimeError(
            f"{failure.source} diagnostics differ: expected {expected}, "
            f"found {actual}\n{output}"
        )


def check_contracts(
    root: Path, project_dir: Path, build_dir: Path
) -> None:
    for contract in CONTRACTS:
        check_compile_pass(root, project_dir, build_dir, contract)
        for failure in contract.compile_failures:
            check_compile_failure(
                root,
                project_dir,
                build_dir,
                contract.package,
                failure,
            )


def parse_args(arguments: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check external Haskell API compile contracts."
    )
    parser.add_argument("--project-dir", required=True, type=Path)
    parser.add_argument("--builddir", required=True, type=Path)
    return parser.parse_args(arguments)


def main(arguments: Iterable[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if arguments is None else arguments)
    root = Path(__file__).resolve().parents[1]
    try:
        check_contracts(
            root,
            args.project_dir.resolve(),
            args.builddir.resolve(),
        )
    except (OSError, RuntimeError, ValueError) as error:
        print(f"[o2i|error] {error}", file=sys.stderr)
        return 1
    print("[o2i|info] External Haskell API contracts passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
