#!/usr/bin/env python3

"""Check public API and private type-safety compile contracts."""

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
IMPORT_MODULE = re.compile(
    r"^[ \t]*import\b"
    r"(?:(?:[ \t\r\n]+)|(?:safe\b)|(?:qualified\b))*"
    r"(?P<module>[A-Z][A-Za-z0-9_']*"
    r"(?:\.[A-Z][A-Za-z0-9_']*)*)",
    re.MULTILINE,
)
RELATIONAL_INTERNAL_MODULE = "O2I.Validation.Relational.Internal"
RELATIONAL_INTERNAL_IMPORTERS = frozenset(
    {
        "O2I/Validation/Relational/Eval.hs",
        "O2I/Validation/Relational/Index.hs",
        "O2I/Validation/Relational/Types.hs",
    }
)


@dataclass(frozen=True)
class CompileFailure:
    source: str
    diagnostics: tuple[tuple[str, int], ...]


@dataclass(frozen=True)
class PackageContract:
    package: str
    compile_pass: str
    compile_failures: tuple[CompileFailure, ...]


@dataclass(frozen=True)
class PrivateCompileFailure:
    source: str
    diagnostics: tuple[tuple[str, int], ...]


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
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "ValidationCollectiveParallelCommitment.hs",
                (("GHC-76037", 1),),
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
    PackageContract(
        "o2i-archimate-profile",
        "spc/ctr/archimate/tst/api/compile-pass/PublicApi.hs",
        (
            CompileFailure(
                "spc/ctr/archimate/tst/api/compile-fail/"
                "OpaqueConstructors.hs",
                (("GHC-31891", 11),),
            ),
            CompileFailure(
                "spc/ctr/archimate/tst/api/compile-fail/"
                "OpaqueVocabularyConstructors.hs",
                (("GHC-76037", 6),),
            ),
            CompileFailure(
                "spc/ctr/archimate/tst/api/compile-fail/"
                "ContractRecordUpdates.hs",
                (("GHC-47535", 13),),
            ),
            CompileFailure(
                "spc/ctr/archimate/tst/api/compile-fail/"
                "MappingRecordUpdates.hs",
                (("GHC-47535", 10),),
            ),
            CompileFailure(
                "spc/ctr/archimate/tst/api/compile-fail/"
                "CollectiveRecordUpdates.hs",
                (("GHC-47535", 18),),
            ),
            CompileFailure(
                "spc/ctr/archimate/tst/api/compile-fail/"
                "HiddenInternalModule.hs",
                (),
            ),
        ),
    ),
)

PRIVATE_COMPILE_FAILURES = (
    PrivateCompileFailure(
        "spc/lib/core/tst/internal/compile-fail/"
        "MacroEvidenceEndpointMismatch.hs",
        (("GHC-83865", 1),),
    ),
    PrivateCompileFailure(
        "spc/lib/core/tst/internal/compile-fail/"
        "MacroEvidenceProjectionMismatch.hs",
        (("GHC-83865", 1),),
    ),
    PrivateCompileFailure(
        "spc/lib/core/tst/internal/compile-fail/"
        "RelationalEndpointVariableMismatch.hs",
        (("GHC-83865", 1),),
    ),
    PrivateCompileFailure(
        "spc/lib/core/tst/internal/compile-fail/"
        "RelationalTypedProjectionMismatch.hs",
        (("GHC-83865", 1),),
    ),
    PrivateCompileFailure(
        "spc/lib/core/tst/internal/compile-fail/"
        "RelationalCrossScopeVariable.hs",
        (("GHC-25897", 1),),
    ),
    PrivateCompileFailure(
        "spc/lib/core/tst/internal/compile-fail/"
        "RelationalDisconnectedPlan.hs",
        (("GHC-31891", 1),),
    ),
    PrivateCompileFailure(
        "spc/lib/core/tst/internal/compile-fail/"
        "RelationalProjectionTokenMismatch.hs",
        (("GHC-83865", 1),),
    ),
    PrivateCompileFailure(
        "spc/lib/core/tst/internal/compile-fail/"
        "RelationalProjectionScopeMismatch.hs",
        (("GHC-83865", 1),),
    ),
    PrivateCompileFailure(
        "spc/lib/core/tst/internal/compile-fail/"
        "RelationalProjectionEndpointMismatch.hs",
        (("GHC-83865", 1),),
    ),
    PrivateCompileFailure(
        "spc/lib/core/tst/internal/compile-fail/"
        "RelationalProjectionModeMismatch.hs",
        (("GHC-83865", 1),),
    ),
    PrivateCompileFailure(
        "spc/lib/core/tst/internal/compile-fail/"
        "RelationalMatchedConstructionOutsideExecutor.hs",
        (("GHC-88464", 1),),
    ),
    PrivateCompileFailure(
        "spc/lib/core/tst/internal/compile-fail/"
        "RelationalProjectionApplicationOutsideExecutor.hs",
        (("GHC-88464", 1),),
    ),
    PrivateCompileFailure(
        "spc/lib/core/tst/internal/compile-fail/"
        "RelationalOccurrenceEndpointMismatch.hs",
        (("GHC-83865", 1),),
    ),
    PrivateCompileFailure(
        "spc/lib/core/tst/internal/compile-fail/"
        "RelationalOccurrenceOrderMismatch.hs",
        (("GHC-25897", 1),),
    ),
    PrivateCompileFailure(
        "spc/lib/core/tst/internal/compile-fail/"
        "RelationalOccurrenceConstructionOutsideExecutor.hs",
        (("GHC-31891", 1),),
    ),
    PrivateCompileFailure(
        "spc/lib/core/tst/internal/compile-fail/"
        "TraceRuleCrossScope.hs",
        (("GHC-25897", 1),),
    ),
    PrivateCompileFailure(
        "spc/lib/core/tst/internal/compile-fail/"
        "TraceRuleEndpointMismatch.hs",
        (("GHC-83865", 1),),
    ),
    PrivateCompileFailure(
        "spc/lib/core/tst/internal/compile-fail/"
        "TraceRuleOccurrenceOrder.hs",
        (("GHC-25897", 1),),
    ),
    PrivateCompileFailure(
        "spc/lib/core/tst/internal/compile-fail/"
        "TraceRuleAnchorMismatch.hs",
        (("GHC-83865", 1),),
    ),
)

PRIVATE_COMPILE_PASSES = (
    "spc/lib/core/tst/internal/compile-pass/MacroVocabulary.hs",
    "spc/lib/core/tst/internal/compile-pass/"
    "RelationalOccurrenceProjection.hs",
    "spc/lib/core/tst/internal/compile-pass/RelationalPlan.hs",
    "spc/lib/core/tst/internal/compile-pass/TraceRules.hs",
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


def private_compiler_command(
    project_dir: Path,
    build_dir: Path,
    source: Path,
    source_dir: Path,
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
        f"-i{source_dir}",
        f"-odir={output_dir}",
        f"-hidir={output_dir}",
        f"-stubdir={output_dir}",
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


def compile_private_source(
    root: Path,
    project_dir: Path,
    build_dir: Path,
    source_name: str,
) -> subprocess.CompletedProcess[str]:
    source = (root / source_name).resolve()
    source_dir = (root / "spc/lib/core/src").resolve()
    with tempfile.TemporaryDirectory(
        prefix="o2i-private-contract."
    ) as temporary:
        command = private_compiler_command(
            project_dir,
            build_dir,
            source,
            source_dir,
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


def haskell_code(source: str) -> str:
    """Blank comments and strings while retaining token positions and lines."""
    result = []
    index = 0
    block_depth = 0
    in_line_comment = False
    in_string = False
    escaped = False
    while index < len(source):
        current = source[index]
        following = source[index + 1] if index + 1 < len(source) else ""
        if in_line_comment:
            if current == "\n":
                in_line_comment = False
                result.append(current)
            else:
                result.append(" ")
        elif block_depth:
            if current == "{" and following == "-":
                block_depth += 1
                result.extend((" ", " "))
                index += 1
            elif current == "-" and following == "}":
                block_depth -= 1
                result.extend((" ", " "))
                index += 1
            else:
                result.append("\n" if current == "\n" else " ")
        elif in_string:
            if current == "\n":
                in_string = False
                escaped = False
                result.append(current)
            elif current == '"' and not escaped:
                in_string = False
                result.append(" ")
            else:
                escaped = current == "\\" and not escaped
                if current != "\\":
                    escaped = False
                result.append(" ")
        elif current == "-" and following == "-":
            in_line_comment = True
            result.extend((" ", " "))
            index += 1
        elif current == "{" and following == "-":
            block_depth = 1
            result.extend((" ", " "))
            index += 1
        elif current == '"':
            in_string = True
            escaped = False
            result.append(" ")
        else:
            result.append(current)
        index += 1
    return "".join(result)


def imported_modules(source: str) -> tuple[str, ...]:
    """Read module names from ordinary and qualified import declarations."""
    code = haskell_code(source)
    return tuple(
        declaration.group("module")
        for declaration in IMPORT_MODULE.finditer(code)
    )


def check_relational_internal_import_boundary(root: Path) -> None:
    source_root = root / "spc/lib/core/src"
    violations = []
    for source in sorted(source_root.rglob("*.hs")):
        relative = source.relative_to(source_root).as_posix()
        if relative in RELATIONAL_INTERNAL_IMPORTERS:
            continue
        if RELATIONAL_INTERNAL_MODULE in imported_modules(source.read_text()):
            violations.append(relative)
    if violations:
        raise RuntimeError(
            "executor-internal relational imports outside the trusted boundary: "
            + ", ".join(violations)
        )


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
    assert_compile_failure(
        root, failure.source, failure.diagnostics, result
    )


def check_private_compile_failure(
    root: Path,
    project_dir: Path,
    build_dir: Path,
    failure: PrivateCompileFailure,
) -> None:
    result = compile_private_source(
        root, project_dir, build_dir, failure.source
    )
    assert_compile_failure(
        root, failure.source, failure.diagnostics, result
    )


def check_private_compile_pass(
    root: Path,
    project_dir: Path,
    build_dir: Path,
    source_name: str,
) -> None:
    result = compile_private_source(
        root, project_dir, build_dir, source_name
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"{source_name} private control failed:\n"
            + combined_output(result)
        )


def assert_compile_failure(
    root: Path,
    source_name: str,
    expected_diagnostics: tuple[tuple[str, int], ...],
    result: subprocess.CompletedProcess[str],
) -> None:
    output = combined_output(result)
    if result.returncode == 0:
        raise RuntimeError(f"{source_name} unexpectedly compiled")

    diagnostics = parse_diagnostics(output)
    source = (root / source_name).resolve()
    foreign = [
        diagnostic
        for diagnostic in diagnostics
        if diagnostic_file(root, diagnostic) != source
    ]
    if foreign:
        raise RuntimeError(
            f"{source_name} produced non-local diagnostics:\n{output}"
        )

    actual = Counter(
        code for diagnostic in diagnostics if (code := error_code(diagnostic))
    )
    expected = Counter(dict(expected_diagnostics))
    if actual != expected:
        raise RuntimeError(
            f"{source_name} diagnostics differ: expected {expected}, "
            f"found {actual}\n{output}"
        )


def check_contracts(
    root: Path, project_dir: Path, build_dir: Path
) -> None:
    check_relational_internal_import_boundary(root)
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
    for failure in PRIVATE_COMPILE_FAILURES:
        check_private_compile_failure(
            root,
            project_dir,
            build_dir,
            failure,
        )
    for source_name in PRIVATE_COMPILE_PASSES:
        check_private_compile_pass(
            root,
            project_dir,
            build_dir,
            source_name,
        )


def parse_args(arguments: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check public and private Haskell compile contracts."
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
    print("[o2i|info] Haskell compile contracts passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
