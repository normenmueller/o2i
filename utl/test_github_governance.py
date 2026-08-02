#!/usr/bin/env python3
"""Static tests for the active GitHub-native governance contract."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GOVERNANCE = ROOT / ".ai4X/governance/guidelines.md"
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


def markdown_field_values(content: str, name: str) -> tuple[str, ...]:
    """Return normalized values of one Markdown bullet field."""
    pattern = rf"(?m)^- {re.escape(name)}:[ \t]*(.*(?:\n  .*)*)$"
    return tuple(
        " ".join(line.strip() for line in block.splitlines()).strip()
        for block in re.findall(pattern, content)
    )


def handoff_contract_violations(content: str) -> list[str]:
    """Return violations of the closed repository handoff contract."""
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

    vocabularies = {
        "Work status": {"ACTIVE", "PAUSED", "BLOCKED", "COMPLETE"},
        "Execution authorization": {"APPROVED", "REQUIRED"},
        "Gate status": {"NOT_REQUIRED", "PENDING", "ACCEPTED", "REJECTED"},
    }
    for name, allowed in vocabularies.items():
        if fields[name] not in allowed:
            violations.append(f"{name} has an invalid value")
    if violations:
        return violations

    gate_sections = content.count("# Current Gate\n")
    work_status = fields["Work status"]
    if work_status in {"PAUSED", "BLOCKED"}:
        if fields["Execution authorization"] != "REQUIRED":
            violations.append(f"{work_status} work must require authorization")
        if work_status == "BLOCKED" and fields["Current Issue"] == "NONE":
            violations.append("BLOCKED work must identify its Issue")
        if fields["Current gate"] != "NONE":
            violations.append(f"{work_status} work must be gate-free")
        if fields["Gate status"] != "NOT_REQUIRED":
            violations.append("a gate-free handoff must not require a gate")
        if gate_sections != 0:
            violations.append("a gate-free handoff must omit Current Gate")
        return violations

    if fields["Execution authorization"] != "APPROVED":
        violations.append(f"{work_status} work must be approved")
    if fields["Current Issue"] == "NONE":
        violations.append(f"{work_status} work must identify its Issue")
    if fields["Current gate"] == "NONE":
        violations.append(f"{work_status} work must identify its gate")
    allowed_gate_statuses = {
        "ACTIVE": {"PENDING", "REJECTED"},
        "COMPLETE": {"ACCEPTED"},
    }
    if fields["Gate status"] not in allowed_gate_statuses[work_status]:
        violations.append(
            f"{work_status} work has an incompatible gate status"
        )
    if gate_sections != 1:
        violations.append(f"{work_status} work must have one Current Gate section")
        return violations

    gate = content.split("# Current Gate\n", 1)[1].split("\n# ", 1)[0]
    gate_fields = {
        name: markdown_field_values(gate, name)
        for name in (
            "Attempt",
            "Candidate revision",
            "Review scope",
            "Mandatory checks",
            "Finding status",
            "Result",
        )
    }
    for name, values in gate_fields.items():
        if len(values) != 1:
            violations.append(f"Current Gate must contain one {name}")

    gate_values = {
        name: values[0]
        for name, values in gate_fields.items()
        if len(values) == 1
    }
    revision = gate_values.get("Candidate revision")
    if revision is not None and revision != "`PENDING`":
        if re.fullmatch(r"`[0-9a-f]{40}`", revision) is None:
            violations.append(
                "Candidate revision must be PENDING or one full Git revision"
            )

    scope = gate_values.get("Review scope")
    if scope is not None:
        subjects = tuple(re.findall(r"`([^`]+)`", scope))
        immutable_subjects = tuple(
            subject for subject in subjects if subject != ".ai4X/STATE.md"
        )
        if not immutable_subjects:
            violations.append("Review scope must declare an immutable subject")
        if ".ai4X/STATE.md" not in subjects or "excluded" not in scope.lower():
            violations.append("Review scope must exclude mutable .ai4X/STATE.md")

    scalar_fields = (
        "Attempt",
        "Candidate revision",
        "Finding status",
        "Result",
    )
    scalar_values: dict[str, str] = {}
    for name in scalar_fields:
        value = gate_values.get(name)
        if value is not None and re.fullmatch(r"`([^`]+)`", value) is not None:
            scalar_values[name] = value[1:-1]

    result_fields = ("Attempt", "Finding status", "Result")
    if all(name in scalar_values for name in result_fields):
        if fields["Current gate"] != scalar_values["Attempt"]:
            violations.append("Current gate must match Attempt")
        if fields["Gate status"] != scalar_values["Result"]:
            violations.append("Gate status must match Result")
        if (
            scalar_values["Result"] == "ACCEPTED"
            and scalar_values["Finding status"] != "CLOSED"
        ):
            violations.append("an accepted gate must have closed findings")
        if (
            scalar_values["Result"] in {"PENDING", "REJECTED"}
            and scalar_values["Finding status"] != "OPEN"
        ):
            violations.append("a non-accepted gate must have open findings")
        if (
            scalar_values["Result"] in {"ACCEPTED", "REJECTED"}
            and scalar_values.get("Candidate revision") == "PENDING"
        ):
            violations.append("a decided gate must bind one full Git revision")
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

    def test_non_core_ai4x_contract_names_are_lowercase(self) -> None:
        for directory in ("governance", "operations", "rules"):
            root = ROOT / ".ai4X" / directory
            if not root.is_dir():
                continue
            for path in root.rglob("*"):
                if path.is_file() and not path.name.startswith("."):
                    with self.subTest(path=path):
                        self.assertEqual(path.name, path.name.lower())

    def test_active_authority_split_is_explicit(self) -> None:
        content = read(GOVERNANCE)
        for term in (
            "A GitHub Issue owns",
            "Native Issue Dependencies own",
            "owns workflow status and Product Owner ordering",
            "owns no contract, admission",
            "activated repository-local handoff",
            "deterministic and network-independent",
        ):
            with self.subTest(term=term):
                self.assertIn(term, content)

    def test_review_candidate_and_evidence_contract_are_exact(self) -> None:
        content = read(GOVERNANCE)
        for term in (
            "one committed exact candidate revision",
            "accepted exact revision",
            "No reviewed file changes",
            "lowercase SHA-256",
            "exact UTF-8 bytes returned by the GitHub API",
            "without normalization or an added newline",
            "comment database ID",
            "Project item is archived",
            "exact Issue-body digest for Admission",
            "implementation-contract comment ID and digest for Finalreview",
        ):
            with self.subTest(term=term):
                self.assertIn(term, content)
        human = read(CONTRIBUTING)
        for term in (
            "Issue-Body-Digest für Admission",
            "ID und Digest des Implementierungsvertrags-Kommentars für "
            "Finalreview",
        ):
            with self.subTest(term=term):
                self.assertIn(term, human)

    def test_human_status_vocabulary_is_complete(self) -> None:
        content = read(CONTRIBUTING)
        for status in (
            "Backlog",
            "Refined",
            "Ready",
            "In progress",
            "Paused",
            "In review",
            "Done",
        ):
            with self.subTest(status=status):
                self.assertIn(f"`{status}`", content)

    def test_workflow_authority_and_transitions_are_explicit(self) -> None:
        content = read(GOVERNANCE)
        for term in (
            "Backlog -> Refined",
            "Refined -> Ready",
            "Ready -> In progress",
            "In progress -> In review",
            "In review -> In progress",
            "In review -> Done",
            "In progress -> Paused",
            "Paused -> Ready",
            "Only the Product Owner moves",
            "Agents control later transitions",
            "Project order never creates a dependency",
        ):
            with self.subTest(term=term):
                self.assertIn(term, content)

    def test_refinement_reads_body_and_comments(self) -> None:
        content = read(GOVERNANCE)
        for term in (
            "complete Issue body",
            "every existing comment",
            "internally consistent contract",
            "Product Owner decision",
            "never silently mutate",
        ):
            with self.subTest(term=term):
                self.assertIn(term, content)

    def test_delegated_remote_facts_use_primary_agent(self) -> None:
        content = read(GOVERNANCE)
        for term in (
            "never query or mutate remote",
            "primary agent",
            "unmodified result",
            "never inferred",
        ):
            with self.subTest(term=term):
                self.assertIn(term, content)

    def test_human_guidance_contains_portable_workflow_diagram(self) -> None:
        content = read(CONTRIBUTING)
        self.assertIn("```text\n", content)
        self.assertIn("Backlog -- Reifung --> Refined", content)
        self.assertIn("Refined -- PO-Freigabe --> Ready", content)
        self.assertIn("In progress -- Kandidat vollständig --> In review", content)
        self.assertIn("Findings", content)

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
                self.assertRegex(
                    normalized.lower(), r"native issue dependenc(?:y|ies)"
                )
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

    def test_maintenance_review_is_independent_and_proportionate(self) -> None:
        agent = read(GOVERNANCE)
        human = read(CONTRIBUTING)
        for term in (
            "Maintenance has no Framework Admission requirement or Admission "
            "digest",
            "every exact Maintenance candidate revision receives at least one "
            "independent Finalreview",
            "Add another reviewer only when a materially distinct risk",
            "Do not impose a fixed capability table, reviewer bundle, reviewer "
            "count, or reviewer-selection mechanism",
            "Any finding rejects that exact candidate",
            "Acceptance requires no finding",
            "10.0 in every selected dimension",
            "Reviewers assess critically, neutrally, objectively, and "
            "independently",
            "Review is never an acceptance default",
            "leanness, clarity, elegance, robustness, modularity, and "
            "usefulness",
            "Maintenance review never substitutes for Framework Admission",
            "Maintenance Finalreview evidence instead records the selected "
            "capability and concise risk rationale",
            "requires neither an Admission digest nor an implementation-contract "
            "comment",
        ):
            with self.subTest(term=term):
                self.assertIn(term, agent)
        for term in (
            "Maintenance benötigt weder Framework Admission noch "
            "Admission-Digest",
            "mindestens einen unabhängigen externen Finalreviewer",
            "nur für ein materiell anderes Risiko",
            "feste Reviewer-Matrix, -Anzahl oder Auswahlmechanik gibt es nicht",
            "Jedes Finding verwirft den exakten Kandidaten",
            "Die Annahme erfordert kein Finding und 10,0",
            "Reviewer bewerten kritisch, neutral, objektiv und unabhängig",
            "Ein Review ist keine Annahmeautomatik",
            "Maintenance-Finalreviews benötigen keinen Admission-Digest",
        ):
            with self.subTest(term=term):
                self.assertIn(term, human)
        self.assertNotIn("| Trigger ID |", agent)

    def test_agentic_responsibility_requires_assignment(self) -> None:
        agent = read(GOVERNANCE)
        human = read(CONTRIBUTING)
        self.assertIn("Add `gertrud-ai4x` as an assignee", agent)
        self.assertIn("Advisory-only participation creates no assignment", agent)
        self.assertIn("Gertrud wird einem Issue zugewiesen", human)
        self.assertIn("reine Advisory-Beteiligung genügt nicht", human)

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
- Candidate revision: `0123456789abcdef0123456789abcdef01234567`
- Review scope: `src/Contract.hs`;
  mutable `.ai4X/STATE.md` is excluded.
- Mandatory checks: governance verification.
- Finding status: `OPEN`
- Result: `PENDING`
"""
        self.assertEqual([], handoff_contract_violations(content))
        pending = content.replace(
            "`0123456789abcdef0123456789abcdef01234567`",
            "`PENDING`",
        )
        self.assertEqual([], handoff_contract_violations(pending))
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
                "candidate revision",
                content.replace(
                    "`0123456789abcdef0123456789abcdef01234567`",
                    "`01234567`",
                ),
                "Candidate revision must be PENDING or one full Git revision",
            ),
            (
                "empty review scope",
                content.replace(
                    "- Review scope: `src/Contract.hs`;\n"
                    "  mutable `.ai4X/STATE.md` is excluded.",
                    "- Review scope:",
                ),
                "Review scope must declare an immutable subject",
            ),
            (
                "exclusion-only review scope",
                content.replace(
                    "- Review scope: `src/Contract.hs`;\n"
                    "  mutable `.ai4X/STATE.md` is excluded.",
                    "- Review scope: mutable `.ai4X/STATE.md` is excluded.",
                ),
                "Review scope must declare an immutable subject",
            ),
            (
                "misplaced state exclusion",
                content.replace(
                    "- Review scope: `src/Contract.hs`;\n"
                    "  mutable `.ai4X/STATE.md` is excluded.\n"
                    "- Mandatory checks: governance verification.",
                    "- Review scope: `src/Contract.hs`.\n"
                    "- Mandatory checks: governance verification; mutable "
                    "`.ai4X/STATE.md` is excluded.",
                ),
                "Review scope must exclude mutable .ai4X/STATE.md",
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

    def test_handoff_status_table_is_closed(self) -> None:
        blocked = """\
# Handoff

- Work status: `BLOCKED`
- Execution authorization: `REQUIRED`
- Current Issue: `#10`
- Current gate: `NONE`
- Gate status: `NOT_REQUIRED`
"""
        complete = """\
# Handoff

- Work status: `COMPLETE`
- Execution authorization: `APPROVED`
- Current Issue: `#10`
- Current gate: `finalreview-1`
- Gate status: `ACCEPTED`

# Current Gate

- Attempt: `finalreview-1`
- Candidate revision: `0123456789abcdef0123456789abcdef01234567`
- Review scope: `src/Contract.hs`; mutable `.ai4X/STATE.md` is excluded.
- Mandatory checks: governance verification.
- Finding status: `CLOSED`
- Result: `ACCEPTED`
"""
        for name, valid in (("blocked", blocked), ("complete", complete)):
            with self.subTest(name=name):
                self.assertEqual([], handoff_contract_violations(valid))

        invalid_cases = (
            (
                "unknown work status",
                blocked.replace("`BLOCKED`", "`INVALID`"),
                "Work status has an invalid value",
            ),
            (
                "active authorization required",
                complete.replace("`COMPLETE`", "`ACTIVE`").replace(
                    "`APPROVED`", "`REQUIRED`", 1
                ).replace("`ACCEPTED`", "`PENDING`", 2).replace(
                    "`CLOSED`", "`OPEN`"
                ),
                "ACTIVE work must be approved",
            ),
            (
                "blocked gate",
                complete.replace("`COMPLETE`", "`BLOCKED`").replace(
                    "`APPROVED`", "`REQUIRED`", 1
                ),
                "BLOCKED work must be gate-free",
            ),
            (
                "complete authorization required",
                complete.replace("`APPROVED`", "`REQUIRED`", 1),
                "COMPLETE work must be approved",
            ),
        )
        for name, invalid, expected in invalid_cases:
            with self.subTest(name=name):
                self.assertIn(expected, handoff_contract_violations(invalid))

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
