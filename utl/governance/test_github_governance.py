#!/usr/bin/env python3
"""Static tests for the lean GitHub-native governance contract."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BEHAVIOR = ROOT / ".ai4x/BEHAVIOR.md"
CONTEXT = ROOT / ".ai4x/CONTEXT.md"
TEAM = ROOT / ".ai4x/TEAM.md"
GOVERNANCE = ROOT / ".ai4x/governance/guidelines.md"
STATE = ROOT / ".ai4x/STATE.md"
CONTRIBUTING = ROOT / "CONTRIBUTING.md"
HASKELL_AUTHORING = ROOT / ".ai4x/operations/haskell-authoring.md"
HASKELL_REVIEW = ROOT / ".ai4x/operations/haskell-review.md"
STRATEGY_REVIEW = ROOT / ".ai4x/operations/strategy-review.md"
FRAMEWORK_FORM = ROOT / ".github/ISSUE_TEMPLATE/framework-change.yml"
MAINTENANCE_FORM = ROOT / ".github/ISSUE_TEMPLATE/maintenance.yml"
FORM_CONFIG = ROOT / ".github/ISSUE_TEMPLATE/config.yml"
GITIGNORE = ROOT / ".gitignore"
SKILLS = {
    "o2i-formalization": (
        ROOT / ".agents/skills/o2i-formalization/SKILL.md",
        ".ai4x/operations/haskell-authoring.md",
    ),
    "o2i-modeling": (
        ROOT / ".agents/skills/o2i-modeling/SKILL.md",
        ".ai4x/operations/modeling.md",
    ),
    "o2i-strategy": (
        ROOT / ".agents/skills/o2i-strategy/SKILL.md",
        ".ai4x/operations/strategy-review.md",
    ),
    "o2i-publication": (
        ROOT / ".agents/skills/o2i-publication/SKILL.md",
        ".ai4x/operations/publication.md",
    ),
    "o2i-independent-review": (
        ROOT / ".agents/skills/o2i-independent-review/SKILL.md",
        ".ai4x/governance/guidelines.md",
    ),
}
AGENT_PROFILES = tuple(sorted((ROOT / ".github/agents").glob("*.agent.md")))
REVIEW_CONTRACTS = (GOVERNANCE, CONTRIBUTING, HASKELL_REVIEW, STRATEGY_REVIEW)
PUBLIC_CONTRACTS = (
    BEHAVIOR,
    CONTEXT,
    TEAM,
    GOVERNANCE,
    STATE,
    CONTRIBUTING,
    HASKELL_AUTHORING,
    HASKELL_REVIEW,
    STRATEGY_REVIEW,
    *(path for path, _ in SKILLS.values()),
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


class GitHubGovernanceContractTests(unittest.TestCase):
    """Keep human, agent, intake, and handoff contracts aligned."""

    def test_required_surfaces_exist(self) -> None:
        for path in (
            BEHAVIOR,
            CONTEXT,
            TEAM,
            GOVERNANCE,
            STATE,
            CONTRIBUTING,
            GITIGNORE,
            HASKELL_AUTHORING,
            HASKELL_REVIEW,
            STRATEGY_REVIEW,
            FRAMEWORK_FORM,
            MAINTENANCE_FORM,
            FORM_CONFIG,
            *(path for path, _ in SKILLS.values()),
            *AGENT_PROFILES,
        ):
            with self.subTest(path=path):
                self.assertTrue(path.is_file())

    def test_non_core_ai4x_contract_names_are_lowercase(self) -> None:
        for directory in ("governance", "operations", "rules"):
            root = ROOT / ".ai4x" / directory
            if not root.is_dir():
                continue
            for path in root.rglob("*"):
                if path.is_file() and not path.name.startswith("."):
                    with self.subTest(path=path):
                        self.assertEqual(path.name, path.name.lower())

    def test_authority_is_recorded_once(self) -> None:
        content = read(GOVERNANCE)
        for term in (
            "A GitHub Issue owns",
            "Native Issue Dependencies own",
            "owns workflow status and Product Owner ordering",
            "owns no product contract or acceptance fact",
            "concise repository-local handoff",
            "Git commits and deterministic checks own",
            "Issue-free Routine work",
        ):
            with self.subTest(term=term):
                self.assertIn(term, content)

    def test_issue_free_work_is_a_bounded_routine_exception(self) -> None:
        self.assertIn("current Issue or `NONE`", read(BEHAVIOR))
        self.assertIn("Issue-free Routine work", read(BEHAVIOR))
        self.assertIn("Issue-free Routine work", read(GOVERNANCE))
        self.assertIn("Routinearbeit auch ohne Issue", read(CONTRIBUTING))
        self.assertIn("Scope des Issues oder des ausdrücklichen PO-Auftrags", read(CONTRIBUTING))

    def test_change_paths_are_risk_proportionate(self) -> None:
        agent = read(GOVERNANCE)
        human = read(CONTRIBUTING)
        for term in (
            "### Routine",
            "### Significant",
            "### Protected",
            "impact, reversibility, and blast radius",
            "author self-review",
            "at least one independent reviewer",
            "explicit Product Owner decision",
            "select the next safer path",
        ):
            with self.subTest(surface="agent", term=term):
                self.assertIn(term, agent)
        for term in (
            "### Routine",
            "### Signifikant",
            "### Geschützt",
            "Wirkung, Reversibilität und Reichweite",
            "kritischer Selbstreview",
            "mindestens ein unabhängiger Reviewer",
            "ausdrückliche PO-Entscheidung",
            "nächstsicherere Klasse",
        ):
            with self.subTest(surface="human", term=term):
                self.assertIn(term, human)

    def test_quality_controls_are_not_waived(self) -> None:
        agent = read(GOVERNANCE)
        human = read(CONTRIBUTING)
        for term in (
            "Never weaken deterministic verification",
            "type safety",
            "repository autonomy",
            "security",
            "publication checks",
        ):
            with self.subTest(surface="agent", term=term):
                self.assertIn(term, agent)
        for term in (
            "Kein Änderungspfad schwächt Tests",
            "Typsicherheit",
            "Reproduzierbarkeit",
            "Repository-Autonomie",
            "Publikationsprüfungen",
        ):
            with self.subTest(surface="human", term=term):
                self.assertIn(term, human)

    def test_workflow_is_visible_without_ceremonial_hops(self) -> None:
        for path in (GOVERNANCE, CONTRIBUTING):
            content = read(path)
            with self.subTest(path=path):
                for status in (
                    "Backlog",
                    "Refinement",
                    "Ready",
                    "In progress",
                    "Paused",
                    "In review",
                    "Done",
                ):
                    self.assertIn(f"`{status}`", content)
                self.assertIn("Backlog -> Refinement -> Ready -> In progress", content)
        self.assertIn("not a mandatory stop", read(GOVERNANCE))
        self.assertIn("kein Pflichtschritt", read(CONTRIBUTING))
        self.assertIn("Board reflects work; it does not manufacture authority", read(GOVERNANCE))
        self.assertIn("Board bildet Autorität ab, erzeugt sie aber nicht", read(CONTRIBUTING))

    def test_paused_means_a_real_wait(self) -> None:
        agent = read(GOVERNANCE)
        human = read(CONTRIBUTING)
        self.assertIn("only a genuine wait state", agent)
        self.assertIn("active investigation is never paused", agent)
        self.assertIn("echter Wartezustand", human)
        self.assertIn("aktive Konzeption, Umsetzung, Untersuchung", human)

    def test_subissues_are_optional_visibility(self) -> None:
        agent = read(GOVERNANCE)
        human = read(CONTRIBUTING)
        for term in (
            "when they materially improve visibility",
            "parent owns integrated scope, authority, acceptance, and publication",
            "adds no product scope or authority",
            "Put active Stories on the Project",
        ):
            with self.subTest(surface="agent", term=term):
                self.assertIn(term, agent)
        for term in (
            "wenn sie einen mehrteiligen Liefergegenstand",
            "Parent besitzt integrierten Scope, Autorität, Annahme und Publikation",
            "ergänzt aber keinen Produktscope und keine Autorität",
            "Aktive Stories dürfen zur Sichtbarkeit im Project stehen",
        ):
            with self.subTest(surface="human", term=term):
                self.assertIn(term, human)

    def test_later_findings_are_acceptance_challenges(self) -> None:
        agent = read(GOVERNANCE)
        human = read(CONTRIBUTING)
        for term in (
            "first an acceptance challenge",
            "not a retroactive invalidation",
            "Reproduce the concern",
            "new linked correction Issue",
            "Reopen closed history only when the Product Owner explicitly chooses",
        ):
            with self.subTest(surface="agent", term=term):
                self.assertIn(term, agent)
        for term in (
            "zunächst eine Akzeptanz-Challenge",
            "keine rückwirkende Entwertung",
            "neues verlinktes Korrektur-Issue",
            "geschlossene Historie bleibt geschlossen",
        ):
            with self.subTest(surface="human", term=term):
                self.assertIn(term, human)

    def test_review_uses_verdicts_without_scores(self) -> None:
        for path in REVIEW_CONTRACTS:
            content = read(path)
            with self.subTest(path=path):
                for verdict in (
                    "`accepted`",
                    "`accepted with follow-ups`",
                    "`changes required`",
                ):
                    self.assertIn(verdict, content)
                self.assertNotIn("10.0", content)
                self.assertNotIn("10,0", content)
        self.assertIn("Numerical scores are prohibited", read(GOVERNANCE))
        self.assertIn("Numerische Bewertungen entfallen", read(CONTRIBUTING))

    def test_coauthoring_follows_material_specialist_judgment(self) -> None:
        behavior = " ".join(read(BEHAVIOR).split())
        team = " ".join(read(TEAM).split())
        haskell = " ".join(read(HASKELL_AUTHORING).split())
        for content in (behavior, team, haskell):
            with self.subTest(contract=content[:40]):
                self.assertIn("specialist judgment materially shapes", content)
                self.assertIn("design and implementation", content)
        self.assertIn("alone never makes co-authoring mandatory", haskell)
        self.assertIn("never independently accepts", behavior)
        self.assertIn("never changes role to independently accept", team)

    def test_gertrud_and_sessions_are_repository_local(self) -> None:
        behavior = read(BEHAVIOR)
        for term in (
            "Top-Quality referent",
            "she is not a universal domain specialist",
            "sole human participant",
            "own repository-local Gertrud instance",
            "No global or cross-project Gertrud instance exists",
            "share no runtime context, memory, work state",
            "Never discover authority, state, or tools through a neighboring checkout",
        ):
            with self.subTest(term=term):
                self.assertIn(term, behavior)

    def test_team_routes_capabilities_and_records_role_separation(self) -> None:
        content = read(TEAM)
        for term in (
            "# Capability Routing",
            "O2I metamodel, formal methods, type theory",
            "TOGAF/ArchiMate expertise",
            "strategy, performance measurement, source criticism",
            "technical publication",
            "repository governance, agentic-workflow safety",
            "assigned capability and role",
            "authorship, implementation, and independent review",
            "stop at the safe boundary",
        ):
            with self.subTest(term=term):
                self.assertIn(term, content)

    def test_repository_skills_are_lean_local_routers(self) -> None:
        for name, (path, contract) in SKILLS.items():
            content = read(path)
            with self.subTest(skill=name):
                frontmatter = re.match(
                    r"\A---\nname: ([a-z0-9-]+)\ndescription: ([^\n]+)\n---\n",
                    content,
                )
                self.assertIsNotNone(frontmatter)
                self.assertEqual(name, frontmatter.group(1) if frontmatter else None)
                self.assertEqual(name, path.parent.name)
                self.assertIn(contract, content)
                self.assertIn(".ai4x/TEAM.md", content)
                self.assertLess(len(content.splitlines()), 25)

    def test_agent_profiles_are_thin_and_role_specific(self) -> None:
        expected = {
            "o2i.agent.md",
            "o2i-formalization-coauthor.agent.md",
            "o2i-governance-coauthor.agent.md",
            "o2i-independent-reviewer.agent.md",
            "o2i-modeling-coauthor.agent.md",
            "o2i-publication-coauthor.agent.md",
            "o2i-strategy-coauthor.agent.md",
        }
        self.assertEqual(expected, {path.name for path in AGENT_PROFILES})
        relative_link = re.compile(r"\]\(([^)#]+)")
        for path in AGENT_PROFILES:
            content = read(path)
            with self.subTest(profile=path.name):
                self.assertLess(len(content.splitlines()), 12)
                for target in relative_link.findall(content):
                    self.assertTrue((path.parent / target).resolve().is_relative_to(ROOT))
                    self.assertTrue((path.parent / target).resolve().is_file())
                if "coauthor" in path.name:
                    self.assertIn("Active Co-Author", content)
                    self.assertIn("design and implementation", content)
                    self.assertIn("never independently accept", content)
                elif "reviewer" in path.name:
                    self.assertIn("Read-only external reviewer", content)
                    self.assertIn("did not author or implement", content)
                    self.assertIn("never mutate", content)
                else:
                    self.assertIn("Gertrud instance", content)
                    self.assertIn("never as a global agent", content)

    def test_temporary_staging_is_local_and_ignored(self) -> None:
        behavior = read(BEHAVIOR)
        governance = read(GOVERNANCE)
        self.assertIn(".ai4x/local/", behavior)
        self.assertIn(".ai4x/local/remote/", governance)
        self.assertNotIn("workspace `tmp/`", governance)
        self.assertIn(".ai4x/local/\n", read(GITIGNORE))

    def test_issue_82_handoff_preserves_independent_issue_52(self) -> None:
        content = read(STATE)
        self.assertIn("- Current Issue: `#82`", content)
        self.assertIn("independent #52 branch", content)
        self.assertIn("remain separate, preserved, and untouched", content)
        self.assertIn("Product artifacts remain outside the candidate", content)

    def test_integrity_evidence_is_exception_based(self) -> None:
        agent = read(GOVERNANCE)
        human = read(CONTRIBUTING)
        for term in (
            "externally supplied authority",
            "release artifact",
            "security-sensitive evidence",
            "another stated integrity need",
        ):
            with self.subTest(surface="agent", term=term):
                self.assertIn(term, agent)
        self.assertIn("anderen konkret benannten Integritätsbedarf", human)

    def test_delegated_remote_facts_use_primary_agent(self) -> None:
        content = read(GOVERNANCE)
        for term in (
            "never query or mutate remote",
            "primary agent",
            "unmodified result",
            "without inference",
        ):
            with self.subTest(term=term):
                self.assertIn(term, content)

    def test_attribution_and_push_authority_are_explicit(self) -> None:
        agent = read(GOVERNANCE)
        human = read(CONTRIBUTING)
        for term in (
            "Product Owner authority commits",
            "Issue-scoped commits include `Refs #N`",
            "Push, release, protected publication",
            "explicit Product Owner authority",
        ):
            with self.subTest(term=term):
                self.assertIn(term, agent)
        self.assertIn("Issue-bezogene Commits führen `Refs #N`", human)

    def test_repository_handoff_is_concise(self) -> None:
        content = read(STATE)
        self.assertLess(len(content.splitlines()), 90)
        self.assertEqual(1, len(re.findall(r"(?m)^- Work status: `(?:ACTIVE|PAUSED|COMPLETE)`$", content)))
        self.assertRegex(content, r"(?m)^- Current Issue: `(?:#[0-9]+|NONE)`$")
        for heading in (
            "# Objective",
            "# Authority",
            "# Material Risk",
            "# Verification",
            "# Next Action",
            "# Local Return Point",
        ):
            with self.subTest(heading=heading):
                self.assertIn(heading, content)
        for obsolete in ("Current gate", "Gate status", "Execution authorization"):
            self.assertNotIn(obsolete, content)

    def test_issue_forms_remain_focused(self) -> None:
        framework = issue_form_fields(FRAMEWORK_FORM)
        maintenance = issue_form_fields(MAINTENANCE_FORM)
        self.assertTrue({"change_path", "problem", "benefit", "target", "scope", "acceptance", "risks"}.issubset(framework))
        self.assertTrue(all(framework[field] for field in ("change_path", "problem", "benefit", "target", "scope", "acceptance", "risks")))
        self.assertTrue(all(not framework[field] for field in ("alternatives", "participants", "reviews")))
        self.assertTrue({"problem", "target", "scope", "acceptance", "semantics"}.issubset(maintenance))
        self.assertTrue(all(maintenance.values()))

    def test_blank_issues_are_disabled(self) -> None:
        self.assertEqual("blank_issues_enabled: false\n", read(FORM_CONFIG))

    def test_repository_verification_remains_deterministic(self) -> None:
        content = read(GOVERNANCE)
        self.assertIn("deterministic and network-independent", content)
        self.assertIn("./utl/verify.sh", content)
        self.assertIn("Before every release tag", content)
        self.assertIn("Remote verification", content)

    def test_public_contract_is_repository_autonomous(self) -> None:
        absolute_posix_path = re.compile(r"(?:^|[\s`(])/(?!/)[A-Za-z0-9._~-]", re.MULTILINE)
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
            BEHAVIOR,
            CONTEXT,
            TEAM,
            GOVERNANCE,
            CONTRIBUTING,
            GITIGNORE,
            HASKELL_AUTHORING,
            HASKELL_REVIEW,
            STRATEGY_REVIEW,
            FRAMEWORK_FORM,
            MAINTENANCE_FORM,
            FORM_CONFIG,
            *(path for path, _ in SKILLS.values()),
            *AGENT_PROFILES,
        ):
            with self.subTest(path=path):
                content = read(path)
                self.assertTrue(content.endswith("\n"))
                self.assertNotIn("\t", content)
                self.assertNotIn(" \n", content)


if __name__ == "__main__":
    unittest.main()
