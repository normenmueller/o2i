#!/usr/bin/env python3
"""Compile the authoritative Core companion into its private Haskell projection."""

from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import re
import subprocess
from pathlib import Path
from typing import Any


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
COMPANION = PACKAGE_ROOT / "semantics.json"
DIAGNOSTIC_COMPANION = PACKAGE_ROOT / "semantic-diagnostic-evidence.json"
GENERATED = PACKAGE_ROOT / "src/O2I/Core/Contract/Generated.hs"
GENERATED_INVENTORY = (
    PACKAGE_ROOT
    / "contract/generated/o2i.core.semantic-diagnostic-evidence-v1.json"
)
GENERATED_OWNER_INVENTORY = (
    PACKAGE_ROOT / "contract/generated/o2i.core.owner-diagnostic-evidence-v1.json"
)
EXPECTED_SHAPE_SHA256 = (
    "3e091e8bc0fd3a887da02f8591292c2a8ea7d64c7e83951183ab71fe4f5b1278"
)
EXPECTED_SHA256 = (
    "fa431df65d5a5fdd64d91d5ad4089a3e8e31421027f4e0258370e742c8b1a333"
)
EXPECTED_DIAGNOSTIC_SHAPE_SHA256 = (
    "bd450f3299730cbac912d7e7239f8d890486252c6abf7a2c1f6189ce7bf77424"
)
EXPECTED_INVENTORY_SHA256 = (
    "8007829ae3b4cd94b4e645ef973926250f8bac654b1bd9d9d1f3f5402355ed55"
)
EXPECTED_OWNER_INVENTORY_SHA256 = (
    "f21319a50ab84fe30c35889ab15d581022783523b1e1198b1f0c2acf021b90db"
)

OCCURRENCE_AUTHORITY = (
    ("core.collective-strategy-realization.asserted-collective-coverage", (("uncovered-target-member", "one-or-more"),)),
    ("core.collective-strategy-realization.asserted-completeness", (("claim", "one"),)),
    ("core.collective-strategy-realization.asserted-macro-support", (("claim", "one"), ("participant", "one"), ("target", "one"))),
    ("core.collective-strategy-realization.asserted-participant-primitive-support", (("claim", "one"), ("participant", "one"), ("target", "one"))),
    ("core.collective-strategy-realization.fit-pairwise-coherence", (("claim", "one"),)),
    ("core.collective-strategy-realization.fit-participant-binding", (("claim", "one"),)),
    ("core.collective-strategy-realization.fit-participant-compatibility", (("claim", "one"),)),
    ("core.collective-strategy-realization.fit-target-binding", (("claim", "one"),)),
    ("core.collective-strategy-realization.fit-target-guiding-policy", (("claim", "one"),)),
    ("core.collective-strategy-realization.fit-target-trade-offs", (("claim", "one"),)),
    ("core.contextualization.asserted-dependency", (("dependent", "one"), ("contextualized-endpoint", "one"), ("candidate-contextualization", "one"))),
    ("core.situated-need.driver-anchoring", (("unanchored-driver", "one"),)),
    ("core.situated-need.driver-cardinality", (("observed-driver", "zero"),)),
    ("core.situated-need.objective-cardinality", (("observed-objective", "zero"),)),
    ("core.situated-need.objective-grounding", (("ungrounded-objective", "one"),)),
    ("core.situated-need.surfacing-situation-anchoring", (("unanchored-surfacing-situation", "one"),)),
    ("core.situated-need.surfacing-situation-cardinality", (("observed-surfacing-situation", "zero"),)),
    ("core.strategy-formulation.action-contributions", (("uncontributing-action", "one"),)),
    ("core.strategy-formulation.actions", (("listed-action", "one-or-more"),)),
    ("core.strategy-formulation.diagnosis", (("owned-diagnosis", "zero-or-more"),)),
    ("core.strategy-formulation.diagnosis-grounding", (("diagnosis", "one"), ("intent", "one"))),
    ("core.strategy-formulation.guiding-policy", (("owned-guiding-policy", "zero-or-more"),)),
    ("core.strategy-formulation.guiding-policy-actions", (("guiding-policy", "one"), ("action", "one"))),
    ("core.strategy-formulation.intent", (("owned-intent", "zero-or-more"),)),
    ("core.strategy-formulation.key-result-substantiation", (("key-result", "one"), ("intent", "one"))),
    ("core.strategy-formulation.key-results", (("listed-key-result", "one-or-more"),)),
    ("core.strategy-formulation.vision-orientation", (("observed-vision-orientation", "zero"),)),
)

STRUCTURE_DIAGNOSTIC_AUTHORITY = (
    (
        "core.qualified-endpoint.catalog-membership",
        "qualified-endpoint-catalog-membership",
        (("subject", "occurrence-identity", "one"),),
    ),
    (
        "core.contextualization.source-category",
        "contextualization-source-category",
        (
            ("segment", "occurrence-identity", "one"),
            ("owner", "occurrence-identity", "one"),
        ),
    ),
    (
        "core.contextualization.target-category",
        "contextualization-target-category",
        (
            ("segment", "occurrence-identity", "one"),
            ("member", "occurrence-identity", "one"),
        ),
    ),
    (
        "core.contextualization.target-owner-cardinality",
        "contextualization-target-owner-cardinality",
        (
            ("member", "occurrence-identity", "one"),
            ("owners", "occurrence-identity", "zero-or-multiple"),
        ),
    ),
    (
        "core.semantic-relation.compatibility",
        "semantic-relation-compatibility",
        (
            ("relation", "occurrence-identity", "one"),
            ("source", "occurrence-identity", "one"),
            ("target", "occurrence-identity", "one"),
        ),
    ),
    (
        "core.structured-proposition.identity",
        "structured-proposition-identity",
        (
            ("subject", "occurrence-identity", "one"),
            ("occurrences", "occurrence-identity", "two-or-more"),
        ),
    ),
    (
        "core.collective-strategy-realization.participant-type",
        "collective-participant-type",
        (
            ("claim", "occurrence-identity", "one"),
            ("segment", "occurrence-identity", "one"),
            ("endpoint", "occurrence-identity", "one"),
        ),
    ),
    (
        "core.collective-strategy-realization.participant-cardinality",
        "collective-participant-cardinality",
        (
            ("claim", "occurrence-identity", "one"),
            ("endpoints", "occurrence-identity", "zero-or-one"),
        ),
    ),
    (
        "core.collective-strategy-realization.participant-uniqueness",
        "collective-participant-uniqueness",
        (
            ("claim", "occurrence-identity", "one"),
            ("duplicateEndpoints", "occurrence-identity", "one-or-more"),
        ),
    ),
    (
        "core.collective-strategy-realization.target-type",
        "collective-target-type",
        (
            ("claim", "occurrence-identity", "one"),
            ("segment", "occurrence-identity", "one"),
            ("endpoint", "occurrence-identity", "one"),
        ),
    ),
    (
        "core.collective-strategy-realization.target-cardinality",
        "collective-target-cardinality",
        (
            ("claim", "occurrence-identity", "one"),
            ("endpoints", "occurrence-identity", "zero-or-multiple"),
        ),
    ),
    (
        "core.collective-strategy-realization.target-distinctness",
        "collective-target-distinctness",
        (
            ("claim", "occurrence-identity", "one"),
            ("overlappingEndpoints", "occurrence-identity", "one-or-more"),
        ),
    ),
)

BINDING_DIAGNOSTIC_RULE_KEYS = (
    "identityUnknown",
    "identityAmbiguous",
    "identityWrongType",
    "identityOutOfSelectedView",
)

STRUCTURE_NON_DIAGNOSTIC_RULES = {
    "core.structured-proposition.commitment",
    "core.structured-proposition.family",
    "core.structured-proposition.incidence",
}


def reject_constant(value: str) -> None:
    raise ValueError(f"invalid JSON numeric constant: {value}")


def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON object member: {key}")
        result[key] = value
    return result


def load_json_object(path: Path, subject: str) -> tuple[dict[str, Any], bytes]:
    payload = path.read_bytes()
    value = json.loads(
        payload.decode("utf-8"),
        object_pairs_hook=unique_object,
        parse_constant=reject_constant,
    )
    if not isinstance(value, dict):
        raise ValueError(f"{subject} must be one JSON object")
    return value, payload


def load_companion() -> tuple[dict[str, Any], bytes]:
    return load_json_object(COMPANION, "Core companion")


def load_diagnostic_companion() -> tuple[dict[str, Any], bytes]:
    return load_json_object(DIAGNOSTIC_COMPANION, "Core diagnostic companion")


def pointer(path: tuple[object, ...]) -> str:
    return "/" + "/".join(
        str(part).replace("~", "~0").replace("/", "~1") for part in path
    )


def json_kind(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, str):
        return "string"
    if isinstance(value, int):
        return "integer"
    if isinstance(value, float):
        return "number"
    if isinstance(value, list):
        return "array"
    if isinstance(value, dict):
        return "object"
    raise TypeError(type(value).__name__)


def shape_manifest(value: Any, path: tuple[object, ...] = ()) -> list[list[Any]]:
    result: list[list[Any]] = []
    kind = json_kind(value)
    here = pointer(path) if path else ""
    if isinstance(value, dict):
        keys = sorted(value)
        result.append([here, kind, keys])
        for key in keys:
            if path + (key,) == ("companionFormatContract", "shapeSha256"):
                continue
            result.extend(shape_manifest(value[key], path + (key,)))
    elif isinstance(value, list):
        result.append([here, kind, len(value)])
        for index, child in enumerate(value):
            result.extend(shape_manifest(child, path + (index,)))
    else:
        result.append([here, kind])
    return result


def sha256(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def shape_sha256(companion: dict[str, Any]) -> str:
    payload = json.dumps(
        shape_manifest(companion), ensure_ascii=False, separators=(",", ":")
    ).encode("utf-8")
    return sha256(payload)


def resolve_pointer(value: Any, path: str) -> Any:
    current = value
    for raw_token in path.removeprefix("/").split("/"):
        token = raw_token.replace("~1", "/").replace("~0", "~")
        current = current[int(token)] if isinstance(current, list) else current[token]
    return current


def require_exact(actual: Any, expected: Any, subject: str) -> None:
    if actual != expected:
        raise ValueError(f"{subject}: expected {expected!r}, got {actual!r}")


def require_nonempty_unique_strings(values: Any, subject: str) -> list[str]:
    if not isinstance(values, list) or not values:
        raise ValueError(f"{subject}: expected a non-empty array")
    if not all(isinstance(value, str) and value for value in values):
        raise ValueError(f"{subject}: expected non-empty string members")
    if len(values) != len(set(values)):
        raise ValueError(f"{subject}: duplicate member")
    return values


def haskell_constructor(prefix: str, value: str) -> str:
    words = re.findall(r"[A-Za-z0-9]+", value)
    if not words:
        raise ValueError(f"cannot derive Haskell constructor from {value!r}")
    return prefix + "".join(word[:1].upper() + word[1:] for word in words)


def constructor_catalog(prefix: str, values: list[str], subject: str) -> dict[str, str]:
    result = {value: haskell_constructor(prefix, value) for value in values}
    constructors = list(result.values())
    if len(constructors) != len(set(constructors)):
        raise ValueError(f"{subject}: Haskell constructor collision")
    return result


def supplemental_rule_identity_associations(
    companion: dict[str, Any],
) -> dict[str, tuple[str, str]]:
    rule_ids = companion["supplementalInputContract"]["ruleIds"]
    if not isinstance(rule_ids, dict):
        raise ValueError("supplemental rule identity catalog: expected an object")
    keys = require_nonempty_unique_strings(
        list(rule_ids), "supplemental rule identity key catalog"
    )
    require_exact(len(keys), 19, "supplemental rule identity cardinality")
    rules = require_nonempty_unique_strings(
        list(rule_ids.values()), "supplemental rule identity catalog"
    )
    constructors = {
        key: haskell_constructor("GeneratedSupplemental", key) + "RuleIdentity"
        for key in keys
    }
    require_nonempty_unique_strings(
        list(constructors.values()),
        "supplemental rule identity constructor catalog",
    )
    return {
        key: (constructors[key], rule)
        for key, rule in zip(keys, rules)
    }


def semantic_rule_constructor(rule: str) -> str:
    return (
        haskell_constructor(
            "",
            rule.removeprefix("core.").replace(
                "collective-strategy-realization", "collective"
            ),
        )
        + "Rule"
    )


def require_catalog_rows(
    values: Any, required_keys: set[str], subject: str
) -> list[dict[str, Any]]:
    if not isinstance(values, list) or not values:
        raise ValueError(f"{subject}: expected a non-empty array")
    result: list[dict[str, Any]] = []
    for index, value in enumerate(values):
        if not isinstance(value, dict):
            raise ValueError(f"{subject}[{index}]: expected an object")
        if not required_keys.issubset(value):
            missing = sorted(required_keys.difference(value))
            raise ValueError(f"{subject}[{index}]: missing members {missing!r}")
        result.append(value)
    return result


def rule_inventory(companion: dict[str, Any]) -> list[str]:
    contract = companion["ruleIdentityContract"]
    rules = [
        resolve_pointer(companion, entry["path"])
        for entry in contract["inventory"]
    ]
    for group in contract["derivedInventoryGroups"]:
        derived = resolve_pointer(companion, group["path"])
        if not isinstance(derived, dict):
            raise ValueError("derived Core rule inventory must resolve to an object")
        rules.extend(derived.values())
    require_nonempty_unique_strings(rules, "derived Core rule inventory")
    return sorted(rules, key=lambda value: value.encode("utf-8"))


def rule_stage_partition(
    companion: dict[str, Any], rules: list[str]
) -> dict[str, list[str]]:
    partition = companion["ruleExplanationContract"]["stagePartition"]
    expected_stages = [
        "capability-input",
        "qualification",
        "readiness-and-assessment",
        "semantics",
        "structure",
        "trace",
    ]
    require_exact(sorted(partition), expected_stages, "Core rule stage catalog")

    stages: dict[str, list[str]] = {}
    members: list[str] = []
    for stage in expected_stages:
        stage_rules = require_nonempty_unique_strings(
            partition[stage], f"Core rule stage {stage}"
        )
        require_exact(
            stage_rules,
            sorted(stage_rules, key=lambda value: value.encode("utf-8")),
            f"canonical Core rule stage {stage}",
        )
        stages[stage] = stage_rules
        members.extend(stage_rules)

    require_nonempty_unique_strings(members, "Core rule stage partition")
    require_exact(
        sorted(members, key=lambda value: value.encode("utf-8")),
        rules,
        "complete disjoint Core rule stage partition",
    )
    return stages


def semantic_evidence_contract(
    companion: dict[str, Any], semantic_rules: list[str]
) -> tuple[dict[str, list[str]], dict[str, str]]:
    sources = [
        ("proof support contract", companion["proofSupportContract"]),
        *[
            (f"structured proposition family {entry['id']}", entry)
            for entry in companion["structuredPropositionFamilies"]
        ],
    ]
    schemas: dict[str, list[str]] = {}
    mappings: dict[str, str] = {}
    semantic_rule_set = set(semantic_rules)

    for subject, source in sources:
        source_schemas = source.get("evidenceKeySchemas")
        if not isinstance(source_schemas, dict) or not source_schemas:
            raise ValueError(f"{subject}: expected evidence-key schemas")
        for schema, fields in source_schemas.items():
            if not isinstance(schema, str) or not schema:
                raise ValueError(f"{subject}: invalid evidence-key schema name")
            if schema in schemas:
                raise ValueError(f"duplicate semantic evidence-key schema: {schema}")
            schemas[schema] = require_nonempty_unique_strings(
                fields, f"semantic evidence-key schema {schema}"
            )

        source_mappings = source.get("evidenceKeyByRule")
        if not isinstance(source_mappings, dict) or not source_mappings:
            raise ValueError(f"{subject}: expected evidence-key mappings")
        for rule, schema in source_mappings.items():
            if not isinstance(rule, str) or not rule:
                raise ValueError(f"{subject}: invalid semantic rule mapping")
            if not isinstance(schema, str) or not schema:
                raise ValueError(f"{subject}: invalid evidence-key mapping target")
            if rule in mappings:
                raise ValueError(
                    f"duplicate semantic evidence-key mapping: {rule}"
                )
            if rule not in semantic_rule_set:
                raise ValueError(
                    f"semantic evidence-key mapping {rule}: non-semantics rule"
                )
            mappings[rule] = schema

    for rule, schema in mappings.items():
        if schema not in schemas:
            raise ValueError(
                f"semantic evidence-key mapping {rule}: unknown schema {schema}"
            )
    unused_schemas = sorted(set(schemas).difference(mappings.values()))
    if unused_schemas:
        raise ValueError(
            f"unused semantic evidence-key schemas: {unused_schemas!r}"
        )

    ordered_schemas = {
        schema: schemas[schema]
        for schema in sorted(schemas, key=lambda value: value.encode("utf-8"))
    }
    ordered_mappings = {
        rule: mappings[rule] for rule in semantic_rules if rule in mappings
    }
    constructor_catalog(
        "Generated",
        list(ordered_schemas),
        "semantic evidence-key schema catalog",
    )
    rule_constructors = [
        semantic_rule_constructor(rule) for rule in ordered_mappings
    ]
    if len(rule_constructors) != len(set(rule_constructors)):
        raise ValueError("semantic rule catalog: Haskell constructor collision")
    return ordered_schemas, ordered_mappings


def semantic_diagnostic_contract(
    diagnostic: dict[str, Any],
    diagnostic_payload: bytes,
    semantics_payload: bytes,
    semantic_rules: list[str],
    existing_schemas: dict[str, list[str]],
    existing_mappings: dict[str, str],
) -> tuple[dict[str, list[str]], dict[str, str], dict[str, list[tuple[str, str]]]]:
    require_exact(
        list(diagnostic),
        [
            "companionFormatContract",
            "schema",
            "coreIdentity",
            "semanticsCompanion",
            "additionalEvidenceKeySchemas",
            "additionalEvidenceKeyByRule",
            "occurrenceEvidenceByRule",
        ],
        "diagnostic companion members",
    )
    require_exact(
        diagnostic["schema"],
        "o2i.core-semantic-diagnostic-evidence/v1",
        "diagnostic companion schema",
    )
    require_exact(
        diagnostic["coreIdentity"],
        {"identity": "o2i.core-semantics", "version": "0.3.0"},
        "diagnostic Core identity",
    )
    declared_shape = diagnostic["companionFormatContract"]["shapeSha256"]
    require_exact(
        declared_shape,
        shape_sha256(diagnostic),
        "diagnostic shape SHA-256",
    )
    require_exact(
        declared_shape,
        EXPECTED_DIAGNOSTIC_SHAPE_SHA256,
        "accepted diagnostic shape SHA-256",
    )
    require_exact(
        diagnostic["semanticsCompanion"],
        {
            "schema": "o2i.core-semantics/target-v46",
            "rawSha256": sha256(semantics_payload),
            "shapeSha256": EXPECTED_SHAPE_SHA256,
        },
        "diagnostic semantics link",
    )

    additional_schemas = diagnostic["additionalEvidenceKeySchemas"]
    require_exact(
        additional_schemas,
        {
            "AssertedDependencyKey": ["dependent", "endpoint", "context"],
            "FitClaimKey": ["claim"],
        },
        "additional semantic evidence-key schemas",
    )
    additional_mappings = diagnostic["additionalEvidenceKeyByRule"]
    require_exact(
        additional_mappings,
        {
            "core.contextualization.asserted-dependency": (
                "AssertedDependencyKey"
            ),
            "core.collective-strategy-realization.asserted-completeness": (
                "FitClaimKey"
            ),
        },
        "additional semantic evidence-key mappings",
    )
    require_exact(len(existing_mappings), 25, "existing diagnostic subject count")
    overlap = set(existing_mappings).intersection(additional_mappings)
    require_exact(overlap, set(), "disjoint diagnostic subject ownership")

    schemas = dict(existing_schemas)
    for schema, fields in additional_schemas.items():
        if schema in schemas:
            require_exact(
                schemas[schema], fields, f"shared semantic evidence schema {schema}"
            )
        else:
            schemas[schema] = fields
    combined_mappings = dict(existing_mappings)
    combined_mappings.update(additional_mappings)
    authority_rules = [rule for rule, _ in OCCURRENCE_AUTHORITY]
    require_exact(
        set(combined_mappings),
        set(authority_rules),
        "complete diagnostic subject authority",
    )
    mappings = {rule: combined_mappings[rule] for rule in authority_rules}

    raw_occurrences = diagnostic["occurrenceEvidenceByRule"]
    if not isinstance(raw_occurrences, dict):
        raise ValueError("occurrence evidence authority: expected an object")
    occurrences: dict[str, list[tuple[str, str]]] = {}
    cardinalities = {"zero", "one", "one-or-more", "zero-or-more"}
    for rule, raw_roles in raw_occurrences.items():
        if not isinstance(rule, str) or not rule:
            raise ValueError("occurrence evidence authority: invalid rule")
        if not isinstance(raw_roles, list) or not raw_roles:
            raise ValueError(f"occurrence evidence {rule}: expected roles")
        roles: list[tuple[str, str]] = []
        for index, raw_role in enumerate(raw_roles):
            if not isinstance(raw_role, dict):
                raise ValueError(f"occurrence evidence {rule}[{index}]: expected object")
            require_exact(
                list(raw_role),
                ["roleId", "cardinality"],
                f"occurrence evidence {rule}[{index}] members",
            )
            role = raw_role["roleId"]
            cardinality = raw_role["cardinality"]
            if not isinstance(role, str) or not role:
                raise ValueError(f"occurrence evidence {rule}[{index}]: invalid role")
            if cardinality not in cardinalities:
                raise ValueError(
                    f"occurrence evidence {rule}[{index}]: unknown cardinality"
                )
            roles.append((role, cardinality))
        require_nonempty_unique_strings(
            [role for role, _ in roles], f"occurrence evidence {rule} roles"
        )
        occurrences[rule] = roles

    actual_authority = tuple(
        (rule, tuple(roles)) for rule, roles in occurrences.items()
    )
    require_exact(
        actual_authority,
        OCCURRENCE_AUTHORITY,
        "exact 27-row occurrence authority",
    )
    require_exact(
        list(mappings),
        authority_rules,
        "complete ordered diagnostic subject authority",
    )
    require_exact(
        set(mappings),
        set(occurrences),
        "subject-to-occurrence cross-layer closure",
    )
    if not set(occurrences).issubset(semantic_rules):
        raise ValueError("diagnostic occurrence authority: non-semantics rule")
    for rule, schema in mappings.items():
        if schema not in schemas:
            raise ValueError(
                f"diagnostic evidence-key mapping {rule}: unknown schema {schema}"
            )
    require_exact(len(mappings), 27, "complete diagnostic rule count")
    return schemas, mappings, occurrences


def diagnostic_inventory(
    semantics: dict[str, Any],
    semantics_payload: bytes,
    diagnostic: dict[str, Any],
    diagnostic_payload: bytes,
    schemas: dict[str, list[str]],
    mappings: dict[str, str],
    occurrences: dict[str, list[tuple[str, str]]],
) -> bytes:
    value = {
        "schema": "o2i.core.semantic-diagnostic-evidence/v1",
        "core": semantics["coreIdentity"],
        "companions": {
            "semantics": {
                "schema": semantics["schema"],
                "rawSha256": sha256(semantics_payload),
                "shapeSha256": shape_sha256(semantics),
            },
            "semanticDiagnosticEvidence": {
                "schema": diagnostic["schema"],
                "rawSha256": sha256(diagnostic_payload),
                "shapeSha256": shape_sha256(diagnostic),
            },
        },
        "diagnostics": [
            {
                "ruleId": rule,
                "subjectEvidence": {
                    "schema": mappings[rule],
                    "fields": schemas[mappings[rule]],
                },
                "occurrenceEvidence": [
                    {"roleId": role, "cardinality": cardinality}
                    for role, cardinality in occurrences[rule]
                ],
            }
            for rule, _ in OCCURRENCE_AUTHORITY
        ],
    }
    return (
        json.dumps(value, ensure_ascii=False, indent=2, separators=(",", ": "))
        + "\n"
    ).encode("utf-8")


def diagnostic_field_alternatives(
    fields: tuple[tuple[str, str, str], ...],
) -> list[dict[str, Any]]:
    cardinality_alternatives = {
        "zero": (("zero", 0, 0),),
        "one": (("one", 1, 1),),
        "zero-or-one": (("zero", 0, 0), ("one", 1, 1)),
        "zero-or-multiple": (("zero", 0, 0), ("multiple", 2, None)),
        "zero-or-more": (("zero-or-more", 0, None),),
        "one-or-more": (("one-or-more", 1, None),),
        "two-or-more": (("two-or-more", 2, None),),
    }
    choices = [
        cardinality_alternatives[cardinality]
        for _, _, cardinality in fields
    ]
    alternatives = []
    for selected in itertools.product(*choices):
        varying = [
            f"{role_id}-{alternative_id}"
            for (role_id, _, cardinality), (alternative_id, _, _) in zip(
                fields, selected
            )
            if cardinality in {"zero-or-one", "zero-or-multiple"}
        ]
        alternatives.append(
            {
                "alternativeId": "-and-".join(varying) if varying else "exact",
                "fields": [
                    {
                        "roleId": role_id,
                        "valueKind": value_kind,
                        "minimum": minimum,
                        "maximum": maximum,
                    }
                    for (role_id, value_kind, _), (_, minimum, maximum) in zip(
                        fields, selected
                    )
                ],
            }
        )
    return alternatives


def owner_diagnostic_inventory(
    semantics: dict[str, Any],
    semantics_payload: bytes,
    semantic_inventory_payload: bytes,
) -> bytes:
    semantic_inventory = json.loads(semantic_inventory_payload)
    binding_rules = semantics["supplementalInputContract"]["ruleIds"]
    stages = rule_stage_partition(semantics, rule_inventory(semantics))
    structure_rule_ids = [
        rule_id for rule_id, _, _ in STRUCTURE_DIAGNOSTIC_AUTHORITY
    ]
    require_exact(
        set(structure_rule_ids),
        set(stages["structure"]).difference(STRUCTURE_NON_DIAGNOSTIC_RULES),
        "complete Structure diagnostic authority",
    )
    require_exact(
        [binding_rules[key] for key in BINDING_DIAGNOSTIC_RULE_KEYS],
        [
            "core.supplemental.identity.unknown",
            "core.supplemental.identity.ambiguous",
            "core.supplemental.identity.wrong-type",
            "core.supplemental.identity.out-of-selected-view",
        ],
        "complete Binding diagnostic authority",
    )
    structure = [
        {
            "ruleId": rule_id,
            "polarity": "rejection",
            "evidenceKind": evidence_kind,
            "sourceRole": "model",
            "alternatives": diagnostic_field_alternatives(fields),
        }
        for rule_id, evidence_kind, fields in STRUCTURE_DIAGNOSTIC_AUTHORITY
    ]
    binding = [
        {
            "ruleId": binding_rules[key],
            "polarity": "rejection",
            "evidenceKind": "supplemental-identity-site",
            "sourceBinding": {
                "role": "supplemental",
                "ordinalEvidence": "inputOrdinal",
            },
            "alternatives": diagnostic_field_alternatives(
                (
                    ("instancePointer", "text", "one"),
                    ("identity", "model-identity", "one"),
                )
            ),
        }
        for key in BINDING_DIAGNOSTIC_RULE_KEYS
    ]
    semantics_rows = []
    for row in semantic_inventory["diagnostics"]:
        subject = row["subjectEvidence"]
        subject_kind = (
            "occurrence-identity"
            if subject["schema"] == "AssertedDependencyKey"
            else "model-identity"
        )
        fields = tuple(
            (field, subject_kind, "one")
            for field in subject["fields"]
        ) + tuple(
            (
                occurrence["roleId"],
                "occurrence-identity",
                occurrence["cardinality"],
            )
            for occurrence in row["occurrenceEvidence"]
        )
        semantics_rows.append(
            {
                "ruleId": row["ruleId"],
                "polarity": "rejection",
                "evidenceKind": subject["schema"],
                "sourceRole": "model",
                "subjectFieldCount": len(subject["fields"]),
                "alternatives": diagnostic_field_alternatives(fields),
            }
        )
    value = {
        "schema": "o2i.core.owner-diagnostic-evidence/v1",
        "core": semantics["coreIdentity"],
        "companions": {
            "semantics": {
                "schema": semantics["schema"],
                "rawSha256": sha256(semantics_payload),
                "shapeSha256": shape_sha256(semantics),
            },
            "semanticDiagnosticInventory": {
                "schema": semantic_inventory["schema"],
                "rawSha256": sha256(semantic_inventory_payload),
            },
        },
        "owners": {
            "structure": structure,
            "binding": binding,
            "semantics": semantics_rows,
        },
    }
    rendered = (
        json.dumps(value, ensure_ascii=False, indent=2, separators=(",", ": "))
        + "\n"
    ).encode("utf-8")
    require_exact(
        sha256(rendered),
        EXPECTED_OWNER_INVENTORY_SHA256,
        "generated Core owner diagnostic inventory SHA-256",
    )
    return rendered


def validate_generated_inventory(payload: bytes) -> None:
    _, expected = compile_outputs()
    require_exact(
        payload,
        expected,
        "generated Core diagnostic inventory bytes",
    )


def haskell_data(name: str, constructors: list[str]) -> list[str]:
    head, *tail = constructors
    if not tail:
        return [
            f"data {name} =",
            f"  {head}",
            "  deriving (Bounded, Enum, Eq, Ord, Show)",
            "",
        ]
    lines = [f"data {name}", f"  = {head}"]
    lines.extend(f"  | {constructor}" for constructor in tail)
    lines.extend(["  deriving (Bounded, Enum, Eq, Ord, Show)", ""])
    return lines


def haskell_signature(name: str, signature: str) -> list[str]:
    line = f"{name} :: {signature}"
    if len(line) <= 80:
        return [line]
    return [f"{name} ::", f"     {signature}"]


def haskell_text_projection(
    function_name: str, type_name: str, constructors: dict[str, str]
) -> list[str]:
    lines = haskell_signature(function_name, f"{type_name} -> Text")
    lines.append(f"{function_name} value =")
    lines.append("  case value of")
    for value, constructor in constructors.items():
        literal = json.dumps(value, ensure_ascii=True)
        branch = f"    {constructor} -> {literal}"
        if len(branch) <= 80:
            lines.append(branch)
        else:
            lines.extend([f"    {constructor} ->", f"      {literal}"])
    lines.append("")
    return lines


def haskell_text_lookup(
    function_name: str, type_name: str, constructors: dict[str, str]
) -> list[str]:
    lines = haskell_signature(function_name, f"Text -> Maybe {type_name}")
    lines.append(f"{function_name} value =")
    lines.append("  case value of")
    for value, constructor in constructors.items():
        literal = json.dumps(value, ensure_ascii=True)
        branch = f"    {literal} -> Just {constructor}"
        if len(branch) <= 80:
            lines.append(branch)
        else:
            lines.extend([f"    {literal} ->", f"      Just {constructor}"])
    lines.extend(["    _ -> Nothing", ""])
    return lines


def haskell_nonempty(name: str, type_name: str, values: list[str]) -> list[str]:
    head, *tail = values
    lines = haskell_signature(name, f"NonEmpty {type_name}")
    if not tail:
        assignment = f"{name} = {head} :| []"
        if len(assignment) <= 80:
            lines.extend([assignment, ""])
        else:
            lines.extend([f"{name} =", f"  {head} :| []", ""])
        return lines
    if len(tail) == 1:
        value = f"{head} :| [{tail[0]}]"
        if len(f"  {value}") <= 80:
            lines.extend([f"{name} =", f"  {value}", ""])
        else:
            lines.extend([f"{name} =", f"  {head}", f"    :| [{tail[0]}]", ""])
        return lines
    lines.extend([f"{name} =", f"  {head}", f"    :| [ {tail[0]}"])
    lines.extend(f"       , {value}" for value in tail[1:])
    lines.extend(["       ]", ""])
    return lines


def haskell_supplemental_rule_identity_contract(
    associations: dict[str, tuple[str, str]],
) -> list[str]:
    constructors = [constructor for constructor, _ in associations.values()]
    rules = {
        rule: constructor for constructor, rule in associations.values()
    }
    lines = haskell_data("GeneratedSupplementalRuleIdentity", constructors)
    lines.extend(
        haskell_text_projection(
            "generatedSupplementalRuleIdentityText",
            "GeneratedSupplementalRuleIdentity",
            rules,
        )
    )
    lines.extend(
        haskell_nonempty(
            "generatedSupplementalRuleIdentities",
            "GeneratedSupplementalRuleIdentity",
            constructors,
        )
    )
    return lines


def haskell_semantic_contract(
    semantic_rules: list[str],
    schemas: dict[str, list[str]],
    mappings: dict[str, str],
    occurrences: dict[str, list[tuple[str, str]]],
) -> list[str]:
    schema_stems = constructor_catalog(
        "Generated", list(schemas), "semantic evidence-key schema catalog"
    )
    schema_constructors = {
        schema: f"{stem}Schema" for schema, stem in schema_stems.items()
    }
    witness_constructors = {
        schema: f"{stem}Witness" for schema, stem in schema_stems.items()
    }
    rule_constructors = {
        rule: semantic_rule_constructor(rule)
        for rule in mappings
    }
    occurrence_schema_constructors = {
        rule: semantic_rule_constructor(rule).removesuffix("Rule")
        + "OccurrenceSchema"
        for rule in mappings
    }
    occurrence_constructors = {
        rule: semantic_rule_constructor(rule).removesuffix("Rule")
        + "Occurrences"
        for rule in mappings
    }
    identity_constructors = {
        rule: f"{semantic_rule_constructor(rule)}Identity"
        for rule in semantic_rules
    }
    if len(rule_constructors) != len(set(rule_constructors.values())):
        raise ValueError("semantic rule catalog: Haskell constructor collision")
    generated_constructors = (
        list(identity_constructors.values())
        + list(schema_constructors.values())
        + list(witness_constructors.values())
        + list(rule_constructors.values())
        + list(occurrence_schema_constructors.values())
        + list(occurrence_constructors.values())
    )
    if len(generated_constructors) != len(set(generated_constructors)):
        raise ValueError("semantic contract: Haskell constructor collision")

    lines = haskell_data(
        "GeneratedSemanticRuleIdentity", list(identity_constructors.values())
    )
    lines.extend(
        haskell_text_projection(
            "generatedSemanticRuleIdentityText",
            "GeneratedSemanticRuleIdentity",
            identity_constructors,
        )
    )
    lines.extend(
        [
            "generatedSemanticRuleIdentityRank ::",
            "     GeneratedSemanticRuleIdentity -> Int",
            "generatedSemanticRuleIdentityRank = fromEnum",
            "",
        ]
    )
    lines.extend(
        haskell_nonempty(
            "generatedSemanticRuleIdentities",
            "GeneratedSemanticRuleIdentity",
            list(identity_constructors.values()),
        )
    )
    lines.extend(
        [
            "semanticsRuleIds :: NonEmpty Text",
            "semanticsRuleIds =",
            "  generatedSemanticRuleIdentityText",
            "    <$> generatedSemanticRuleIdentities",
            "",
        ]
    )

    lines.extend(haskell_data(
        "GeneratedSemanticEvidenceSchema", list(schema_constructors.values())
    ))
    lines.extend(
        [
            "data GeneratedSemanticEvidenceSchemaWitness",
            "       (schema :: GeneratedSemanticEvidenceSchema) where",
        ]
    )
    for schema, constructor in witness_constructors.items():
        lines.extend(
            [
                f"  {constructor} ::",
                "    GeneratedSemanticEvidenceSchemaWitness",
                f"      '{schema_constructors[schema]}",
            ]
        )
    lines.append("")
    lines.extend(
        [
            "generatedSemanticEvidenceSchemaName ::",
            "     GeneratedSemanticEvidenceSchemaWitness schema -> Text",
            "generatedSemanticEvidenceSchemaName witness =",
            "  case witness of",
        ]
    )
    for schema, constructor in witness_constructors.items():
        lines.append(f"    {constructor} -> {json.dumps(schema)}")
    lines.append("")
    lines.extend(
        [
            "generatedSemanticEvidenceSchemaFields ::",
            "     GeneratedSemanticEvidenceSchemaWitness schema",
            "  -> NonEmpty Text",
            "generatedSemanticEvidenceSchemaFields witness =",
            "  case witness of",
        ]
    )
    for schema, constructor in witness_constructors.items():
        fields = schemas[schema]
        head, *tail = fields
        if not tail:
            lines.append(
                f"    {constructor} -> {json.dumps(head)} :| []"
            )
            continue
        lines.extend(
            [
                f"    {constructor} ->",
                f"      {json.dumps(head)}",
                f"        :| [ {json.dumps(tail[0])}",
            ]
        )
        lines.extend(f"           , {json.dumps(field)}" for field in tail[1:])
        lines.append("           ]")
    lines.append("")

    lines.extend(
        haskell_data(
            "GeneratedSemanticOccurrenceSchema",
            list(occurrence_schema_constructors.values()),
        )
    )
    lines.extend(
        [
            "data GeneratedSemanticOccurrenceEvidence",
            "       (schema :: GeneratedSemanticOccurrenceSchema)",
            "       occurrence where",
        ]
    )
    for rule, constructor in occurrence_constructors.items():
        field_types = {
            "zero": [],
            "one": ["!occurrence"],
            "one-or-more": ["!(NonEmpty occurrence)"],
            "zero-or-more": ["![occurrence]"],
        }
        fields = [
            field
            for _, cardinality in occurrences[rule]
            for field in field_types[cardinality]
        ]
        lines.append(f"  {constructor} ::")
        lines.extend(f"       {field} ->" for field in fields)
        lines.extend(
            [
                "       GeneratedSemanticOccurrenceEvidence",
                f"         '{occurrence_schema_constructors[rule]}",
                "         occurrence",
            ]
        )
    lines.append("")
    lines.extend(
        [
            "generatedSemanticOccurrenceEvidenceGroups ::",
            "     GeneratedSemanticOccurrenceEvidence schema occurrence",
            "  -> NonEmpty (Text, [occurrence])",
            "generatedSemanticOccurrenceEvidenceGroups evidence =",
            "  case evidence of",
        ]
    )
    for rule, constructor in occurrence_constructors.items():
        roles = occurrences[rule]
        binders = [
            f"occurrence{index}"
            for index, (_, cardinality) in enumerate(roles)
            if cardinality != "zero"
        ]
        pattern = " ".join([constructor, *binders])
        groups: list[str] = []
        binder_index = 0
        for role, cardinality in roles:
            if cardinality == "zero":
                values = "[]"
            else:
                binder = binders[binder_index]
                binder_index += 1
                if cardinality == "one":
                    values = f"[{binder}]"
                elif cardinality == "one-or-more":
                    values = f"NonEmpty.toList {binder}"
                else:
                    values = binder
            groups.append(f"({json.dumps(role)}, {values})")
        head, *tail = groups
        lines.append(f"    {pattern} ->")
        lines.append(f"      {head}")
        if tail:
            lines.append(f"        :| [ {tail[0]}")
            lines.extend(f"           , {group}" for group in tail[1:])
            lines.append("           ]")
        else:
            lines.append("        :| []")
    lines.append("")

    lines.extend(
        [
            "data GeneratedSemanticRule",
            "       (schema :: GeneratedSemanticEvidenceSchema)",
            "       (occurrenceSchema :: GeneratedSemanticOccurrenceSchema) where",
        ]
    )
    for rule, constructor in rule_constructors.items():
        lines.extend(
            [
                f"  {constructor} ::",
                "    GeneratedSemanticRule",
                f"      '{schema_constructors[mappings[rule]]}",
                f"      '{occurrence_schema_constructors[rule]}",
            ]
        )
    lines.append("")

    lines.extend(
        [
            "generatedSemanticRuleId ::",
            "     GeneratedSemanticRule schema occurrenceSchema -> Text",
            "generatedSemanticRuleId =",
            "  generatedSemanticRuleIdentityText . generatedSemanticRuleIdentity",
            "",
            "generatedSemanticRuleIdentity ::",
            "     GeneratedSemanticRule schema occurrenceSchema",
            "  -> GeneratedSemanticRuleIdentity",
            "generatedSemanticRuleIdentity rule =",
            "  case rule of",
        ]
    )
    for rule, constructor in rule_constructors.items():
        lines.extend(
            [
                f"    {constructor} ->",
                f"      {identity_constructors[rule]}",
            ]
        )
    lines.append("")

    lines.extend(
        [
            "generatedSemanticRuleRank ::",
            "     GeneratedSemanticRule schema occurrenceSchema -> Int",
            "generatedSemanticRuleRank =",
            "  generatedSemanticRuleIdentityRank . generatedSemanticRuleIdentity",
        ]
    )
    lines.append("")

    lines.extend(
        [
            "generatedSemanticRuleEvidenceSchema ::",
            "     GeneratedSemanticRule schema occurrenceSchema",
            "  -> GeneratedSemanticEvidenceSchemaWitness schema",
            "generatedSemanticRuleEvidenceSchema rule =",
            "  case rule of",
        ]
    )
    for rule, constructor in rule_constructors.items():
        lines.extend(
            [
                f"    {constructor} ->",
                f"      {witness_constructors[mappings[rule]]}",
            ]
        )
    lines.append("")

    return lines


def compile_outputs() -> tuple[str, bytes]:
    companion, payload = load_companion()
    require_exact(companion["schema"], "o2i.core-semantics/target-v46", "schema")
    require_exact(
        companion["coreIdentity"],
        {"identity": "o2i.core-semantics", "version": "0.3.0"},
        "Core identity",
    )

    declared_shape = companion["companionFormatContract"]["shapeSha256"]
    require_exact(declared_shape, shape_sha256(companion), "shape SHA-256")
    require_exact(declared_shape, EXPECTED_SHAPE_SHA256, "accepted shape SHA-256")
    require_exact(
        companion["selectedViewDependencyContract"]["outcomePrecedence"],
        [
            "unknown-model-identity",
            "ambiguous-model-identity",
            "model-identity-out-of-selected-view",
            "wrong-model-identity-type",
            "resolved",
        ],
        "selected View identity precedence",
    )
    require_exact(
        companion["evidenceInputDecoderContract"]["identityResolutionPrecedence"],
        [
            "unknown",
            "ambiguous",
            "out-of-selected-view",
            "wrong-qualified-type",
            "resolved",
        ],
        "evidence identity precedence",
    )

    rules = rule_inventory(companion)
    declared_rules = require_nonempty_unique_strings(
        companion["ruleIdentityContract"]["completeRuleInventory"],
        "complete Core rule inventory",
    )
    require_exact(declared_rules, rules, "complete Core rule inventory derivation")
    require_exact(
        companion["ruleIdentityContract"]["completeRuleInventoryDerivation"][
            "cardinality"
        ],
        len(rules),
        "complete Core rule inventory cardinality",
    )
    stages = rule_stage_partition(companion, rules)
    evidence_schemas, evidence_mappings = semantic_evidence_contract(
        companion, stages["semantics"]
    )
    supplemental_rule_associations = supplemental_rule_identity_associations(
        companion
    )
    supplemental_rules = [
        rule for _, rule in supplemental_rule_associations.values()
    ]
    require_exact(
        sorted(supplemental_rules, key=lambda value: value.encode("utf-8")),
        sorted(
            companion["supplementalInputContract"]["ruleIds"].values(),
            key=lambda value: value.encode("utf-8"),
        ),
        "supplemental rule identity derivation",
    )
    if not set(supplemental_rules).issubset(stages["capability-input"]):
        raise ValueError(
            "supplemental rule identity catalog: rule outside capability-input stage"
        )

    relation_tokens = require_nonempty_unique_strings(
        companion["relationTokenCatalog"], "relation token catalog"
    )
    endpoint_rows = require_catalog_rows(
        companion["qualifiedEndpointCatalog"],
        {"id", "o2iType", "carrierCategory"},
        "qualified endpoint catalog",
    )
    endpoints = require_nonempty_unique_strings(
        [entry["id"] for entry in endpoint_rows],
        "qualified endpoint catalog",
    )
    endpoint_set = set(endpoints)
    relation_rows = require_catalog_rows(
        companion["relationSemantics"],
        {"id", "source", "target", "relationToken"},
        "semantic relation catalog",
    )
    relation_ids = require_nonempty_unique_strings(
        [entry["id"] for entry in relation_rows], "semantic relation catalog"
    )
    for index, entry in enumerate(relation_rows):
        if entry["source"] not in endpoint_set:
            raise ValueError(
                f"semantic relation catalog[{index}]: unknown source endpoint"
            )
        if entry["target"] not in endpoint_set:
            raise ValueError(
                f"semantic relation catalog[{index}]: unknown target endpoint"
            )
        if entry["relationToken"] not in relation_tokens:
            raise ValueError(
                f"semantic relation catalog[{index}]: unknown relation token"
            )
    family_rows = require_catalog_rows(
        companion["structuredPropositionFamilies"],
        {"id", "propositionType", "composition", "participant", "target"},
        "structured proposition family catalog",
    )
    families = require_nonempty_unique_strings(
        [entry["id"] for entry in family_rows],
        "structured proposition family catalog",
    )
    roles = require_nonempty_unique_strings(
        [
            role
            for entry in family_rows
            for role in (entry["participant"]["roleId"], entry["target"]["roleId"])
        ],
        "structured proposition role catalog",
    )
    qualification = companion["qualificationProposalSemantics"]
    qualification_role_rows = qualification["roles"]
    if not isinstance(qualification_role_rows, dict) or not qualification_role_rows:
        raise ValueError("qualification proposal role catalog: expected an object")
    qualification_role_order = require_nonempty_unique_strings(
        qualification["routingContract"]["roleOrder"],
        "qualification proposal role order",
    )
    require_exact(
        sorted(qualification_role_rows),
        sorted(qualification_role_order),
        "qualification proposal role catalog membership",
    )
    qualification_roles: list[str] = []
    for role_name in qualification_role_order:
        row = qualification_role_rows[role_name]
        if not isinstance(row, dict):
            raise ValueError(
                f"qualification proposal role {role_name}: expected an object"
            )
        missing = {"id", "target", "cardinality", "ruleIds"}.difference(row)
        if missing:
            raise ValueError(
                f"qualification proposal role {role_name}: "
                f"missing members {sorted(missing)!r}"
            )
        if row["target"] not in endpoint_set:
            raise ValueError(
                f"qualification proposal role {role_name}: unknown target endpoint"
            )
        qualification_roles.append(row["id"])
    qualification_roles = require_nonempty_unique_strings(
        qualification_roles,
        "qualification proposal role identity catalog",
    )

    carrier_categories = sorted(
        {entry["carrierCategory"] for entry in endpoint_rows},
        key=lambda value: value.encode("utf-8"),
    )
    o2i_types = sorted(
        {entry["o2iType"] for entry in endpoint_rows},
        key=lambda value: value.encode("utf-8"),
    )

    endpoint_constructors = constructor_catalog(
        "GeneratedEndpoint", endpoints, "qualified endpoint catalog"
    )
    token_constructors = constructor_catalog(
        "GeneratedToken", relation_tokens, "relation token catalog"
    )
    relation_constructors = constructor_catalog(
        "GeneratedRelation", relation_ids, "semantic relation catalog"
    )
    family_constructors = constructor_catalog(
        "GeneratedFamily", families, "structured proposition family catalog"
    )
    role_constructors = constructor_catalog(
        "GeneratedRole", roles, "structured proposition role catalog"
    )
    qualification_role_constructors = constructor_catalog(
        "GeneratedQualificationRole",
        qualification_roles,
        "qualification proposal role identity catalog",
    )
    compositions = require_nonempty_unique_strings(
        list(dict.fromkeys(entry["composition"] for entry in family_rows)),
        "structured proposition composition catalog",
    )
    cardinalities = require_nonempty_unique_strings(
        list(
            dict.fromkeys(
                cardinality
                for entry in family_rows
                for cardinality in (
                    entry["participant"]["cardinality"],
                    entry["target"]["cardinality"],
                )
            )
        ),
        "structured proposition cardinality catalog",
    )
    completeness_rows = require_catalog_rows(
        [
            value
            for entry in family_rows
            for value in entry["participantCompleteness"]["values"]
        ],
        {"id", "token"},
        "participant completeness catalog",
    )
    require_nonempty_unique_strings(
        [value["id"] for value in completeness_rows],
        "participant completeness identity catalog",
    )
    require_nonempty_unique_strings(
        [value["token"] for value in completeness_rows],
        "participant completeness token catalog",
    )
    for index, entry in enumerate(family_rows):
        for role_name in ("participant", "target"):
            if entry[role_name]["target"] not in endpoint_set:
                raise ValueError(
                    f"structured proposition family catalog[{index}]: "
                    f"unknown {role_name} endpoint"
                )
    composition_constructors = constructor_catalog(
        "GeneratedComposition",
        compositions,
        "structured proposition composition catalog",
    )
    cardinality_constructors = constructor_catalog(
        "GeneratedCardinality",
        cardinalities,
        "structured proposition cardinality catalog",
    )
    completeness_constructors = constructor_catalog(
        "GeneratedCompleteness",
        [value["token"] for value in completeness_rows],
        "participant completeness token catalog",
    )
    completeness_id_constructors = {
        value["id"]: completeness_constructors[value["token"]]
        for value in completeness_rows
    }
    completeness_token_constructors = dict(completeness_constructors)
    category_constructors = constructor_catalog(
        "GeneratedCarrier", carrier_categories, "carrier category catalog"
    )
    type_constructors = constructor_catalog(
        "GeneratedType", o2i_types, "O2I type catalog"
    )
    require_exact(sha256(payload), EXPECTED_SHA256, "accepted file SHA-256")
    diagnostic, diagnostic_payload = load_diagnostic_companion()
    evidence_schemas, evidence_mappings, occurrence_mappings = (
        semantic_diagnostic_contract(
            diagnostic,
            diagnostic_payload,
            payload,
            stages["semantics"],
            evidence_schemas,
            evidence_mappings,
        )
    )
    inventory = diagnostic_inventory(
        companion,
        payload,
        diagnostic,
        diagnostic_payload,
        evidence_schemas,
        evidence_mappings,
        occurrence_mappings,
    )

    def string_literal(value: str) -> str:
        return json.dumps(value, ensure_ascii=True)

    def nonempty(name: str, values: list[str]) -> list[str]:
        head, *tail = values
        if not tail:
            return [
                f"{name} :: NonEmpty Text",
                f"{name} = {string_literal(head)} :| []",
                "",
            ]
        result = [f"{name} :: NonEmpty Text", f"{name} ="]
        result.extend(
            [
                f"  {string_literal(head)}",
                "    :| [ " + string_literal(tail[0]),
            ]
        )
        result.extend("       , " + string_literal(value) for value in tail[1:])
        result.extend(["       ]", ""])
        return result

    lines = [
        "{-# LANGUAGE DataKinds #-}",
        "{-# LANGUAGE GADTs #-}",
        "{-# LANGUAGE KindSignatures #-}",
        "{-# LANGUAGE OverloadedStrings #-}",
        "",
        "-- This module is generated by contract/compile.py. Do not edit.",
        "module O2I.Core.Contract.Generated where",
        "",
        "import Data.List.NonEmpty (NonEmpty(..))",
        "import qualified Data.List.NonEmpty as NonEmpty",
        "import Data.Text (Text)",
        "",
        "contractIdentity :: Text",
        f"contractIdentity = {string_literal(companion['coreIdentity']['identity'])}",
        "",
        "contractVersion :: Text",
        f"contractVersion = {string_literal(companion['coreIdentity']['version'])}",
        "",
        "contractSha256 :: Text",
        "contractSha256 =",
        f"  {string_literal(sha256(payload))}",
        "",
        "contractShapeSha256 :: Text",
        "contractShapeSha256 =",
        f"  {string_literal(declared_shape)}",
        "",
        "diagnosticContractSha256 :: Text",
        "diagnosticContractSha256 =",
        f"  {string_literal(sha256(diagnostic_payload))}",
        "",
        "diagnosticContractShapeSha256 :: Text",
        "diagnosticContractShapeSha256 =",
        f"  {string_literal(shape_sha256(diagnostic))}",
        "",
    ]
    lines.extend(
        haskell_data(
            "GeneratedCarrierCategory", list(category_constructors.values())
        )
    )
    lines.extend(
        haskell_text_projection(
            "generatedCarrierCategoryText",
            "GeneratedCarrierCategory",
            category_constructors,
        )
    )
    lines.extend(
        haskell_text_lookup(
            "lookupGeneratedCarrierCategory",
            "GeneratedCarrierCategory",
            category_constructors,
        )
    )
    lines.extend(
        haskell_nonempty(
            "generatedCarrierCategories",
            "GeneratedCarrierCategory",
            list(category_constructors.values()),
        )
    )
    lines.extend(haskell_data("GeneratedO2IType", list(type_constructors.values())))
    lines.extend(
        haskell_text_projection(
            "generatedO2ITypeText", "GeneratedO2IType", type_constructors
        )
    )
    lines.extend(
        haskell_text_lookup(
            "lookupGeneratedO2IType", "GeneratedO2IType", type_constructors
        )
    )
    lines.extend(
        haskell_nonempty(
            "generatedO2ITypes",
            "GeneratedO2IType",
            list(type_constructors.values()),
        )
    )
    lines.extend(
        haskell_data(
            "GeneratedQualifiedEndpoint", list(endpoint_constructors.values())
        )
    )
    lines.extend(
        haskell_text_projection(
            "generatedQualifiedEndpointText",
            "GeneratedQualifiedEndpoint",
            endpoint_constructors,
        )
    )
    lines.extend(
        haskell_text_lookup(
            "lookupGeneratedQualifiedEndpoint",
            "GeneratedQualifiedEndpoint",
            endpoint_constructors,
        )
    )
    lines.extend(
        [
            "data GeneratedQualifiedEndpointRow =",
            "  GeneratedQualifiedEndpointRow",
            "    !GeneratedQualifiedEndpoint",
            "    !GeneratedCarrierCategory",
            "    !(Maybe GeneratedO2IType)",
            "    !GeneratedO2IType",
            "  deriving (Eq, Ord, Show)",
            "",
            "generatedQualifiedEndpointRow ::",
            "     GeneratedQualifiedEndpoint -> GeneratedQualifiedEndpointRow",
            "generatedQualifiedEndpointRow endpoint =",
            "  case endpoint of",
        ]
    )
    for entry in endpoint_rows:
        context = entry.get("contextType")
        context_expression = (
            "Nothing"
            if context is None
            else f"Just {type_constructors[context]}"
        )
        lines.extend(
            [
                f"    {endpoint_constructors[entry['id']]} ->",
                "      GeneratedQualifiedEndpointRow",
                f"        {endpoint_constructors[entry['id']]}",
                f"        {category_constructors[entry['carrierCategory']]}",
                f"        ({context_expression})",
                f"        {type_constructors[entry['o2iType']]}",
            ]
        )
    lines.append("")
    lines.extend(
        haskell_nonempty(
            "generatedQualifiedEndpoints",
            "GeneratedQualifiedEndpoint",
            list(endpoint_constructors.values()),
        )
    )
    lines.extend(
        [
            "generatedQualifiedEndpointRows :: NonEmpty GeneratedQualifiedEndpointRow",
            "generatedQualifiedEndpointRows =",
            "  generatedQualifiedEndpointRow <$> generatedQualifiedEndpoints",
            "",
        ]
    )

    lines.extend(
        haskell_data("GeneratedRelationToken", list(token_constructors.values()))
    )
    lines.extend(
        haskell_text_projection(
            "generatedRelationTokenText",
            "GeneratedRelationToken",
            token_constructors,
        )
    )
    lines.extend(
        haskell_text_lookup(
            "lookupGeneratedRelationToken",
            "GeneratedRelationToken",
            token_constructors,
        )
    )
    lines.extend(
        haskell_nonempty(
            "generatedRelationTokens",
            "GeneratedRelationToken",
            list(token_constructors.values()),
        )
    )
    lines.extend(
        haskell_data(
            "GeneratedSemanticRelation", list(relation_constructors.values())
        )
    )
    lines.extend(
        [
            "data GeneratedSemanticRelationRow =",
            "  GeneratedSemanticRelationRow",
            "    !GeneratedSemanticRelation",
            "    !GeneratedQualifiedEndpoint",
            "    !GeneratedQualifiedEndpoint",
            "    !GeneratedRelationToken",
            "  deriving (Eq, Ord, Show)",
            "",
            "generatedSemanticRelationRow ::",
            "     GeneratedSemanticRelation -> GeneratedSemanticRelationRow",
            "generatedSemanticRelationRow relation =",
            "  case relation of",
        ]
    )
    for entry in relation_rows:
        lines.extend(
            [
                f"    {relation_constructors[entry['id']]} ->",
                "      GeneratedSemanticRelationRow",
                f"        {relation_constructors[entry['id']]}",
                f"        {endpoint_constructors[entry['source']]}",
                f"        {endpoint_constructors[entry['target']]}",
                f"        {token_constructors[entry['relationToken']]}",
            ]
        )
    lines.append("")
    lines.extend(
        haskell_nonempty(
            "generatedSemanticRelations",
            "GeneratedSemanticRelation",
            list(relation_constructors.values()),
        )
    )
    lines.extend(
        [
            "generatedSemanticRelationRows :: NonEmpty GeneratedSemanticRelationRow",
            "generatedSemanticRelationRows =",
            "  generatedSemanticRelationRow <$> generatedSemanticRelations",
            "",
        ]
    )

    lines.extend(
        haskell_data(
            "GeneratedStructuredPropositionFamily",
            list(family_constructors.values()),
        )
    )
    lines.extend(
        haskell_text_projection(
            "generatedStructuredPropositionFamilyText",
            "GeneratedStructuredPropositionFamily",
            family_constructors,
        )
    )
    lines.extend(
        haskell_text_lookup(
            "lookupGeneratedStructuredPropositionFamily",
            "GeneratedStructuredPropositionFamily",
            family_constructors,
        )
    )
    lines.extend(
        haskell_nonempty(
            "generatedStructuredPropositionFamilies",
            "GeneratedStructuredPropositionFamily",
            list(family_constructors.values()),
        )
    )
    lines.extend(
        haskell_data(
            "GeneratedStructuredPropositionRole", list(role_constructors.values())
        )
    )
    lines.extend(
        haskell_text_projection(
            "generatedStructuredPropositionRoleText",
            "GeneratedStructuredPropositionRole",
            role_constructors,
        )
    )
    lines.extend(
        haskell_text_lookup(
            "lookupGeneratedStructuredPropositionRole",
            "GeneratedStructuredPropositionRole",
            role_constructors,
        )
    )
    lines.extend(
        haskell_nonempty(
            "generatedStructuredPropositionRoles",
            "GeneratedStructuredPropositionRole",
            list(role_constructors.values()),
        )
    )
    lines.extend(
        haskell_data(
            "GeneratedQualificationProposalRole",
            list(qualification_role_constructors.values()),
        )
    )
    lines.extend(
        haskell_text_projection(
            "generatedQualificationProposalRoleText",
            "GeneratedQualificationProposalRole",
            qualification_role_constructors,
        )
    )
    lines.extend(
        haskell_text_lookup(
            "lookupGeneratedQualificationProposalRole",
            "GeneratedQualificationProposalRole",
            qualification_role_constructors,
        )
    )
    lines.extend(
        haskell_nonempty(
            "generatedQualificationProposalRoles",
            "GeneratedQualificationProposalRole",
            list(qualification_role_constructors.values()),
        )
    )
    lines.extend(
        haskell_data(
            "GeneratedStructuredComposition",
            list(composition_constructors.values()),
        )
    )
    lines.extend(
        haskell_data(
            "GeneratedStructuredCardinality",
            list(cardinality_constructors.values()),
        )
    )
    lines.extend(
        haskell_data(
            "GeneratedParticipantCompleteness",
            list(completeness_constructors.values()),
        )
    )
    lines.extend(
        haskell_text_projection(
            "generatedParticipantCompletenessIdText",
            "GeneratedParticipantCompleteness",
            completeness_id_constructors,
        )
    )
    lines.extend(
        haskell_text_projection(
            "generatedParticipantCompletenessToken",
            "GeneratedParticipantCompleteness",
            completeness_token_constructors,
        )
    )
    lines.extend(
        haskell_text_lookup(
            "lookupGeneratedParticipantCompletenessId",
            "GeneratedParticipantCompleteness",
            completeness_id_constructors,
        )
    )
    lines.extend(
        haskell_text_lookup(
            "lookupGeneratedParticipantCompletenessToken",
            "GeneratedParticipantCompleteness",
            completeness_token_constructors,
        )
    )
    lines.extend(
        haskell_nonempty(
            "generatedParticipantCompletenessValues",
            "GeneratedParticipantCompleteness",
            list(completeness_constructors.values()),
        )
    )
    lines.extend(
        [
            "data GeneratedStructuredFamilyRow =",
            "  GeneratedStructuredFamilyRow",
            "    !GeneratedStructuredPropositionFamily",
            "    !Text",
            "    !GeneratedStructuredComposition",
            "    !GeneratedStructuredPropositionRole",
            "    !GeneratedQualifiedEndpoint",
            "    !GeneratedStructuredCardinality",
            "    !Bool",
            "    !GeneratedStructuredPropositionRole",
            "    !GeneratedQualifiedEndpoint",
            "    !GeneratedStructuredCardinality",
            "    !Bool",
            "    !(NonEmpty GeneratedParticipantCompleteness)",
            "    !Bool",
            "  deriving (Eq, Ord, Show)",
            "",
            "generatedStructuredFamilyRow ::",
            "     GeneratedStructuredPropositionFamily -> GeneratedStructuredFamilyRow",
            "generatedStructuredFamilyRow family =",
            "  case family of",
        ]
    )
    for entry in family_rows:
        completeness = [
            completeness_constructors[value["token"]]
            for value in entry["participantCompleteness"]["values"]
        ]
        completeness_expression = (
            f"{completeness[0]} :| [" + ", ".join(completeness[1:]) + "]"
        )
        asserted_requires_closed = (
            entry["commitmentSensitivity"]
            == "asserted-requires-closed-participant-completeness"
        )
        lines.extend(
            [
                f"    {family_constructors[entry['id']]} ->",
                "      GeneratedStructuredFamilyRow",
                f"        {family_constructors[entry['id']]}",
                f"        {string_literal(entry['propositionType'])}",
                f"        {composition_constructors[entry['composition']]}",
                f"        {role_constructors[entry['participant']['roleId']]}",
                f"        {endpoint_constructors[entry['participant']['target']]}",
                f"        {cardinality_constructors[entry['participant']['cardinality']]}",
                f"        {str(entry['participant']['uniqueness'] == 'distinct')}",
                f"        {role_constructors[entry['target']['roleId']]}",
                f"        {endpoint_constructors[entry['target']['target']]}",
                f"        {cardinality_constructors[entry['target']['cardinality']]}",
                f"        {str(bool(entry['target']['distinctFromParticipants']))}",
                f"        ({completeness_expression})",
                f"        {str(asserted_requires_closed)}",
            ]
        )
    lines.append("")
    lines.extend(
        [
            "generatedStructuredFamilyRows :: NonEmpty GeneratedStructuredFamilyRow",
            "generatedStructuredFamilyRows =",
            "  generatedStructuredFamilyRow <$> generatedStructuredPropositionFamilies",
            "",
        ]
    )
    lines.extend(
        haskell_semantic_contract(
            stages["semantics"],
            evidence_schemas,
            evidence_mappings,
            occurrence_mappings,
        )
    )
    lines.extend(
        haskell_supplemental_rule_identity_contract(
            supplemental_rule_associations
        )
    )
    lines.extend(nonempty("ruleIds", rules))
    lines.extend(nonempty("capabilityInputRuleIds", stages["capability-input"]))
    lines.extend(nonempty("qualificationRuleIds", stages["qualification"]))
    lines.extend(
        nonempty(
            "readinessAndAssessmentRuleIds",
            stages["readiness-and-assessment"],
        )
    )
    lines.extend(nonempty("structureRuleIds", stages["structure"]))
    lines.extend(nonempty("traceRuleIds", stages["trace"]))
    lines.extend(nonempty("relationTokens", relation_tokens))
    lines.extend(nonempty("qualifiedEndpointIds", endpoints))
    lines.extend(nonempty("structuredPropositionFamilyIds", families))
    rendered = "\n".join(lines)
    formatted = subprocess.run(
        ["hindent", "--line-length", "80"],
        input=rendered,
        text=True,
        capture_output=True,
        check=False,
    )
    if formatted.returncode != 0:
        raise ValueError(
            f"hindent rejected generated Core projection: {formatted.stderr}"
        )
    return formatted.stdout, inventory


def compile_contract() -> str:
    return compile_outputs()[0]


def compile_inventory() -> bytes:
    return compile_outputs()[1]


def compile_owner_inventory() -> bytes:
    companion, payload = load_companion()
    return owner_diagnostic_inventory(companion, payload, compile_inventory())


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--write", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    expected_haskell, expected_inventory = compile_outputs()
    expected_owner_inventory = owner_diagnostic_inventory(
        *load_companion(), expected_inventory
    )
    expected = expected_haskell.encode("utf-8")
    if args.write:
        GENERATED.parent.mkdir(parents=True, exist_ok=True)
        GENERATED.write_bytes(expected)
        GENERATED_INVENTORY.parent.mkdir(parents=True, exist_ok=True)
        GENERATED_INVENTORY.write_bytes(expected_inventory)
        GENERATED_OWNER_INVENTORY.parent.mkdir(parents=True, exist_ok=True)
        GENERATED_OWNER_INVENTORY.write_bytes(expected_owner_inventory)
        return
    actual = GENERATED.read_bytes()
    if actual != expected:
        raise SystemExit(f"generated Core contract is stale: {GENERATED}")
    actual_inventory = GENERATED_INVENTORY.read_bytes()
    try:
        validate_generated_inventory(actual_inventory)
    except ValueError as error:
        raise SystemExit(
            f"generated Core diagnostic inventory is stale: {GENERATED_INVENTORY}"
        ) from error
    if (
        not GENERATED_OWNER_INVENTORY.exists()
        or GENERATED_OWNER_INVENTORY.read_bytes() != expected_owner_inventory
    ):
        raise SystemExit(
            "generated Core owner diagnostic inventory is stale: "
            f"{GENERATED_OWNER_INVENTORY}"
        )


if __name__ == "__main__":
    main()
