#!/usr/bin/env python3
"""Static tests for the active GitHub-native governance contract."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GOVERNANCE = ROOT / ".ai4X/governance/README.md"
STATE = ROOT / ".ai4X/STATE.md"
CONTRIBUTING = ROOT / "CONTRIBUTING.md"
FRAMEWORK_FORM = ROOT / ".github/ISSUE_TEMPLATE/framework-change.yml"
MAINTENANCE_FORM = ROOT / ".github/ISSUE_TEMPLATE/maintenance.yml"
FORM_CONFIG = ROOT / ".github/ISSUE_TEMPLATE/config.yml"
PUBLIC_CONTRACTS = (
    GOVERNANCE,
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


def handoff_contract_violations(content: str) -> list[str]:
    """Return violations of the active or paused handoff contract."""
    violations: list[str] = []
    fields: dict[str, str] = {}
    for name in (
        "Work status",
        "Execution authorization",
        "Current Issue",
        "Current gate",
        "Gate status",
    ):
        matches = re.findall(rf"(?m)^- {re.escape(name)}: `([^`]+)`$", content)
        if len(matches) != 1:
            violations.append(f"{name} must occur exactly once")
            continue
        fields[name] = matches[0]

    if len(fields) != 5:
        return violations

    gate_sections = content.count("# Current Gate\n")
    if fields["Current gate"] == "NONE":
        if fields["Work status"] != "PAUSED":
            violations.append("a gate-free handoff must be PAUSED")
        if fields["Execution authorization"] != "REQUIRED":
            violations.append("a gate-free handoff must require authorization")
        if fields["Current Issue"] != "NONE":
            violations.append("a gate-free handoff must have no current Issue")
        if fields["Gate status"] != "NOT_REQUIRED":
            violations.append("a gate-free handoff must not require a gate")
        if gate_sections != 0:
            violations.append("a gate-free handoff must omit Current Gate")
        return violations

    if fields["Current Issue"] == "NONE":
        violations.append("an active gate must identify its Issue")
    if fields["Gate status"] == "NOT_REQUIRED":
        violations.append("an active gate must require a gate result")
    if gate_sections != 1:
        violations.append("an active gate must have one Current Gate section")
        return violations

    gate = content.split("# Current Gate\n", 1)[1].split("\n# ", 1)[0]
    for name in (
        "Attempt",
        "Subject",
        "Mandatory checks",
        "Finding status",
        "Result",
    ):
        if gate.count(f"- {name}:") != 1:
            violations.append(f"Current Gate must contain one {name}")
    if "exact repository `HEAD` containing this record" not in gate:
        violations.append("an active gate must bind the exact repository HEAD")

    gate_values: dict[str, str] = {}
    for name in ("Attempt", "Finding status", "Result"):
        matches = re.findall(rf"(?m)^- {re.escape(name)}: `([^`]+)`$", gate)
        if len(matches) == 1:
            gate_values[name] = matches[0]
    if len(gate_values) == 3:
        if fields["Current gate"] != gate_values["Attempt"]:
            violations.append("Current gate must match Attempt")
        if fields["Gate status"] != gate_values["Result"]:
            violations.append("Gate status must match Result")
        if (
            gate_values["Result"] == "ACCEPTED"
            and gate_values["Finding status"] != "CLOSED"
        ):
            violations.append("an accepted gate must have closed findings")
    return violations


class GitHubGovernanceContractTests(unittest.TestCase):
    """Keep human, agent, intake, and execution contracts aligned."""

    def test_required_surfaces_exist(self) -> None:
        for path in (
            GOVERNANCE,
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

    def test_dependency_boundary_is_explicit_without_reserved_label(
        self,
    ) -> None:
        for path, terms in (
            (
                GOVERNANCE,
                ("outside", "affected Issue", "next-check condition"),
            ),
            (
                CONTRIBUTING,
                ("außerhalb", "betroffenen Issue", "nächster Prüfbedingung"),
            ),
        ):
            with self.subTest(path=path):
                content = read(path)
                normalized = " ".join(content.split())
                self.assertRegex(normalized.lower(), r"native issue dependency")
                for term in terms:
                    self.assertIn(term, normalized)
                self.assertIn("Paused", normalized)
                self.assertNotIn("blocked:external", normalized)

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

    def test_repository_handoff_matches_execution_contract(self) -> None:
        content = read(STATE)
        self.assertLess(len(content.splitlines()), 90)
        self.assertEqual([], handoff_contract_violations(content))

    def test_active_handoff_requires_one_complete_gate(self) -> None:
        content = """\
# Handoff

- Work status: `ACTIVE`
- Execution authorization: `APPROVED`
- Current Issue: `#10`
- Current gate: `closed-handoff-contract-1`
- Gate status: `PENDING`

# Current Gate

- Attempt: `closed-handoff-contract-1`
- Subject: the exact repository `HEAD` containing this record.
- Mandatory checks: governance verification.
- Finding status: `OPEN`
- Result: `PENDING`
"""
        self.assertEqual([], handoff_contract_violations(content))
        cases = (
            (
                "gate identity",
                content.replace(
                    "- Current gate: `closed-handoff-contract-1`",
                    "- Current gate: `different-gate`",
                ),
                "Current gate must match Attempt",
            ),
            (
                "gate result",
                content.replace(
                    "- Gate status: `PENDING`",
                    "- Gate status: `REJECTED`",
                ),
                "Gate status must match Result",
            ),
            (
                "accepted finding",
                content.replace(
                    "- Gate status: `PENDING`",
                    "- Gate status: `ACCEPTED`",
                ).replace(
                    "- Result: `PENDING`",
                    "- Result: `ACCEPTED`",
                ),
                "an accepted gate must have closed findings",
            ),
        )
        for name, malformed, expected in cases:
            with self.subTest(name=name):
                self.assertIn(expected, handoff_contract_violations(malformed))

    def test_paused_handoff_requires_no_current_gate(self) -> None:
        content = """\
# Handoff

- Work status: `PAUSED`
- Execution authorization: `REQUIRED`
- Current Issue: `NONE`
- Current gate: `NONE`
- Gate status: `NOT_REQUIRED`

# Repository Facts

- The accepted revision remains recorded here.
"""
        self.assertEqual([], handoff_contract_violations(content))

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
