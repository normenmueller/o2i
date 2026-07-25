#!/usr/bin/env python3
"""Tests for the current-snapshot O2I governance validator."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any, Optional
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
CHANGE_ROOT = ".ai4X/governance/changes/o2i-0001"
CAPABILITIES = ("strategy", "formalization", "agentic AI")
SPEC = importlib.util.spec_from_file_location(
    "change_governance", Path(__file__).with_name("change-governance.py")
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("cannot load change-governance.py")
governance = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = governance
SPEC.loader.exec_module(governance)


class Repository:
    """Small Git-optional governance fixture."""

    def __init__(self, root: Path) -> None:
        self.root = root
        self.proposal = f"{CHANGE_ROOT}/proposal.md"
        self.plan = f"{CHANGE_ROOT}/plan.md"
        self.admission = [
            f"{CHANGE_ROOT}/reviews/admission-strategy.json",
            f"{CHANGE_ROOT}/reviews/admission-formalization.json",
        ]
        self.write(self.proposal, "# Proposal\n\nGeneric benefit.\n")
        self.write_plan()
        self.write_admission(0, "strategy-reviewer", "strategy")
        self.write_admission(1, "formalization-reviewer", "formalization")

    def write(self, reference: str, content: str) -> None:
        path = self.root / reference
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def write_json(self, reference: str, value: object) -> None:
        self.write(reference, json.dumps(value, indent=2, sort_keys=True) + "\n")

    def read_json(self, reference: str) -> dict[str, Any]:
        return json.loads((self.root / reference).read_text(encoding="utf-8"))

    def write_plan(
        self,
        surfaces: tuple[str, ...] = ("governance",),
        capabilities: tuple[str, ...] = CAPABILITIES,
    ) -> None:
        bullets = lambda values: "".join(f"- {value};\n" for value in values)
        self.write(
            self.plan,
            "# Plan\n\n"
            "## Affected Surfaces\n\n"
            f"{bullets(surfaces)}\n"
            "## Required Finalreview Capabilities\n\n"
            f"{bullets(capabilities)}",
        )

    def digest(self) -> str:
        return hashlib.sha256((self.root / self.proposal).read_bytes()).hexdigest()

    def write_admission(
        self,
        index: int,
        reviewer: str,
        capability: str,
        digest: Optional[str] = None,
        verdict: str = "accepted",
    ) -> None:
        self.write_json(
            self.admission[index],
            {
                "schema_version": 1,
                "proposal": "o2i-0001",
                "phase": "admission",
                "reviewer": reviewer,
                "capability": capability,
                "proposal_path": self.proposal,
                "proposal_sha256": digest or self.digest(),
                "verdict": verdict,
                "scores": {"quality": 10.0},
                "findings": [] if verdict == "accepted" else ["finding"],
            },
        )

    def entry(self, **changes: Any) -> dict[str, Any]:
        entry = {
            "id": "o2i-0001",
            "title": "Lean Governance",
            "author": "author",
            "coauthors": ["coauthor"],
            "state": "implementing",
            "proposal": self.proposal,
            "plan": self.plan,
            "admission_reviews": self.admission,
            "final_reviews": [],
            "derived_from": [],
            "depends_on": [],
        }
        entry.update(changes)
        return entry

    def register(self, *entries: dict[str, Any]) -> None:
        self.write_json(
            governance.REGISTER,
            {"schema_version": 1, "changes": list(entries)},
        )

    def final(
        self,
        capability: str,
        reviewer: Optional[str] = None,
        revision: str = "a" * 40,
        verdict: str = "accepted",
        scope: Optional[list[str]] = None,
        scores: Optional[dict[str, float]] = None,
        findings: Optional[list[str]] = None,
    ) -> str:
        reference = (
            f"{CHANGE_ROOT}/reviews/final-"
            f"{capability.lower().replace(' ', '-')}.json"
        )
        self.write_json(
            reference,
            {
                "schema_version": 1,
                "change": "o2i-0001",
                "phase": "final",
                "reviewer": reviewer or capability.lower() + "-reviewer",
                "capability": capability,
                "reviewed_revision": revision,
                "reviewed_scope": scope if scope is not None else [self.proposal],
                "verdict": verdict,
                "scores": scores if scores is not None else {"quality": 10.0},
                "findings": (
                    findings
                    if findings is not None
                    else ([] if verdict == "accepted" else ["finding"])
                ),
            },
        )
        return reference

    def done(self) -> list[str]:
        reviews = [self.final(capability) for capability in CAPABILITIES]
        self.register(self.entry(state="done", final_reviews=reviews))
        return reviews

    def init_git(self) -> None:
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)
        subprocess.run(
            ["git", "config", "user.name", "O2I Test"],
            cwd=self.root,
            check=True,
        )
        subprocess.run(
            ["git", "config", "user.email", "o2i@example.invalid"],
            cwd=self.root,
            check=True,
        )

    def commit(self, message: str) -> str:
        subprocess.run(["git", "add", "-A"], cwd=self.root, check=True)
        subprocess.run(
            ["git", "commit", "-qm", message],
            cwd=self.root,
            check=True,
        )
        return subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=self.root,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()


def change(
    change_id: str,
    state: str = "proposed",
    derived_from: tuple[str, ...] = (),
    depends_on: tuple[str, ...] = (),
) -> Any:
    return governance.Change(
        change_id,
        change_id,
        "author",
        (),
        state,
        f".ai4X/governance/changes/{change_id}/proposal.md",
        "",
        (),
        (),
        derived_from,
        depends_on,
    )


class ChangeGovernanceTests(unittest.TestCase):
    def assert_error(self, errors: list[str], message: str) -> None:
        self.assertTrue(
            any(message in error for error in errors),
            f"{message!r} not found in {errors!r}",
        )

    def test_current_repository_and_gitless_done_snapshot_are_valid(self) -> None:
        self.assertEqual([], governance.validate_repository(ROOT))
        with tempfile.TemporaryDirectory() as directory:
            repo = Repository(Path(directory))
            repo.done()
            self.assertEqual([], governance.validate_repository(repo.root))

    def test_json_rejects_boolean_versions_and_duplicate_keys(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = Repository(Path(directory))
            repo.write_json(
                governance.REGISTER,
                {"schema_version": True, "changes": [repo.entry()]},
            )
            self.assert_error(
                governance.validate_repository(repo.root),
                "schema_version: must be integer 1",
            )

            repo.write(
                governance.REGISTER,
                '{"schema_version":1,"schema_version":1,"changes":[]}\n',
            )
            self.assert_error(
                governance.validate_repository(repo.root),
                "duplicate key 'schema_version'",
            )

    def test_register_schema_state_and_paths(self) -> None:
        cases = (
            ({"id": "change-1"}, "must match o2i-NNNN"),
            ({"state": "unknown"}, "unknown state"),
            ({"title": " padded "}, "must be trimmed and single-line"),
            ({"author": "author\nother"}, "must be trimmed and single-line"),
            ({"proposal": "proposal.md"}, "proposal must be"),
            ({"plan": ""}, "active change requires a plan"),
            (
                {
                    "final_reviews": [
                        f"{CHANGE_ROOT}/reviews/nested/final-review.json"
                    ]
                },
                "invalid Finalreview path",
            ),
        )
        for changes, message in cases:
            with self.subTest(message=message), tempfile.TemporaryDirectory() as path:
                repo = Repository(Path(path))
                repo.register(repo.entry(**changes))
                self.assert_error(
                    governance.validate_repository(repo.root), message
                )

        with tempfile.TemporaryDirectory() as directory:
            repo = Repository(Path(directory))
            entry = repo.entry()
            del entry["title"]
            repo.register(entry)
            self.assert_error(
                governance.validate_repository(repo.root), "missing fields: title"
            )

    def test_referenced_artifacts_must_be_regular_files(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = Repository(Path(directory))
            target = repo.root / "proposal-target.md"
            target.write_text("# Target\n", encoding="utf-8")
            (repo.root / repo.proposal).unlink()
            (repo.root / repo.proposal).symlink_to(target)
            repo.register(repo.entry())
            self.assert_error(
                governance.validate_repository(repo.root),
                "symlinks are not allowed",
            )

    def test_admission_digest_capabilities_and_roles(self) -> None:
        cases = (
            (
                lambda repo: repo.write_admission(
                    0, "strategy-reviewer", "strategy", "0" * 64
                ),
                "proposal_sha256",
            ),
            (
                lambda repo: repo.write_admission(0, "author", "strategy"),
                "reviewer collides",
            ),
            (
                lambda repo: repo.write_admission(
                    1, "strategy-reviewer", "formalization"
                ),
                "Admission reviewers must be distinct",
            ),
            (
                lambda repo: repo.write_admission(1, "reviewer", "other"),
                "capability: invalid",
            ),
            (
                lambda repo: repo.write_json(
                    repo.admission[0],
                    {**repo.read_json(repo.admission[0]), "extra": True},
                ),
                "unknown fields: extra",
            ),
            (
                lambda repo: repo.write_json(
                    repo.admission[0],
                    {
                        **repo.read_json(repo.admission[0]),
                        "schema_version": True,
                    },
                ),
                "schema_version: must be integer 1",
            ),
            (
                lambda repo: repo.write_json(
                    repo.admission[0],
                    {
                        key: value
                        for key, value in repo.read_json(
                            repo.admission[0]
                        ).items()
                        if key != "scores"
                    },
                ),
                "missing fields: scores",
            ),
            (
                lambda repo: repo.write_json(
                    repo.admission[0],
                    {
                        **repo.read_json(repo.admission[0]),
                        "scores": {"quality": 9.0},
                    },
                ),
                "accepted review requires 10.0",
            ),
            (
                lambda repo: repo.write_json(
                    repo.admission[0],
                    {
                        **repo.read_json(repo.admission[0]),
                        "verdict": "rejected",
                        "findings": [],
                    },
                ),
                "rejected review must have findings",
            ),
        )
        for mutate, message in cases:
            with self.subTest(message=message), tempfile.TemporaryDirectory() as path:
                repo = Repository(Path(path))
                mutate(repo)
                repo.register(repo.entry())
                self.assert_error(
                    governance.validate_repository(repo.root), message
                )

    def test_active_plan_declares_surfaces_and_review_capabilities(self) -> None:
        cases = (
            ((), CAPABILITIES, "Affected Surfaces"),
            (("governance",), (), "Required Finalreview Capabilities"),
        )
        for surfaces, capabilities, message in cases:
            with self.subTest(message=message), tempfile.TemporaryDirectory() as path:
                repo = Repository(Path(path))
                repo.write_plan(surfaces, capabilities)
                repo.register(repo.entry())
                self.assert_error(
                    governance.validate_repository(repo.root), message
                )

    def test_state_artifact_coherence(self) -> None:
        for state in (
            "proposed",
            "admitted",
            "implementing",
            "reviewing",
            "done",
            "rejected",
            "withdrawn",
        ):
            with self.subTest(valid=state), tempfile.TemporaryDirectory() as path:
                repo = Repository(Path(path))
                if state == "done":
                    repo.done()
                elif state == "rejected":
                    repo.write_admission(
                        0, "strategy-reviewer", "strategy", verdict="rejected"
                    )
                    repo.register(
                        repo.entry(
                            state=state,
                            plan="",
                            admission_reviews=[repo.admission[0]],
                        )
                    )
                elif state == "withdrawn":
                    review = repo.final("strategy")
                    repo.register(
                        repo.entry(state=state, final_reviews=[review])
                    )
                else:
                    plan = "" if state in {"proposed", "admitted"} else repo.plan
                    repo.register(repo.entry(state=state, plan=plan))
                self.assertEqual([], governance.validate_repository(repo.root))

        cases = (
            ("proposed", {}, "must not have a plan"),
            (
                "proposed",
                {"plan": "", "final_reviews": ["invalid.json"]},
                "must not have Finalreviews",
            ),
            (
                "admitted",
                {"final_reviews": ["invalid.json"]},
                "must not have Finalreviews",
            ),
            (
                "implementing",
                {"final_reviews": ["invalid.json"]},
                "must not have Finalreviews",
            ),
            (
                "rejected",
                {"plan": ""},
                "needs a rejected Admission",
            ),
        )
        for state, changes, message in cases:
            with self.subTest(invalid=state, message=message), tempfile.TemporaryDirectory() as path:
                repo = Repository(Path(path))
                repo.register(repo.entry(state=state, **changes))
                self.assert_error(
                    governance.validate_repository(repo.root), message
                )

        for artifact in ("plan", "Finalreviews"):
            with self.subTest(rejected=artifact), tempfile.TemporaryDirectory() as path:
                repo = Repository(Path(path))
                repo.write_admission(
                    0, "strategy-reviewer", "strategy", verdict="rejected"
                )
                changes = {
                    "state": "rejected",
                    "admission_reviews": [repo.admission[0]],
                }
                if artifact == "Finalreviews":
                    changes.update(
                        plan="",
                        final_reviews=[
                            repo.final("strategy", verdict="rejected")
                        ],
                    )
                repo.register(repo.entry(**changes))
                article = "a " if artifact == "plan" else ""
                self.assert_error(
                    governance.validate_repository(repo.root),
                    f"rejected change must not have {article}{artifact}",
                )

    def test_lineage_and_dependencies_are_separate_dags(self) -> None:
        cases = (
            (
                {"o2i-0001": change("o2i-0001", depends_on=("o2i-9999",))},
                "unknown id",
            ),
            (
                {"o2i-0001": change("o2i-0001", derived_from=("o2i-0001",))},
                "self-edge",
            ),
            (
                {
                    "o2i-0001": change("o2i-0001", derived_from=("o2i-0002",)),
                    "o2i-0002": change("o2i-0002", derived_from=("o2i-0001",)),
                },
                "derived_from: cycle",
            ),
            (
                {
                    "o2i-0001": change("o2i-0001", depends_on=("o2i-0002",)),
                    "o2i-0002": change("o2i-0002", depends_on=("o2i-0001",)),
                },
                "depends_on: cycle",
            ),
            (
                {
                    "o2i-0001": change(
                        "o2i-0001", "done", depends_on=("o2i-0002",)
                    ),
                    "o2i-0002": change("o2i-0002", "implementing"),
                },
                "open dependency",
            ),
        )
        for graph, message in cases:
            with self.subTest(message=message):
                self.assert_error(governance.validate_graphs(graph), message)

    def test_done_finalreview_contract(self) -> None:
        cases = (
            (
                lambda repo, refs: repo.write_json(
                    refs[0],
                    {**repo.read_json(refs[0]), "extra": True},
                ),
                "unknown fields: extra",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[0],
                    {**repo.read_json(refs[0]), "schema_version": True},
                ),
                "schema_version: must be integer 1",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[0],
                    {**repo.read_json(refs[0]), "change": "o2i-9999"},
                ),
                "change: must be 'o2i-0001'",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[0],
                    {**repo.read_json(refs[0]), "phase": "admission"},
                ),
                "phase: must be 'final'",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[0],
                    {**repo.read_json(refs[0]), "reviewed_revision": "abc"},
                ),
                "must be a full Git SHA",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[0],
                    {**repo.read_json(refs[0]), "reviewed_scope": []},
                ),
                "reviewed_scope: must not be empty",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[0],
                    {**repo.read_json(refs[0]), "reviewed_scope": ["/absolute"]},
                ),
                "canonical repository-relative paths",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[0],
                    {
                        **repo.read_json(refs[0]),
                        "reviewed_scope": [".ai4X/STATE.md"],
                    },
                ),
                "must exclude .ai4X/STATE.md",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[0],
                    {
                        **repo.read_json(refs[0]),
                        "reviewed_scope": [
                            ".ai4X/governance/changes.json"
                        ],
                    },
                ),
                "must exclude .ai4X/governance/changes.json",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[0],
                    {
                        **repo.read_json(refs[0]),
                        "reviewed_scope": [CHANGE_ROOT],
                    },
                ),
                "must exclude Finalreview evidence",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[0],
                    {
                        **repo.read_json(refs[0]),
                        "reviewed_scope": [refs[0]],
                    },
                ),
                "must exclude Finalreview evidence",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[0],
                    {
                        **repo.read_json(refs[0]),
                        "reviewed_scope": [".ai4X"],
                    },
                ),
                "and its ancestors",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[0],
                    {**repo.read_json(refs[0]), "reviewed_scope": ["missing"]},
                ),
                "current path does not exist",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[0],
                    {**repo.read_json(refs[0]), "reviewed_scope": ["../outside"]},
                ),
                "canonical repository-relative paths",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[0],
                    {**repo.read_json(refs[0]), "scores": {}},
                ),
                "scores: must be a nonempty object",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[0],
                    {**repo.read_json(refs[0]), "scores": {"quality": 9.9}},
                ),
                "accepted review requires 10.0",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[0],
                    {**repo.read_json(refs[0]), "findings": ["finding"]},
                ),
                "accepted review must have no findings",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[0],
                    {**repo.read_json(refs[0]), "reviewer": "author"},
                ),
                "reviewer collides",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[0],
                    {**repo.read_json(refs[0]), "reviewer": " reviewer "},
                ),
                "must be trimmed and single-line",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[1],
                    {
                        **repo.read_json(refs[1]),
                        "reviewer": repo.read_json(refs[0])["reviewer"],
                    },
                ),
                "Finalreview reviewers must be distinct",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[0],
                    {**repo.read_json(refs[0]), "capability": "other"},
                ),
                "not required by plan",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[0],
                    {
                        **repo.read_json(refs[0]),
                        "verdict": "rejected",
                        "findings": ["finding"],
                    },
                ),
                "done requires accepted Finalreviews",
            ),
            (
                lambda repo, refs: repo.write_json(
                    refs[1],
                    {**repo.read_json(refs[1]), "reviewed_revision": "b" * 40},
                ),
                "must bind one reviewed_revision",
            ),
        )
        for mutate, message in cases:
            with self.subTest(message=message), tempfile.TemporaryDirectory() as path:
                repo = Repository(Path(path))
                references = repo.done()
                mutate(repo, references)
                self.assert_error(
                    governance.validate_repository(repo.root), message
                )

        with tempfile.TemporaryDirectory() as directory:
            repo = Repository(Path(directory))
            references = repo.done()
            entry = repo.entry(state="done", final_reviews=references[:-1])
            repo.register(entry)
            self.assert_error(
                governance.validate_repository(repo.root),
                "must exactly cover plan capabilities",
            )

        for findings, message in (
            ("invalid", "must be an array"),
            ([""], "must not be empty"),
            ([" padded "], "must be trimmed and single-line"),
            (["line\nbreak"], "must be trimmed and single-line"),
            ([1], "must be a string"),
        ):
            with self.subTest(findings=findings):
                errors: list[str] = []
                governance._findings({"findings": findings}, "review", errors)
                self.assert_error(errors, message)

    def test_git_revision_existence_is_checked_only_with_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = Repository(Path(directory))
            repo.done()
            self.assertEqual([], governance.validate_repository(repo.root))
            repo.init_git()
            self.assert_error(
                governance.validate_repository(repo.root),
                "Git commit does not exist",
            )

    def test_review_scores_and_rejected_findings_apply_before_done(self) -> None:
        cases = (
            (
                "accepted",
                {"quality": 9.0},
                [],
                "accepted review requires 10.0",
            ),
            (
                "rejected",
                {"quality": 11.0},
                ["finding"],
                "must be within 0..10",
            ),
            (
                "rejected",
                {"quality": 5.0},
                [],
                "rejected review must have findings",
            ),
        )
        for verdict, scores, findings, message in cases:
            with self.subTest(message=message), tempfile.TemporaryDirectory() as path:
                repo = Repository(Path(path))
                review = repo.final(
                    "strategy",
                    verdict=verdict,
                    scores=scores,
                    findings=findings,
                )
                repo.register(
                    repo.entry(state="reviewing", final_reviews=[review])
                )
                self.assert_error(
                    governance.validate_repository(repo.root), message
                )

    def test_reviewed_scope_is_durable_and_git_is_repository_local(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = Repository(Path(directory))
            reviews = [
                repo.final(
                    capability,
                    scope=[repo.admission[0]],
                )
                for capability in CAPABILITIES
            ]
            repo.register(repo.entry(state="done", final_reviews=reviews))
            self.assertEqual([], governance.validate_repository(repo.root))

        with tempfile.TemporaryDirectory() as directory:
            repo = Repository(Path(directory))
            repo.write("surface/item.txt", "reviewed\n")
            repo.register(repo.entry(state="reviewing"))
            repo.init_git()
            revision = repo.commit("review subject")
            reviews = [
                repo.final(capability, revision=revision, scope=["surface"])
                for capability in CAPABILITIES
            ]
            repo.register(repo.entry(state="done", final_reviews=reviews))
            self.assertEqual([], governance.validate_repository(repo.root))
            repo.write("surface/item.txt", "changed\n")
            self.assertEqual([], governance.validate_repository(repo.root))
            (repo.root / "surface/item.txt").unlink()
            (repo.root / "surface").rmdir()
            self.assertEqual([], governance.validate_repository(repo.root))

        with tempfile.TemporaryDirectory() as directory:
            repo = Repository(Path(directory))
            repo.register(repo.entry(state="reviewing"))
            repo.init_git()
            revision = repo.commit("review subject")
            repo.write("later.txt", "not reviewed\n")
            reviews = [
                repo.final(capability, revision=revision, scope=["later.txt"])
                for capability in CAPABILITIES
            ]
            repo.register(repo.entry(state="done", final_reviews=reviews))
            self.assert_error(
                governance.validate_repository(repo.root),
                "path does not exist at reviewed_revision",
            )

        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            Repository(parent / "nested").done()
            subprocess.run(["git", "init", "-q"], cwd=parent, check=True)
            self.assertEqual(
                [],
                governance.validate_repository(parent / "nested"),
            )

        with tempfile.TemporaryDirectory() as directory:
            repo = Repository(Path(directory))
            repo.done()
            with mock.patch.object(
                governance.subprocess,
                "run",
                side_effect=FileNotFoundError,
            ):
                self.assertEqual([], governance.validate_repository(repo.root))

    def test_projections_are_deterministic(self) -> None:
        changes = {
            "o2i-0002": change(
                "o2i-0002",
                derived_from=("o2i-0001",),
                depends_on=("o2i-0001",),
            ),
            "o2i-0001": change("o2i-0001"),
        }
        backlog = governance.render_backlog(changes)
        graph = governance.render_graph(changes)
        self.assertEqual(
            "# O2I Change Backlog\n\n"
            "| ID | State | Title | Depends on |\n"
            "| --- | --- | --- | --- |\n"
            "| o2i-0001 | proposed | o2i-0001 | - |\n"
            "| o2i-0002 | proposed | o2i-0002 | o2i-0001 |\n",
            backlog,
        )
        self.assertEqual(
            "flowchart LR\n"
            '  change_o2i_0001["o2i-0001: o2i-0001 [proposed]"]\n'
            '  change_o2i_0002["o2i-0002: o2i-0002 [proposed]"]\n'
            "  change_o2i_0001 -->|derived| change_o2i_0002\n"
            "  change_o2i_0001 -->|required by| change_o2i_0002\n",
            graph,
        )


if __name__ == "__main__":
    unittest.main()
