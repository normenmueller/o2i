#!/usr/bin/env python3
"""Compile the authoritative Core companion into its private Haskell projection."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
COMPANION = PACKAGE_ROOT / "semantics.json"
GENERATED = PACKAGE_ROOT / "src/O2I/Core/Contract/Generated.hs"
EXPECTED_SHAPE_SHA256 = (
    "3e091e8bc0fd3a887da02f8591292c2a8ea7d64c7e83951183ab71fe4f5b1278"
)
EXPECTED_SHA256 = (
    "fa431df65d5a5fdd64d91d5ad4089a3e8e31421027f4e0258370e742c8b1a333"
)


def reject_constant(value: str) -> None:
    raise ValueError(f"invalid JSON numeric constant: {value}")


def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON object member: {key}")
        result[key] = value
    return result


def load_companion() -> tuple[dict[str, Any], bytes]:
    payload = COMPANION.read_bytes()
    value = json.loads(
        payload.decode("utf-8"),
        object_pairs_hook=unique_object,
        parse_constant=reject_constant,
    )
    if not isinstance(value, dict):
        raise ValueError("Core companion must be one JSON object")
    return value, payload


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


def haskell_semantic_contract(
    semantic_rules: list[str],
    schemas: dict[str, list[str]],
    mappings: dict[str, str],
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
        [
            "data GeneratedSemanticRule",
            "       (schema :: GeneratedSemanticEvidenceSchema) where",
        ]
    )
    for rule, constructor in rule_constructors.items():
        lines.extend(
            [
                f"  {constructor} ::",
                "    GeneratedSemanticRule",
                f"      '{schema_constructors[mappings[rule]]}",
            ]
        )
    lines.append("")

    lines.extend(
        [
            "generatedSemanticRuleId :: GeneratedSemanticRule schema -> Text",
            "generatedSemanticRuleId =",
            "  generatedSemanticRuleIdentityText . generatedSemanticRuleIdentity",
            "",
            "generatedSemanticRuleIdentity ::",
            "     GeneratedSemanticRule schema",
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
            "generatedSemanticRuleRank :: GeneratedSemanticRule schema -> Int",
            "generatedSemanticRuleRank =",
            "  generatedSemanticRuleIdentityRank . generatedSemanticRuleIdentity",
        ]
    )
    lines.append("")

    lines.extend(
        [
            "generatedSemanticRuleEvidenceSchema ::",
            "     GeneratedSemanticRule schema",
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


def compile_contract() -> str:
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
            stages["semantics"], evidence_schemas, evidence_mappings
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
    return formatted.stdout


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--write", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    expected = compile_contract().encode("utf-8")
    if args.write:
        GENERATED.parent.mkdir(parents=True, exist_ok=True)
        GENERATED.write_bytes(expected)
        return
    actual = GENERATED.read_bytes()
    if actual != expected:
        raise SystemExit(f"generated Core contract is stale: {GENERATED}")


if __name__ == "__main__":
    main()
