#!/usr/bin/env python3
"""Select the O2I verification stages affected by one Git change."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
from pathlib import Path
import re
import subprocess
from typing import Iterable, Sequence


STAGES = ("licensing", "governance", "model", "haskell", "paper")
ALL_STAGES = frozenset(STAGES)
REVISION = re.compile(r"[0-9a-f]{40}")

FULL_PATHS = frozenset(
    {
        ".gitattributes",
        "utl/verification/verification_scope.py",
        "utl/verification/test_verification_scope.py",
        "utl/verify.sh",
    }
)
NEUTRAL_PATHS = frozenset(
    {
        ".gitignore",
        "CHANGELOG.md",
        "LICENSING.md",
        "REUSE.toml",
    }
)
GOVERNANCE_PATHS = frozenset(
    {
        "AGENTS.md",
        "CONTRIBUTING.md",
        "utl/governance/test_github_governance.py",
    }
)
LICENSING_PATHS = frozenset(
    {
        "utl/licensing/check-license-texts.sh",
        "utl/licensing/check_license_assignments.py",
        "utl/licensing/test_license_assignments.py",
    }
)
MODEL_PATHS = frozenset(
    {
        "utl/model/check-executable-views.py",
        "utl/model/audit-archimate-model.py",
        "utl/model/extract-archimate-view.py",
        "utl/model/focused_view_contract.py",
        "utl/model/repository_view_contract.py",
        "utl/model/test_audit_archimate_model.py",
        "utl/model/test_check_executable_views.py",
        "utl/model/test_extract_archimate_view.py",
        "utl/model/test_focused_view_contract.py",
        "utl/model/test_repository_view_contract.py",
    }
)
HASKELL_PATHS = frozenset(
    {
        "mdl/o2i.archimate",
        "utl/model/check-executable-views.py",
        "utl/model/test_check_executable_views.py",
        "utl/haskell/check-package-licenses.sh",
        "utl/haskell/check_cabal_plan.py",
        "utl/haskell/check_haskell_api_contracts.py",
        "utl/haskell/test_check_cabal_plan.py",
        "utl/haskell/test_check_haskell_api_contracts.py",
    }
)
PAPER_PATHS = frozenset(
    {
        "ACKNOWLEDGEMENTS.md",
        "README.md",
        "o2i.md",
        "o2i.pdf",
        "o2i.pdf.manifest.json",
        "toPDF.sh",
        "utl/paper/check-paper-assets.py",
        "utl/paper/check-pdf-freshness.py",
        "utl/paper/render-paper-figures.sh",
        "utl/paper/test_check_paper_assets.py",
        "utl/paper/test_check_pdf_freshness.py",
        "wtf.md",
    }
)
HASKELL_OPERATION_PATHS = frozenset(
    {
        ".ai4x/operations/haskell-authoring.md",
        ".ai4x/operations/haskell-review.md",
    }
)
MODEL_OPERATION_PATHS = frozenset({".ai4x/operations/modeling.md"})
PAPER_OPERATION_PATHS = frozenset({".ai4x/operations/publication.md"})


@dataclass(frozen=True)
class Selection:
    """One deterministic stage selection and its fixed diagnostic reason."""

    stages: frozenset[str]
    mode: str
    reason: str


def _under(path: str, directory: str) -> bool:
    """Return whether path is located in directory."""
    return path.startswith(f"{directory}/")


def stages_for_path(path: str) -> frozenset[str] | None:
    """Return owned stages, an empty known result, or None for an unknown path."""
    if path in FULL_PATHS or _under(path, ".github/workflows"):
        return ALL_STAGES

    stages: set[str] = set()
    known = False

    if (
        _under(path, ".ai4x")
        or _under(path, ".github/ISSUE_TEMPLATE")
        or _under(path, ".github/agents")
        or path in GOVERNANCE_PATHS
    ):
        stages.add("governance")
        known = True
    if path in HASKELL_OPERATION_PATHS:
        stages.add("haskell")
    if path in MODEL_OPERATION_PATHS:
        stages.add("model")
    if path in PAPER_OPERATION_PATHS:
        stages.add("paper")

    if _under(path, "mdl") or path in MODEL_PATHS:
        stages.add("model")
        known = True

    if _under(path, "spc"):
        stages.add("haskell")
        known = True
    if _under(path, "spc/lib/core/src"):
        stages.add("paper")
    if _under(path, "spc/ctr/archimate"):
        stages.update(("model", "paper"))
    if path in HASKELL_PATHS:
        stages.add("haskell")
        known = True

    if (
        _under(path, "acc")
        or _under(path, "img")
        or path in PAPER_PATHS
    ):
        stages.add("paper")
        known = True

    if path in NEUTRAL_PATHS:
        known = True
    if _under(path, "LICENSES") or path in LICENSING_PATHS:
        known = True

    if not known:
        return None
    stages.add("licensing")
    return frozenset(stages)


def classify_paths(paths: Iterable[str]) -> Selection:
    """Classify changed paths, conservatively selecting all stages if unknown."""
    changed = tuple(dict.fromkeys(paths))
    if not changed:
        return Selection(ALL_STAGES, "full", "empty-change-set")

    selected: set[str] = set()
    for path in changed:
        stages = stages_for_path(path)
        if stages is None:
            return Selection(ALL_STAGES, "full", "unknown-path")
        selected.update(stages)
    return Selection(frozenset(selected), "selective", "path-matrix")


def changed_paths(
    root: Path,
    event: str,
    base: str,
    head: str,
) -> tuple[str, ...] | None:
    """Return both sides of changed paths, or None when the range is unavailable."""
    if REVISION.fullmatch(base) is None or REVISION.fullmatch(head) is None:
        return None
    if set(base) == {"0"} or set(head) == {"0"}:
        return None
    separator = "..." if event == "pull_request" else ".."
    try:
        result = subprocess.run(
            [
                "git",
                "-C",
                str(root),
                "diff",
                "--name-only",
                "--no-renames",
                "-z",
                f"{base}{separator}{head}",
                "--",
            ],
            check=True,
            capture_output=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return None
    return tuple(
        value.decode("utf-8", errors="surrogateescape")
        for value in result.stdout.split(b"\0")
        if value
    )


def select_for_event(
    root: Path,
    event: str,
    base: str,
    head: str,
    forced: str,
) -> Selection:
    """Select stages for one GitHub event with a complete-suite fallback."""
    normalized_forced = forced.lower()
    if normalized_forced not in {"true", "false"}:
        return Selection(ALL_STAGES, "full", "invalid-force-flag")
    if event == "workflow_dispatch":
        return Selection(ALL_STAGES, "full", "manual-dispatch")
    if event not in {"push", "pull_request"}:
        return Selection(ALL_STAGES, "full", "unknown-event")
    if normalized_forced == "true":
        return Selection(ALL_STAGES, "full", "forced-push")

    paths = changed_paths(root, event, base, head)
    if paths is None:
        return Selection(ALL_STAGES, "full", "unavailable-diff")
    return classify_paths(paths)


def github_output(selection: Selection) -> str:
    """Render a selection as stable GitHub step outputs."""
    lines = [
        f"{stage}={'true' if stage in selection.stages else 'false'}"
        for stage in STAGES
    ]
    lines.extend((f"mode={selection.mode}", f"reason={selection.reason}"))
    return "\n".join(lines)


def main(argv: Sequence[str] | None = None) -> int:
    """Run the verification-scope selector."""
    parser = argparse.ArgumentParser(
        description="Select O2I verification stages for one Git change."
    )
    parser.add_argument("--event", required=True)
    parser.add_argument("--base", default="")
    parser.add_argument("--head", default="")
    parser.add_argument("--forced", default="false")
    parser.add_argument(
        "--format",
        choices=("github", "json"),
        default="json",
    )
    parser.add_argument("--root", type=Path, default=Path.cwd())
    arguments = parser.parse_args(argv)

    selection = select_for_event(
        arguments.root,
        arguments.event,
        arguments.base,
        arguments.head,
        arguments.forced,
    )
    if arguments.format == "github":
        print(github_output(selection))
    else:
        print(
            json.dumps(
                {
                    "mode": selection.mode,
                    "reason": selection.reason,
                    "stages": sorted(selection.stages),
                },
                sort_keys=True,
            )
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
