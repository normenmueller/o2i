#!/usr/bin/env python3
"""Static tests for the lean GitHub-native governance contract."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AGENTS = ROOT / "AGENTS.md"
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
    AGENTS,
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
            AGENTS,
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

    def test_agents_facade_is_the_canonical_behavior_symlink(self) -> None:
        self.assertTrue(AGENTS.is_symlink())
        self.assertEqual(Path(".ai4x/BEHAVIOR.md"), AGENTS.readlink())
        self.assertEqual(BEHAVIOR.resolve(), AGENTS.resolve())

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

    def test_ready_issue_release_authority_reaches_in_review_and_stops(self) -> None:
        for path in (BEHAVIOR, GOVERNANCE):
            content = read(path)
            with self.subTest(path=path):
                for term in (
                    "explicit Product Owner release of one exact Issue in Project status `Ready`",
                    "within that Issue's accepted scope",
                    "carry it through `In review`",
                    "capability-matched specialist and Co-Author coordination",
                    "deterministic verification",
                    "independent review and corrections",
                    "commit, push, Pull Request publication",
                    "green required remote verification",
                    "evidence receipts",
                    "Project status `Ready` alone creates no authority",
                    "scope expansion",
                    "bypassing statement owners or required role separation",
                    "merge, Issue closure, Project `Done`",
                    "branch or worktree cleanup",
                    "release or tag, or protected publication",
                    "required machine identity is unavailable or unverified",
                ):
                    self.assertIn(term, content)

        human = read(CONTRIBUTING)
        for term in (
            "ausdrückliche PO-Freigabe eines exakten Issues im Project-Status `Ready`",
            "innerhalb seines akzeptierten Scopes standardmäßig bis `In review`",
            "Commit, Push, Pull Request",
            "Der bloße Status `Ready` genügt nicht",
            "Merge, Issue-Schließung, `Done`",
            "Branch- oder Worktree-Bereinigung",
            "geschützte Publikation",
            "verifizierte Machine-User-Identität",
        ):
            with self.subTest(surface="human", term=term):
                self.assertIn(term, human)

    def test_completed_issue_cleanup_is_mandatory_bounded_and_audited(self) -> None:
        governance = read(GOVERNANCE).split(
            "### Completed-Issue Cleanup Authority", 1
        )[1].split("## Epics, Stories, And Batches", 1)[0]
        behavior = "Explicit Product Owner authority" + read(BEHAVIOR).split(
            "Explicit Product Owner authority", 1
        )[1].split("`.ai4x/STATE.md`", 1)[0]
        for path, content in ((BEHAVIOR, behavior), (GOVERNANCE, governance)):
            with self.subTest(path=path):
                for term in (
                    "accepted",
                    "published",
                    "remote",
                    "closed",
                    "Project status `Done`",
                    "Product Owner authority for one exact Issue's completion actions",
                    "only the cleanup portion becomes executable",
                    "remove all no-longer-needed Issue-scoped local and remote working branches",
                    "linked worktrees",
                    "Issue-owned stashes",
                    "stale `.ai4x/local/ACTIVE.md` pointer",
                    "Issue-owned scratch artifacts",
                    "ordinary Ready-Issue release through `In review` never authorizes",
                    "durable on the owning published branch or intentionally obsolete",
                    "Immediately before each",
                    "re-resolve",
                    "stable identity plus any expected ref against the preflight",
                    "any mismatch stops cleanup",
                    "default or protected branch",
                    "active, review, unmerged, or recovery branch",
                    "active worktree",
                    "unique or user-owned",
                    "outside the completed Issue's scope",
                    "unresolved variable, glob, or recursive",
                    "verified machine identity",
                    "conditional operation bound to the expected ref",
                    "re-inventory local and remote",
                    "only within the same explicit authority",
                ):
                    self.assertIn(term, content)

        for term in (
            "completion actions remains effective according to its stated scope and conditions",
            "only the cleanup portion becomes executable after the Issue is accepted, published when publication is required, green at its required remote verification boundary, closed, and in Project status `Done`",
            "Cleanup is part of the authorized completion, not an optional chat convention",
            "one read-only preflight",
            "enumerates every exact candidate by stable identity and expected ref where applicable",
            "Immediately before each individual deletion",
            "Use scoped native Git operations",
            "never substitute a broad direct filesystem deletion",
            "Clear a stale active-checkout pointer before removing the exact worktree it names",
            "remove a linked worktree before its local branch",
            "remote branch deletion only through the verified machine identity and with a lease or equivalent conditional operation bound to the expected ref",
            "stops cleanup at the safe boundary",
            "every authorized target is absent and every protected or unrelated target remains",
        ):
            with self.subTest(surface="operational", term=term):
                self.assertIn(term, governance)

        self.assertIn(
            "completion actions applies according to its stated scope",
            behavior,
        )
        self.assertIn(
            "only the cleanup portion becomes executable after the Issue is accepted, published when required, remotely verified, closed, and in Project status `Done`",
            behavior,
        )
        self.assertIn(
            "Remote branch deletion additionally requires the verified machine identity and a lease or conditional operation bound to the expected ref",
            behavior,
        )

        human = read(CONTRIBUTING)
        for term in (
            "PO-Autorität für die Abschlussaktionen eines exakten Issues gilt nach ihrem genannten Scope und ihren Bedingungen",
            "nur dieser Bereinigungsanteil erst ausführbar",
            "muss dann sämtliche nicht mehr benötigten Issue-eigenen lokalen und Remote-Arbeitsbranches",
            "gewöhnliche Ready-Freigabe bis `In review` autorisiert sie nicht",
            "Unmittelbar vor jeder einzelnen Löschung",
            "stabile Identität sowie ein gegebenenfalls erwarteter Ref gegen den Vorabnachweis geprüft",
            "jede Abweichung stoppt die Bereinigung vor dieser Mutation",
            "Default-, geschützte, aktive, im Review befindliche, ungemergte",
            "einzigartigem oder nutzereigenem Inhalt bleiben unangetastet",
            "unaufgelöste Variablen, Globs und rekursive Dateisystemlöschungen sind ausgeschlossen",
            "Remote-Branch-Löschungen benötigen die verifizierte Machine-User-Identität",
            "an den erwarteten Ref gebundene bedingte Operation",
            "lokale und Remote-Bestände erneut inventarisiert",
            "nur innerhalb derselben Autorität korrigiert",
        ):
            with self.subTest(surface="human", term=term):
                self.assertIn(term, human)

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
        for path in (HASKELL_REVIEW, STRATEGY_REVIEW):
            with self.subTest(formal_review=path):
                self.assertNotIn("10/10", read(path))

    def test_ten_of_ten_is_only_product_owner_acceptance_shorthand(self) -> None:
        for path in (BEHAVIOR, GOVERNANCE):
            content = read(path)
            with self.subTest(path=path):
                for term in (
                    "`10/10` is Product Owner shorthand",
                    "all required formal verdicts being `accepted`",
                    "zero blocking or advisory findings",
                    "all exact-candidate local and remote checks being green",
                    "intact authorship-versus-review separation",
                    "never a formal review score",
                    "`accepted with follow-ups` does not satisfy it",
                ):
                    self.assertIn(term, content)

        human = read(CONTRIBUTING)
        for term in (
            "`10/10` ist ausschließlich die PO-Kurzform",
            "alle erforderlichen formalen Verdicts `accepted`",
            "weder blockierende noch beratende Findings offen",
            "Prüfungen des exakten Kandidaten grün",
            "Trennung von Autorschaft und Review gewahrt",
            "`accepted with follow-ups` erfüllt diese Kurzform nicht",
        ):
            with self.subTest(surface="human", term=term):
                self.assertIn(term, human)

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

    def test_local_active_checkout_pointer_is_optional_and_non_authoritative(self) -> None:
        behavior = read(BEHAVIOR)
        for term in (
            ".ai4x/local/ACTIVE.md",
            "non-symlink regular file",
            "Path: <relative-path>",
            "Expected branch: <branch>",
            "same common Git directory",
            "carries no authority",
            "Never checkout, reset, mutate, or select",
            "continue from the current checkout's tracked state",
            "fully operational without the pointer",
        ):
            with self.subTest(term=term):
                self.assertIn(term, behavior)
        self.assertIn(".ai4x/local/\n", read(GITIGNORE))

    def test_normal_session_continuity_is_prompt_free_and_durable(self) -> None:
        behavior = read(BEHAVIOR)
        for term in (
            "# Normal Session Continuity",
            "any ordinary greeting",
            "prompt carries no work state",
            "requires no path, digest, snapshot locator, or handoff payload",
            "durable repository-owned sources",
            "observed tracked Git branch, revision, and status",
            "GitHub Issue and Project facts",
            "Conversation transcripts, prior-session runtime context",
            "neither authority nor required continuity input",
            "missing, contradictory, or unverifiable",
            "ask the Product Owner instead of guessing",
            "exceptional recovery",
            "never routine startup",
        ):
            with self.subTest(term=term):
                self.assertIn(term, behavior)

    def test_routine_cold_start_completion_is_exact_and_safe(self) -> None:
        behavior = read(BEHAVIOR)
        completion = behavior.split("Only after the return point", 1)[1].split(
            "A long transport snapshot", 1
        )[0]
        self.assertEqual(
            [
                "1. Enter `/delete` and confirm.",
                "2. Start a fresh Codex CLI session without `resume` in this repository root.",
                "3. Say `Hi Gertrud, weiter geht’s!`.",
            ],
            re.findall(r"(?m)^[1-3]\. .+$", completion),
        )
        for term in (
            "durably materialized",
            "all required work and review activities are complete",
            "no delegated or background work remains",
            "exactly these three actionable steps",
            "wording of all three actions in the Product Owner's language",
            "keeping `/delete`, `resume`, and `Hi Gertrud, weiter geht’s!` literal",
            "repository root from the current checkout",
            "never place an absolute host path",
            "permanently removes the completed current session and its descendant sessions",
            "when transcript retention is required",
            "example greeting carries no state and may be replaced by any ordinary greeting",
            "routine transitions provide no path, digest, snapshot locator, or handoff payload",
        ):
            with self.subTest(term=term):
                self.assertIn(term, completion)
        self.assertNotIn("first two actions", completion)
        self.assertNotIn("`Approval:`", completion)
        self.assertNotRegex(completion, r"(?m)^4\. ")

    def test_product_owner_decision_handoff_is_deterministic(self) -> None:
        behavior = read(BEHAVIOR)
        decision = behavior.split("# Product Owner Decision Handoff\n", 1)[1].split(
            "\n# Referent Role", 1
        )[0]
        continuity_and_decision = behavior.split("# Normal Session Continuity\n", 1)[
            1
        ].split("\n# Referent Role", 1)[0]
        self.assertEqual(
            [
                "1. Enter `/delete` and confirm.",
                "2. Start a fresh Codex CLI session without `resume` in this repository root.",
                "3. Say `Hi Gertrud, weiter geht’s!`.",
            ],
            re.findall(r"(?m)^[1-9]\. .+$", continuity_and_decision),
        )
        self.assertNotRegex(decision, r"(?m)^[1-9]\. ")
        self.assertEqual(
            ["Recommendation:", "Alternatives:", "Cold start:", "Approval:"],
            re.findall(r"(?m)^- `([^`]+:)`", decision),
        )
        self.assertEqual(
            [
                "- `Approval:` the exact standalone Product Owner reply `Freigegeben.` for this recommendation."
            ],
            re.findall(r"(?m)^- `Approval:` .+$", decision),
        )
        recommendation = re.search(r"(?m)^- `Recommendation:` (.+)$", decision)
        self.assertIsNotNone(recommendation)
        assert recommendation is not None
        self.assertEqual(
            ["Subject", "Scope", "Target state", "Authority boundary", "Reason"],
            re.findall(
                r"`(Subject|Scope|Target state|Authority boundary|Reason)`",
                recommendation.group(1),
            ),
        )
        self.assertEqual(
            ["Requested agent authority:", "Exclusions:"],
            re.findall(
                r"`(Requested agent authority:|Exclusions:)`",
                recommendation.group(1),
            ),
        )
        self.assertEqual(
            {"recommended", "not recommended"},
            set(
                re.findall(r"`(recommended|not recommended)`", decision)
            ),
        )
        self.assertNotIn("`eligible but not recommended`", decision)
        self.assertNotIn("`ineligible`", decision)
        for term in (
            "completes an authorized work unit",
            "hands control back at a Product Owner decision or wait point",
            "Interim progress updates",
            "autonomous continuation within existing authority",
            "exactly one concrete next action",
            "exactly these labeled elements in order",
            "subject is unambiguous",
            "scope is bounded",
            "target state is observable",
            "one short evidence-based sentence",
            "exact newly requested agent authority or the literal `none`",
            "mandatory `Exclusions:` value in both cases",
            "write `none` when no such alternative exists",
            "never invent one for symmetry",
            "exactly one of `recommended` or `not recommended`",
            "every Normal Session Continuity safety gate",
            "`safety gate failed:`",
            "`eligible, but not the recommendation:`",
            "the exact standalone Product Owner reply `Freigegeben.`",
            "recommendation never creates authority",
            "never pauses autonomous work still covered by existing authority",
            "recommendation with `Approval:` requires the exact newly requested agent authority",
            "may not use `Requested agent authority: none`",
            "replace `Approval:` with `Product Owner action:`",
            "one exact, self-contained action with its subject, bounded scope, target state, and authority boundary",
            "that boundary must use `Requested agent authority: none`",
            "recommended cold start must also use `Requested agent authority: none`",
            "never invent agent authority",
            "exclusions remain mandatory for every recommendation",
            "observable single-use binding",
            "immediately preceding still-open decision handoff",
            "authorizes solely that handoff's single recommendation",
            "never authorizes an alternative or any omitted action",
            "consumed by one valid approval",
            "revalidates that exactly one such handoff exists",
            "immediately precedes the approval",
            "still matches current facts",
            "A missing handoff",
            "multiple candidate handoffs",
            "an already consumed handoff",
            "superseded by a later handoff or material new fact blocks execution",
            "requires a new decision handoff",
            "one non-authorizing `Approval bound:` receipt",
            "marks the handoff `consumed` before executing it",
            "binds the approval to this one bounded execution and prevents replay",
            "receipt makes that one-time binding observable but never broadens it",
            "exists only in the current live exchange",
            "never reconstructed from a conversation transcript or carried across a session boundary",
            "creates no binding for a `Product Owner action:` handoff or a recommended cold start",
            "only the three non-imperative decision metadata fields",
            "omit `Approval:` and `Product Owner action:`",
            "exactly the three numbered actions defined under Normal Session Continuity",
            "metadata contains no imperative",
            "no other imperative sentence or numbered transition instruction",
            "only transition instructions",
            "ends immediately after step 3 with no following text",
            "If `Cold start: not recommended`, do not print the three actions",
        ):
            with self.subTest(term=term):
                self.assertIn(term, decision)

        governance = read(GOVERNANCE)
        for term in (
            "follow the deterministic Product Owner Decision Handoff in `.ai4x/BEHAVIOR.md`",
            "presentation and authority-request contract",
            "not workflow state or authority",
            "never copied into `.ai4x/STATE.md`",
        ):
            with self.subTest(surface="governance", term=term):
                self.assertIn(term, governance)
        self.assertNotIn("# Product Owner Decision Handoff", read(STATE))

        human = read(CONTRIBUTING)
        self.assertNotIn("`eligible but not recommended`", human)
        self.assertNotIn("`ineligible`", human)
        for term in (
            "## PO-Entscheidungsvorlage",
            "genau einer konkreten Empfehlung",
            "exakten Gegenstand, begrenzten Scope, beobachtbaren Zielzustand",
            "exakt neu angefragte Agentenautorität oder das Literal `none`",
            "in beiden Fällen zwingend die Ausschlüsse",
            "durch `Freigegeben.` ausführbare Empfehlung muss die exakte neue Agentenautorität nennen",
            "darf `none` nicht verwenden",
            "direkte PO-Aktion und ein empfohlener Cold Start müssen `none` verwenden",
            "dürfen keine Agentenautorität erfinden",
            "kurzen evidenzbasierten Grund",
            "Zwischenstände, reine Antworten und autonomes Weiterarbeiten",
            "genau `recommended` oder `not recommended`",
            "fehlgeschlagenen Sicherheitsbedingung",
            "sicheren, aber gegenüber der Empfehlung nachrangigen Cold Start",
            "alleinstehende PO-Antwort",
            "`Freigegeben.` bindet genau einmal ausschließlich",
            "unmittelbar vorausgehenden, noch offenen Entscheidungsvorlage",
            "Zustand `consumed` sichtbar",
            "eine begrenzte Ausführung und verhindert ihre Wiederverwendung",
            "fehlende oder mehrdeutige Vorlage",
            "bereits verbrauchte Vorlage",
            "spätere Vorlage oder neue materielle Fakten überholte Vorlage blockieren",
            "nur im aktuellen laufenden Austausch",
            "weder aus einem Gesprächsprotokoll rekonstruiert noch über eine Session-Grenze getragen",
            "nicht imperative Entscheidungsmetadaten",
            "unveränderten drei nummerierten Aktionsschritte",
            "Weitere imperative Sätze oder nummerierte Übergangsanweisungen sind ausgeschlossen",
            "endet unmittelbar nach Schritt 3",
        ):
            with self.subTest(surface="human", term=term):
                self.assertIn(term, human)

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
                path_content = content.replace("`/delete`", "")
                self.assertIsNone(absolute_posix_path.search(path_content))
                self.assertIsNone(absolute_windows_path.search(content))
                self.assertIsNone(parent_traversal.search(content))
                for target in relative_link.findall(content):
                    resolved = (path.parent / target).resolve()
                    self.assertTrue(resolved.is_relative_to(root), target)

    def test_text_contracts_use_clean_files(self) -> None:
        for path in (
            AGENTS,
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
