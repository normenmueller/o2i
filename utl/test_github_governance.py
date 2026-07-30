#!/usr/bin/env python3
"""Static tests for the active GitHub-native governance contract."""

from __future__ import annotations

import hashlib
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GOVERNANCE = ROOT / ".ai4X/governance/README.md"
TARGET = ROOT / ".ai4X/governance/github-target.md"
MIGRATION = ROOT / ".ai4X/governance/issue-migration.md"
STATE = ROOT / ".ai4X/STATE.md"
CONTRIBUTING = ROOT / "CONTRIBUTING.md"
VERIFY = ROOT / "utl/verify.sh"
FRAMEWORK_FORM = ROOT / ".github/ISSUE_TEMPLATE/framework-change.yml"
MAINTENANCE_FORM = ROOT / ".github/ISSUE_TEMPLATE/maintenance.yml"
FORM_CONFIG = ROOT / ".github/ISSUE_TEMPLATE/config.yml"
BASELINE_MANIFEST = ROOT / ".ai4X/governance/issue-migration.sha256"
EXPECTED_BASELINE_PATHS = {
    ".ai4X/governance/README.md",
    ".ai4X/governance/changes.json",
    ".ai4X/governance/changes/o2i-0002/plan.md",
    ".ai4X/governance/changes/o2i-0002/proposal.md",
    ".ai4X/governance/changes/o2i-0002/reviews/admission-formalization.json",
    ".ai4X/governance/changes/o2i-0002/reviews/admission-strategy.json",
    ".ai4X/governance/changes/o2i-0003/authority-audit.md",
    ".ai4X/governance/changes/o2i-0003/plan.md",
    ".ai4X/governance/changes/o2i-0003/proposal.md",
    ".ai4X/governance/changes/o2i-0003/reviews/admission-formalization.json",
    ".ai4X/governance/changes/o2i-0003/reviews/admission-strategy.json",
    ".ai4X/governance/changes/o2i-0004/plan.md",
    ".ai4X/governance/changes/o2i-0004/proposal.md",
    ".ai4X/governance/changes/o2i-0004/reviews/admission-formalization.json",
    ".ai4X/governance/changes/o2i-0004/reviews/admission-strategy.json",
    ".ai4X/governance/changes/o2i-0004/reviews/final-formalization.json",
    ".ai4X/governance/changes/o2i-0004/reviews/final-haskell.json",
    ".ai4X/governance/changes/o2i-0004/reviews/final-publication.json",
    ".ai4X/governance/changes/o2i-0004/reviews/final-strategy.json",
    ".github/workflows/verify.yml",
    "utl/change-governance.py",
    "utl/test_change_governance.py",
    "utl/verify.sh",
}
PUBLIC_CONTRACTS = (
    GOVERNANCE,
    TARGET,
    MIGRATION,
    STATE,
    CONTRIBUTING,
)


def read(path: Path) -> str:
    """Read one UTF-8 contract."""
    return path.read_text(encoding="utf-8")


def issue_form_fields(path: Path) -> dict[str, bool]:
    """Return each issue-form field and whether it is required."""
    fields: dict[str, bool] = {}
    for block in re.split(r"(?m)^  - type: ", read(path))[1:]:
        identifier = re.search(r"(?m)^    id: ([a-z][a-z0-9_-]*)$", block)
        if identifier is None:
            continue
        required = re.search(r"(?m)^ {6,}required: true$", block)
        fields[identifier.group(1)] = required is not None
    return fields


def manifest_entries() -> dict[str, str]:
    """Parse the immutable migration-baseline manifest."""
    entries: dict[str, str] = {}
    for line in read(BASELINE_MANIFEST).splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  ([^\0]+)", line)
        if match is None:
            raise AssertionError(f"invalid manifest line: {line!r}")
        digest, path = match.groups()
        if path in entries:
            raise AssertionError(f"duplicate manifest path: {path}")
        entries[path] = digest
    return entries


class GitHubGovernanceContractTests(unittest.TestCase):
    """Keep human, agent, intake, and migration contracts aligned."""

    def test_required_surfaces_exist(self) -> None:
        for path in (
            GOVERNANCE,
            TARGET,
            MIGRATION,
            CONTRIBUTING,
            FRAMEWORK_FORM,
            MAINTENANCE_FORM,
            FORM_CONFIG,
        ):
            with self.subTest(path=path):
                self.assertTrue(path.is_file())

    def test_active_authority_split_is_explicit(self) -> None:
        content = read(GOVERNANCE)
        for term in (
            "A GitHub Issue owns",
            "Native Issue Dependencies own",
            "PO scheduling",
            "owns no admission",
            "only the activated local handoff",
            "deterministic and network-independent",
        ):
            with self.subTest(term=term):
                self.assertIn(term, content)
        self.assertNotIn("changes.json` is the single change register", content)

    def test_human_status_vocabulary_is_complete(self) -> None:
        content = read(CONTRIBUTING)
        for status in (
            "Backlog",
            "Ready",
            "In progress",
            "Paused",
            "In review",
            "Done",
        ):
            with self.subTest(status=status):
                self.assertIn(f"`{status}`", content)
        self.assertIn("blocked:external", content)

    def test_external_blocker_boundary_is_explicit(self) -> None:
        for path, boundary in (
            (GOVERNANCE, "outside"),
            (CONTRIBUTING, "außerhalb"),
        ):
            with self.subTest(path=path):
                content = read(path)
                self.assertIn(boundary, content)
                self.assertRegex(content.lower(), r"native issue\s+dependency")
                self.assertIn("blocked:external", content)
                self.assertIn("Paused", content)

    def test_framework_form_captures_admission_contract(self) -> None:
        self.assertRegex(
            read(FRAMEWORK_FORM),
            r"(?m)^labels:\n  - framework-change$",
        )
        expected = {
            "problem",
            "benefit",
            "target",
            "scope",
            "acceptance",
            "alternatives",
            "risks",
            "participants",
            "reviews",
        }
        fields = issue_form_fields(FRAMEWORK_FORM)
        self.assertEqual(expected, set(fields))
        self.assertTrue(all(fields.values()))

    def test_maintenance_form_captures_semantic_boundary(self) -> None:
        content = read(MAINTENANCE_FORM)
        self.assertRegex(content, r"(?m)^labels:\n  - maintenance$")
        fields = issue_form_fields(MAINTENANCE_FORM)
        self.assertEqual(
            {"problem", "target", "scope", "acceptance", "semantics"},
            set(fields),
        )
        self.assertTrue(all(fields.values()))
        self.assertIn("does not alter O2I semantics", content)

    def test_blank_issues_are_disabled(self) -> None:
        self.assertEqual("blank_issues_enabled: false\n", read(FORM_CONFIG))

    def test_cutover_contract_is_bound_and_non_competing(self) -> None:
        target = read(TARGET)
        migration = read(MIGRATION)
        self.assertIn("Status: `ACCEPTED`", target)
        self.assertIn("not a second\nruntime authority", target)
        self.assertIn("Status: `CUTOVER CANDIDATE`", migration)
        self.assertIn("Issue `#2` binds\nits full SHA", migration)
        self.assertIn("Result: `ACCEPTED`", migration)
        self.assertIn("None. Every legacy change", migration)
        self.assertIn("scheduling View is\n`Main`", migration)
        self.assertIn(
            "label set is exactly\n"
            "`framework-change`, `maintenance`, and `blocked:external`",
            migration,
        )

    def test_legacy_evidence_is_retained_but_not_executed(self) -> None:
        self.assertTrue((ROOT / "utl/change-governance.py").is_file())
        self.assertTrue((ROOT / "utl/test_change_governance.py").is_file())
        verification = read(VERIFY)
        self.assertIn("test_github_governance.py", verification)
        self.assertNotIn("test_*governance.py", verification)
        self.assertNotIn("change-governance.py validate", verification)

    def test_active_handoff_has_one_complete_gate_record(self) -> None:
        content = read(STATE)
        self.assertLess(len(content.splitlines()), 90)
        gate = content.split("# Current Gate\n", 1)[1].split("\n# ", 1)[0]
        for field in (
            "Attempt",
            "Subject",
            "Mandatory checks",
            "Finding status",
            "Result",
        ):
            with self.subTest(field=field):
                self.assertEqual(1, gate.count(f"- {field}:"))
        self.assertIn("exact repository `HEAD` containing this record", gate)

    def test_baseline_manifest_matches_immutable_revision(self) -> None:
        migration = read(MIGRATION)
        revision_match = re.search(r"(?m)^  `([0-9a-f]{40})`$", migration)
        self.assertIsNotNone(revision_match)
        revision = revision_match.group(1)

        probe = subprocess.run(
            ["git", "rev-parse", "--is-inside-work-tree"],
            cwd=ROOT,
            capture_output=True,
            check=False,
            text=True,
        )
        if probe.returncode != 0:
            self.skipTest("Git metadata is unavailable")

        entries = manifest_entries()
        self.assertEqual(EXPECTED_BASELINE_PATHS, set(entries))
        for path, expected in entries.items():
            with self.subTest(path=path):
                blob = subprocess.run(
                    ["git", "show", f"{revision}:{path}"],
                    cwd=ROOT,
                    capture_output=True,
                    check=False,
                )
                self.assertEqual(0, blob.returncode, blob.stderr.decode())
                self.assertEqual(expected, hashlib.sha256(blob.stdout).hexdigest())

    def test_public_contract_is_repository_autonomous(self) -> None:
        absolute_posix_path = re.compile(
            r"(?:^|[\s`(])/(?!/)[A-Za-z0-9._~-]",
            re.MULTILINE,
        )
        absolute_windows_path = re.compile(r"\b[A-Za-z]:[\\/]")
        parent_traversal = re.compile(r"(?:^|[\s`(])\.\./")
        relative_link = re.compile(r"\]\((?!https?://|#)([^)#]+)")

        root = ROOT.resolve()
        for path in PUBLIC_CONTRACTS:
            with self.subTest(path=path):
                content = read(path)
                self.assertIsNone(absolute_posix_path.search(content))
                self.assertIsNone(absolute_windows_path.search(content))
                self.assertIsNone(parent_traversal.search(content))
                for target in relative_link.findall(content):
                    resolved = (path.parent / target).resolve()
                    self.assertTrue(resolved.is_relative_to(root), target)

    def test_text_contracts_use_clean_files(self) -> None:
        for path in (
            GOVERNANCE,
            TARGET,
            MIGRATION,
            CONTRIBUTING,
            FRAMEWORK_FORM,
            MAINTENANCE_FORM,
            FORM_CONFIG,
        ):
            with self.subTest(path=path):
                content = read(path)
                self.assertTrue(content.endswith("\n"))
                self.assertNotIn("\t", content)
                self.assertNotIn(" \n", content)


if __name__ == "__main__":
    unittest.main()
