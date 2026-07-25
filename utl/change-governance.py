#!/usr/bin/env python3
"""Validate and project the lean O2I change-governance register."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Optional, Sequence

REGISTER = ".ai4X/governance/changes.json"
SCHEMA_VERSION = 1
BOOTSTRAP_ID = "o2i-0001"
ID_PATTERN = re.compile(r"^o2i-[0-9]{4}$")
REVISION_PATTERN = re.compile(r"^[0-9a-f]{40,64}$")
REQUIRED_ADMISSION = {"strategy", "formalization"}
FINAL_CAPABILITIES_HEADING = "## Required Finalreview Capabilities"

STATES = {
    "proposed",
    "admitted",
    "implementing",
    "reviewing",
    "done",
    "rejected",
    "withdrawn",
}
ADMITTED = {"admitted", "implementing", "reviewing", "done"}
PLANNED = {"implementing", "reviewing", "done"}
TRANSITIONS = {
    "proposed": {"admitted", "rejected", "withdrawn"},
    "admitted": {"implementing", "withdrawn"},
    "implementing": {"reviewing", "withdrawn"},
    "reviewing": {"implementing", "done", "withdrawn"},
    "done": set(),
    "rejected": set(),
    "withdrawn": set(),
}
CHANGE_FIELDS = (
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
)


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


def _text(value: object, field: str, errors: list[str], empty: bool = False) -> str:
    if not isinstance(value, str):
        errors.append(f"{field}: must be a string")
        return ""
    if not empty and not value.strip():
        errors.append(f"{field}: must not be empty")
    return value


def _texts(value: object, field: str, errors: list[str]) -> tuple[str, ...]:
    if not isinstance(value, list):
        errors.append(f"{field}: must be an array of strings")
        return ()
    result = tuple(
        _text(item, f"{field}[{index}]", errors)
        for index, item in enumerate(value)
    )
    if len(result) != len(set(result)):
        errors.append(f"{field}: must not contain duplicates")
    return result


def parse_register(
    data: Mapping[str, Any], source: str = REGISTER
) -> tuple[dict[str, Change], list[str]]:
    """Parse the canonical register with deterministic diagnostics."""

    errors: list[str] = []
    unknown = sorted(set(data) - {"schema_version", "changes"})
    if unknown:
        errors.append(f"{source}: unknown fields: {', '.join(unknown)}")
    if data.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{source}: schema_version must be {SCHEMA_VERSION}")

    entries = data.get("changes")
    if not isinstance(entries, list):
        return {}, [*errors, f"{source}: changes must be an array of tables"]

    changes: dict[str, Change] = {}
    expected = set(CHANGE_FIELDS)
    for index, raw in enumerate(entries):
        label = f"{source}:changes[{index}]"
        if not isinstance(raw, dict):
            errors.append(f"{label}: must be a table")
            continue
        missing = sorted(expected - set(raw))
        extra = sorted(set(raw) - expected)
        if missing:
            errors.append(f"{label}: missing fields: {', '.join(missing)}")
        if extra:
            errors.append(f"{label}: unknown fields: {', '.join(extra)}")
        if missing:
            continue

        change_id = _text(raw["id"], f"{label}.id", errors)
        author = _text(raw["author"], f"{label}.author", errors)
        coauthors = _texts(raw["coauthors"], f"{label}.coauthors", errors)
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
            title=_text(raw["title"], f"{label}.title", errors),
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


def _json(
    path: Path, label: str, errors: list[str]
) -> Optional[Mapping[str, Any]]:
    try:
        with path.open(encoding="utf-8") as handle:
            value = json.load(handle)
    except FileNotFoundError:
        errors.append(f"{label}: file does not exist")
        return None
    except json.JSONDecodeError as exc:
        errors.append(f"{label}: invalid JSON: {exc}")
        return None
    if not isinstance(value, dict):
        errors.append(f"{label}: must contain a JSON object")
        return None
    return value


def _file(
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
    candidate = root.joinpath(*path.parts)
    try:
        candidate.resolve().relative_to(root.resolve())
    except ValueError:
        errors.append(f"{label}: path escapes repository")
        return None
    if not candidate.is_file():
        errors.append(f"{label}: {reference!r} does not exist")
        return None
    return candidate


def _review_field(
    data: Mapping[str, Any], field: str, label: str, errors: list[str]
) -> str:
    if field not in data:
        errors.append(f"{label}: missing field {field!r}")
        return ""
    return _text(data[field], f"{label}.{field}", errors)


def _findings(
    data: Mapping[str, Any], label: str, errors: list[str]
) -> tuple[object, ...]:
    value = data.get("findings")
    if not isinstance(value, list):
        errors.append(f"{label}.findings: must be an array")
        return ()
    return tuple(value)


def _validate_admission(
    root: Path, change: Change, proposal: Path, errors: list[str]
) -> None:
    digest = hashlib.sha256(proposal.read_bytes()).hexdigest()
    protected_roles = {change.author, *change.coauthors}
    reviewers: list[str] = []
    accepted: list[str] = []

    for reference in change.admission_reviews:
        label = f"{change.id}:Admission:{reference}"
        path = _file(root, reference, label, errors)
        data = _json(path, label, errors) if path else None
        if data is None:
            continue
        reviewer = _review_field(data, "reviewer", label, errors)
        capability = _review_field(data, "capability", label, errors)
        verdict = _review_field(data, "verdict", label, errors)
        findings = _findings(data, label, errors)

        expected = {
            "schema_version": SCHEMA_VERSION,
            "proposal": change.id,
            "phase": "admission",
            "proposal_path": change.proposal,
            "proposal_sha256": digest,
        }
        for field, value in expected.items():
            if data.get(field) != value:
                errors.append(f"{label}.{field}: must be {value!r}")
        if capability not in REQUIRED_ADMISSION:
            errors.append(f"{label}.capability: invalid {capability!r}")
        if verdict not in {"accepted", "rejected"}:
            errors.append(f"{label}.verdict: invalid {verdict!r}")
        if verdict == "accepted" and findings:
            errors.append(f"{label}: accepted review must have no findings")
        if reviewer in protected_roles:
            errors.append(f"{label}: reviewer collides with author or co-author")
        reviewers.append(reviewer)
        if verdict == "accepted":
            accepted.append(capability)

    if len(reviewers) != len(set(reviewers)):
        errors.append(f"{change.id}: Admission reviewers must be distinct")
    if change.state in ADMITTED:
        if len(change.admission_reviews) != 2:
            errors.append(f"{change.id}: needs exactly two Admission reviews")
        if sorted(accepted) != sorted(REQUIRED_ADMISSION):
            errors.append(
                f"{change.id}: needs accepted strategy and formalization reviews"
            )


def _required_capabilities(plan: Path, label: str, errors: list[str]) -> set[str]:
    lines = plan.read_text(encoding="utf-8").splitlines()
    try:
        start = lines.index(FINAL_CAPABILITIES_HEADING) + 1
    except ValueError:
        errors.append(f"{label}: missing {FINAL_CAPABILITIES_HEADING!r}")
        return set()
    capabilities: list[str] = []
    for line in lines[start:]:
        if line.startswith("## "):
            break
        if line.strip().startswith("- "):
            capabilities.append(line.strip()[2:].rstrip(";.").strip())
    if not capabilities:
        errors.append(f"{label}: declares no Finalreview capabilities")
    if len(capabilities) != len(set(capabilities)):
        errors.append(f"{label}: declares duplicate Finalreview capabilities")
    return set(capabilities)


def _git(root: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *arguments],
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )


def _exact_revision(root: Path, revision: str) -> bool:
    if not REVISION_PATTERN.fullmatch(revision):
        return False
    result = _git(root, "rev-parse", "--verify", f"{revision}^{{commit}}")
    return result.returncode == 0 and result.stdout.strip().lower() == revision.lower()


def _validate_final(
    root: Path, change: Change, plan: Path, errors: list[str]
) -> Optional[str]:
    required = _required_capabilities(plan, f"{change.id}:plan", errors)
    protected_roles = {change.author, *change.coauthors}
    accepted: dict[str, list[tuple[str, str]]] = {}

    for reference in change.final_reviews:
        label = f"{change.id}:Finalreview:{reference}"
        path = _file(root, reference, label, errors)
        data = _json(path, label, errors) if path else None
        if data is None:
            continue
        reviewer = _review_field(data, "reviewer", label, errors)
        capability = _review_field(data, "capability", label, errors)
        revision = _review_field(data, "reviewed_revision", label, errors)
        verdict = _review_field(data, "verdict", label, errors)
        findings = _findings(data, label, errors)

        if reviewer in protected_roles:
            errors.append(f"{label}: reviewer collides with author or co-author")
        if verdict not in {"accepted", "rejected"}:
            errors.append(f"{label}.verdict: invalid {verdict!r}")
        if not _exact_revision(root, revision):
            errors.append(f"{label}: reviewed_revision is not an exact Git revision")
        if verdict == "accepted" and findings:
            errors.append(f"{label}: accepted review must have no findings")
        if verdict == "accepted":
            accepted.setdefault(capability, []).append((reviewer, revision.lower()))

    if change.state != "done":
        return None

    selected: list[tuple[str, str]] = []
    for capability in sorted(required):
        reviews = accepted.get(capability, [])
        if len(reviews) != 1:
            errors.append(
                f"{change.id}: needs exactly one accepted {capability!r} Finalreview"
            )
        else:
            selected.append(reviews[0])
    reviewers = [reviewer for reviewer, _ in selected]
    if len(reviewers) != len(set(reviewers)):
        errors.append(f"{change.id}: required Finalreview reviewers must be distinct")
    revisions = {revision for _, revision in selected}
    if len(revisions) != 1:
        errors.append(f"{change.id}: accepted Finalreviews must bind one revision")
        return None

    return next(iter(revisions))


def _validate_final_scope(
    root: Path, change: Change, revision: str, errors: list[str]
) -> None:
    result = _git(root, "diff", "--name-only", f"{revision}..HEAD", "--")
    if result.returncode != 0:
        errors.append(f"{change.id}: cannot verify Finalreview scope")
        return
    allowed = {REGISTER, *change.final_reviews}
    changed = {line for line in result.stdout.splitlines() if line}
    unexpected = sorted(changed - allowed)
    if unexpected:
        errors.append(
            f"{change.id}: files changed after reviewed revision: "
            + ", ".join(unexpected)
        )


def _cycle(
    changes: Mapping[str, Change], relation: str
) -> Optional[tuple[str, ...]]:
    visiting: set[str] = set()
    visited: set[str] = set()
    path: list[str] = []

    def visit(node: str) -> Optional[tuple[str, ...]]:
        if node in visiting:
            start = path.index(node)
            return (*path[start:], node)
        if node in visited:
            return None
        visiting.add(node)
        path.append(node)
        for target in sorted(getattr(changes[node], relation)):
            if target in changes:
                found = visit(target)
                if found:
                    return found
        path.pop()
        visiting.remove(node)
        visited.add(node)
        return None

    for change_id in sorted(changes):
        found = visit(change_id)
        if found:
            return found
    return None


def validate_graphs(changes: Mapping[str, Change]) -> list[str]:
    """Validate lineage and dependency as separate DAGs."""

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


def validate_transition(
    previous: Mapping[str, Change],
    current: Mapping[str, Change],
    bootstrap: bool = False,
) -> list[str]:
    """Validate one transition without a second history store."""

    if bootstrap:
        if (
            set(current) == {BOOTSTRAP_ID}
            and current[BOOTSTRAP_ID].state == "implementing"
        ):
            return []
        return [f"bootstrap: only {BOOTSTRAP_ID!r} may start in 'implementing'"]

    errors = [
        f"{change_id}: registered change must not be removed"
        for change_id in sorted(set(previous) - set(current))
    ]
    for change_id in sorted(set(current) - set(previous)):
        if current[change_id].state != "proposed":
            errors.append(f"{change_id}: new change must start in 'proposed'")
    for change_id in sorted(set(previous) & set(current)):
        old, new = previous[change_id].state, current[change_id].state
        if old != new and new not in TRANSITIONS.get(old, set()):
            errors.append(f"{change_id}: invalid transition {old!r} -> {new!r}")
    return errors


def _register_at(
    root: Path, revision: str, errors: list[str]
) -> tuple[dict[str, Change], bool]:
    if _git(root, "rev-parse", "--verify", f"{revision}^{{commit}}").returncode:
        errors.append(f"--base: unknown Git revision {revision!r}")
        return {}, False
    if _git(root, "cat-file", "-e", f"{revision}:{REGISTER}").returncode:
        return {}, True
    result = _git(root, "show", f"{revision}:{REGISTER}")
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        errors.append(f"--base: invalid prior register: {exc}")
        return {}, False
    if not isinstance(data, dict):
        errors.append("--base: prior register must contain a JSON object")
        return {}, False
    changes, found = parse_register(data, f"{revision}:{REGISTER}")
    errors.extend(found)
    return changes, False


def inspect_repository(
    root: Path, base_revision: Optional[str] = None
) -> tuple[dict[str, Change], list[str]]:
    """Load and validate one repository governance state."""

    root = root.resolve()
    errors: list[str] = []
    data = _json(root / REGISTER, REGISTER, errors)
    if data is None:
        return {}, errors
    changes, found = parse_register(data)
    errors.extend(found)
    final_revisions: dict[str, str] = {}

    for change in (changes[key] for key in sorted(changes)):
        base = f".ai4X/governance/changes/{change.id}"
        if change.proposal != f"{base}/proposal.md":
            errors.append(f"{change.id}: proposal must be {base}/proposal.md")
        if change.plan and change.plan != f"{base}/plan.md":
            errors.append(f"{change.id}: plan must be {base}/plan.md")
        allowed_admission = {
            f"{base}/reviews/admission-strategy.json",
            f"{base}/reviews/admission-formalization.json",
        }
        for reference in change.admission_reviews:
            if reference not in allowed_admission:
                errors.append(f"{change.id}: invalid Admission review path {reference!r}")
        for reference in change.final_reviews:
            if not (
                reference.startswith(f"{base}/reviews/final-")
                and reference.endswith(".json")
            ):
                errors.append(f"{change.id}: invalid Finalreview path {reference!r}")

        proposal = _file(root, change.proposal, f"{change.id}.proposal", errors)
        if proposal and change.admission_reviews:
            _validate_admission(root, change, proposal, errors)
        elif change.state in ADMITTED:
            errors.append(f"{change.id}: admitted change has no Admission reviews")

        plan = (
            _file(root, change.plan, f"{change.id}.plan", errors)
            if change.plan
            else None
        )
        if change.state in PLANNED and plan is None:
            errors.append(f"{change.id}: implementing change has no plan")
        if change.final_reviews and plan:
            revision = _validate_final(root, change, plan, errors)
            if revision:
                final_revisions[change.id] = revision
        elif change.final_reviews:
            errors.append(f"{change.id}: Finalreviews require a valid plan")
        elif change.state == "done":
            errors.append(f"{change.id}: done change has no Finalreviews")

    errors.extend(validate_graphs(changes))
    if base_revision:
        previous, bootstrap = _register_at(root, base_revision, errors)
        if not any(error.startswith("--base:") for error in errors):
            errors.extend(validate_transition(previous, changes, bootstrap))
            for change_id in sorted(set(previous) & set(changes)):
                if (
                    previous[change_id].state == "reviewing"
                    and changes[change_id].state == "done"
                    and change_id in final_revisions
                ):
                    _validate_final_scope(
                        root,
                        changes[change_id],
                        final_revisions[change_id],
                        errors,
                    )
    return changes, sorted(set(errors))


def validate_repository(
    root: Path, base_revision: Optional[str] = None
) -> list[str]:
    """Return deterministic validation errors."""

    return inspect_repository(root, base_revision)[1]


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
        dependencies = ", ".join(change.depends_on) or "-"
        title = change.title.replace("|", "\\|")
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
    validate = commands.add_parser("validate")
    validate.add_argument("--root", type=Path, default=Path.cwd())
    validate.add_argument("--base")
    for name in ("backlog", "graph"):
        command = commands.add_parser(name)
        command.add_argument("--root", type=Path, default=Path.cwd())
    return parser


def main(arguments: Optional[Sequence[str]] = None) -> int:
    options = _parser().parse_args(arguments)
    changes, errors = inspect_repository(options.root, getattr(options, "base", None))
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
