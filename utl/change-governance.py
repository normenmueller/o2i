#!/usr/bin/env python3
"""Validate and project the current O2I change-governance snapshot."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import stat
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Optional, Sequence

REGISTER = ".ai4X/governance/changes.json"
SCHEMA_VERSION = 1
ID_PATTERN = re.compile(r"^o2i-[0-9]{4}$")
REVISION_PATTERN = re.compile(r"^(?:[0-9a-f]{40}|[0-9a-f]{64})$")
FINAL_REVIEW_PATTERN = re.compile(r"^final-[a-z0-9][a-z0-9-]*\.json$")
REQUIRED_ADMISSION = {"strategy", "formalization"}
ADMISSION_REQUIRED = {"admitted", "implementing", "reviewing", "done"}
PLAN_REQUIRED = {"implementing", "reviewing", "done"}
NO_PLAN = {"proposed", "rejected"}
NO_FINAL = {"proposed", "admitted", "implementing", "rejected"}
VOLATILE_SCOPE = PurePosixPath(".ai4X/STATE.md")
REGISTER_SCOPE = PurePosixPath(REGISTER)
CHANGES_SCOPE = PurePosixPath(".ai4X/governance/changes")
STATES = {
    "proposed",
    "admitted",
    "implementing",
    "reviewing",
    "done",
    "rejected",
    "withdrawn",
}
CHANGE_FIELDS = {
    "id",
    "title",
    "author",
    "coauthors",
    "state",
    "proposal",
    "plan",
    "admission_reviews",
    "final_reviews",
    "derived_from",
    "depends_on",
}
ADMISSION_FIELDS = {
    "schema_version",
    "proposal",
    "phase",
    "reviewer",
    "capability",
    "proposal_path",
    "proposal_sha256",
    "verdict",
    "scores",
    "findings",
}
FINAL_FIELDS = {
    "schema_version",
    "change",
    "phase",
    "reviewer",
    "capability",
    "reviewed_revision",
    "reviewed_scope",
    "verdict",
    "scores",
    "findings",
}


@dataclass(frozen=True)
class Change:
    """One canonical register entry."""

    id: str
    title: str
    author: str
    coauthors: tuple[str, ...]
    state: str
    proposal: str
    plan: str
    admission_reviews: tuple[str, ...]
    final_reviews: tuple[str, ...]
    derived_from: tuple[str, ...]
    depends_on: tuple[str, ...]


def _text(value: object, label: str, errors: list[str], empty: bool = False) -> str:
    if not isinstance(value, str):
        errors.append(f"{label}: must be a string")
        return ""
    if not empty and not value.strip():
        errors.append(f"{label}: must not be empty")
    return value


def _identity(value: object, label: str, errors: list[str]) -> str:
    text = _text(value, label, errors)
    if text != text.strip() or "\n" in text or "\r" in text:
        errors.append(f"{label}: must be trimmed and single-line")
    return text


def _texts(value: object, label: str, errors: list[str]) -> tuple[str, ...]:
    if not isinstance(value, list):
        errors.append(f"{label}: must be an array of strings")
        return ()
    values = tuple(
        _text(item, f"{label}[{index}]", errors)
        for index, item in enumerate(value)
    )
    if len(values) != len(set(values)):
        errors.append(f"{label}: must not contain duplicates")
    return values


def _identities(value: object, label: str, errors: list[str]) -> tuple[str, ...]:
    if not isinstance(value, list):
        errors.append(f"{label}: must be an array of strings")
        return ()
    values = tuple(
        _identity(item, f"{label}[{index}]", errors)
        for index, item in enumerate(value)
    )
    if len(values) != len(set(values)):
        errors.append(f"{label}: must not contain duplicates")
    return values


def _schema_version(
    data: Mapping[str, Any], label: str, errors: list[str]
) -> None:
    value = data.get("schema_version")
    if type(value) is not int or value != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version: must be integer {SCHEMA_VERSION}")


def parse_register(
    data: Mapping[str, Any], source: str = REGISTER
) -> tuple[dict[str, Change], list[str]]:
    """Parse the register with deterministic diagnostics."""

    errors: list[str] = []
    unknown = sorted(set(data) - {"schema_version", "changes"})
    if unknown:
        errors.append(f"{source}: unknown fields: {', '.join(unknown)}")
    _schema_version(data, source, errors)
    entries = data.get("changes")
    if not isinstance(entries, list):
        return {}, [*errors, f"{source}: changes must be an array"]

    changes: dict[str, Change] = {}
    for index, raw in enumerate(entries):
        label = f"{source}:changes[{index}]"
        if not isinstance(raw, dict):
            errors.append(f"{label}: must be an object")
            continue
        missing = sorted(CHANGE_FIELDS - set(raw))
        extra = sorted(set(raw) - CHANGE_FIELDS)
        if missing:
            errors.append(f"{label}: missing fields: {', '.join(missing)}")
        if extra:
            errors.append(f"{label}: unknown fields: {', '.join(extra)}")
        if missing:
            continue

        change_id = _text(raw["id"], f"{label}.id", errors)
        author = _identity(raw["author"], f"{label}.author", errors)
        coauthors = _identities(raw["coauthors"], f"{label}.coauthors", errors)
        state = _text(raw["state"], f"{label}.state", errors)
        if not ID_PATTERN.fullmatch(change_id):
            errors.append(f"{label}.id: must match o2i-NNNN")
        if change_id in changes:
            errors.append(f"{label}.id: duplicate {change_id!r}")
        if author in coauthors:
            errors.append(f"{label}: author must not also be a co-author")
        if state not in STATES:
            errors.append(f"{label}.state: unknown state {state!r}")

        change = Change(
            id=change_id,
            title=_identity(raw["title"], f"{label}.title", errors),
            author=author,
            coauthors=coauthors,
            state=state,
            proposal=_text(raw["proposal"], f"{label}.proposal", errors),
            plan=_text(raw["plan"], f"{label}.plan", errors, empty=True),
            admission_reviews=_texts(
                raw["admission_reviews"], f"{label}.admission_reviews", errors
            ),
            final_reviews=_texts(
                raw["final_reviews"], f"{label}.final_reviews", errors
            ),
            derived_from=_texts(
                raw["derived_from"], f"{label}.derived_from", errors
            ),
            depends_on=_texts(raw["depends_on"], f"{label}.depends_on", errors),
        )
        if change_id and change_id not in changes:
            changes[change_id] = change
    return changes, errors


def _artifact(
    root: Path, reference: str, label: str, errors: list[str]
) -> Optional[Path]:
    path = PurePosixPath(reference)
    if (
        not reference
        or path.is_absolute()
        or ".." in path.parts
        or str(path) != reference
    ):
        errors.append(f"{label}: must be a canonical repository-relative path")
        return None

    candidate = root
    for part in path.parts:
        candidate /= part
        if candidate.is_symlink():
            errors.append(f"{label}: symlinks are not allowed: {reference}")
            return None
    try:
        mode = candidate.stat().st_mode
    except FileNotFoundError:
        errors.append(f"{label}: file does not exist: {reference}")
        return None
    if not stat.S_ISREG(mode):
        errors.append(f"{label}: must be a regular file: {reference}")
        return None
    try:
        candidate.resolve().relative_to(root.resolve())
    except ValueError:
        errors.append(f"{label}: path escapes repository")
        return None
    return candidate


def _json_file(
    path: Optional[Path], label: str, errors: list[str]
) -> Optional[Mapping[str, Any]]:
    if path is None:
        return None
    try:
        value = json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=_unique_object,
        )
    except (UnicodeDecodeError, ValueError) as exc:
        errors.append(f"{label}: invalid JSON: {exc}")
        return None
    if not isinstance(value, dict):
        errors.append(f"{label}: must contain a JSON object")
        return None
    return value


def _unique_object(pairs: Sequence[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        if key in value:
            raise ValueError(f"duplicate key {key!r}")
        value[key] = item
    return value


def _field(
    data: Mapping[str, Any], name: str, label: str, errors: list[str]
) -> str:
    if name not in data:
        return ""
    return _identity(data[name], f"{label}.{name}", errors)


def _findings(
    data: Mapping[str, Any], label: str, errors: list[str]
) -> tuple[str, ...]:
    if "findings" not in data:
        return ()
    value = data["findings"]
    if not isinstance(value, list):
        errors.append(f"{label}.findings: must be an array")
        return ()
    return tuple(
        _identity(item, f"{label}.findings[{index}]", errors)
        for index, item in enumerate(value)
    )


def _section(
    plan: Path, heading: str, label: str, errors: list[str]
) -> tuple[str, ...]:
    try:
        lines = plan.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        errors.append(f"{label}: plan must be UTF-8")
        return ()
    try:
        start = lines.index(f"## {heading}") + 1
    except ValueError:
        errors.append(f"{label}: missing section {heading!r}")
        return ()
    items: list[str] = []
    for line in lines[start:]:
        if line.startswith("## "):
            break
        if line.strip().startswith("- "):
            item = line.strip()[2:].rstrip(";.").strip()
            if item:
                items.append(item)
    if not items:
        errors.append(f"{label}: section {heading!r} must not be empty")
    if len(items) != len(set(items)):
        errors.append(f"{label}: section {heading!r} contains duplicates")
    return tuple(items)


def _validate_admission(
    root: Path, change: Change, proposal: Path, errors: list[str]
) -> tuple[str, ...]:
    digest = hashlib.sha256(proposal.read_bytes()).hexdigest()
    protected = {change.author, *change.coauthors}
    accepted: list[str] = []
    reviewers: list[str] = []
    verdicts: list[str] = []
    for reference in change.admission_reviews:
        label = f"{change.id}:Admission:{reference}"
        data = _json_file(_artifact(root, reference, label, errors), label, errors)
        if data is None:
            continue
        missing = sorted(ADMISSION_FIELDS - set(data))
        extra = sorted(set(data) - ADMISSION_FIELDS)
        if missing:
            errors.append(f"{label}: missing fields: {', '.join(missing)}")
        if extra:
            errors.append(f"{label}: unknown fields: {', '.join(extra)}")
        reviewer = _field(data, "reviewer", label, errors)
        capability = _field(data, "capability", label, errors)
        verdict = _field(data, "verdict", label, errors)
        _schema_version(data, label, errors)
        expected = {
            "proposal": change.id,
            "phase": "admission",
            "proposal_path": change.proposal,
            "proposal_sha256": digest,
        }
        for field, value in expected.items():
            if data.get(field) != value:
                errors.append(f"{label}.{field}: must be {value!r}")
        findings = _findings(data, label, errors)
        if capability not in REQUIRED_ADMISSION:
            errors.append(f"{label}.capability: invalid {capability!r}")
        if verdict not in {"accepted", "rejected"}:
            errors.append(f"{label}.verdict: invalid {verdict!r}")
        _scores(data.get("scores"), label, verdict, errors)
        if verdict == "accepted" and findings:
            errors.append(f"{label}: accepted review must have no findings")
        if verdict == "rejected" and not findings:
            errors.append(f"{label}: rejected review must have findings")
        if reviewer in protected:
            errors.append(f"{label}: reviewer collides with author or co-author")
        reviewers.append(reviewer)
        verdicts.append(verdict)
        if verdict == "accepted":
            accepted.append(capability)

    if len(reviewers) != len(set(reviewers)):
        errors.append(f"{change.id}: Admission reviewers must be distinct")
    if change.state in ADMISSION_REQUIRED:
        if len(change.admission_reviews) != 2:
            errors.append(f"{change.id}: needs exactly two Admission reviews")
        if sorted(accepted) != sorted(REQUIRED_ADMISSION):
            errors.append(
                f"{change.id}: needs accepted strategy and formalization reviews"
            )
    return tuple(verdicts)


def _git(root: Path, *arguments: str) -> Optional[subprocess.CompletedProcess[str]]:
    try:
        return subprocess.run(
            ["git", *arguments],
            cwd=root,
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError:
        return None


def _git_metadata(root: Path) -> bool:
    result = _git(root, "rev-parse", "--show-toplevel")
    if result is None or result.returncode != 0 or not result.stdout.strip():
        return False
    return Path(result.stdout.strip()).resolve() == root.resolve()


def _git_revision_exists(root: Path, revision: str) -> bool:
    result = _git(root, "cat-file", "-e", f"{revision}^{{commit}}")
    return result is not None and result.returncode == 0


def _scope(
    root: Path,
    value: object,
    revision: str,
    has_git: bool,
    revision_exists: bool,
    label: str,
    errors: list[str],
) -> tuple[str, ...]:
    scope = _texts(value, f"{label}.reviewed_scope", errors)
    if not scope:
        errors.append(f"{label}.reviewed_scope: must not be empty")
    for reference in scope:
        path = PurePosixPath(reference)
        if path.is_absolute() or ".." in path.parts or str(path) != reference:
            errors.append(
                f"{label}.reviewed_scope: must contain canonical "
                "repository-relative paths"
            )
            continue
        excluded = _closure_mutable_scope(path)
        if excluded:
            errors.append(
                f"{label}.reviewed_scope: must exclude {excluded} "
                f"and its ancestors: {reference}"
            )
            continue
        if has_git:
            if not revision_exists:
                continue
            exists = _git(root, "cat-file", "-e", f"{revision}:{reference}")
            if exists is None or exists.returncode != 0:
                errors.append(
                    f"{label}.reviewed_scope: path does not exist at "
                    f"reviewed_revision: {reference}"
                )
            continue
    return scope


def _closure_mutable_scope(path: PurePosixPath) -> Optional[str]:
    for protected in (VOLATILE_SCOPE, REGISTER_SCOPE):
        if path == protected or path in protected.parents:
            return str(protected)
    if path == CHANGES_SCOPE or path in CHANGES_SCOPE.parents:
        return "Finalreview evidence"
    try:
        relative = path.relative_to(CHANGES_SCOPE)
    except ValueError:
        return None
    parts = relative.parts
    if len(parts) == 1 and ID_PATTERN.fullmatch(parts[0]):
        return "Finalreview evidence"
    if (
        len(parts) == 2
        and ID_PATTERN.fullmatch(parts[0])
        and parts[1] == "reviews"
    ):
        return "Finalreview evidence"
    if (
        len(parts) == 3
        and ID_PATTERN.fullmatch(parts[0])
        and parts[1] == "reviews"
        and FINAL_REVIEW_PATTERN.fullmatch(parts[2])
    ):
        return "Finalreview evidence"
    return None


def _scores(
    value: object, label: str, verdict: str, errors: list[str]
) -> Mapping[str, float]:
    if not isinstance(value, dict) or not value:
        errors.append(f"{label}.scores: must be a nonempty object")
        return {}
    scores: dict[str, float] = {}
    for dimension, score in value.items():
        dimension_errors: list[str] = []
        name = _identity(dimension, f"{label}.scores dimension", dimension_errors)
        errors.extend(dimension_errors)
        if not name:
            continue
        if isinstance(score, bool) or not isinstance(score, (int, float)):
            errors.append(f"{label}.scores.{name}: must be numeric")
            continue
        numeric = float(score)
        scores[name] = numeric
        if not 0.0 <= numeric <= 10.0:
            errors.append(f"{label}.scores.{name}: must be within 0..10")
        if verdict == "accepted" and numeric != 10.0:
            errors.append(f"{label}.scores.{name}: accepted review requires 10.0")
    return scores


def _validate_finals(
    root: Path,
    change: Change,
    required: set[str],
    errors: list[str],
) -> None:
    protected = {change.author, *change.coauthors}
    reviewers: list[str] = []
    accepted_capabilities: list[str] = []
    accepted_revisions: list[str] = []
    has_git = _git_metadata(root)
    for reference in change.final_reviews:
        label = f"{change.id}:Finalreview:{reference}"
        data = _json_file(_artifact(root, reference, label, errors), label, errors)
        if data is None:
            continue
        missing = sorted(FINAL_FIELDS - set(data))
        extra = sorted(set(data) - FINAL_FIELDS)
        if missing:
            errors.append(f"{label}: missing fields: {', '.join(missing)}")
        if extra:
            errors.append(f"{label}: unknown fields: {', '.join(extra)}")
        reviewer = _field(data, "reviewer", label, errors)
        capability = _field(data, "capability", label, errors)
        revision = _field(data, "reviewed_revision", label, errors)
        verdict = _field(data, "verdict", label, errors)
        _schema_version(data, label, errors)
        expected = {
            "change": change.id,
            "phase": "final",
        }
        for field, value in expected.items():
            if data.get(field) != value:
                errors.append(f"{label}.{field}: must be {value!r}")
        valid_revision = bool(REVISION_PATTERN.fullmatch(revision))
        revision_exists = valid_revision and (
            not has_git or _git_revision_exists(root, revision)
        )
        if not valid_revision:
            errors.append(f"{label}.reviewed_revision: must be a full Git SHA")
        elif has_git and not revision_exists:
            errors.append(f"{label}.reviewed_revision: Git commit does not exist")
        _scope(
            root,
            data.get("reviewed_scope"),
            revision,
            has_git,
            revision_exists,
            label,
            errors,
        )
        _scores(data.get("scores"), label, verdict, errors)
        findings = _findings(data, label, errors)
        if reviewer in protected:
            errors.append(f"{label}: reviewer collides with author or co-author")
        if verdict not in {"accepted", "rejected"}:
            errors.append(f"{label}.verdict: invalid {verdict!r}")
        if verdict == "accepted" and findings:
            errors.append(f"{label}: accepted review must have no findings")
        if verdict == "rejected" and not findings:
            errors.append(f"{label}: rejected review must have findings")
        if capability not in required:
            errors.append(f"{label}.capability: not required by plan")
        if change.state == "done" and verdict != "accepted":
            errors.append(f"{label}: done requires accepted Finalreviews")
        reviewers.append(reviewer)
        if verdict == "accepted":
            accepted_capabilities.append(capability)
            if REVISION_PATTERN.fullmatch(revision):
                accepted_revisions.append(revision)

    if len(reviewers) != len(set(reviewers)):
        errors.append(f"{change.id}: Finalreview reviewers must be distinct")
    if change.state == "done":
        if sorted(accepted_capabilities) != sorted(required):
            errors.append(
                f"{change.id}: Finalreviews must exactly cover plan capabilities"
            )
        if len(set(accepted_revisions)) != 1:
            errors.append(
                f"{change.id}: accepted Finalreviews must bind one reviewed_revision"
            )


def _cycle(
    changes: Mapping[str, Change], relation: str
) -> Optional[tuple[str, ...]]:
    visiting: set[str] = set()
    visited: set[str] = set()
    path: list[str] = []

    def visit(change_id: str) -> Optional[tuple[str, ...]]:
        if change_id in visiting:
            start = path.index(change_id)
            return (*path[start:], change_id)
        if change_id in visited:
            return None
        visiting.add(change_id)
        path.append(change_id)
        for target in sorted(getattr(changes[change_id], relation)):
            if target in changes:
                found = visit(target)
                if found:
                    return found
        path.pop()
        visiting.remove(change_id)
        visited.add(change_id)
        return None

    for change_id in sorted(changes):
        found = visit(change_id)
        if found:
            return found
    return None


def validate_graphs(changes: Mapping[str, Change]) -> list[str]:
    """Validate lineage and dependencies as separate DAGs."""

    errors: list[str] = []
    for change_id in sorted(changes):
        change = changes[change_id]
        for relation in ("derived_from", "depends_on"):
            for target in getattr(change, relation):
                if target == change_id:
                    errors.append(f"{change_id}.{relation}: self-edge")
                elif target not in changes:
                    errors.append(f"{change_id}.{relation}: unknown id {target!r}")
        for dependency in change.depends_on:
            if (
                change.state == "done"
                and dependency in changes
                and changes[dependency].state != "done"
            ):
                errors.append(f"{change_id}: open dependency {dependency!r}")
    for relation in ("derived_from", "depends_on"):
        found = _cycle(changes, relation)
        if found:
            errors.append(f"{relation}: cycle: {' -> '.join(found)}")
    return errors


def inspect_repository(root: Path) -> tuple[dict[str, Change], list[str]]:
    """Load and validate the current repository snapshot."""

    root = root.resolve()
    errors: list[str] = []
    register = _artifact(root, REGISTER, REGISTER, errors)
    data = _json_file(register, REGISTER, errors)
    if data is None:
        return {}, errors
    changes, found = parse_register(data)
    errors.extend(found)

    for change in (changes[key] for key in sorted(changes)):
        base = f".ai4X/governance/changes/{change.id}"
        proposal_ref = f"{base}/proposal.md"
        plan_ref = f"{base}/plan.md"
        if change.proposal != proposal_ref:
            errors.append(f"{change.id}: proposal must be {proposal_ref}")
        if change.plan and change.plan != plan_ref:
            errors.append(f"{change.id}: plan must be {plan_ref}")
        if change.state in NO_PLAN and change.plan:
            errors.append(f"{change.id}: {change.state} change must not have a plan")
        if change.state in NO_FINAL and change.final_reviews:
            errors.append(
                f"{change.id}: {change.state} change must not have Finalreviews"
            )
        allowed_admission = {
            f"{base}/reviews/admission-strategy.json",
            f"{base}/reviews/admission-formalization.json",
        }
        for reference in change.admission_reviews:
            if reference not in allowed_admission:
                errors.append(f"{change.id}: invalid Admission review path {reference!r}")
        for reference in change.final_reviews:
            path = PurePosixPath(reference)
            if (
                path.parent != PurePosixPath(base) / "reviews"
                or not FINAL_REVIEW_PATTERN.fullmatch(path.name)
            ):
                errors.append(f"{change.id}: invalid Finalreview path {reference!r}")

        proposal = _artifact(root, change.proposal, f"{change.id}.proposal", errors)
        admission_verdicts: tuple[str, ...] = ()
        if proposal and change.admission_reviews:
            admission_verdicts = _validate_admission(
                root, change, proposal, errors
            )
        elif change.state in ADMISSION_REQUIRED:
            errors.append(f"{change.id}: admitted change has no Admission reviews")
        if change.state == "rejected" and "rejected" not in admission_verdicts:
            errors.append(f"{change.id}: rejected change needs a rejected Admission")

        plan = (
            _artifact(root, change.plan, f"{change.id}.plan", errors)
            if change.plan
            else None
        )
        if change.state in PLAN_REQUIRED and plan is None:
            errors.append(f"{change.id}: active change requires a plan")
        required: set[str] = set()
        if plan:
            _section(plan, "Affected Surfaces", f"{change.id}:plan", errors)
            required = set(
                _section(
                    plan,
                    "Required Finalreview Capabilities",
                    f"{change.id}:plan",
                    errors,
                )
            )
        if change.final_reviews:
            if plan:
                _validate_finals(root, change, required, errors)
            else:
                errors.append(f"{change.id}: Finalreviews require a valid plan")
        elif change.state == "done":
            errors.append(f"{change.id}: done change has no Finalreviews")

    errors.extend(validate_graphs(changes))
    return changes, sorted(set(errors))


def validate_repository(root: Path) -> list[str]:
    """Return deterministic current-snapshot validation errors."""

    return inspect_repository(root)[1]


def render_backlog(changes: Mapping[str, Change]) -> str:
    """Render deterministic Markdown."""

    lines = [
        "# O2I Change Backlog",
        "",
        "| ID | State | Title | Depends on |",
        "| --- | --- | --- | --- |",
    ]
    for change_id in sorted(changes):
        change = changes[change_id]
        title = change.title.replace("|", "\\|")
        dependencies = ", ".join(change.depends_on) or "-"
        lines.append(
            f"| {change.id} | {change.state} | {title} | {dependencies} |"
        )
    return "\n".join(lines) + "\n"


def render_graph(changes: Mapping[str, Change]) -> str:
    """Render deterministic Mermaid."""

    node = lambda value: "change_" + re.sub(r"[^A-Za-z0-9_]", "_", value)
    lines = ["flowchart LR"]
    for change_id in sorted(changes):
        change = changes[change_id]
        label = f"{change.id}: {change.title} [{change.state}]"
        label = label.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ")
        lines.append(f'  {node(change_id)}["{label}"]')
    for change_id in sorted(changes):
        change = changes[change_id]
        for parent in sorted(change.derived_from):
            lines.append(f"  {node(parent)} -->|derived| {node(change_id)}")
        for dependency in sorted(change.depends_on):
            lines.append(
                f"  {node(dependency)} -->|required by| {node(change_id)}"
            )
    return "\n".join(lines) + "\n"


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate and project O2I change governance."
    )
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("validate", "backlog", "graph"):
        command = commands.add_parser(name)
        command.add_argument("--root", type=Path, default=Path.cwd())
    return parser


def main(arguments: Optional[Sequence[str]] = None) -> int:
    options = _parser().parse_args(arguments)
    changes, errors = inspect_repository(options.root)
    if errors:
        for error in errors:
            print(f"[o2i|error] {error}", file=sys.stderr)
        return 1
    if options.command == "validate":
        print("[o2i|info] change governance is valid.")
    elif options.command == "backlog":
        print(render_backlog(changes), end="")
    else:
        print(render_graph(changes), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
