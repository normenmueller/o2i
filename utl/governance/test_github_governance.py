#!/usr/bin/env python3
"""Structural tests for the executable O2I agent-governance contract."""

from __future__ import annotations

import copy
import itertools
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ai4x_contract as contract  # noqa: E402


ROOT = Path(__file__).resolve().parents[2]
AGENTS = ROOT / "AGENTS.md"
BEHAVIOR = ROOT / ".ai4x/BEHAVIOR.md"
CONTEXT = ROOT / ".ai4x/CONTEXT.md"
STATE = ROOT / ".ai4x/STATE.md"
HANDOFF = ROOT / ".ai4x/HANDOFF.md"
TEAM = ROOT / ".ai4x/TEAM.md"
POLICY = ROOT / ".ai4x/governance/policy.json"
AGENT_PROJECTION = ROOT / ".ai4x/governance/policy.agent.md"
GOVERNANCE = ROOT / ".ai4x/governance/guidelines.md"
DECISIONS = ROOT / ".ai4x/governance/decision-handoff.md"
CONTINUITY = ROOT / ".ai4x/governance/continuity.md"
CLEANUP = ROOT / ".ai4x/governance/cleanup.md"
CONTRIBUTING = ROOT / "CONTRIBUTING.md"
FRAMEWORK_FORM = ROOT / ".github/ISSUE_TEMPLATE/framework-change.yml"
MAINTENANCE_FORM = ROOT / ".github/ISSUE_TEMPLATE/maintenance.yml"
FORM_CONFIG = ROOT / ".github/ISSUE_TEMPLATE/config.yml"
SKILLS = tuple(sorted((ROOT / ".agents/skills").glob("*/SKILL.md")))
FACADES = tuple(sorted((ROOT / ".github/agents").glob("*.agent.md")))
OPERATIONS = tuple(sorted((ROOT / ".ai4x/operations").glob("*.md")))
PUBLIC_CONTRACTS = (
    AGENTS,
    BEHAVIOR,
    CONTEXT,
    STATE,
    HANDOFF,
    TEAM,
    POLICY,
    AGENT_PROJECTION,
    GOVERNANCE,
    DECISIONS,
    CONTINUITY,
    CLEANUP,
    CONTRIBUTING,
    *SKILLS,
    *FACADES,
    *OPERATIONS,
)


def read(path: Path) -> str:
    """Read one strict UTF-8 repository contract."""
    return path.read_text(encoding="utf-8", errors="strict")


def issue_form_fields(path: Path) -> dict[str, bool]:
    """Return Issue-form fields and whether each is required."""
    fields: dict[str, bool] = {}
    for block in re.split(r"(?m)^  - type: ", read(path))[1:]:
        identifier = re.search(r"(?m)^    id: ([a-z][a-z0-9_-]*)$", block)
        if identifier is not None:
            fields[identifier.group(1)] = bool(
                re.search(r"(?m)^ {6,}required: true$", block)
            )
    return fields


def policy_copy() -> dict[str, object]:
    """Return one mutable exact copy of the canonical policy."""
    return copy.deepcopy(dict(contract.load_policy()))


class PolicyShapeTests(unittest.TestCase):
    """Keep the canonical policy closed, linked, and projection-complete."""

    def test_required_surfaces_exist(self) -> None:
        for path in PUBLIC_CONTRACTS + (
            FRAMEWORK_FORM,
            MAINTENANCE_FORM,
            FORM_CONFIG,
            ROOT / "utl/governance/ai4x_contract.py",
        ):
            with self.subTest(path=path):
                self.assertTrue(path.is_file())

    def test_policy_is_strict_canonical_json(self) -> None:
        policy = contract.load_policy()
        self.assertEqual(contract.POLICY_SCHEMA, policy["schema"])
        self.assertEqual(POLICY.read_bytes(), contract.canonical_policy_bytes(policy))

    def test_duplicate_json_members_are_rejected_at_every_depth(self) -> None:
        fixtures = (
            b'{"schema":"a","schema":"b"}',
            b'{"outer":{"id":"a","id":"b"}}',
        )
        for source in fixtures:
            with self.subTest(source=source), self.assertRaises(contract.ContractError):
                contract.decode_json(source, origin="fixture")

    def test_policy_rejects_unknown_missing_and_reordered_members(self) -> None:
        mutations = []
        unknown = policy_copy()
        unknown["unknown"] = True
        mutations.append(unknown)
        missing = policy_copy()
        del missing["events"]
        mutations.append(missing)
        reordered = policy_copy()
        events = reordered.pop("events")
        reordered["events"] = events
        mutations.append(reordered)
        invalid_boolean = policy_copy()
        invalid_boolean["workflow"]["statusCreatesAuthority"] = "false"
        mutations.append(invalid_boolean)
        boolean_budget = policy_copy()
        boolean_budget["budgets"]["surfaces"][0]["wordCap"] = True
        mutations.append(boolean_budget)
        for value in mutations:
            with self.subTest(keys=tuple(value)), self.assertRaises(
                contract.ContractError
            ):
                contract._validate_policy_shape(value)

    def test_policy_rejects_every_material_v1_vocabulary_change(self) -> None:
        mutations = []
        for mutate in (
            lambda p: p["authorityGrant"].__setitem__("schema", "evil/v1"),
            lambda p: p["ruleOwners"][2].__setitem__("loadsWhen", "always"),
            lambda p: p["loadRoutes"].append(
                {
                    "from": "bootstrap",
                    "to": "return-point",
                    "justification": "bypass applicability",
                }
            ),
            lambda p: p["budgets"].__setitem__("wordDefinition", "anything"),
            lambda p: p["workflow"]["states"].append("Later"),
            lambda p: p["workflow"]["transitions"][0].__setitem__("to", "Done"),
            lambda p: p["actions"][0].__setitem__("id", "local.erase"),
            lambda p: p["mutationGates"]["gates"].__setitem__(0, "maybe-grant"),
            lambda p: p["events"]["authority_request"]["requiredFields"].__setitem__(0, "anything"),
            lambda p: p["authorityGrant"]["validityRules"].__setitem__(0, "anything"),
            lambda p: p["provenance"]["approvalNeverImplies"].remove("author"),
            lambda p: p["forbiddenActions"][0].__setitem__("when", "never"),
        ):
            policy = policy_copy()
            mutate(policy)
            mutations.append(policy)
        for index, value in enumerate(mutations):
            with self.subTest(index=index), self.assertRaises(contract.ContractError):
                contract._validate_policy_shape(value)

    def test_rule_owners_are_unique_and_load_routes_are_acyclic(self) -> None:
        policy = contract.load_policy()
        owners = policy["ruleOwners"]
        self.assertEqual(len(owners), len({item["id"] for item in owners}))
        self.assertEqual(len(owners), len({item["owner"] for item in owners}))
        contract.validate_owner_routes(policy)
        cyclic = policy_copy()
        cyclic["loadRoutes"].append(
            {
                "from": "return-point",
                "to": "applicability-envelope",
                "justification": "negative-cycle-fixture",
            }
        )
        with self.assertRaises(contract.ContractError):
            contract._validate_policy_shape(cyclic)

    def test_workflow_is_closed_and_ready_is_descriptive_only(self) -> None:
        policy = contract.load_policy()
        workflow = policy["workflow"]
        expected = {
            ("Backlog", "Refinement"),
            ("Refinement", "Ready"),
            ("Ready", "In progress"),
            ("In progress", "In review"),
            ("In progress", "Paused"),
            ("Paused", "Ready"),
            ("In review", "Done"),
        }
        observed = {(item["from"], item["to"]) for item in workflow["transitions"]}
        self.assertEqual(expected, observed)
        self.assertFalse(workflow["statusCreatesAuthority"])
        self.assertEqual("forbidden", workflow["unlistedTransition"])
        self.assertIn("descriptive execution readiness only", workflow["readySemantics"])
        for source, target in itertools.product(workflow["states"], repeat=2):
            with self.subTest(source=source, target=target):
                self.assertEqual(
                    (source, target) in expected,
                    contract.transition_allowed(policy, source, target),
                )

    def test_actions_forbidden_rules_and_grant_receipt_resolve(self) -> None:
        policy = contract.load_policy()
        actions = {item["id"] for item in policy["actions"]}
        self.assertEqual(len(actions), len(policy["actions"]))
        receipt = policy["authorityGrant"]["durableReceipt"]
        self.assertIn(receipt["action"], actions)
        self.assertTrue(receipt["mustBeFirstAuthorizedRemoteWrite"])
        self.assertTrue(receipt["sameSessionReadbackRequired"])
        self.assertTrue(
            receipt["crossSessionReconstruction"][
                "requiresExactlyOneReceiptForGrantId"
            ]
        )
        for rule in policy["forbiddenActions"]:
            with self.subTest(rule=rule["id"]):
                self.assertTrue(set(rule.get("actionIds", ())).issubset(actions))
        ordinary_boundary = next(
            rule
            for rule in policy["forbiddenActions"]
            if rule["id"] == "forbid-ordinary-execution-completion"
        )
        self.assertNotIn("project.transition", ordinary_boundary["actionIds"])
        self.assertTrue(
            {"pull-request.merge", "issue.close", "completed-work.cleanup"}.issubset(
                ordinary_boundary["actionIds"]
            )
        )

    def test_authority_grant_is_subject_bound_and_non_consuming(self) -> None:
        grant = contract.load_policy()["authorityGrant"]
        required = set(grant["requiredFields"])
        self.assertTrue(
            {
                "grantId",
                "subject.repository",
                "subject.issue",
                "decisionPayloadSha256",
                "expectedIssueBodySha256",
                "actionIds",
                "resourceIds",
                "scope",
                "targetState",
                "exclusions",
                "durableReceipt",
                "validity",
                "lifecycle",
            }.issubset(required)
        )
        self.assertTrue(grant["approvalConsumptionDoesNotConsumeGrant"])
        self.assertTrue(grant["issueBodyUnchangedByActivation"])
        self.assertEqual(
            {"active", "fulfilled", "revoked", "superseded", "invalidated"},
            set(grant["lifecycleStates"]),
        )

    def test_events_are_disjoint_and_only_authority_request_creates_grant(self) -> None:
        events = contract.load_policy()["events"]
        self.assertEqual(
            {"authority_request", "product_owner_action", "cold_start"},
            set(events),
        )
        self.assertTrue(events["authority_request"]["createsGrant"])
        self.assertEqual(
            "Freigegeben.", events["authority_request"]["approvalReply"]
        )
        for name in ("product_owner_action", "cold_start"):
            with self.subTest(event=name):
                self.assertFalse(events[name]["createsGrant"])
                self.assertEqual("none", events[name]["requestedAgentAuthorityMustEqual"])
                self.assertIn("approvalReply", events[name]["forbiddenFields"])

    def test_provenance_never_infers_identity_from_approval(self) -> None:
        provenance = contract.load_policy()["provenance"]
        self.assertEqual(
            {
                "product-owner-decision-authority",
                "actual-content-authorship",
                "git-commit-object-creator",
                "verified-remote-publisher-identity",
            },
            set(provenance["independentFacts"]),
        )
        approval = next(
            row
            for row in provenance["matrix"]
            if row["case"] == "product-owner-approval"
        )
        self.assertEqual("Product Owner", approval["decisionAuthority"])
        self.assertEqual("no-inference", approval["contentAuthor"])
        self.assertEqual("no-inference", approval["commitActor"])
        self.assertEqual("no-inference", approval["remotePublisher"])
        self.assertEqual(
            {"author", "co-author", "committer", "publisher"},
            set(provenance["approvalNeverImplies"]),
        )

    def test_generated_projections_are_byte_exact_and_identifier_complete(self) -> None:
        policy = contract.load_policy()
        contract.validate_projections(policy)
        projection = read(AGENT_PROJECTION)
        identifiers = (
            [item["id"] for item in policy["ruleOwners"]]
            + [item["id"] for item in policy["workflow"]["transitions"]]
            + [item["id"] for item in policy["actions"]]
            + list(policy["events"])
            + [item["id"] for item in policy["forbiddenActions"]]
        )
        for identifier in identifiers:
            with self.subTest(identifier=identifier):
                self.assertIn(f"`{identifier}`", projection)


class StateAndBudgetTests(unittest.TestCase):
    """Keep startup bounded and handoff loading observably fail-closed."""

    def test_state_is_exact_bounded_envelope(self) -> None:
        state = contract.read_state_envelope()
        self.assertEqual(contract.STATE_SCHEMA, state["schema"])
        self.assertEqual(contract.HANDOFF_SCHEMA, state["handoffSchema"])
        self.assertLessEqual(len(STATE.read_bytes()), 1024)

    def test_state_rejects_noncanonical_or_unbounded_fixtures(self) -> None:
        canonical = STATE.read_bytes()
        fixtures = (
            canonical.replace(b'"schema"', b'"unknown"', 1),
            canonical.replace(b'","appliesOnBranch"', b', "appliesOnBranch"', 1),
            canonical.replace(b"\n", b"\r\n", 1),
            canonical + b"extra\n",
            canonical + b"x" * 1024,
        )
        for index, source in enumerate(fixtures):
            with tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "STATE.md"
                path.write_bytes(source)
                with self.subTest(fixture=index), self.assertRaises(
                    contract.ContractError
                ):
                    contract.read_state_envelope(path)

    def test_applicability_ladder_is_exhaustive_for_material_cases(self) -> None:
        evidence = contract.ApplicabilityEvidence
        cases = (
            (evidence("absent", True, "feat/1", True, "feat/1"), "applicable"),
            (evidence("absent", True, "feat/1", False, "feat/1"), "applicable"),
            (
                evidence("activated_restart", True, "feat/1", True, "feat/1"),
                "applicable",
            ),
            (evidence("unresolved", True, "feat/1", True, "feat/1"), "UNVERIFIED"),
            (evidence("absent", False, None, True, "feat/1"), "UNVERIFIED"),
            (evidence("absent", True, None, True, "feat/1"), "UNVERIFIED"),
            (evidence("absent", True, "trunk", True, "feat/1"), "dormant"),
            (evidence("absent", True, "trunk", False, "feat/1"), "UNVERIFIED"),
            (
                evidence("activated_restart", True, "trunk", True, "feat/1"),
                "UNVERIFIED",
            ),
            (evidence("absent", True, "feat/2", True, "feat/1"), "UNVERIFIED"),
        )
        for value, expected in cases:
            with self.subTest(value=value):
                self.assertEqual(expected, contract.classify_applicability(value))

    def test_handoff_loader_is_never_called_for_dormant_or_unverified(self) -> None:
        for classification in ("dormant", "UNVERIFIED"):
            loader = mock.Mock(return_value="forbidden")
            with self.subTest(classification=classification):
                self.assertIsNone(
                    contract.load_handoff_if_applicable(classification, loader)
                )
                loader.assert_not_called()
        loader = mock.Mock(return_value="handoff")
        self.assertEqual(
            "handoff", contract.load_handoff_if_applicable("applicable", loader)
        )
        loader.assert_called_once_with()

    def test_bootstrap_reads_handoff_only_after_actual_applicability(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = root / "STATE.md"
            handoff = root / "HANDOFF.md"
            pointer = root / "ACTIVE.md"
            state.write_bytes(STATE.read_bytes())
            handoff.write_bytes(HANDOFF.read_bytes())
            branch = contract.read_state_envelope(state)["appliesOnBranch"]
            applicable = contract.bootstrap_checkout(
                pointer_path=pointer,
                state_path=state,
                handoff_path=handoff,
                git_metadata=True,
                observed_branch=branch,
                clean=False,
                activate_pointer=mock.Mock(),
            )
            self.assertEqual("applicable", applicable.classification)
            self.assertEqual(contract.HANDOFF_SCHEMA, applicable.handoff["schema"])
            with mock.patch.object(contract, "read_handoff") as loader:
                dormant = contract.bootstrap_checkout(
                    pointer_path=pointer,
                    state_path=state,
                    handoff_path=handoff,
                    git_metadata=True,
                    observed_branch="trunk",
                    clean=True,
                    activate_pointer=mock.Mock(),
                )
                detached = contract.bootstrap_checkout(
                    pointer_path=pointer,
                    state_path=state,
                    handoff_path=handoff,
                    git_metadata=True,
                    observed_branch=None,
                    clean=True,
                    activate_pointer=mock.Mock(),
                )
            self.assertEqual("dormant", dormant.classification)
            self.assertEqual("UNVERIFIED", detached.classification)
            loader.assert_not_called()

    def test_bootstrap_rejects_pointer_and_handoff_uncertainty(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = root / "STATE.md"
            handoff = root / "HANDOFF.md"
            pointer = root / "ACTIVE.md"
            state.write_bytes(STATE.read_bytes())
            handoff.write_bytes(HANDOFF.read_bytes())
            branch = contract.read_state_envelope(state)["appliesOnBranch"]
            for source in (
                "bad\n",
                "Path: ../escape\nExpected branch: feat/1\n",
                "Path: checkout\nExpected branch: bad branch\n",
            ):
                pointer.write_text(source, encoding="utf-8")
                with self.subTest(source=source):
                    result = contract.bootstrap_checkout(
                        pointer_path=pointer,
                        state_path=state,
                        handoff_path=handoff,
                        git_metadata=True,
                        observed_branch=branch,
                        clean=True,
                        activate_pointer=mock.Mock(return_value=True),
                    )
                    self.assertEqual("UNVERIFIED", result.classification)
                    self.assertIsNone(result.handoff)
            pointer.write_text(
                "Path: checkout\nExpected branch: feat/1\n", encoding="utf-8"
            )
            stale = contract.bootstrap_checkout(
                pointer_path=pointer,
                state_path=state,
                handoff_path=handoff,
                git_metadata=True,
                observed_branch=branch,
                clean=True,
                activate_pointer=mock.Mock(return_value=False),
            )
            self.assertEqual("UNVERIFIED", stale.classification)
            activated = contract.bootstrap_checkout(
                pointer_path=pointer,
                state_path=state,
                handoff_path=handoff,
                git_metadata=True,
                observed_branch=branch,
                clean=True,
                activate_pointer=mock.Mock(return_value=True),
            )
            self.assertTrue(activated.restart_required)
            self.assertIsNone(activated.handoff)
            pointer.unlink()
            target = root / "pointer-target"
            target.write_text(
                "Path: checkout\nExpected branch: feat/1\n", encoding="utf-8"
            )
            pointer.symlink_to(target.name)
            symlinked = contract.bootstrap_checkout(
                pointer_path=pointer,
                state_path=state,
                handoff_path=handoff,
                git_metadata=True,
                observed_branch=branch,
                clean=True,
                activate_pointer=mock.Mock(return_value=True),
            )
            self.assertEqual("UNVERIFIED", symlinked.classification)
            pointer.unlink()
            handoff.write_text("malformed\n", encoding="utf-8")
            invalid_handoff = contract.bootstrap_checkout(
                pointer_path=pointer,
                state_path=state,
                handoff_path=handoff,
                git_metadata=True,
                observed_branch=branch,
                clean=True,
                activate_pointer=mock.Mock(),
            )
            self.assertEqual("UNVERIFIED", invalid_handoff.classification)
            self.assertIsNone(invalid_handoff.handoff)

    def test_active_pointer_read_is_bounded_before_overflow_rejection(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "ACTIVE.md"
            path.write_text("placeholder\n", encoding="utf-8")
            context = mock.MagicMock()
            context.__enter__.return_value.read.return_value = b"x" * 1025
            with mock.patch.object(Path, "open", return_value=context) as opened:
                with self.assertRaises(contract.ContractError):
                    contract.read_active_pointer(path)
            opened.assert_called_once_with("rb")
            context.__enter__.return_value.read.assert_called_once_with(1025)

    def test_symlink_resolution_is_direct_contained_and_deduplicated(self) -> None:
        self.assertTrue(AGENTS.is_symlink())
        unit = contract.worktree_source("AGENTS.md")
        self.assertEqual(".ai4x/BEHAVIOR.md", unit.canonical_path)
        self.assertEqual(BEHAVIOR.read_bytes(), unit.source)
        revision_unit = contract.revision_source("HEAD", "AGENTS.md")
        self.assertEqual(".ai4x/BEHAVIOR.md", revision_unit.canonical_path)
        for target in ("/tmp/file", "../../escape", ""):
            with self.subTest(target=target), self.assertRaises(contract.ContractError):
                contract._canonical_link_target("AGENTS.md", target)

    def test_recursive_glob_matches_zero_or_more_path_components(self) -> None:
        pattern = ".ai4x/**/*"
        for path in (
            ".ai4x/BEHAVIOR.md",
            ".ai4x/governance/policy.json",
            ".ai4x/operations/haskell-authoring.md",
        ):
            with self.subTest(path=path):
                self.assertTrue(contract._path_matches(path, pattern))
        self.assertFalse(contract._path_matches("README.md", pattern))

    def test_complete_ai4x_budget_inventory_equals_every_tracked_source(self) -> None:
        policy = contract.load_policy()
        surfaces = {
            item["id"]: item for item in policy["budgets"]["surfaces"]
        }
        units = contract._surface_units(
            surfaces["complete-ai4x-tree"],
            surfaces,
            revision=None,
        )
        result = subprocess.run(
            ["git", "ls-files", "-z", "--", ".ai4x"],
            cwd=ROOT,
            check=True,
            capture_output=True,
        )
        requested = {
            value.decode("utf-8")
            for value in result.stdout.split(b"\0")
            if value
        }
        expected = {
            contract.worktree_source(path).canonical_path for path in requested
        }
        self.assertEqual(expected, {unit.canonical_path for unit in units})

    def test_named_tree_inventory_is_nul_delimited_and_utf8_exact(self) -> None:
        output = b".ai4x/line\nbreak.md\0.ai4x/gr\xc3\xbc\xc3\x9fe.md\0README.md\0"
        completed = subprocess.CompletedProcess(
            args=(), returncode=0, stdout=output, stderr=b""
        )
        with mock.patch.object(contract, "_git", return_value=completed) as git:
            self.assertEqual(
                (".ai4x/gr\u00fc\u00dfe.md", ".ai4x/line\nbreak.md"),
                contract._glob_paths(".ai4x/**/*", (), revision="tree-id"),
            )
        git.assert_called_once_with(
            "ls-tree", "-rz", "--name-only", "--full-tree", "tree-id"
        )

    def test_exact_policy_budgets_and_current_counts_pass(self) -> None:
        policy = contract.load_policy()
        expected = {
            "behavior-kernel": (1000, 8000),
            "state-header": (80, 1024),
            "mandatory-bootstrap-union": (1080, 9024),
            "context": (600, 5000),
            "team": (500, 4200),
            "applicable-handoff": (600, 5000),
            "pre-task-union": (2780, 23224),
            "canonical-policy": (3000, 32000),
            "generated-governance-route": (800, 6500),
            "hand-authored-governance-contract": (1200, 10000),
            "operation-contract": (1200, 10000),
            "repository-skill-router": (180, 1500),
            "github-agent-facade": (120, 1000),
            "contributing-governance-block": (1000, 8000),
            "complete-ai4x-tree": (12000, 96000),
        }
        observed = {
            item["id"]: (item["wordCap"], item["byteCap"])
            for item in policy["budgets"]["surfaces"]
        }
        self.assertEqual(expected, observed)
        counts = contract.validate_budgets(policy)
        self.assertEqual(set(expected), set(counts))

    def test_budget_overflow_is_rejected(self) -> None:
        policy = policy_copy()
        surface = next(
            item
            for item in policy["budgets"]["surfaces"]
            if item["id"] == "behavior-kernel"
        )
        surface["wordCap"] = 1
        with self.assertRaises(contract.ContractError):
            contract.validate_budgets(policy)


class DecisionAndMutationTests(unittest.TestCase):
    """Exercise closed mutation, approval, and cleanup predicates."""

    def test_mutation_requires_every_gate_and_enumerated_transition(self) -> None:
        policy = contract.load_policy()
        names = tuple(policy["mutationGates"]["gates"])
        passing = {name: True for name in names}
        self.assertTrue(
            contract.mutation_allowed(
                policy,
                action_id="project.transition",
                gate_evidence=passing,
                transition=("In progress", "In review"),
            )
        )
        for name in names:
            for missing in (False, None):
                values = dict(passing)
                values[name] = missing
                with self.subTest(gate=name, value=missing):
                    self.assertFalse(
                        contract.mutation_allowed(
                            policy,
                            action_id="project.transition",
                            gate_evidence=values,
                            transition=("In progress", "In review"),
                        )
                    )
        self.assertFalse(
            contract.mutation_allowed(
                policy,
                action_id="project.transition",
                gate_evidence=passing,
                transition=("Ready", "Done"),
            )
        )

    def test_ready_without_matching_grant_denies_execution(self) -> None:
        policy = contract.load_policy()
        evidence = {name: True for name in policy["mutationGates"]["gates"]}
        evidence["current-matching-subject-grant"] = False
        self.assertFalse(
            contract.mutation_allowed(
                policy,
                action_id="local.write",
                gate_evidence=evidence,
            )
        )

    def test_exact_adjacent_unused_reply_binds_once(self) -> None:
        policy = contract.load_policy()
        guards = tuple(policy["events"]["authority_request"]["bindingRequires"])
        passing = {name: True for name in guards}
        self.assertTrue(
            contract.authority_reply_binds(
                policy,
                event_type="authority_request",
                reply="Freigegeben.",
                binding_evidence=passing,
            )
        )
        for name in guards:
            values = dict(passing)
            values[name] = False
            with self.subTest(guard=name):
                self.assertFalse(
                    contract.authority_reply_binds(
                        policy,
                        event_type="authority_request",
                        reply="Freigegeben.",
                        binding_evidence=values,
                    )
                )

    def test_wrong_event_reply_and_replay_never_bind(self) -> None:
        policy = contract.load_policy()
        guards = tuple(policy["events"]["authority_request"]["bindingRequires"])
        evidence = {name: True for name in guards}
        for event in ("product_owner_action", "cold_start"):
            with self.subTest(event=event):
                self.assertFalse(
                    contract.authority_reply_binds(
                        policy,
                        event_type=event,
                        reply="Freigegeben.",
                        binding_evidence=evidence,
                    )
                )
        for reply in ("freigegeben.", "Freigegeben", " Freigegeben."):
            with self.subTest(reply=reply):
                self.assertFalse(
                    contract.authority_reply_binds(
                        policy,
                        event_type="authority_request",
                        reply=reply,
                        binding_evidence=evidence,
                    )
                )

    def test_forbidden_actions_and_grant_instances_are_policy_driven(self) -> None:
        policy = contract.load_policy()
        condition = "grant-target-ends-at-In-review"
        self.assertTrue(
            contract.action_forbidden(policy, "issue.close", (condition,))
        )
        self.assertFalse(
            contract.action_forbidden(policy, "project.transition", (condition,))
        )
        required = policy["authorityGrant"]["requiredFields"]
        grant = dict.fromkeys(required)
        grant.update(
            {
                "grantId": "grant-1",
                "issuer": "Product Owner",
                "subject.repository": "o2i",
                "subject.issue": "#103",
                "decisionPayloadSha256": "a" * 64,
                "expectedIssueBodySha256": "b" * 64,
                "actionIds": ["local.write", "project.transition"],
                "resourceIds": ["issue:#103"],
                "scope": "Issue #103",
                "targetState": "In review",
                "exclusions": ["merge"],
                "durableReceipt": "comment:1",
                "validity": {
                    name: True
                    for name in policy["authorityGrant"]["validityRules"]
                },
                "lifecycle": "active",
            }
        )
        expected = {name: copy.deepcopy(grant[name]) for name in required[:-2]}
        evidence = copy.deepcopy(grant["validity"])
        self.assertTrue(
            contract.grant_instance_valid(
                policy,
                grant,
                action_id="local.write",
                resource_id="issue:#103",
                expected_binding=expected,
                validity_evidence=evidence,
                current_lifecycle="active",
            )
        )
        for field, value in (
            ("lifecycle", "fulfilled"),
            ("decisionPayloadSha256", "bad"),
            ("actionIds", ["unknown.action"]),
        ):
            invalid = copy.deepcopy(grant)
            invalid[field] = value
            with self.subTest(field=field):
                self.assertFalse(
                    contract.grant_instance_valid(
                        policy,
                        invalid,
                        action_id="local.write",
                        resource_id="issue:#103",
                        expected_binding=expected,
                        validity_evidence=evidence,
                        current_lifecycle="active",
                    )
                )
        forged = copy.deepcopy(grant)
        forged.update(
            {
                "issuer": "Mallory",
                "subject.repository": "foreign",
                "subject.issue": "#999",
                "scope": "everything",
                "targetState": "Done",
                "durableReceipt": "unverified-comment",
            }
        )
        self.assertFalse(
            contract.grant_instance_valid(
                policy,
                forged,
                action_id="local.write",
                resource_id="issue:#103",
                expected_binding=expected,
                validity_evidence=evidence,
                current_lifecycle="active",
            )
        )
        receipt_unknown = copy.deepcopy(evidence)
        receipt_unknown[
            "durable-receipt-is-currently-verifiable-after-session-boundary"
        ] = None
        self.assertFalse(
            contract.grant_instance_valid(
                policy,
                grant,
                action_id="local.write",
                resource_id="issue:#103",
                expected_binding=expected,
                validity_evidence=receipt_unknown,
                current_lifecycle="active",
            )
        )

    def test_cleanup_requires_every_completion_and_safety_fact(self) -> None:
        names = (
            "issue_accepted",
            "publication_complete",
            "remote_checks_green",
            "issue_closed",
            "project_done",
            "cleanup_grant",
            "durability_proven",
            "target_identity_stable",
            "required_identity_verified",
            "technical_permission",
        )
        passing = {name: True for name in names}
        self.assertTrue(contract.cleanup_allowed(**passing))
        for name in names:
            values = dict(passing)
            values[name] = False
            with self.subTest(fact=name):
                self.assertFalse(contract.cleanup_allowed(**values))


class RepositorySurfaceTests(unittest.TestCase):
    """Keep repository routing, intake, autonomy, and text hygiene aligned."""

    def test_handoff_contains_only_the_branch_return_point(self) -> None:
        content = read(HANDOFF)
        self.assertEqual(contract.HANDOFF_SCHEMA, contract.read_handoff()["schema"])
        for heading in (
            "# Objective",
            "# Authority",
            "# Current Facts",
            "# Material Risk",
            "# Verification",
            "# Next Action",
            "# Local Return Point",
        ):
            with self.subTest(heading=heading):
                self.assertIn(heading, content)
        self.assertNotRegex(content, r"(?i)(session[_ -]?id|conversation transcript)")

    def test_issue_forms_remain_focused_and_blank_issues_are_disabled(self) -> None:
        framework = issue_form_fields(FRAMEWORK_FORM)
        maintenance = issue_form_fields(MAINTENANCE_FORM)
        required_framework = {
            "change_path",
            "problem",
            "benefit",
            "target",
            "scope",
            "acceptance",
            "risks",
        }
        self.assertTrue(required_framework.issubset(framework))
        self.assertTrue(all(framework[field] for field in required_framework))
        self.assertTrue(
            all(
                not framework[field]
                for field in ("alternatives", "participants", "reviews")
            )
        )
        self.assertTrue(
            {"problem", "target", "scope", "acceptance", "semantics"}.issubset(
                maintenance
            )
        )
        self.assertTrue(all(maintenance.values()))
        self.assertEqual("blank_issues_enabled: false\n", read(FORM_CONFIG))

    def test_skills_and_facades_are_bounded_routes(self) -> None:
        self.assertTrue(SKILLS)
        self.assertTrue(FACADES)
        for path in SKILLS:
            words, octets = contract.source_measure(path.read_bytes(), origin=str(path))
            with self.subTest(skill=path):
                self.assertLessEqual(words, 180)
                self.assertLessEqual(octets, 1500)
                self.assertIn(".ai4x/TEAM.md", read(path))
        for path in FACADES:
            words, octets = contract.source_measure(path.read_bytes(), origin=str(path))
            with self.subTest(facade=path):
                self.assertLessEqual(words, 120)
                self.assertLessEqual(octets, 1000)

    def test_local_staging_is_ignored(self) -> None:
        result = subprocess.run(
            ["git", "check-ignore", "-q", ".ai4x/local/probe"],
            cwd=ROOT,
            check=False,
        )
        self.assertEqual(0, result.returncode)

    def test_public_contracts_are_repository_autonomous(self) -> None:
        absolute_posix = re.compile(
            r"(?:^|[\s`(])/(?:Users|home|private|var|tmp)/", re.MULTILINE
        )
        absolute_windows = re.compile(r"\b[A-Za-z]:[\\/]")
        relative_link = re.compile(r"\]\((?!https?://|#)([^)#]+)")
        for path in PUBLIC_CONTRACTS:
            content = read(path)
            without_literal_delete = content.replace("`/delete`", "")
            with self.subTest(path=path):
                self.assertIsNone(absolute_posix.search(without_literal_delete))
                self.assertIsNone(absolute_windows.search(content))
                for target in relative_link.findall(content):
                    resolved = (path.parent / target).resolve()
                    self.assertTrue(resolved.is_relative_to(ROOT.resolve()), target)
                    self.assertTrue(resolved.is_file(), target)

    def test_text_contracts_are_clean_utf8_files(self) -> None:
        for path in PUBLIC_CONTRACTS + (
            FRAMEWORK_FORM,
            MAINTENANCE_FORM,
            FORM_CONFIG,
        ):
            content = read(path)
            with self.subTest(path=path):
                self.assertTrue(content.endswith("\n"))
                self.assertNotIn("\t", content)
                self.assertNotIn(" \n", content)


if __name__ == "__main__":
    unittest.main()
