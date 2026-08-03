#!/usr/bin/env python3
"""Verify repository Candidate Views through the public O2I CLI contract."""

from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import subprocess
import sys
from typing import Any


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MODEL = REPOSITORY_ROOT / "mdl" / "o2i.archimate"
CLI_TIMEOUT_SECONDS = 30
EXPECTED_SCHEMA = "o2i.inspection.report/v1"

EXPECTED_DIAGNOSTICS = {
    "O2I Syntax - Contextualization": Counter(
        {"o2i.claim.candidate-excluded": 4}
    ),
    "O2I Syntax - Collective Strategy Realization": Counter(
        {
            "o2i.claim.candidate-excluded": 3,
            "o2i.claim.collective-candidate-excluded": 1,
            (
                "o2i.semantics.collective."
                "candidate-participant-semantics-unavailable"
            ): 3,
        }
    ),
}

EXPECTED_STAGES = (
    ("decode", "passed", None),
    ("view-scope", "passed", None),
    ("profile", "passed", None),
    ("structure", "passed", None),
    ("semantics", "unavailable", None),
    (
        "traceability",
        "not-run",
        (("reason", "unavailable"), ("stage", "semantics")),
    ),
    (
        "readiness",
        "not-run",
        (("reason", "unavailable"), ("stage", "semantics")),
    ),
    (
        "evidence",
        "not-run",
        (("reason", "unavailable"), ("stage", "semantics")),
    ),
)


def validate_report(
    view_name: str,
    exit_code: int,
    report: Any,
) -> list[str]:
    """Return deterministic contract violations for one Candidate View."""
    errors = []
    if exit_code != 3:
        errors.append(f"expected CLI exit 3, found {exit_code}")
    if not isinstance(report, dict):
        return errors + ["JSON report is not an object"]
    if report.get("schema") != EXPECTED_SCHEMA:
        errors.append(
            f"expected schema {EXPECTED_SCHEMA!r}, "
            f"found {report.get('schema')!r}"
        )
    if report.get("inspectionState") != "inspected":
        errors.append(
            "expected inspectionState 'inspected', found "
            f"{report.get('inspectionState')!r}"
        )
    if report.get("result") != "partial":
        errors.append(
            f"expected result 'partial', found {report.get('result')!r}"
        )

    request = report.get("request")
    if not isinstance(request, dict):
        errors.append("request is not an object")
        selector = None
    else:
        selector = request.get("viewSelector")
    if selector != {"kind": "name", "value": view_name}:
        errors.append(f"unexpected View selector: {selector!r}")
    view_resolution = report.get("viewResolution")
    if not isinstance(view_resolution, dict):
        errors.append("viewResolution is not an object")
        resolved_view = None
    else:
        resolved_view = view_resolution.get("view")
    if not isinstance(resolved_view, dict):
        errors.append("viewResolution.view is not an object")
        resolved_name = None
    else:
        resolved_name = resolved_view.get("name")
    if resolved_name != view_name:
        errors.append(
            f"resolved View name differs: {resolved_name!r}"
        )

    stages = report.get("stages")
    if not isinstance(stages, list):
        errors.append("stages is not an array")
    elif not all(isinstance(stage, dict) for stage in stages):
        errors.append("stages contains a non-object entry")
    else:
        actual_stages = []
        for stage in stages:
            blocked_by = stage.get("blockedBy")
            if blocked_by is not None and not isinstance(blocked_by, dict):
                errors.append(
                    f"stage {stage.get('stage')!r} blockedBy is not an object"
                )
            normalized_blocker = (
                tuple(sorted(blocked_by.items()))
                if isinstance(blocked_by, dict)
                else blocked_by
            )
            actual_stages.append(
                (
                    stage.get("stage"),
                    stage.get("state"),
                    normalized_blocker,
                )
            )
        if tuple(actual_stages) != EXPECTED_STAGES:
            errors.append(
                f"unexpected stage states: {tuple(actual_stages)!r}"
            )

    diagnostics = report.get("diagnostics")
    if not isinstance(diagnostics, list):
        errors.append("diagnostics is not an array")
    elif not all(isinstance(item, dict) for item in diagnostics):
        errors.append("diagnostics contains a non-object entry")
    else:
        actual_diagnostics = Counter(
            diagnostic.get("code")
            if isinstance(diagnostic.get("code"), str)
            else repr(diagnostic.get("code"))
            for diagnostic in diagnostics
        )
        expected_diagnostics = EXPECTED_DIAGNOSTICS[view_name]
        if actual_diagnostics != expected_diagnostics:
            errors.append(
                "unexpected diagnostic multiset: "
                f"{dict(sorted(actual_diagnostics.items()))!r}"
            )
        for diagnostic in diagnostics:
            if diagnostic.get("stage") != "semantics":
                errors.append(
                    f"diagnostic {diagnostic.get('code')!r} is not semantic"
                )
            if diagnostic.get("severity") != "warn":
                errors.append(
                    f"diagnostic {diagnostic.get('code')!r} is not a warning"
                )

    return errors


def inspect_view(o2i: Path, model: Path, view_name: str) -> list[str]:
    """Run one public CLI inspection and validate its complete JSON result."""
    try:
        result = subprocess.run(
            [
                str(o2i),
                "inspect",
                str(model),
                "--view",
                view_name,
                "--json",
            ],
            check=False,
            capture_output=True,
            text=True,
            timeout=CLI_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        return [
            "O2I CLI exceeded "
            f"the {CLI_TIMEOUT_SECONDS}-second execution limit"
        ]
    except OSError as error:
        return [f"cannot execute O2I CLI: {error}"]
    try:
        report = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        detail = result.stderr.strip()
        suffix = f"; stderr: {detail}" if detail else ""
        return [f"invalid JSON report: {error}{suffix}"]
    return validate_report(view_name, result.returncode, report)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check executable O2I repository Candidate Views."
    )
    parser.add_argument("--o2i", type=Path, required=True)
    parser.add_argument("--model", type=Path, default=DEFAULT_MODEL)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    errors = []
    for view_name in EXPECTED_DIAGNOSTICS:
        errors.extend(
            f"{view_name}: {error}"
            for error in inspect_view(args.o2i, args.model, view_name)
        )
    if errors:
        for error in errors:
            print(f"[o2i|error] {error}", file=sys.stderr)
        return 1
    print(
        "[o2i|success] Executable Candidate Views satisfy the repository "
        "acceptance contract."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
