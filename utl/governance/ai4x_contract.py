#!/usr/bin/env python3
"""Validate and project the structured O2I agent-governance contract."""

from __future__ import annotations

import argparse
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass
from fnmatch import fnmatchcase
from functools import lru_cache
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import posixpath
import re
import subprocess
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
POLICY_PATH = ROOT / ".ai4x/governance/policy.json"
STATE_PATH = ROOT / ".ai4x/STATE.md"
HANDOFF_PATH = ROOT / ".ai4x/HANDOFF.md"
AGENT_PROJECTION_PATH = ROOT / ".ai4x/governance/policy.agent.md"
CONTRIBUTING_PATH = ROOT / "CONTRIBUTING.md"
DECISION_PATH = ROOT / ".ai4x/governance/decision-handoff.md"
POLICY_SCHEMA = "o2i.ai4x-governance-policy/v1"
STATE_SCHEMA = "o2i.state-envelope/v1"
HANDOFF_SCHEMA = "o2i.handoff/v1"
STATE_OPEN = "<!-- o2i-state-envelope-v1 -->"
STATE_CLOSE = "<!-- /o2i-state-envelope-v1 -->"
HANDOFF_OPEN = "<!-- o2i-handoff-envelope-v1 -->"
HANDOFF_CLOSE = "<!-- /o2i-handoff-envelope-v1 -->"
CONTRIBUTING_OPEN = "<!-- BEGIN GENERATED: ai4x-governance -->"
CONTRIBUTING_CLOSE = "<!-- END GENERATED: ai4x-governance -->"
DECISION_OPEN = "<!-- BEGIN GENERATED: ai4x-event-schemas -->"
DECISION_CLOSE = "<!-- END GENERATED: ai4x-event-schemas -->"


class ContractError(ValueError):
    """The repository governance contract is malformed or inconsistent."""


def _object_without_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ContractError(f"duplicate JSON member: {key}")
        result[key] = value
    return result


def _reject_constant(value: str) -> None:
    raise ContractError(f"non-finite JSON number: {value}")


def decode_json(source: bytes, *, origin: str) -> Any:
    """Decode strict UTF-8 JSON while rejecting duplicate members."""
    if source.startswith(b"\xef\xbb\xbf"):
        raise ContractError(f"{origin}: UTF-8 BOM is forbidden")
    try:
        text = source.decode("utf-8", errors="strict")
        return json.loads(
            text,
            object_pairs_hook=_object_without_duplicates,
            parse_constant=_reject_constant,
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ContractError(f"{origin}: invalid strict JSON: {error}") from error


def canonical_policy_bytes(value: Any) -> bytes:
    """Serialize policy JSON with the normative repository encoding."""
    return (
        json.dumps(value, ensure_ascii=False, allow_nan=False, indent=2) + "\n"
    ).encode("utf-8")


def canonical_state_object(value: Any) -> str:
    """Serialize the compact State object with no optional whitespace."""
    return json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        separators=(",", ":"),
    )


def _require_mapping(value: Any, where: str) -> Mapping[str, Any]:
    if not isinstance(value, dict):
        raise ContractError(f"{where}: expected object")
    return value


def _require_sequence(value: Any, where: str) -> Sequence[Any]:
    if not isinstance(value, list):
        raise ContractError(f"{where}: expected array")
    return value


def _require_string(value: Any, where: str) -> str:
    if not isinstance(value, str) or not value:
        raise ContractError(f"{where}: expected non-empty string")
    return value


def _require_bool(value: Any, where: str) -> bool:
    if type(value) is not bool:
        raise ContractError(f"{where}: expected boolean")
    return value


def _require_keys(
    value: Any, expected: Sequence[str], where: str
) -> Mapping[str, Any]:
    obj = _require_mapping(value, where)
    actual = tuple(obj)
    if actual != tuple(expected):
        raise ContractError(
            f"{where}: expected ordered keys {tuple(expected)!r}, found {actual!r}"
        )
    return obj


def _unique_strings(values: Any, where: str) -> tuple[str, ...]:
    items = _require_sequence(values, where)
    if not all(isinstance(item, str) and item for item in items):
        raise ContractError(f"{where}: expected non-empty strings")
    result = tuple(items)
    if len(set(result)) != len(result):
        raise ContractError(f"{where}: duplicate value")
    return result


def _validate_policy_shape(policy: Any) -> Mapping[str, Any]:
    top = _require_keys(
        policy,
        (
            "schema",
            "ruleOwners",
            "loadRoutes",
            "budgets",
            "workflow",
            "actions",
            "authorityGrant",
            "mutationGates",
            "continuity",
            "events",
            "provenance",
            "forbiddenActions",
        ),
        "policy",
    )
    if top["schema"] != POLICY_SCHEMA:
        raise ContractError(f"policy: unsupported schema {top['schema']!r}")

    owners = _require_sequence(top["ruleOwners"], "policy.ruleOwners")
    owner_ids: list[str] = []
    owner_paths: list[str] = []
    owner_rows: list[tuple[str, str, str, str]] = []
    for index, value in enumerate(owners):
        owner = _require_keys(
            value,
            ("id", "owner", "loadsWhen", "scope"),
            f"policy.ruleOwners[{index}]",
        )
        owner_ids.append(_require_string(owner["id"], f"policy.ruleOwners[{index}].id"))
        owner_paths.append(
            _require_string(owner["owner"], f"policy.ruleOwners[{index}].owner")
        )
        _require_string(owner["loadsWhen"], f"policy.ruleOwners[{index}].loadsWhen")
        _require_string(owner["scope"], f"policy.ruleOwners[{index}].scope")
        owner_rows.append(tuple(owner.values()))
    if len(set(owner_ids)) != len(owner_ids):
        raise ContractError("policy.ruleOwners: duplicate rule id")
    if len(set(owner_paths)) != len(owner_paths):
        raise ContractError("policy.ruleOwners: one file owns multiple rule classes")
    if tuple(owner_rows) != (
        ("bootstrap", ".ai4x/BEHAVIOR.md", "always", "precedence, bounded startup, active-checkout pointer validation, handoff applicability, repository isolation, routing, and universal fail-closed safety"),
        ("applicability-envelope", ".ai4x/STATE.md", "bootstrap", "one bounded closed header and no handoff body"),
        ("return-point", ".ai4x/HANDOFF.md", "handoff-applicable", "branch-bound local return point"),
        ("repository-context", ".ai4x/CONTEXT.md", "repository-context-required-after-checkout-selection", "stable identity, statement-class ownership, retrieval links, and durable product invariants"),
        ("capability-routing", ".ai4x/TEAM.md", "collaboration-or-review-required", "capability routing and authorship-versus-review separation"),
        ("executable-governance", ".ai4x/governance/policy.json", "deterministic-evaluation-before-authority-decision-or-mutation", "workflow transitions, actions, grants, mutation gates, events, provenance, rule registry, and budgets"),
        ("governance-practice", ".ai4x/governance/guidelines.md", "risk-classification-issue-project-review-or-remote-work", "risk paths, Issue and Project ownership, reviews, and remote-work rules"),
        ("decision-rendering", ".ai4x/governance/decision-handoff.md", "product-owner-decision-or-control-handoff", "event rendering and live approval binding"),
        ("session-continuity", ".ai4x/governance/continuity.md", "applicable-handoff-reconstruction-or-cold-start-evaluation", "post-classification reconstruction and cold-start eligibility"),
        ("completed-work-cleanup", ".ai4x/governance/cleanup.md", "explicit-completion-and-cleanup-grant", "cleanup preflight, destructive-action safeguards, deletion ordering, and postflight"),
        ("task-contracts", ".ai4x/operations/*.md", "matching-task-class", "task-class-specific design, implementation, and quality rules"),
    ):
        raise ContractError("policy.ruleOwners: unsupported v1 owner registry")

    routes = _require_sequence(top["loadRoutes"], "policy.loadRoutes")
    edges: list[tuple[str, str]] = []
    for index, value in enumerate(routes):
        route = _require_keys(
            value,
            ("from", "to", "justification"),
            f"policy.loadRoutes[{index}]",
        )
        edge = (
            _require_string(route["from"], f"policy.loadRoutes[{index}].from"),
            _require_string(route["to"], f"policy.loadRoutes[{index}].to"),
        )
        _require_string(
            route["justification"], f"policy.loadRoutes[{index}].justification"
        )
        if any(node not in owner_ids for node in edge):
            raise ContractError(f"policy.loadRoutes[{index}]: unknown rule id")
        edges.append(edge)
    if len(set(edges)) != len(edges):
        raise ContractError("policy.loadRoutes: duplicate route")
    if tuple(tuple(route.values()) for route in routes) != (
        ("bootstrap", "applicability-envelope", "classify the branch-bound handoff from a bounded header"),
        ("applicability-envelope", "return-point", "load only after an applicable result"),
        ("bootstrap", "repository-context", "retrieve stable repository context after checkout selection when required"),
        ("bootstrap", "capability-routing", "select roles when collaboration or review is required"),
        ("bootstrap", "governance-practice", "route governance work to its canonical practice contract"),
        ("governance-practice", "executable-governance", "evaluate authority decisions and mutations deterministically"),
        ("governance-practice", "decision-rendering", "render a Product Owner decision or control handoff"),
        ("applicability-envelope", "session-continuity", "reconstruct only after applicability classification"),
        ("governance-practice", "completed-work-cleanup", "perform cleanup only under its dedicated grant"),
        ("bootstrap", "task-contracts", "load only contracts selected by the actual task class"),
    ):
        raise ContractError("policy.loadRoutes: unsupported v1 load graph")
    _require_acyclic(owner_ids, edges)

    budgets = _require_keys(
        top["budgets"],
        (
            "wordDefinition",
            "byteDefinition",
            "tokenCounts",
            "symlinkRule",
            "surfaces",
        ),
        "policy.budgets",
    )
    for key in ("wordDefinition", "byteDefinition", "tokenCounts", "symlinkRule"):
        _require_string(budgets[key], f"policy.budgets.{key}")
    surface_ids: list[str] = []
    for index, value in enumerate(
        _require_sequence(budgets["surfaces"], "policy.budgets.surfaces")
    ):
        surface = _require_mapping(value, f"policy.budgets.surfaces[{index}]")
        keys = tuple(surface)
        admitted = {
            ("id", "path", "wordCap", "byteCap"),
            ("id", "members", "wordCap", "byteCap"),
            ("glob", "id", "wordCap", "byteCap"),
            ("glob", "id", "exclude", "wordCap", "byteCap"),
            ("id", "path", "region", "wordCap", "byteCap"),
        }
        if keys not in admitted:
            raise ContractError(
                f"policy.budgets.surfaces[{index}]: closed shape violation {keys!r}"
            )
        identifier = _require_string(
            surface.get("id"), f"policy.budgets.surfaces[{index}].id"
        )
        for locator in ("path", "glob", "region"):
            if locator in surface:
                _require_string(
                    surface[locator],
                    f"policy.budgets.surfaces[{index}].{locator}",
                )
        if "members" in surface:
            _unique_strings(
                surface["members"], f"policy.budgets.surfaces[{index}].members"
            )
        if "exclude" in surface:
            _unique_strings(
                surface["exclude"], f"policy.budgets.surfaces[{index}].exclude"
            )
        if type(surface.get("wordCap")) is not int or surface["wordCap"] <= 0:
            raise ContractError(f"policy.budgets.surfaces[{index}]: invalid word cap")
        if type(surface.get("byteCap")) is not int or surface["byteCap"] <= 0:
            raise ContractError(f"policy.budgets.surfaces[{index}]: invalid byte cap")
        surface_ids.append(identifier)
    if len(set(surface_ids)) != len(surface_ids):
        raise ContractError("policy.budgets.surfaces: duplicate id")
    surface_set = set(surface_ids)
    for surface in budgets["surfaces"]:
        for member in surface.get("members", []):
            if member not in surface_set:
                raise ContractError(f"budget {surface['id']}: unknown member {member}")
    budget_digest = hashlib.sha256(canonical_policy_bytes(budgets)).hexdigest()
    if budget_digest != "583e49b2d8ef7d113c725b7ead8efb75262bd38cf90aaf83744e65823fb1a167":
        raise ContractError("policy.budgets: unsupported v1 definitions or caps")

    workflow = _require_keys(
        top["workflow"],
        (
            "states",
            "readySemantics",
            "readyCapacity",
            "statusCreatesAuthority",
            "productOwnerOrderingIsSchedulingAuthority",
            "transitions",
            "unlistedTransition",
        ),
        "policy.workflow",
    )
    states = _unique_strings(workflow["states"], "policy.workflow.states")
    if states != (
        "Backlog",
        "Refinement",
        "Ready",
        "In progress",
        "In review",
        "Paused",
        "Done",
    ):
        raise ContractError("policy.workflow.states: unsupported v1 vocabulary")
    _require_string(workflow["readySemantics"], "policy.workflow.readySemantics")
    if workflow["readyCapacity"] != "unbounded":
        raise ContractError("policy.workflow: Ready capacity must be unbounded")
    if workflow["statusCreatesAuthority"] is not False:
        raise ContractError("policy.workflow: status must not create authority")
    if workflow["productOwnerOrderingIsSchedulingAuthority"] is not True:
        raise ContractError("policy.workflow: Product Owner ordering must schedule")
    transitions = _require_sequence(
        workflow["transitions"], "policy.workflow.transitions"
    )
    transition_rows: list[tuple[str, str, str]] = []
    for index, value in enumerate(transitions):
        transition = _require_keys(
            value,
            ("id", "from", "to"),
            f"policy.workflow.transitions[{index}]",
        )
        identifier = _require_string(
            transition["id"], f"policy.workflow.transitions[{index}].id"
        )
        source = _require_string(
            transition["from"], f"policy.workflow.transitions[{index}].from"
        )
        target = _require_string(
            transition["to"], f"policy.workflow.transitions[{index}].to"
        )
        if source not in states or target not in states:
            raise ContractError(f"policy.workflow.transitions[{index}]: unknown state")
        transition_rows.append((identifier, source, target))
    if tuple(transition_rows) != (
        ("workflow.backlog-to-refinement", "Backlog", "Refinement"),
        ("workflow.refinement-to-ready", "Refinement", "Ready"),
        ("workflow.ready-to-in-progress", "Ready", "In progress"),
        ("workflow.in-progress-to-in-review", "In progress", "In review"),
        ("workflow.in-progress-to-paused", "In progress", "Paused"),
        ("workflow.paused-to-ready", "Paused", "Ready"),
        ("workflow.in-review-to-done", "In review", "Done"),
    ):
        raise ContractError("policy.workflow.transitions: unsupported v1 transition set")
    if workflow["unlistedTransition"] != "forbidden":
        raise ContractError("policy.workflow: unlisted transitions must be forbidden")

    actions = _require_sequence(top["actions"], "policy.actions")
    action_rows: list[tuple[str, str]] = []
    for index, value in enumerate(actions):
        action = _require_keys(
            value,
            ("id", "identityRequirement"),
            f"policy.actions[{index}]",
        )
        identifier = _require_string(action["id"], f"policy.actions[{index}].id")
        identity = _require_string(
            action["identityRequirement"],
            f"policy.actions[{index}].identityRequirement",
        )
        action_rows.append((identifier, identity))
    expected_actions = (
        ("local.write", "declared-agent-or-directly-evidenced-human"),
        ("git.commit.create", "truthful-commit-actor"),
        ("project.transition", "verified-machine-user-for-agent-action"),
        ("remote.issue-comment.create", "verified-machine-user-for-agent-action"),
        ("remote.push", "verified-machine-user-for-agent-action"),
        ("remote.pull-request.publish", "verified-machine-user-for-agent-action"),
        ("remote.evidence.publish", "verified-machine-user-for-agent-action"),
        ("issue.contract.mutate", "verified-machine-user-for-agent-action"),
        ("issue.close", "verified-machine-user-for-agent-action"),
        ("pull-request.merge", "verified-authorized-publisher"),
        (
            "completed-work.cleanup",
            "declared-local-and-verified-remote-identity-as-applicable",
        ),
        ("release.publish", "verified-authorized-publisher"),
        ("tag.create", "verified-authorized-publisher"),
        ("protected.publication", "verified-authorized-publisher"),
        ("scope.expand", "new-product-owner-grant"),
    )
    if tuple(action_rows) != expected_actions:
        raise ContractError("policy.actions: unsupported v1 action vocabulary")
    action_ids = [identifier for identifier, _identity in action_rows]

    grant = _require_keys(
        top["authorityGrant"],
        (
            "schema",
            "requiredFields",
            "immutableFields",
            "lifecycleStates",
            "activeUntil",
            "validityRules",
            "invalidationConditions",
            "approvalConsumptionDoesNotConsumeGrant",
            "issueBodyUnchangedByActivation",
            "durableReceipt",
        ),
        "policy.authorityGrant",
    )
    if grant["schema"] != "o2i.authority-grant/v1":
        raise ContractError("policy.authorityGrant: unsupported schema")
    required_fields = _unique_strings(
        grant["requiredFields"], "policy.authorityGrant.requiredFields"
    )
    if required_fields != (
        "grantId", "issuer", "subject.repository", "subject.issue",
        "decisionPayloadSha256", "expectedIssueBodySha256", "actionIds",
        "resourceIds", "scope", "targetState", "exclusions", "durableReceipt",
        "validity", "lifecycle",
    ):
        raise ContractError("policy.authorityGrant: unsupported required fields")
    immutable_fields = _unique_strings(
        grant["immutableFields"], "policy.authorityGrant.immutableFields"
    )
    if immutable_fields != (
        "grantId", "issuer", "subject", "decisionPayloadSha256",
        "expectedIssueBodySha256", "actionIds", "resourceIds", "scope",
        "targetState", "exclusions",
    ):
        raise ContractError("policy.authorityGrant: unsupported immutable fields")
    if _unique_strings(
        grant["lifecycleStates"], "policy.authorityGrant.lifecycleStates"
    ) != ("active", "fulfilled", "revoked", "superseded", "invalidated"):
        raise ContractError("policy.authorityGrant: unsupported lifecycle")
    if _unique_strings(
        grant["activeUntil"], "policy.authorityGrant.activeUntil"
    ) != ("target-fulfilled", "revoked", "superseded", "material-mismatch"):
        raise ContractError("policy.authorityGrant: unsupported active boundary")
    validity_rules = _unique_strings(
        grant["validityRules"], "policy.authorityGrant.validityRules"
    )
    if validity_rules != (
        "grant-id-is-unique-and-immutable",
        "issuer-is-product-owner",
        "repository-and-issue-match-current-subject",
        "decision-payload-sha256-matches-approved-canonical-bytes",
        "issue-body-sha256-matches-bind-time-precondition",
        "action-and-resource-ids-contain-requested-mutation",
        "scope-and-target-contain-requested-mutation",
        "no-exclusion-is-crossed",
        "durable-receipt-is-currently-verifiable-after-session-boundary",
    ):
        raise ContractError("policy.authorityGrant: unsupported validity rules")
    invalidation = _unique_strings(
        grant["invalidationConditions"],
        "policy.authorityGrant.invalidationConditions",
    )
    if invalidation != (
        "target-fulfilled",
        "product-owner-revocation",
        "newer-grant-supersession",
        "subject-or-decision-digest-mismatch",
        "issue-body-precondition-mismatch",
        "scope-target-action-resource-or-exclusion-mismatch",
        "durable-receipt-missing-ambiguous-malformed-or-unverifiable",
    ):
        raise ContractError("policy.authorityGrant: unsupported invalidation conditions")
    if grant["approvalConsumptionDoesNotConsumeGrant"] is not True:
        raise ContractError("policy.authorityGrant: approval must not consume grant")
    if grant["issueBodyUnchangedByActivation"] is not True:
        raise ContractError("policy.authorityGrant: activation must preserve Issue body")
    receipt = _require_keys(
        grant["durableReceipt"],
        (
            "action",
            "mustBeFirstAuthorizedRemoteWrite",
            "immutableCommentRequired",
            "requiredContent",
            "sameSessionReadbackRequired",
            "crossSessionReconstruction",
        ),
        "policy.authorityGrant.durableReceipt",
    )
    action = _require_string(
        receipt["action"], "policy.authorityGrant.durableReceipt.action"
    )
    if action != "remote.issue-comment.create":
        raise ContractError("policy.authorityGrant.durableReceipt: unsupported action")
    for key in (
        "mustBeFirstAuthorizedRemoteWrite",
        "immutableCommentRequired",
        "sameSessionReadbackRequired",
    ):
        if receipt[key] is not True:
            raise ContractError(f"policy.authorityGrant.durableReceipt.{key}: required")
    if _unique_strings(
        receipt["requiredContent"], "durableReceipt.requiredContent"
    ) != (
        "full-approved-canonical-decision-payload",
        "decision-payload-sha256",
        "expected-unchanged-issue-body-sha256",
        "complete-grant-receipt",
    ):
        raise ContractError("durableReceipt.requiredContent: unsupported values")
    reconstruction = _require_keys(
        receipt["crossSessionReconstruction"],
        (
            "authoritySource",
            "requiresExactlyOneReceiptForGrantId",
            "requiresVerifiedAuthorIdentity",
            "requiresCanonicalBytesAndAllGrantFields",
            "rejects",
        ),
        "policy.authorityGrant.durableReceipt.crossSessionReconstruction",
    )
    if reconstruction["authoritySource"] != "current-observable-remote-state-only":
        raise ContractError("crossSessionReconstruction: unsupported authority source")
    for key in (
        "requiresExactlyOneReceiptForGrantId",
        "requiresVerifiedAuthorIdentity",
        "requiresCanonicalBytesAndAllGrantFields",
    ):
        if reconstruction[key] is not True:
            raise ContractError(f"crossSessionReconstruction.{key}: required")
    if _unique_strings(
        reconstruction["rejects"], "crossSessionReconstruction.rejects"
    ) != (
        "zero-receipts",
        "multiple-receipts",
        "malformed-receipt",
        "mismatched-receipt",
        "superseded-grant",
        "revoked-grant",
        "unverifiable-receipt",
        "transcript-source",
        "historical-readback-only",
    ):
        raise ContractError("crossSessionReconstruction.rejects: unsupported values")

    gates = _require_keys(
        top["mutationGates"],
        (
            "allRequired",
            "missingOrUnknown",
            "gates",
            "permissionDenialRevokesAuthority",
            "identityFailureBlocksOnlyIdentityRequiringActions",
            "policyTransitionMustBeEnumerated",
        ),
        "policy.mutationGates",
    )
    if gates["allRequired"] is not True or gates["missingOrUnknown"] != "deny":
        raise ContractError("policy.mutationGates: gates must be conjunctive and closed")
    gate_names = _unique_strings(gates["gates"], "policy.mutationGates.gates")
    if gate_names != (
        "current-matching-subject-grant",
        "event-specific-guards",
        "declared-and-verified-execution-identity",
        "technical-host-or-tool-permission",
    ):
        raise ContractError("policy.mutationGates: unsupported v1 gates")
    if gates["permissionDenialRevokesAuthority"] is not False:
        raise ContractError("policy.mutationGates: permission must not revoke authority")
    if gates["identityFailureBlocksOnlyIdentityRequiringActions"] is not True:
        raise ContractError("policy.mutationGates: identity failure scope is not closed")
    if gates["policyTransitionMustBeEnumerated"] is not True:
        raise ContractError("policy.mutationGates: transitions must be enumerated")

    _validate_continuity(top["continuity"])

    events = _require_keys(
        top["events"],
        ("authority_request", "product_owner_action", "cold_start"),
        "policy.events",
    )
    _validate_events(events)

    provenance = _require_keys(
        top["provenance"],
        (
            "independentFacts",
            "approvalNeverImplies",
            "agentIdentity",
            "agentAuthoredAndCommitted",
            "humanIdentityUse",
            "mixedAuthorship",
            "matrix",
            "issueScopedAgentCommitTrailers",
            "decisionAuthorityRecord",
        ),
        "policy.provenance",
    )
    if _unique_strings(
        provenance["independentFacts"], "provenance.independentFacts"
    ) != (
        "product-owner-decision-authority",
        "actual-content-authorship",
        "git-commit-object-creator",
        "verified-remote-publisher-identity",
    ):
        raise ContractError("policy.provenance: unsupported independent facts")
    if _unique_strings(
        provenance["approvalNeverImplies"], "provenance.approvalNeverImplies"
    ) != ("author", "co-author", "committer", "publisher"):
        raise ContractError("policy.provenance: unsupported approval implications")
    identity = _require_keys(
        provenance["agentIdentity"],
        ("name", "email", "remoteLogin"),
        "policy.provenance.agentIdentity",
    )
    if tuple(identity.values()) != (
        "Gertrud ai4X",
        "311782161+gertrud-ai4x@users.noreply.github.com",
        "gertrud-ai4x",
    ):
        raise ContractError("policy.provenance: unsupported agent identity")
    authored = _require_keys(
        provenance["agentAuthoredAndCommitted"],
        ("author", "committer"),
        "policy.provenance.agentAuthoredAndCommitted",
    )
    if tuple(authored.values()) != ("agentIdentity", "agentIdentity"):
        raise ContractError("policy.provenance: unsupported agent authorship")
    if provenance["humanIdentityUse"] != "direct-evidence-only":
        raise ContractError("policy.provenance: unsupported human identity rule")
    if provenance["mixedAuthorship"] != (
        "principal-actual-author-plus-truthful-co-authored-by-trailers"
    ):
        raise ContractError("policy.provenance: unsupported mixed authorship rule")
    matrix_rows: list[tuple[str, str, str, str, str]] = []
    for index, value in enumerate(
        _require_sequence(provenance["matrix"], "policy.provenance.matrix")
    ):
        row = _require_keys(
            value,
            (
                "case",
                "decisionAuthority",
                "contentAuthor",
                "commitActor",
                "remotePublisher",
            ),
            f"policy.provenance.matrix[{index}]",
        )
        for key in (
            "case",
            "decisionAuthority",
            "contentAuthor",
            "commitActor",
            "remotePublisher",
        ):
            _require_string(row[key], f"policy.provenance.matrix[{index}].{key}")
        matrix_rows.append(tuple(row.values()))
    if tuple(matrix_rows) != (
        ("product-owner-approval", "Product Owner", "no-inference", "no-inference", "no-inference"),
        ("agent-authored-and-committed", "current-grant-issuer", "agentIdentity", "agentIdentity", "separately-verified-identity"),
        ("human-authored-or-committed", "current-grant-issuer", "direct-evidence-only", "direct-evidence-only", "separately-verified-identity"),
        ("agent-remote-publication", "current-grant-issuer", "independent-observed-fact", "independent-observed-fact", "verified-gertrud-ai4x"),
    ):
        raise ContractError("policy.provenance.matrix: unsupported v1 matrix")
    if _unique_strings(
        provenance["issueScopedAgentCommitTrailers"],
        "provenance.issueScopedAgentCommitTrailers",
    ) != ("Refs #N", "O2I-Grant: <grant-id>"):
        raise ContractError("policy.provenance: unsupported commit trailers")
    if provenance["decisionAuthorityRecord"] != "owning-Issue-durable-grant-receipt":
        raise ContractError("policy.provenance: unsupported decision record")

    forbidden = _require_sequence(top["forbiddenActions"], "policy.forbiddenActions")
    forbidden_ids: list[str] = []
    for index, value in enumerate(forbidden):
        rule = _require_mapping(value, f"policy.forbiddenActions[{index}]")
        keys = tuple(rule)
        identifier = _require_string(
            rule.get("id"), f"policy.forbiddenActions[{index}].id"
        )
        _require_string(rule.get("when"), f"policy.forbiddenActions[{index}].when")
        if keys == ("id", "when", "actionIds"):
            for action in _unique_strings(
                rule["actionIds"], f"policy.forbiddenActions[{index}].actionIds"
            ):
                if action not in action_ids:
                    raise ContractError(
                        f"policy.forbiddenActions[{index}]: unknown action {action}"
                    )
        elif keys == ("id", "when", "selector"):
            if rule["selector"] not in {
                "all-actions",
                "current-action",
                "remote-actions",
            }:
                raise ContractError(
                    f"policy.forbiddenActions[{index}]: unknown selector"
                )
        else:
            raise ContractError(
                f"policy.forbiddenActions[{index}]: closed shape violation {keys!r}"
            )
        forbidden_ids.append(identifier)
    if len(set(forbidden_ids)) != len(forbidden_ids):
        raise ContractError("policy.forbiddenActions: duplicate id")
    expected_forbidden = (
        {
            "id": "forbid-ready-as-authority",
            "when": "Project-status-Ready-without-current-matching-grant",
            "selector": "all-actions",
        },
        {
            "id": "forbid-unlisted-transition",
            "when": "workflow-transition-is-not-enumerated",
            "actionIds": ["project.transition"],
        },
        {
            "id": "forbid-grant-activation-issue-mutation",
            "when": "activating-or-materializing-a-grant",
            "actionIds": ["issue.contract.mutate"],
        },
        {
            "id": "forbid-ordinary-execution-completion",
            "when": "grant-target-ends-at-In-review",
            "actionIds": [
                "pull-request.merge",
                "issue.close",
                "completed-work.cleanup",
                "release.publish",
                "tag.create",
                "protected.publication",
                "scope.expand",
            ],
        },
        {
            "id": "forbid-gate-substitution",
            "when": "identity-or-permission-is-present-without-another-required-gate",
            "selector": "all-actions",
        },
        {
            "id": "forbid-scope-or-exclusion-mismatch",
            "when": "action-expands-scope-target-or-crosses-an-exclusion",
            "selector": "current-action",
        },
        {
            "id": "forbid-unverified-remote-identity",
            "when": "agent-remote-action-without-required-verified-machine-user",
            "selector": "remote-actions",
        },
    )
    if tuple(forbidden) != expected_forbidden:
        raise ContractError("policy.forbiddenActions: unsupported v1 rules")
    return top


def _validate_continuity(value: Any) -> None:
    continuity = _require_keys(
        value,
        (
            "operationalTarget",
            "sharedRequiredEvidence",
            "boundaryKinds",
            "missingOrUnknown",
        ),
        "policy.continuity",
    )
    if continuity["operationalTarget"] != "GitHub":
        raise ContractError("policy.continuity: GitHub must be the sole target")
    if continuity["missingOrUnknown"] != "deny":
        raise ContractError("policy.continuity: unknown evidence must deny")
    if _unique_strings(
        continuity["sharedRequiredEvidence"],
        "policy.continuity.sharedRequiredEvidence",
    ) != (
        "published-head-and-clean-fresh-clone",
        "applicable-tracked-state-and-handoff",
        "remote-return-point-and-authority-current",
        "no-delegated-or-background-work",
        "no-local-or-session-dependency",
        "restore-proof-current",
    ):
        raise ContractError("policy.continuity: unsupported shared evidence")
    expected = (
        (
            "completed-work-unit",
            "COMPLETE",
            (
                "work-verification-corrections-and-reviews-complete",
                "no-unresolved-fact-or-decision",
            ),
        ),
        (
            "active-product-owner-decision",
            "ACTIVE",
            (
                "one-exact-current-non-authorizing-decision-next",
                "all-required-changes-pushed",
                "incomplete-and-unaccepted-state-explicit",
                "no-other-unresolved-fact",
            ),
        ),
    )
    observed = []
    for index, item in enumerate(
        _require_sequence(continuity["boundaryKinds"], "policy.continuity.boundaryKinds")
    ):
        boundary = _require_keys(
            item,
            ("id", "handoffWorkStatus", "additionalRequiredEvidence"),
            f"policy.continuity.boundaryKinds[{index}]",
        )
        observed.append(
            (
                _require_string(
                    boundary["id"], f"policy.continuity.boundaryKinds[{index}].id"
                ),
                _require_string(
                    boundary["handoffWorkStatus"],
                    f"policy.continuity.boundaryKinds[{index}].handoffWorkStatus",
                ),
                _unique_strings(
                    boundary["additionalRequiredEvidence"],
                    f"policy.continuity.boundaryKinds[{index}].additionalRequiredEvidence",
                ),
            )
        )
    if tuple(observed) != expected:
        raise ContractError("policy.continuity: unsupported boundary kinds")


def _validate_events(events: Mapping[str, Any]) -> None:
    authority = _require_keys(
        events["authority_request"],
        (
            "createsGrant",
            "requiredFields",
            "approvalReply",
            "bindingRequires",
            "receiptRepeats",
            "requestLifecycle",
            "rejectApprovalWhen",
        ),
        "policy.events.authority_request",
    )
    if (
        authority["createsGrant"] is not True
        or authority["approvalReply"] != "Freigegeben."
    ):
        raise ContractError("authority_request: invalid approval contract")
    expected_authority = {
        "requiredFields": (
            "requestId", "payloadFingerprint", "subject", "scope", "targetState",
            "requestedAuthority", "exclusions", "reason", "alternatives", "coldStart",
        ),
        "bindingRequires": (
            "unique-request-id", "canonical-payload-fingerprint",
            "immediately-following-standalone-exact-reply", "exactly-one-open-request",
            "still-current-request", "unchanged-revalidated-facts",
            "same-live-exchange", "unused-request",
        ),
        "receiptRepeats": ("subject", "scope", "targetState", "exclusions"),
        "requestLifecycle": (
            "open", "bound", "consumed", "rejected", "superseded", "invalidated",
        ),
        "rejectApprovalWhen": (
            "superseded", "facts-changed", "already-consumed", "non-adjacent",
            "session-reconstructed", "wrong-event", "wrong-reply",
        ),
    }
    for key, expected in expected_authority.items():
        actual = _unique_strings(
            authority[key], f"policy.events.authority_request.{key}"
        )
        if actual != expected:
            raise ContractError(f"authority_request.{key}: unsupported v1 values")

    direct = _require_keys(
        events["product_owner_action"],
        (
            "createsGrant",
            "requiredFields",
            "requestedAgentAuthorityMustEqual",
            "forbiddenFields",
        ),
        "policy.events.product_owner_action",
    )
    cold = _require_keys(
        events["cold_start"],
        (
            "createsGrant",
            "requiredFields",
            "requestedAgentAuthorityMustEqual",
            "coldStartMustEqual",
            "fixedActionIds",
            "fixedLiterals",
            "forbiddenFields",
        ),
        "policy.events.cold_start",
    )
    expected_direct = (
        "eventId", "subject", "scope", "targetState", "requestedAgentAuthority",
        "exclusions", "reason", "alternatives", "coldStart", "productOwnerAction",
    )
    expected_cold = (
        "eventId", "subject", "scope", "targetState", "requestedAgentAuthority",
        "exclusions", "reason", "alternatives", "coldStart",
    )
    for name, event, expected_fields in (
        ("product_owner_action", direct, expected_direct),
        ("cold_start", cold, expected_cold),
    ):
        if (
            event["createsGrant"] is not False
            or event["requestedAgentAuthorityMustEqual"] != "none"
        ):
            raise ContractError(f"{name}: must never create agent authority")
        if _unique_strings(
            event["requiredFields"], f"policy.events.{name}.requiredFields"
        ) != expected_fields:
            raise ContractError(f"{name}: unsupported v1 required fields")
    if cold["coldStartMustEqual"] != "recommended":
        raise ContractError("cold_start: fixed recommendation value required")
    if _unique_strings(
        direct["forbiddenFields"], "policy.events.product_owner_action.forbiddenFields"
    ) != ("approvalReply", "requestedAuthority"):
        raise ContractError("product_owner_action: unsupported forbidden fields")
    if _unique_strings(
        cold["fixedActionIds"], "policy.events.cold_start.fixedActionIds"
    ) != (
        "delete-current-session",
        "start-fresh-session-without-resume-in-repository-root",
        "say-literal-greeting",
    ):
        raise ContractError("cold_start: unsupported fixed actions")
    if _unique_strings(
        cold["fixedLiterals"], "policy.events.cold_start.fixedLiterals"
    ) != ("/delete", "resume", "Hi Gertrud, weiter geht’s!"):
        raise ContractError("cold_start: unsupported fixed literals")
    if _unique_strings(
        cold["forbiddenFields"], "policy.events.cold_start.forbiddenFields"
    ) != ("approvalReply", "productOwnerAction", "requestedAuthority"):
        raise ContractError("cold_start: unsupported forbidden fields")


def _require_acyclic(nodes: Iterable[str], edges: Iterable[tuple[str, str]]) -> None:
    graph = {node: [] for node in nodes}
    for source, target in edges:
        graph[source].append(target)
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(node: str) -> None:
        if node in visiting:
            raise ContractError(f"load graph cycle at {node}")
        if node in visited:
            return
        visiting.add(node)
        for target in graph[node]:
            visit(target)
        visiting.remove(node)
        visited.add(node)

    for node in graph:
        visit(node)


def _load_policy_source(source: bytes, *, origin: str) -> Mapping[str, Any]:
    policy = _validate_policy_shape(decode_json(source, origin=origin))
    if canonical_policy_bytes(policy) != source:
        raise ContractError(f"{origin}: source is not canonical JSON")
    return policy


def load_policy(path: Path = POLICY_PATH) -> Mapping[str, Any]:
    """Load, close, and canonicalize the worktree governance policy."""
    return _load_policy_source(path.read_bytes(), origin=str(path))


def _validate_state_source(source: bytes, *, origin: str) -> Mapping[str, Any]:
    if len(source) > 1024:
        raise ContractError(f"{origin}: State envelope exceeds 1,024 bytes")
    try:
        text = source.decode("utf-8", errors="strict")
    except UnicodeDecodeError as error:
        raise ContractError(f"{origin}: State envelope is not strict UTF-8") from error
    lines = text.splitlines(keepends=True)
    if len(lines) != 3 or any(not line.endswith("\n") for line in lines):
        raise ContractError(f"{origin}: expected exactly three LF-terminated lines")
    if lines[0] != STATE_OPEN + "\n" or lines[2] != STATE_CLOSE + "\n":
        raise ContractError(f"{origin}: invalid State delimiters")
    if "\r" in text:
        raise ContractError(f"{origin}: CR is forbidden")
    object_text = lines[1][:-1]
    value = decode_json(object_text.encode("utf-8"), origin=origin)
    state = _require_keys(
        value,
        ("schema", "appliesOnBranch", "handoffSchema"),
        "State envelope",
    )
    if state["schema"] != STATE_SCHEMA or state["handoffSchema"] != HANDOFF_SCHEMA:
        raise ContractError(f"{origin}: unsupported State or handoff schema")
    if canonical_state_object(state) != object_text:
        raise ContractError(f"{origin}: State object is not canonical")
    branch = state["appliesOnBranch"]
    if not isinstance(branch, str) or not branch:
        raise ContractError(f"{origin}: invalid branch value")
    result = subprocess.run(
        ["git", "check-ref-format", "--branch", branch],
        cwd=ROOT,
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        raise ContractError(f"{origin}: invalid Git branch {branch!r}")
    return state


def read_state_envelope(path: Path = STATE_PATH) -> Mapping[str, Any]:
    """Read only the bounded worktree State envelope and validate exact bytes."""
    with path.open("rb") as handle:
        source = handle.read(1025)
    return _validate_state_source(source, origin=str(path))


def _validate_handoff_source(source: bytes, *, origin: str) -> Mapping[str, Any]:
    if len(source) > 5000:
        raise ContractError(f"{origin}: Handoff exceeds 5,000 bytes")
    try:
        text = source.decode("utf-8", errors="strict")
    except UnicodeDecodeError as error:
        raise ContractError(f"{origin}: Handoff is not strict UTF-8") from error
    if "\r" in text or not text.endswith("\n"):
        raise ContractError(f"{origin}: Handoff must be LF-terminated")
    lines = text.splitlines()
    if len(lines) < 7 or lines[:3] != ["# Handoff", "", HANDOFF_OPEN]:
        raise ContractError(f"{origin}: invalid Handoff header")
    if lines[4:6] != [HANDOFF_CLOSE, ""]:
        raise ContractError(f"{origin}: invalid Handoff envelope delimiters")
    value = decode_json(lines[3].encode("utf-8"), origin=origin)
    envelope = _require_keys(
        value,
        ("schema", "workStatus", "currentIssue", "currentNode"),
        "Handoff envelope",
    )
    if envelope["schema"] != HANDOFF_SCHEMA:
        raise ContractError(f"{origin}: unsupported Handoff schema")
    if envelope["workStatus"] not in {"ACTIVE", "PAUSED", "COMPLETE"}:
        raise ContractError(f"{origin}: invalid Handoff work status")
    issue = envelope["currentIssue"]
    if issue != "NONE" and (
        not isinstance(issue, str) or re.fullmatch(r"#[1-9][0-9]*", issue) is None
    ):
        raise ContractError(f"{origin}: invalid current Issue")
    _require_string(envelope["currentNode"], "Handoff envelope.currentNode")
    if canonical_state_object(envelope) != lines[3]:
        raise ContractError(f"{origin}: Handoff envelope is not canonical")
    expected_headings = (
        "# Objective",
        "# Authority",
        "# Current Facts",
        "# Material Risk",
        "# Verification",
        "# Next Action",
        "# Local Return Point",
    )
    headings = tuple(line for line in lines[6:] if line.startswith("# "))
    if headings != expected_headings:
        raise ContractError(f"{origin}: invalid Handoff section topology")
    return envelope


def read_handoff(path: Path = HANDOFF_PATH) -> Mapping[str, Any]:
    """Read the closed handoff only after applicability is established."""
    with path.open("rb") as handle:
        source = handle.read(5001)
    return _validate_handoff_source(source, origin=str(path))


def read_handoff_revision(revision: str) -> Mapping[str, Any]:
    """Read one named-tree handoff after the caller established applicability."""
    unit = revision_source(revision, ".ai4x/HANDOFF.md")
    return _validate_handoff_source(
        unit.source, origin=f"{revision}:{unit.canonical_path}"
    )


@dataclass(frozen=True)
class ActivePointer:
    """One parsed repository-relative local active-checkout pointer."""

    path: str
    expected_branch: str


def read_active_pointer(path: Path) -> ActivePointer:
    """Read a closed two-line pointer without following a symlink."""
    stat = path.lstat()
    if not path.is_file() or path.is_symlink() or not os.path.isfile(path):
        raise ContractError(f"{path}: pointer must be a non-symlink regular file")
    del stat
    with path.open("rb") as handle:
        source = handle.read(1025)
    if len(source) > 1024 or b"\r" in source or not source.endswith(b"\n"):
        raise ContractError(f"{path}: malformed active pointer bytes")
    try:
        text = source.decode("utf-8", errors="strict")
    except UnicodeDecodeError as error:
        raise ContractError(f"{path}: active pointer is not strict UTF-8") from error
    match = re.fullmatch(r"Path: ([^\n]+)\nExpected branch: ([^\n]+)\n", text)
    if match is None:
        raise ContractError(f"{path}: malformed active pointer")
    relative, branch = match.groups()
    relative_path = PurePosixPath(relative)
    if relative_path.is_absolute() or not relative_path.parts or ".." in relative_path.parts:
        raise ContractError(f"{path}: active pointer escapes the checkout")
    result = subprocess.run(
        ["git", "check-ref-format", "--branch", branch],
        cwd=ROOT,
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        raise ContractError(f"{path}: invalid expected branch")
    return ActivePointer(relative_path.as_posix(), branch)


@dataclass(frozen=True)
class ApplicabilityEvidence:
    """Closed read-only evidence needed by the applicability ladder."""

    pointer_outcome: str
    git_metadata: bool
    observed_branch: str | None
    clean: bool
    state_branch: str | None


def classify_applicability(evidence: ApplicabilityEvidence) -> str:
    """Classify an already observed checkout without opening its handoff."""
    if evidence.pointer_outcome == "unresolved":
        return "UNVERIFIED"
    if evidence.pointer_outcome not in {"absent", "activated_restart"}:
        return "UNVERIFIED"
    if not evidence.git_metadata or evidence.observed_branch is None or evidence.state_branch is None:
        return "UNVERIFIED"
    if evidence.observed_branch == evidence.state_branch:
        return "applicable"
    if (
        evidence.pointer_outcome == "absent"
        and evidence.observed_branch == "trunk"
        and evidence.clean
        and evidence.state_branch != "trunk"
    ):
        return "dormant"
    return "UNVERIFIED"


def load_handoff_if_applicable(
    classification: str, loader: Any
) -> Any | None:
    """Load the handoff only after the closed ladder returned applicable."""
    if classification == "applicable":
        return loader()
    if classification in {"dormant", "UNVERIFIED"}:
        return None
    raise ContractError(f"unknown handoff classification: {classification}")


@dataclass(frozen=True)
class BootstrapResult:
    """Observable outcome of the applicability-first bootstrap path."""

    classification: str
    restart_required: bool
    pointer: ActivePointer | None
    handoff: Mapping[str, Any] | None


def bootstrap_checkout(
    *,
    pointer_path: Path,
    state_path: Path,
    handoff_path: Path,
    git_metadata: bool,
    observed_branch: str | None,
    clean: bool,
    activate_pointer: Any,
) -> BootstrapResult:
    """Parse pointer then State, and open Handoff only for applicable evidence."""
    if os.path.lexists(pointer_path):
        try:
            pointer = read_active_pointer(pointer_path)
            activated = activate_pointer(pointer)
        except (ContractError, OSError):
            return BootstrapResult("UNVERIFIED", False, None, None)
        if activated is not True:
            return BootstrapResult("UNVERIFIED", False, pointer, None)
        return BootstrapResult("activated_restart", True, pointer, None)
    try:
        state = read_state_envelope(state_path)
    except (ContractError, OSError):
        return BootstrapResult("UNVERIFIED", False, None, None)
    classification = classify_applicability(
        ApplicabilityEvidence(
            "absent",
            git_metadata,
            observed_branch,
            clean,
            state["appliesOnBranch"],
        )
    )
    if classification != "applicable":
        return BootstrapResult(classification, False, None, None)
    try:
        handoff = read_handoff(handoff_path)
    except (ContractError, OSError):
        return BootstrapResult("UNVERIFIED", False, None, None)
    return BootstrapResult(classification, False, None, handoff)


@dataclass(frozen=True)
class SourceUnit:
    """One canonical repository source counted in a load or budget union."""

    requested_path: str
    canonical_path: str
    source: bytes


def _git(*args: str, cwd: Path = ROOT) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        ["git", *args],
        cwd=cwd,
        check=False,
        capture_output=True,
    )


def _resolve_tree(revision: str) -> str:
    if not revision or revision.startswith("-"):
        raise ContractError(f"invalid Git revision: {revision!r}")
    result = _git(
        "rev-parse",
        "--verify",
        "--end-of-options",
        f"{revision}^{{tree}}",
    )
    tree = result.stdout.strip().decode("ascii", errors="strict")
    if result.returncode != 0 or re.fullmatch(r"[0-9a-f]{40,64}", tree) is None:
        raise ContractError(f"cannot resolve Git tree: {revision!r}")
    return tree


def _canonical_link_target(path: str, target: str) -> str:
    target_path = PurePosixPath(target)
    if target_path.is_absolute() or not target:
        raise ContractError(f"{path}: absolute or empty symlink target")
    joined = posixpath.normpath(posixpath.join(posixpath.dirname(path), target))
    if joined == ".." or joined.startswith("../") or joined.startswith("/"):
        raise ContractError(f"{path}: symlink target escapes the repository")
    return PurePosixPath(joined).as_posix()


def _require_tracked(path: str) -> None:
    result = _git("ls-files", "--error-unmatch", "--", path)
    if result.returncode != 0:
        raise ContractError(f"{path}: source is not tracked")


def worktree_source(path: str) -> SourceUnit:
    """Read one worktree source under the canonical direct-symlink rule."""
    requested = ROOT / path
    _require_tracked(path)
    if requested.is_symlink():
        target_text = os.readlink(requested)
        canonical = _canonical_link_target(path, target_text)
        target = ROOT / canonical
        _require_tracked(canonical)
        if target.is_symlink() or not target.is_file():
            raise ContractError(f"{path}: symlink target must be one tracked regular file")
        return SourceUnit(path, canonical, target.read_bytes())
    if not requested.is_file():
        raise ContractError(f"{path}: expected tracked regular file")
    return SourceUnit(path, path, requested.read_bytes())


def _tree_entry(revision: str, path: str) -> tuple[str, bytes]:
    entry = _git("ls-tree", revision, "--", path)
    if entry.returncode != 0 or not entry.stdout:
        raise ContractError(f"{revision}:{path}: missing tracked tree entry")
    metadata, _, _name = entry.stdout.partition(b"\t")
    parts = metadata.split()
    if len(parts) != 3:
        raise ContractError(f"{revision}:{path}: malformed tree entry")
    mode = parts[0].decode("ascii")
    blob = _git("show", f"{revision}:{path}")
    if blob.returncode != 0:
        raise ContractError(f"{revision}:{path}: cannot read blob")
    return mode, blob.stdout


def revision_source(revision: str, path: str) -> SourceUnit:
    """Read one named Git-tree source under the same canonical link rule."""
    mode, source = _tree_entry(revision, path)
    if mode == "120000":
        try:
            link = source.decode("utf-8", errors="strict")
        except UnicodeDecodeError as error:
            raise ContractError(f"{revision}:{path}: invalid symlink blob") from error
        canonical = _canonical_link_target(path, link)
        target_mode, target_source = _tree_entry(revision, canonical)
        if target_mode == "120000" or not target_mode.startswith("100"):
            raise ContractError(
                f"{revision}:{path}: symlink target must be one tracked regular file"
            )
        return SourceUnit(path, canonical, target_source)
    if not mode.startswith("100"):
        raise ContractError(f"{revision}:{path}: expected regular file")
    return SourceUnit(path, path, source)


def load_policy_revision(revision: str) -> Mapping[str, Any]:
    """Load and validate the canonical policy from one named Git tree."""
    unit = revision_source(revision, ".ai4x/governance/policy.json")
    return _load_policy_source(unit.source, origin=f"{revision}:{unit.canonical_path}")


def read_state_envelope_revision(revision: str) -> Mapping[str, Any]:
    """Read and validate the bounded State envelope from one named Git tree."""
    unit = revision_source(revision, ".ai4x/STATE.md")
    return _validate_state_source(
        unit.source,
        origin=f"{revision}:{unit.canonical_path}",
    )


def source_measure(source: bytes, *, origin: str) -> tuple[int, int]:
    """Return deterministic whitespace-word and exact-byte counts."""
    try:
        text = source.decode("utf-8", errors="strict")
    except UnicodeDecodeError as error:
        raise ContractError(f"{origin}: budgeted source is not strict UTF-8") from error
    return len(text.split()), len(source)


def _region_source(
    path: str, region: str, *, revision: str | None = None
) -> SourceUnit:
    if path != "CONTRIBUTING.md" or region != "generated-governance":
        raise ContractError(f"{path}: unknown budget region {region}")
    source = worktree_source(path) if revision is None else revision_source(revision, path)
    text = source.source.decode("utf-8")
    start = text.count(CONTRIBUTING_OPEN)
    end = text.count(CONTRIBUTING_CLOSE)
    if start != 1 or end != 1:
        raise ContractError(f"{path}: generated governance markers must be unique")
    before, remainder = text.split(CONTRIBUTING_OPEN, 1)
    body, after = remainder.split(CONTRIBUTING_CLOSE, 1)
    if not before.endswith("\n") or not body.startswith("\n") or not body.endswith("\n"):
        raise ContractError(f"{path}: malformed generated governance region")
    del after
    region_bytes = (CONTRIBUTING_OPEN + body + CONTRIBUTING_CLOSE + "\n").encode(
        "utf-8"
    )
    return SourceUnit(path, f"{path}#{region}", region_bytes)


def _path_matches(path: str, pattern: str) -> bool:
    """Match repository paths with `**` spanning zero or more components."""
    path_parts = PurePosixPath(path).parts
    pattern_parts = PurePosixPath(pattern).parts

    @lru_cache(maxsize=None)
    def match(path_index: int, pattern_index: int) -> bool:
        if pattern_index == len(pattern_parts):
            return path_index == len(path_parts)
        token = pattern_parts[pattern_index]
        if token == "**":
            return match(path_index, pattern_index + 1) or (
                path_index < len(path_parts)
                and match(path_index + 1, pattern_index)
            )
        return (
            path_index < len(path_parts)
            and fnmatchcase(path_parts[path_index], token)
            and match(path_index + 1, pattern_index + 1)
        )

    return match(0, 0)


def _glob_paths(
    pattern: str, excludes: Sequence[str], *, revision: str | None = None
) -> tuple[str, ...]:
    if revision is None:
        result = _git("ls-files", "-z")
        if result.returncode != 0:
            raise ContractError("worktree: cannot enumerate tracked sources")
        candidates = [
            value.decode("utf-8", errors="strict")
            for value in result.stdout.split(b"\0")
            if value
        ]
    else:
        result = _git(
            "ls-tree",
            "-rz",
            "--name-only",
            "--full-tree",
            revision,
        )
        if result.returncode != 0:
            raise ContractError(f"{revision}: cannot enumerate Git tree")
        candidates = [
            value.decode("utf-8", errors="strict")
            for value in result.stdout.split(b"\0")
            if value
        ]
    paths: list[str] = []
    for relative in candidates:
        if not _path_matches(relative, pattern):
            continue
        if any(_path_matches(relative, exclusion) for exclusion in excludes):
            continue
        paths.append(relative)
    return tuple(sorted(set(paths)))


def _surface_units(
    surface: Mapping[str, Any],
    surfaces: Mapping[str, Mapping[str, Any]],
    *,
    revision: str | None,
    stack: tuple[str, ...] = (),
) -> tuple[SourceUnit, ...]:
    identifier = surface["id"]
    if identifier in stack:
        raise ContractError(f"budget membership cycle at {identifier}")
    if "members" in surface:
        units: list[SourceUnit] = []
        for member in surface["members"]:
            units.extend(
                _surface_units(
                    surfaces[member],
                    surfaces,
                    revision=revision,
                    stack=(*stack, identifier),
                )
            )
        return tuple(units)
    if "region" in surface:
        return (
            _region_source(surface["path"], surface["region"], revision=revision),
        )
    paths = (
        _glob_paths(
            surface["glob"], surface.get("exclude", ()), revision=revision
        )
        if "glob" in surface
        else (surface["path"],)
    )
    loader = worktree_source if revision is None else lambda path: revision_source(revision, path)
    return tuple(loader(path) for path in paths)


def _deduplicated(units: Iterable[SourceUnit]) -> tuple[SourceUnit, ...]:
    by_path: dict[str, SourceUnit] = {}
    for unit in units:
        prior = by_path.get(unit.canonical_path)
        if prior is not None and prior.source != unit.source:
            raise ContractError(f"{unit.canonical_path}: inconsistent canonical source")
        by_path[unit.canonical_path] = unit
    return tuple(by_path[path] for path in sorted(by_path))


def _measure_union(units: Iterable[SourceUnit]) -> tuple[int, int]:
    words = 0
    octets = 0
    for unit in _deduplicated(units):
        unit_words, unit_bytes = source_measure(unit.source, origin=unit.canonical_path)
        words += unit_words
        octets += unit_bytes
    return words, octets


def validate_budgets(
    policy: Mapping[str, Any], *, revision: str | None = None
) -> dict[str, tuple[int, int]]:
    """Enforce every individual and aggregate policy budget."""
    listed = policy["budgets"]["surfaces"]
    surfaces = {surface["id"]: surface for surface in listed}
    results: dict[str, tuple[int, int]] = {}
    for surface in listed:
        identifier = surface["id"]
        units = _surface_units(surface, surfaces, revision=revision)
        if "glob" in surface and identifier != "complete-ai4x-tree":
            for unit in units:
                counts = source_measure(unit.source, origin=unit.canonical_path)
                if counts[0] > surface["wordCap"] or counts[1] > surface["byteCap"]:
                    raise ContractError(
                        f"budget {identifier}: {unit.canonical_path} has {counts}, "
                        f"cap {(surface['wordCap'], surface['byteCap'])}"
                    )
            counts = _measure_union(units)
        else:
            counts = _measure_union(units)
            if counts[0] > surface["wordCap"] or counts[1] > surface["byteCap"]:
                raise ContractError(
                    f"budget {identifier}: has {counts}, "
                    f"cap {(surface['wordCap'], surface['byteCap'])}"
                )
        results[identifier] = counts
    return results


def validate_owner_routes(
    policy: Mapping[str, Any], *, revision: str | None = None
) -> None:
    """Require every declared owner and every route endpoint to resolve."""
    owners = {entry["id"]: entry for entry in policy["ruleOwners"]}
    for entry in owners.values():
        path = entry["owner"]
        matches = (
            _glob_paths(path, (), revision=revision) if "*" in path else (path,)
        )
        if not matches:
            raise ContractError(f"owner {entry['id']}: path does not resolve: {path}")
        for match in matches:
            if revision is None:
                worktree_source(match)
            else:
                revision_source(revision, match)
    for route in policy["loadRoutes"]:
        if route["from"] not in owners or route["to"] not in owners:
            raise ContractError(f"unresolved load route: {route}")


def mutation_allowed(
    policy: Mapping[str, Any],
    *,
    action_id: str,
    gate_evidence: Mapping[str, bool | None],
    transition: tuple[str, str] | None = None,
    active_conditions: Iterable[str] = (),
) -> bool:
    """Evaluate one policy action from the canonical gates and transition set."""
    action_ids = {item["id"] for item in policy["actions"]}
    gate_names = tuple(policy["mutationGates"]["gates"])
    if action_id not in action_ids or tuple(gate_evidence) != gate_names:
        return False
    if not all(gate_evidence[name] is True for name in gate_names):
        return False
    if action_id == "project.transition":
        if transition is None or not transition_allowed(policy, *transition):
            return False
    elif transition is not None:
        return False
    return not action_forbidden(policy, action_id, active_conditions)


def transition_allowed(
    policy: Mapping[str, Any], source: str, target: str
) -> bool:
    """Return whether one exact Project transition is enumerated."""
    return any(
        item["from"] == source and item["to"] == target
        for item in policy["workflow"]["transitions"]
    )


def authority_reply_binds(
    policy: Mapping[str, Any],
    *,
    event_type: str,
    reply: str,
    binding_evidence: Mapping[str, bool | None],
) -> bool:
    """Evaluate the single-use binding predicate from the event policy."""
    event = policy["events"].get(event_type)
    if event is None or event.get("createsGrant") is not True:
        return False
    guards = tuple(event["bindingRequires"])
    return (
        reply == event["approvalReply"]
        and tuple(binding_evidence) == guards
        and all(binding_evidence[guard] is True for guard in guards)
    )


def action_forbidden(
    policy: Mapping[str, Any], action_id: str, active_conditions: Iterable[str]
) -> bool:
    """Apply the canonical forbidden-action selectors to one action."""
    actions = {item["id"]: item for item in policy["actions"]}
    if action_id not in actions:
        return True
    active = set(active_conditions)
    for rule in policy["forbiddenActions"]:
        if rule["when"] not in active:
            continue
        if action_id in rule.get("actionIds", ()):
            return True
        selector = rule.get("selector")
        if selector in {"all-actions", "current-action"}:
            return True
        if selector == "remote-actions" and actions[action_id][
            "identityRequirement"
        ] in {
            "verified-machine-user-for-agent-action",
            "verified-authorized-publisher",
        }:
            return True
    return False


def grant_instance_valid(
    policy: Mapping[str, Any],
    grant: Mapping[str, Any],
    *,
    action_id: str,
    resource_id: str,
    expected_binding: Mapping[str, Any],
    validity_evidence: Mapping[str, bool | None],
    current_lifecycle: str | None,
) -> bool:
    """Validate a grant against independently supplied current binding facts."""
    contract = policy["authorityGrant"]
    required = tuple(contract["requiredFields"])
    if tuple(grant) != required:
        return False
    string_fields = (
        "grantId",
        "issuer",
        "subject.repository",
        "subject.issue",
        "scope",
        "targetState",
        "durableReceipt",
    )
    if not all(isinstance(grant[name], str) and grant[name] for name in string_fields):
        return False
    for digest in ("decisionPayloadSha256", "expectedIssueBodySha256"):
        if not isinstance(grant[digest], str) or re.fullmatch(
            r"[0-9a-f]{64}", grant[digest]
        ) is None:
            return False
    for field in ("actionIds", "resourceIds", "exclusions"):
        values = grant[field]
        if (
            not isinstance(values, list)
            or not values
            or not all(isinstance(value, str) and value for value in values)
            or len(values) != len(set(values))
        ):
            return False
    known_actions = {item["id"] for item in policy["actions"]}
    if not set(grant["actionIds"]).issubset(known_actions):
        return False
    binding_fields = required[:-2]
    if tuple(expected_binding) != binding_fields:
        return False
    for field in binding_fields:
        grant_value = grant[field]
        expected_value = expected_binding[field]
        if field in {"actionIds", "resourceIds", "exclusions"}:
            if not isinstance(expected_value, list) or grant_value != expected_value:
                return False
        elif grant_value != expected_value:
            return False
    validity = grant["validity"]
    rules = tuple(contract["validityRules"])
    if (
        not isinstance(validity, dict)
        or tuple(validity) != rules
        or tuple(validity_evidence) != rules
    ):
        return False
    if not all(
        validity[rule] is True and validity_evidence[rule] is True
        for rule in rules
    ):
        return False
    return (
        grant["lifecycle"] == "active"
        and current_lifecycle == "active"
        and action_id in grant["actionIds"]
        and resource_id in grant["resourceIds"]
    )


def cleanup_allowed(
    *,
    issue_accepted: bool | None,
    publication_complete: bool | None,
    remote_checks_green: bool | None,
    issue_closed: bool | None,
    project_done: bool | None,
    cleanup_grant: bool | None,
    durability_proven: bool | None,
    target_identity_stable: bool | None,
    required_identity_verified: bool | None,
    technical_permission: bool | None,
    cleanup_kind: str = "completed-work",
    replacement_restore_proven: bool | None = None,
    unique_data_resolved: bool | None = None,
    recoverable_deletion: bool | None = None,
) -> bool:
    """Evaluate one closed fail-safe cleanup predicate."""
    shared = (
        issue_accepted,
        publication_complete,
        remote_checks_green,
        cleanup_grant,
        durability_proven,
        target_identity_stable,
        required_identity_verified,
        technical_permission,
    )
    if cleanup_kind == "completed-work":
        required = shared + (issue_closed, project_done)
    elif cleanup_kind == "superseded-continuity-source":
        required = shared + (
            replacement_restore_proven,
            unique_data_resolved,
            recoverable_deletion,
        )
    else:
        return False
    return all(
        value is True
        for value in required
    )


def cold_start_eligible(
    policy: Mapping[str, Any],
    *,
    boundary_kind: str,
    handoff_work_status: str,
    evidence: Mapping[str, bool | None],
) -> bool:
    """Evaluate one policy-owned cold-start boundary fail closed."""
    continuity = policy["continuity"]
    boundary = next(
        (
            item
            for item in continuity["boundaryKinds"]
            if item["id"] == boundary_kind
        ),
        None,
    )
    if boundary is None or boundary["handoffWorkStatus"] != handoff_work_status:
        return False
    required = tuple(continuity["sharedRequiredEvidence"]) + tuple(
        boundary["additionalRequiredEvidence"]
    )
    return tuple(evidence) == required and all(evidence[name] is True for name in required)


def render_agent_projection(policy: Mapping[str, Any]) -> str:
    """Render the complete non-authoritative English agent route."""
    lines = [
        "# Generated Agent Governance Projection",
        "",
        "> Generated from `.ai4x/governance/policy.json`; non-authoritative and never manually edited.",
        "",
        "# Owners And Loads",
        "",
    ]
    for owner in policy["ruleOwners"]:
        lines.append(
            f"- `{owner['id']}` → `{owner['owner']}`; load `{owner['loadsWhen']}`; {owner['scope']}."
        )
    lines.extend(("", "Routes: " + "; ".join(
        f"`{route['from']}` → `{route['to']}`" for route in policy["loadRoutes"]
    ) + ".", "", "# Workflow And Authority", ""))
    workflow = policy["workflow"]
    lines.append(
        f"`Ready`: {workflow['readySemantics']}. Capacity: `{workflow['readyCapacity']}`. "
        f"Status creates authority: `{str(workflow['statusCreatesAuthority']).lower()}`."
    )
    for transition in workflow["transitions"]:
        lines.append(
            f"- `{transition['id']}`: `{transition['from']}` → `{transition['to']}`."
        )
    lines.extend(("", "Actions: " + ", ".join(
        f"`{action['id']}`" for action in policy["actions"]
    ) + ".", ""))
    gates = policy["mutationGates"]
    lines.append(
        "Every enumerated mutation requires all four gates: "
        + ", ".join(f"`{gate}`" for gate in gates["gates"])
        + ". Missing or unknown evidence denies execution; permission never creates or revokes authority."
    )
    grant = policy["authorityGrant"]
    lines.append(
        f"Grant schema `{grant['schema']}` remains active until "
        + ", ".join(f"`{state}`" for state in grant["activeUntil"])
        + ". Consuming approval does not consume the grant. Its first authorized remote write is the immutable owning-Issue receipt; cross-session authority exists only when current remote state contains exactly one fully valid receipt."
    )
    lines.extend(("", "# Decision Events", ""))
    for name, event in policy["events"].items():
        grant_text = "creates a grant" if event["createsGrant"] else "creates no grant"
        lines.append(
            f"- `{name}` {grant_text}; required fields: "
            + ", ".join(f"`{field}`" for field in event["requiredFields"])
            + "."
        )
    lines.append(
        "Only `authority_request` accepts the exact adjacent reply `Freigegeben.`; it is single-use, current-fact-bound, observable, and non-replayable."
    )
    continuity = policy["continuity"]
    lines.extend(("", "# Cold Start Continuity", ""))
    lines.append(
        f"`{continuity['operationalTarget']}` alone. Boundaries: `completed-work-unit`, "
        "`active-product-owner-decision`. Load `session-continuity`; unknown denies; "
        "no local/session dependency; no checkpoint-derived acceptance or authority."
    )
    lines.extend(("", "# Provenance And Forbidden Actions", ""))
    provenance = policy["provenance"]
    lines.append(
        "Independent provenance facts: "
        + ", ".join(f"`{fact}`" for fact in provenance["independentFacts"])
        + ". Approval never implies authorship, committer, or publisher identity."
    )
    for rule in policy["forbiddenActions"]:
        if "actionIds" in rule:
            forbidden_text = ", ".join(f"`{item}`" for item in rule["actionIds"])
        else:
            forbidden_text = f"selector `{rule['selector']}`"
        lines.append(f"- `{rule['id']}`: when `{rule['when']}`, forbid {forbidden_text}.")
    return "\n".join(lines) + "\n"


def render_contributing_projection(policy: Mapping[str, Any]) -> str:
    """Render the bounded German human projection from canonical policy."""
    workflow = policy["workflow"]
    transitions = "; ".join(
        f"`{item['from']}` → `{item['to']}`" for item in workflow["transitions"]
    )
    completion_rule = next(
        rule
        for rule in policy["forbiddenActions"]
        if rule["id"] == "forbid-ordinary-execution-completion"
    )
    action_boundary = completion_rule["actionIds"]
    lines = [
        CONTRIBUTING_OPEN,
        "## Generierte Governance-Übersicht",
        "",
        "> Automatisch aus `.ai4x/governance/policy.json` erzeugt; diese Projektion ist nicht normativ und wird niemals manuell editiert.",
        "",
        "### Arbeitsstatus und Autorität",
        "",
        "Das Project zeigt Arbeitsstand und Product-Owner-Reihenfolge. `Ready` bedeutet ausschließlich: Der Issue-Vertrag ist geklärt, Voraussetzungen sind bekannt und kein bekannter Blocker verhindert den nächsten Schritt. Ein Status erzeugt niemals Autorität; "
        + (
            "beliebig viele Issues dürfen `Ready` sein"
            if workflow["readyCapacity"] == "unbounded"
            else "die `Ready`-Kapazität ist begrenzt"
        )
        + ", ihre vertikale Product-Owner-Reihenfolge bestimmt die Planung.",
        "",
        f"Erlaubte Übergänge: {transitions}. Jeder nicht aufgeführte Übergang ist verboten.",
        "",
        "Eine Mutation benötigt gleichzeitig einen aktuellen Subject-Grant, die ereignisspezifischen Guards, die deklarierte und verifizierte Ausführungsidentität sowie die technische Host- oder Tool-Berechtigung. Fehlt eine Bedingung oder bleibt sie unbekannt, wird nicht ausgeführt. Eine technische Berechtigung erzeugt oder widerruft keine Product-Owner-Autorität.",
        "",
        "Ein gebundener Grant bleibt bis zu seinem Zielzustand wirksam; nur die Freigabeantwort wird einmalig verbraucht. Vor einer Session-Grenze muss genau ein vollständiger, unveränderlicher Grant-Beleg im owning Issue aktuell beobachtbar und durch die vorgeschriebene Machine-User-Identität verifizierbar sein.",
        "",
        "### Entscheidungsereignisse",
        "",
        "`authority_request` fordert genau einen begrenzten Agenten-Grant an und akzeptiert allein die unmittelbar folgende, alleinstehende Antwort `Freigegeben.`. `product_owner_action` fordert genau eine Handlung des Product Owners und erzeugt keinen Grant. `cold_start` verwendet ausschließlich die drei festen Übergangsaktionen und erzeugt ebenfalls keinen Grant. Falsche, nicht angrenzende, überholte, rekonstruierte oder bereits verbrauchte Freigaben werden abgewiesen.",
        "",
        "### Cold Start",
        "",
        "GitHub ist das einzige operative Continuity-Ziel. Zulässig sind ein vollständig abgeschlossener Arbeitsstand und eine aktive, vollständig veröffentlichte Entscheidungsgrenze. Beide benötigen einen sauberen Fresh-Clone-Beweis, ein passendes getracktes State/Handoff-Paar, aktuelle dauerhafte Autoritätsbelege und dürfen weder Transcript, `resume`, lokale Pointer, ignorierte Dateien, Host-Snapshots noch Modellgedächtnis voraussetzen. Ein aktiver Checkpoint macht Unfertigkeit und fehlende Akzeptanz ausdrücklich sichtbar und erzeugt selbst weder Akzeptanz noch Autorität.",
        "",
        "### Provenienz und Grenzen",
        "",
        "Product-Owner-Entscheidungsautorität, tatsächliche Inhaltsautorschaft, Erzeuger des Git-Commit-Objekts und verifizierte Remote-Publisher-Identität sind unabhängige Fakten. Eine Freigabe macht den Product Owner niemals automatisch zum Autor, Co-Author, Committer oder Publisher.",
        "",
        "Ein gewöhnlicher Work-Unit-Grant bis `In review` umfasst insbesondere nicht: "
        + ", ".join(f"`{item}`" for item in action_boundary)
        + ". Scope- oder Zielerweiterung und das Überschreiten eines Ausschlusses benötigen einen neuen exakten Grant.",
        CONTRIBUTING_CLOSE,
    ]
    return "\n".join(lines) + "\n"


def render_decision_schema_manifest(policy: Mapping[str, Any]) -> str:
    """Render the policy-owned event-field manifest embedded in the template."""
    lines = [DECISION_OPEN]
    for name, event in policy["events"].items():
        lines.append(
            f"- `{name}` required fields: "
            + ", ".join(f"`{field}`" for field in event["requiredFields"])
            + "."
        )
    lines.append(DECISION_CLOSE)
    return "\n".join(lines) + "\n"


def _replace_contributing_region(document: str, projection: str) -> str:
    if document.count(CONTRIBUTING_OPEN) != 1 or document.count(CONTRIBUTING_CLOSE) != 1:
        raise ContractError("CONTRIBUTING.md: generated governance markers must exist once")
    before, remainder = document.split(CONTRIBUTING_OPEN, 1)
    _old, after = remainder.split(CONTRIBUTING_CLOSE, 1)
    return before + projection.rstrip("\n") + after


def _replace_decision_region(document: str, projection: str) -> str:
    if document.count(DECISION_OPEN) != 1 or document.count(DECISION_CLOSE) != 1:
        raise ContractError("decision-handoff.md: generated event markers must exist once")
    before, remainder = document.split(DECISION_OPEN, 1)
    _old, after = remainder.split(DECISION_CLOSE, 1)
    return before + projection.rstrip("\n") + after


def validate_projections(
    policy: Mapping[str, Any], *, revision: str | None = None
) -> None:
    """Require byte-exact freshness of both generated projections."""
    expected_agent = render_agent_projection(policy).encode("utf-8")
    if revision is None:
        agent_source = AGENT_PROJECTION_PATH.read_bytes()
        document_source = CONTRIBUTING_PATH.read_bytes()
        decision_source = DECISION_PATH.read_bytes()
        origin = str(CONTRIBUTING_PATH)
    else:
        agent_source = revision_source(
            revision, ".ai4x/governance/policy.agent.md"
        ).source
        document_source = revision_source(revision, "CONTRIBUTING.md").source
        decision_source = revision_source(
            revision, ".ai4x/governance/decision-handoff.md"
        ).source
        origin = f"{revision}:CONTRIBUTING.md"
    if agent_source != expected_agent:
        raise ContractError("generated agent governance projection is stale")
    try:
        document = document_source.decode("utf-8", errors="strict")
    except UnicodeDecodeError as error:
        raise ContractError(f"{origin}: not strict UTF-8") from error
    if (
        document.count(CONTRIBUTING_OPEN) != 1
        or document.count(CONTRIBUTING_CLOSE) != 1
    ):
        raise ContractError(f"{origin}: generated governance markers must exist once")
    expected_block = render_contributing_projection(policy).rstrip("\n")
    actual_block = (
        CONTRIBUTING_OPEN
        + document.split(CONTRIBUTING_OPEN, 1)[1].split(CONTRIBUTING_CLOSE, 1)[0]
        + CONTRIBUTING_CLOSE
    )
    if actual_block != expected_block:
        raise ContractError(f"{origin}: stale generated governance region")
    try:
        decision = decision_source.decode("utf-8", errors="strict")
    except UnicodeDecodeError as error:
        raise ContractError("decision-handoff.md: not strict UTF-8") from error
    expected_manifest = render_decision_schema_manifest(policy).rstrip("\n")
    if decision.count(DECISION_OPEN) != 1 or decision.count(DECISION_CLOSE) != 1:
        raise ContractError("decision-handoff.md: generated event markers must exist once")
    actual_manifest = (
        DECISION_OPEN
        + decision.split(DECISION_OPEN, 1)[1].split(DECISION_CLOSE, 1)[0]
        + DECISION_CLOSE
    )
    if actual_manifest != expected_manifest:
        raise ContractError("decision-handoff.md: stale generated event manifest")


def validate_repository(
    *, revision: str | None = None
) -> dict[str, tuple[int, int]]:
    """Validate the exact worktree or named Git-tree governance candidate."""
    if revision is None:
        policy = load_policy()
        read_state_envelope()
        read_handoff()
    else:
        revision = _resolve_tree(revision)
        policy = load_policy_revision(revision)
        read_state_envelope_revision(revision)
        read_handoff_revision(revision)
    validate_owner_routes(policy, revision=revision)
    validate_projections(policy, revision=revision)
    return validate_budgets(policy, revision=revision)


def _write_projections(policy: Mapping[str, Any]) -> None:
    AGENT_PROJECTION_PATH.write_text(render_agent_projection(policy), encoding="utf-8")
    document = CONTRIBUTING_PATH.read_text(encoding="utf-8")
    CONTRIBUTING_PATH.write_text(
        _replace_contributing_region(document, render_contributing_projection(policy)),
        encoding="utf-8",
    )
    decision = DECISION_PATH.read_text(encoding="utf-8")
    DECISION_PATH.write_text(
        _replace_decision_region(decision, render_decision_schema_manifest(policy)),
        encoding="utf-8",
    )


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("check", "render"))
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--revision")
    args = parser.parse_args(argv)
    try:
        if args.write and args.revision is not None:
            raise ContractError("--write and --revision are mutually exclusive")
        if args.command == "render" and args.revision is not None:
            raise ContractError("render accepts only the worktree policy")
        if args.command == "render":
            policy = load_policy()
            if args.write:
                _write_projections(policy)
            else:
                sys.stdout.write(render_agent_projection(policy))
            return 0
        counts = validate_repository(revision=args.revision)
        print(
            "[o2i|success] Agent governance contract passed "
            f"({len(counts)} budget surfaces)."
        )
        return 0
    except (ContractError, OSError) as error:
        print(f"[o2i|error] {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
