#!/usr/bin/env python3
"""Tests for the lean O2I change-governance validator."""

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

ROOT = Path(__file__).resolve().parents[1]
CHANGE_ROOT = ".ai4X/governance/changes/o2i-0001"
DEFAULT_REVIEWS = (
    ("strategy", None, "accepted"),
    ("formalization", None, "accepted"),
    ("agentic AI", None, "accepted"),
)
SPEC = importlib.util.spec_from_file_location(
    "change_governance", Path(__file__).with_name("change-governance.py")
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("cannot load change-governance.py")
governance = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = governance
SPEC.loader.exec_module(governance)


def run(root: Path, *arguments: str) -> str:
    result = subprocess.run(
        arguments, cwd=root, check=True, capture_output=True, text=True
    )
    return result.stdout.strip()


class Repository:
    """Minimal valid governance repository."""

    def __init__(self, root: Path) -> None:
        self.root = root
        self.write(f"{CHANGE_ROOT}/proposal.md", "# Proposal\n\nGeneric benefit.\n")
        self.write(
            f"{CHANGE_ROOT}/plan.md",
            "# Plan\n\n"
            "## Required Finalreview Capabilities\n\n"
            "- strategy;\n"
            "- formalization;\n"
            "- agentic AI.\n",
        )
        self.admission = [
            f"{CHANGE_ROOT}/reviews/admission-strategy.json",
            f"{CHANGE_ROOT}/reviews/admission-formalization.json",
        ]
        self.write_admission(0, "strategy-reviewer", "strategy")
        self.write_admission(1, "formalization-reviewer", "formalization")

    def write(self, reference: str, content: str) -> None:
        path = self.root / reference
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def write_json(self, reference: str, value: object) -> None:
        self.write(reference, json.dumps(value, indent=2, sort_keys=True) + "\n")

    def digest(self) -> str:
        return hashlib.sha256(
            (self.root / CHANGE_ROOT / "proposal.md").read_bytes()
        ).hexdigest()

    def write_admission(
        self,
        index: int,
        reviewer: str,
        capability: str,
        digest: Optional[str] = None,
    ) -> None:
        self.write_json(
            self.admission[index],
            {
                "schema_version": 1,
                "proposal": "o2i-0001",
                "phase": "admission",
                "reviewer": reviewer,
                "capability": capability,
                "proposal_path": f"{CHANGE_ROOT}/proposal.md",
                "proposal_sha256": digest or self.digest(),
                "verdict": "accepted",
                "findings": [],
            },
        )

    def entry(self, **changes: Any) -> dict[str, Any]:
        result = {
            "id": "o2i-0001",
            "title": "Lean Governance",
            "author": "author",
            "coauthors": ["coauthor"],
            "state": "implementing",
            "proposal": f"{CHANGE_ROOT}/proposal.md",
            "plan": f"{CHANGE_ROOT}/plan.md",
            "admission_reviews": self.admission,
            "final_reviews": [],
            "derived_from": [],
            "depends_on": [],
        }
        result.update(changes)
        return result

    def register(self, *entries: dict[str, Any]) -> None:
        self.write_json(
            ".ai4X/governance/changes.json",
            {"schema_version": 1, "changes": list(entries)},
        )

    def init_git(self) -> None:
        run(self.root, "git", "init", "-q")
        run(self.root, "git", "config", "user.name", "O2I Test")
        run(self.root, "git", "config", "user.email", "o2i@example.invalid")

    def commit(self, message: str) -> str:
        run(self.root, "git", "add", "-A")
        run(self.root, "git", "commit", "-qm", message)
        return run(self.root, "git", "rev-parse", "HEAD")

    def final(
        self,
        capability: str,
        revision: str,
        reviewer: Optional[str] = None,
        verdict: str = "accepted",
    ) -> str:
        slug = capability.lower().replace(" ", "-")
        reference = f"{CHANGE_ROOT}/reviews/final-{slug}.json"
        self.write_json(
            reference,
            {
                "reviewer": reviewer or slug + "-reviewer",
                "capability": capability,
                "reviewed_revision": revision,
                "verdict": verdict,
                "findings": [] if verdict == "accepted" else ["finding"],
            },
        )
        return reference

    def done(
        self,
        reviews: tuple[tuple[str, Optional[str], str], ...] = DEFAULT_REVIEWS,
        revision_override: Optional[str] = None,
    ) -> str:
        self.register(self.entry(state="reviewing"))
        self.init_git()
        revision = self.commit("review subject")
        references = [
            self.final(
                capability,
                revision_override or revision,
                reviewer=reviewer,
                verdict=verdict,
            )
            for capability, reviewer, verdict in reviews
        ]
        self.register(self.entry(state="done", final_reviews=references))
        self.commit("attest reviews")
        return revision


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
    def test_current_repository_is_valid(self) -> None:
        self.assertEqual([], governance.validate_repository(ROOT))

    def test_admission_digest_and_roles(self) -> None:
        for case in ("digest", "role"):
            with self.subTest(case=case), tempfile.TemporaryDirectory() as directory:
                repo = Repository(Path(directory))
                if case == "digest":
                    repo.write_admission(0, "strategy-reviewer", "strategy", "0" * 64)
                else:
                    repo.write_admission(0, "author", "strategy")
                repo.register(repo.entry())
                errors = governance.validate_repository(repo.root)
                expected = (
                    "proposal_sha256" if case == "digest" else "reviewer collides"
                )
                self.assertTrue(any(expected in error for error in errors))

    def test_ids_states_artifacts_and_base_transition(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = Repository(Path(directory))
            repo.register(repo.entry(id="change-1"))
            self.assertTrue(
                any(
                    "must match o2i-NNNN" in error
                    for error in governance.validate_repository(repo.root)
                )
            )
            repo.register(repo.entry(state="unknown"))
            self.assertTrue(
                any(
                    "unknown state" in error
                    for error in governance.validate_repository(repo.root)
                )
            )
            repo.register(repo.entry(proposal=".ai4X/governance/proposal.md"))
            self.assertTrue(
                any(
                    "proposal must be" in error
                    for error in governance.validate_repository(repo.root)
                )
            )
            repo.register(repo.entry(state="implementing", plan=""))
            self.assertTrue(
                any(
                    "has no plan" in error
                    for error in governance.validate_repository(repo.root)
                )
            )
            repo.register(
                repo.entry(state="proposed", plan="", admission_reviews=[])
            )
            repo.init_git()
            base = repo.commit("proposed")
            repo.register(repo.entry(state="implementing"))
            self.assertTrue(
                any(
                    "invalid transition" in error
                    for error in governance.validate_repository(repo.root, base)
                )
            )

    def test_graph_contracts(self) -> None:
        cases = {
            "unknown": {
                "o2i-0001": change("o2i-0001", depends_on=("o2i-9999",))
            },
            "self": {
                "o2i-0001": change("o2i-0001", derived_from=("o2i-0001",))
            },
            "lineage cycle": {
                "o2i-0001": change("o2i-0001", derived_from=("o2i-0002",)),
                "o2i-0002": change("o2i-0002", derived_from=("o2i-0001",)),
            },
            "dependency cycle": {
                "o2i-0001": change("o2i-0001", depends_on=("o2i-0002",)),
                "o2i-0002": change("o2i-0002", depends_on=("o2i-0001",)),
            },
            "open dependency": {
                "o2i-0001": change(
                    "o2i-0001", "done", depends_on=("o2i-0002",)
                ),
                "o2i-0002": change("o2i-0002", "implementing"),
            },
        }
        expected = ("unknown id", "self-edge", "cycle", "cycle", "open dependency")
        for (name, graph), message in zip(cases.items(), expected):
            with self.subTest(case=name):
                self.assertTrue(
                    any(message in error for error in governance.validate_graphs(graph))
                )

    def test_finalreview_capability_verdict_revision_and_roles(self) -> None:
        cases = {
            "capability": (
                (
                    ("strategy", None, "accepted"),
                    ("formalization", None, "accepted"),
                    ("other", None, "accepted"),
                ),
                None,
                "agentic AI",
            ),
            "verdict": (
                (
                    ("strategy", None, "accepted"),
                    ("formalization", None, "rejected"),
                    ("agentic AI", None, "accepted"),
                ),
                None,
                "formalization",
            ),
            "revision": (DEFAULT_REVIEWS, "0" * 40, "exact Git"),
            "author collision": (
                (
                    ("strategy", "author", "accepted"),
                    ("formalization", None, "accepted"),
                    ("agentic AI", None, "accepted"),
                ),
                None,
                "reviewer collides",
            ),
            "reviewer collision": (
                (
                    ("strategy", "same-reviewer", "accepted"),
                    ("formalization", "same-reviewer", "accepted"),
                    ("agentic AI", None, "accepted"),
                ),
                None,
                "reviewers must be distinct",
            ),
        }
        for name, (reviews, revision, message) in cases.items():
            with self.subTest(case=name), tempfile.TemporaryDirectory() as directory:
                repo = Repository(Path(directory))
                repo.done(reviews, revision)
                errors = governance.validate_repository(repo.root)
                self.assertTrue(any(message in error for error in errors))

    def test_finalreview_scope_is_transition_bound(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = Repository(Path(directory))
            repo.register(repo.entry(state="reviewing"))
            repo.init_git()
            revision = repo.commit("review subject")
            references = [
                repo.final(capability, revision)
                for capability, _, _ in DEFAULT_REVIEWS
            ]
            repo.write("unrelated.txt", "committed unrelated work\n")
            repo.register(repo.entry(state="done", final_reviews=references))
            repo.commit("invalid attestation scope")
            errors = governance.validate_repository(repo.root, revision)
            self.assertTrue(
                any(
                    "files changed after reviewed revision" in error
                    for error in errors
                )
            )

        with tempfile.TemporaryDirectory() as directory:
            repo = Repository(Path(directory))
            revision = repo.done()
            repo.write("unrelated.txt", "uncommitted user work\n")
            self.assertEqual(
                [], governance.validate_repository(repo.root, revision)
            )

            (repo.root / "unrelated.txt").unlink()
            done_revision = run(repo.root, "git", "rev-parse", "HEAD")
            repo.write("later.txt", "regular later work\n")
            repo.commit("later repository work")
            self.assertEqual([], governance.validate_repository(repo.root))
            self.assertEqual(
                [],
                governance.validate_repository(repo.root, done_revision),
            )

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
        self.assertEqual(backlog, governance.render_backlog(changes))
        self.assertEqual(graph, governance.render_graph(changes))
        self.assertLess(backlog.index("o2i-0001"), backlog.index("o2i-0002"))
        self.assertIn("change_o2i_0001 -->|derived| change_o2i_0002", graph)
        self.assertIn("change_o2i_0001 -->|required by| change_o2i_0002", graph)


if __name__ == "__main__":
    unittest.main()
