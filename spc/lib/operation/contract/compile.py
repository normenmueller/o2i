#!/usr/bin/env python3
"""Compile the authoritative Operation companion into static artifacts."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Callable, NamedTuple, Optional


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
COMPANION = PACKAGE_ROOT / "contract/operation.json"
COMMAND_ERROR_COMPANION = PACKAGE_ROOT / "contract/command-error.json"
DEFAULT_PROFILE_COMPANION = (
    PACKAGE_ROOT.parents[1] / "ctr/archimate/profile.json"
)
DEFAULT_PROFILE_DIAGNOSTIC_INVENTORY = (
    PACKAGE_ROOT.parents[1]
    / "ctr/archimate/contract/generated/o2i.archimate-profile.diagnostic-evidence-v1.json"
)
DEFAULT_CORE_OWNER_DIAGNOSTIC_INVENTORY = (
    PACKAGE_ROOT.parents[1]
    / "lib/core/contract/generated/o2i.core.owner-diagnostic-evidence-v1.json"
)
DEFAULT_CORE_COMPANION = PACKAGE_ROOT.parents[1] / "lib/core/semantics.json"
RULE_GENERATED = PACKAGE_ROOT / "src/O2I/Operation/Rule/Generated.hs"
SCHEMA_GENERATED = PACKAGE_ROOT / "src/O2I/Operation/Schema/Generated.hs"
COMMAND_ERROR_BRANCH_GENERATED = (
    PACKAGE_ROOT
    / "src/O2I/Operation/Command/Error/Branch/Generated.hs"
)
SCHEMA_DIRECTORY = PACKAGE_ROOT / "contract/schema"
GENERATED = RULE_GENERATED

SCHEMA_DRAFT = "https://json-schema.org/draft/2020-12/schema"
SHA256_PATTERN = "^[0-9a-f]{64}$"
TOOL_TEXT_PATTERN = "^[^\u0000]+$"
TOKEN_PATTERN = "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
IDENTITY_PATTERN = (
    "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*"
    "(?:\\.[a-z][a-z0-9]*(?:-[a-z0-9]+)*)+$"
)
ECMA_WHITESPACE = (
    "\u0009\u000b\u000c\u000a\u000d\u0020\u00a0\u1680"
    "\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007"
    "\u2008\u2009\u200a\u2028\u2029\u202f\u205f\u3000\ufeff"
)
ECMA_WHITESPACE_CLASS = "[" + ECMA_WHITESPACE + "]"
NON_ECMA_WHITESPACE = "[^" + ECMA_WHITESPACE + "]"
PORTABLE_ANY_CHARACTER = "(.|\n|\r|\u2028|\u2029)"
PORTABLE_CANONICAL_TEXT_PATTERN = (
    "^"
    + NON_ECMA_WHITESPACE
    + "("
    + PORTABLE_ANY_CHARACTER
    + "*"
    + NON_ECMA_WHITESPACE
    + ")?$"
)

NOTATION_ISSUE_TOKENS = (
    "model-identity-missing",
    "model-identity-multiplicity",
    "model-identity-value-kind-invalid",
    "model-identity-grammar-invalid",
    "model-identity-duplicate",
    "view-identity-missing",
    "view-identity-multiplicity",
    "view-identity-value-kind-invalid",
    "view-identity-grammar-invalid",
    "view-identity-duplicate",
    "view-name-missing",
    "view-name-multiplicity",
    "view-name-value-kind-invalid",
    "marker-key-missing",
    "marker-key-multiplicity",
    "marker-key-value-kind-invalid",
    "marker-reference-identity-missing",
    "marker-reference-identity-multiplicity",
    "marker-reference-identity-value-kind-invalid",
    "marker-reference-identity-grammar-invalid",
    "marker-reference-target-missing",
    "marker-reference-target-wrong-family",
    "marker-reference-target-ambiguous",
    "marker-definition-name-missing",
    "marker-definition-name-multiplicity",
    "marker-definition-name-value-kind-invalid",
    "record-identity-missing",
    "record-identity-multiplicity",
    "record-identity-value-kind-invalid",
    "record-identity-grammar-invalid",
    "record-identity-duplicate",
    "reference-identity-missing",
    "reference-identity-multiplicity",
    "reference-identity-value-kind-invalid",
    "reference-identity-grammar-invalid",
    "reference-target-missing",
    "reference-target-wrong-family",
    "reference-target-ambiguous",
)


class MachineDocument(NamedTuple):
    name: str
    identity: str
    version: int
    variants: tuple[str, ...]

    @property
    def reference(self) -> str:
        return f"{self.identity}/v{self.version}"

    @property
    def binding(self) -> str:
        return self.name + "MachineSchema"

    @property
    def schema_path(self) -> Path:
        return SCHEMA_DIRECTORY / f"{self.identity}-v{self.version}.schema.json"


class SchemaFragment(NamedTuple):
    name: str
    identity: str
    version: int

    @property
    def reference(self) -> str:
        return f"{self.identity}/v{self.version}"

    @property
    def binding(self) -> str:
        return self.name + "SchemaAuthority"

    @property
    def schema_path(self) -> Path:
        return SCHEMA_DIRECTORY / f"{self.identity}-v{self.version}.schema.json"


EXPECTED_DOCUMENTS: tuple[tuple[str, tuple[str, ...]], ...] = (
    ("adapterInventory", ("adapter-inventory",)),
    (
        "profileInventory",
        ("profile-inventory", "profile-static-definition-invalid"),
    ),
    (
        "ruleInventory",
        ("rule-inventory", "rule-static-definition-invalid"),
    ),
    (
        "ruleExplanation",
        ("rule-explanation-found", "rule-explanation-not-found"),
    ),
    (
        "viewDiscovery",
        (
            "views-discovered",
            "view-acquisition-failed",
            "view-adapter-selection-failed",
            "view-adapter-decode-failed",
        ),
    ),
    (
        "qualificationSubjects",
        (
            "qualification-subjects-prerequisite-rejected",
            "qualification-subjects-discovered",
        ),
    ),
    (
        "validateResult",
        (
            "notation-validation-accepted",
            "notation-validation-rejected",
            "profile-validation-accepted",
            "profile-validation-rejected",
            "structure-validation-accepted",
            "structure-validation-rejected",
            "semantics-validation-accepted",
            "semantics-validation-rejected",
            "semantics-validation-unavailable",
        ),
    ),
    (
        "traceResult",
        (
            "trace-prerequisite-rejected",
            "trace-rejected",
            "trace-accepted",
        ),
    ),
    (
        "qualifyResult",
        ("qualify-prerequisite-rejected", "qualify-completed"),
    ),
    (
        "readinessResult",
        (
            "readiness-prerequisite-rejected",
            "readiness-subject-unavailable",
            "readiness-not-ready",
            "readiness-ready",
        ),
    ),
    (
        "assessResult",
        (
            "assess-prerequisite-rejected",
            "assess-subject-unavailable",
            "assess-collection-invalid",
            "assess-observations-invalid",
            "assess-completed",
        ),
    ),
)
EXPECTED_VARIANTS = dict(EXPECTED_DOCUMENTS)
COMMAND_ERROR_DOCUMENTS = (
    (
        "commandError",
        (
            "argument-invalid",
            "command-failed",
            "preparation-failed",
            "validate-failed",
            "qualify-failed",
            "readiness-failed",
            "assess-failed",
        ),
    ),
)
EXPECTED_VARIANTS.update(COMMAND_ERROR_DOCUMENTS)
EXPECTED_FRAGMENTS = ("diagnostic",)

VARIANT_BINDINGS: dict[str, str] = {
    "adapter-inventory": "adapterInventoryVariant",
    "profile-inventory": "profileInventoryVariant",
    "profile-static-definition-invalid": "profileDefinitionInvalidVariant",
    "rule-inventory": "ruleInventoryVariant",
    "rule-static-definition-invalid": "ruleDefinitionInvalidVariant",
    "rule-explanation-found": "ruleExplanationFoundVariant",
    "rule-explanation-not-found": "ruleExplanationNotFoundVariant",
    "views-discovered": "viewsDiscoveredVariant",
    "view-acquisition-failed": "viewAcquisitionFailedVariant",
    "view-adapter-selection-failed": "viewAdapterSelectionFailedVariant",
    "view-adapter-decode-failed": "viewAdapterDecodeFailedVariant",
    "qualification-subjects-prerequisite-rejected": (
        "qualificationSubjectsPrerequisiteRejectedVariant"
    ),
    "qualification-subjects-discovered": (
        "qualificationSubjectsDiscoveredVariant"
    ),
    "argument-invalid": "argumentInvalidVariant",
    "command-failed": "commandFailedVariant",
    "preparation-failed": "preparationFailedVariant",
    "validate-failed": "validateFailedVariant",
    "qualify-failed": "qualifyFailedVariant",
    "readiness-failed": "readinessFailedVariant",
    "assess-failed": "assessFailedVariant",
    "notation-validation-accepted": "notationValidationAcceptedVariant",
    "notation-validation-rejected": "notationValidationRejectedVariant",
    "profile-validation-accepted": "profileValidationAcceptedVariant",
    "profile-validation-rejected": "profileValidationRejectedVariant",
    "structure-validation-accepted": "structureValidationAcceptedVariant",
    "structure-validation-rejected": "structureValidationRejectedVariant",
    "semantics-validation-accepted": "semanticsValidationAcceptedVariant",
    "semantics-validation-rejected": "semanticsValidationRejectedVariant",
    "semantics-validation-unavailable": "semanticsValidationUnavailableVariant",
    "trace-prerequisite-rejected": "tracePrerequisiteRejectedVariant",
    "trace-rejected": "traceRejectedVariant",
    "trace-accepted": "traceAcceptedVariant",
    "qualify-prerequisite-rejected": "qualifyPrerequisiteRejectedVariant",
    "qualify-completed": "qualifyCompletedVariant",
    "readiness-prerequisite-rejected": (
        "readinessPrerequisiteRejectedVariant"
    ),
    "readiness-subject-unavailable": "readinessSubjectUnavailableVariant",
    "readiness-not-ready": "readinessNotReadyVariant",
    "readiness-ready": "readinessReadyVariant",
    "assess-prerequisite-rejected": (
        "assessPrerequisiteRejectedVariant"
    ),
    "assess-subject-unavailable": "assessSubjectUnavailableVariant",
    "assess-collection-invalid": "assessCollectionInvalidVariant",
    "assess-observations-invalid": "assessObservationsInvalidVariant",
    "assess-completed": "assessCompletedVariant",
}


def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON object member: {key}")
        result[key] = value
    return result


def load_object(path: Path) -> tuple[dict[str, Any], bytes]:
    payload = path.read_bytes()
    value = json.loads(payload.decode("utf-8"), object_pairs_hook=unique_object)
    if not isinstance(value, dict):
        raise ValueError(f"{path}: expected one JSON object")
    return value, payload


def require_keys(value: dict[str, Any], keys: set[str], subject: str) -> None:
    if set(value) != keys:
        raise ValueError(f"{subject}: expected members {sorted(keys)!r}")


def require_text(value: Any, subject: str) -> str:
    if not isinstance(value, str) or not value or "\x00" in value:
        raise ValueError(f"{subject}: expected non-empty NUL-free text")
    return value


def validate_command_error_owner_branches(
    value: Any,
) -> dict[str, list[dict[str, str]]]:
    if not isinstance(value, dict):
        raise ValueError("ownerBranches: expected object")
    capabilities = ["validate", "qualify", "readiness", "assess"]
    require_keys(value, set(capabilities), "ownerBranches")
    expected_lengths = {
        "validate": 10,
        "qualify": 10,
        "readiness": 11,
        "assess": 11,
    }
    checked: dict[str, list[dict[str, str]]] = {}
    for capability in capabilities:
        rows = value[capability]
        if not isinstance(rows, list):
            raise ValueError(f"ownerBranches.{capability}: expected array")
        if len(rows) != expected_lengths[capability]:
            raise ValueError(
                f"ownerBranches.{capability}: unexpected branch cardinality"
            )
        checked_rows: list[dict[str, str]] = []
        for index, row in enumerate(rows):
            subject = f"ownerBranches.{capability}[{index}]"
            if not isinstance(row, dict):
                raise ValueError(f"{subject}: expected object")
            require_keys(row, {"constructor", "token"}, subject)
            constructor = require_text(row["constructor"], f"{subject}.constructor")
            token = require_text(row["token"], f"{subject}.token")
            if re.fullmatch(r"[A-Z][A-Za-z0-9]+", constructor) is None:
                raise ValueError(f"{subject}.constructor: invalid Haskell constructor")
            if re.fullmatch(TOKEN_PATTERN, token) is None:
                raise ValueError(f"{subject}.token: invalid stable token")
            checked_rows.append({"constructor": constructor, "token": token})
        if len({row["constructor"] for row in checked_rows}) != len(checked_rows):
            raise ValueError(f"ownerBranches.{capability}: duplicate constructor")
        if len({row["token"] for row in checked_rows}) != len(checked_rows):
            raise ValueError(f"ownerBranches.{capability}: duplicate token")
        checked[capability] = checked_rows
    return checked


def require_positive_integer(value: Any, subject: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise ValueError(f"{subject}: expected positive integer")
    return value


def valid_token(value: str) -> bool:
    return re.fullmatch(TOKEN_PATTERN, value) is not None


def valid_identity(value: str) -> bool:
    return re.fullmatch(IDENTITY_PATTERN, value) is not None


def resolve_pointer(value: Any, pointer: str) -> Any:
    current = value
    for raw in pointer.removeprefix("/").split("/"):
        token = raw.replace("~1", "/").replace("~0", "~")
        current = current[int(token)] if isinstance(current, list) else current[token]
    return current


def validate_machine_documents(
    value: Any,
    expected: tuple[tuple[str, tuple[str, ...]], ...] = EXPECTED_DOCUMENTS,
) -> list[MachineDocument]:
    if not isinstance(value, list) or not value:
        raise ValueError("machineDocuments: expected non-empty array")
    documents: list[MachineDocument] = []
    for index, raw in enumerate(value):
        subject = f"machineDocuments[{index}]"
        if not isinstance(raw, dict):
            raise ValueError(f"{subject}: expected object")
        require_keys(raw, {"name", "identity", "version", "variants"}, subject)
        name = require_text(raw["name"], f"{subject}.name")
        if re.fullmatch(r"[a-z][A-Za-z0-9]*", name) is None:
            raise ValueError(f"{subject}.name: invalid lower-camel name")
        if name not in EXPECTED_VARIANTS:
            raise ValueError(f"{subject}.name: unsupported machine document")
        identity = require_text(raw["identity"], f"{subject}.identity")
        if not valid_identity(identity):
            raise ValueError(f"{subject}.identity: invalid schema identity")
        version = require_positive_integer(raw["version"], f"{subject}.version")
        raw_variants = raw["variants"]
        if not isinstance(raw_variants, list) or not raw_variants:
            raise ValueError(f"{subject}.variants: expected non-empty array")
        variants = tuple(
            require_text(variant, f"{subject}.variants[{variant_index}]")
            for variant_index, variant in enumerate(raw_variants)
        )
        invalid = [variant for variant in variants if not valid_token(variant)]
        if invalid:
            raise ValueError(f"{subject}.variants: invalid variant {invalid[0]!r}")
        if len(variants) != len(set(variants)):
            raise ValueError(f"{subject}.variants: duplicate variant")
        if variants != EXPECTED_VARIANTS[name]:
            raise ValueError(f"{subject}.variants: unexpected closed variant inventory")
        documents.append(MachineDocument(name, identity, version, variants))

    names = [document.name for document in documents]
    identities = [document.identity for document in documents]
    bindings = [document.binding for document in documents]
    paths = [document.schema_path for document in documents]
    if len(names) != len(set(names)):
        raise ValueError("duplicate machine document name")
    if len(identities) != len(set(identities)):
        raise ValueError("duplicate machine document identity")
    if len(bindings) != len(set(bindings)):
        raise ValueError("duplicate machine document Haskell binding")
    if len(paths) != len(set(paths)):
        raise ValueError("duplicate machine document output path")
    if tuple(names) != tuple(name for name, _ in expected):
        raise ValueError("machine documents are not in canonical order")
    return documents


def validate_schema_fragments(value: Any) -> list[SchemaFragment]:
    if not isinstance(value, list) or not value:
        raise ValueError("schemaFragments: expected non-empty array")
    fragments: list[SchemaFragment] = []
    for index, raw in enumerate(value):
        subject = f"schemaFragments[{index}]"
        if not isinstance(raw, dict):
            raise ValueError(f"{subject}: expected object")
        require_keys(raw, {"name", "identity", "version"}, subject)
        name = require_text(raw["name"], f"{subject}.name")
        if name not in EXPECTED_FRAGMENTS:
            raise ValueError(f"{subject}.name: unsupported Schema fragment")
        identity = require_text(raw["identity"], f"{subject}.identity")
        if not valid_identity(identity):
            raise ValueError(f"{subject}.identity: invalid schema identity")
        version = require_positive_integer(raw["version"], f"{subject}.version")
        fragments.append(SchemaFragment(name, identity, version))
    names = [fragment.name for fragment in fragments]
    identities = [fragment.identity for fragment in fragments]
    paths = [fragment.schema_path for fragment in fragments]
    if len(names) != len(set(names)):
        raise ValueError("duplicate Schema fragment name")
    if len(identities) != len(set(identities)):
        raise ValueError("duplicate Schema fragment identity")
    if len(paths) != len(set(paths)):
        raise ValueError("duplicate Schema fragment output path")
    if tuple(names) != EXPECTED_FRAGMENTS:
        raise ValueError("Schema fragments are not in canonical order")
    return fragments


def validate_schema_output_ownership(
    documents: list[MachineDocument], fragments: list[SchemaFragment]
) -> None:
    schemas = [*documents, *fragments]
    references = [schema.reference for schema in schemas]
    paths = [schema.schema_path for schema in schemas]
    if len(references) != len(set(references)):
        raise ValueError("duplicate generated schema reference")
    if len(paths) != len(set(paths)):
        raise ValueError("duplicate generated schema output path")


def validate(
    profile_companion: Path = DEFAULT_PROFILE_COMPANION,
    profile_diagnostic_inventory: Path = DEFAULT_PROFILE_DIAGNOSTIC_INVENTORY,
    core_owner_diagnostic_inventory: Path = DEFAULT_CORE_OWNER_DIAGNOSTIC_INVENTORY,
) -> tuple[
    dict[str, str],
    list[dict[str, str]],
    str,
    list[MachineDocument],
    list[SchemaFragment],
    dict[str, Any],
    dict[str, Any],
]:
    companion, payload = load_object(COMPANION)
    require_keys(
        companion,
        {
            "schema",
            "contract",
            "machineDocuments",
            "schemaFragments",
            "diagnosticConformance",
            "rules",
            "profileConformance",
        },
        "Operation companion",
    )
    if companion["schema"] != "o2i.operation-contract/1":
        raise ValueError("unsupported Operation companion schema")

    contract = companion["contract"]
    if not isinstance(contract, dict):
        raise ValueError("Operation contract: expected object")
    require_keys(contract, {"identity", "version", "authority"}, "contract")
    checked_contract = {
        key: require_text(contract[key], f"contract.{key}")
        for key in ("identity", "version", "authority")
    }
    if checked_contract["authority"] != "Operation":
        raise ValueError("Operation authority must be exact")

    documents = validate_machine_documents(companion["machineDocuments"])
    command_error, _ = load_object(COMMAND_ERROR_COMPANION)
    require_keys(
        command_error,
        {"schema", "document", "ownerBranches"},
        "Command-error companion",
    )
    if command_error["schema"] != "o2i.command-error-contract/1":
        raise ValueError("unsupported Command-error companion schema")
    validate_command_error_owner_branches(command_error["ownerBranches"])
    documents.extend(
        validate_machine_documents(
            [command_error["document"]], COMMAND_ERROR_DOCUMENTS
        )
    )
    fragments = validate_schema_fragments(companion["schemaFragments"])
    validate_schema_output_ownership(documents, fragments)

    conformance = companion["diagnosticConformance"]
    require_keys(conformance, {"profile", "core"}, "diagnosticConformance")
    profile_inventory, profile_inventory_bytes = load_object(
        profile_diagnostic_inventory
    )
    core_inventory, core_inventory_bytes = load_object(
        core_owner_diagnostic_inventory
    )
    for name, declared, inventory, inventory_bytes, identity, version in (
        (
            "profile",
            conformance["profile"],
            profile_inventory,
            profile_inventory_bytes,
            profile_inventory.get("profile", {}).get("identity"),
            profile_inventory.get("profile", {}).get("version"),
        ),
        (
            "core",
            conformance["core"],
            core_inventory,
            core_inventory_bytes,
            core_inventory.get("core", {}).get("identity"),
            core_inventory.get("core", {}).get("version"),
        ),
    ):
        subject = f"diagnosticConformance.{name}"
        if not isinstance(declared, dict):
            raise ValueError(f"{subject}: expected object")
        require_keys(
            declared, {"schema", "identity", "version", "sha256"}, subject
        )
        if inventory.get("schema") != declared["schema"]:
            raise ValueError(f"{subject}: inventory schema differs")
        if identity != declared["identity"] or version != declared["version"]:
            raise ValueError(f"{subject}: owner identity differs")
        if hashlib.sha256(inventory_bytes).hexdigest() != declared["sha256"]:
            raise ValueError(f"{subject}: inventory digest differs")

    raw_rules = companion["rules"]
    if not isinstance(raw_rules, list) or not raw_rules:
        raise ValueError("rules: expected non-empty array")
    fields = {"constructor", "id", "stage", "expectation", "meaning", "action"}
    rules: list[dict[str, str]] = []
    for index, raw_rule in enumerate(raw_rules):
        if not isinstance(raw_rule, dict):
            raise ValueError(f"rules[{index}]: expected object")
        require_keys(raw_rule, fields, f"rules[{index}]")
        rule = {
            field: require_text(raw_rule[field], f"rules[{index}].{field}")
            for field in fields
        }
        if not re.fullmatch(r"[A-Z][A-Za-z0-9]*", rule["constructor"]):
            raise ValueError(f"rules[{index}].constructor: invalid Haskell name")
        if rule["stage"] != "preparation":
            raise ValueError(f"rules[{index}].stage: unsupported stage")
        rules.append(rule)

    identifiers = [rule["id"] for rule in rules]
    constructors = [rule["constructor"] for rule in rules]
    if len(identifiers) != len(set(identifiers)):
        raise ValueError("duplicate Operation rule identity")
    if len(constructors) != len(set(constructors)):
        raise ValueError("duplicate Operation rule constructor")
    if identifiers != sorted(identifiers, key=lambda item: item.encode("utf-8")):
        raise ValueError("Operation rules are not in canonical identity order")

    conformance = companion["profileConformance"]
    if not isinstance(conformance, dict):
        raise ValueError("profileConformance: expected object")
    require_keys(conformance, {"companion", "pointer"}, "profileConformance")
    require_text(conformance["companion"], "profileConformance.companion")
    profile, _ = load_object(profile_companion)
    profile_rules = resolve_pointer(
        profile, require_text(conformance["pointer"], "profileConformance.pointer")
    )
    if profile_rules != identifiers:
        raise ValueError("Operation rules differ from Profile conformance inventory")

    return (
        checked_contract,
        rules,
        hashlib.sha256(payload).hexdigest(),
        documents,
        fragments,
        profile_inventory,
        core_inventory,
    )


def text_schema(*, pattern: str | None = None) -> dict[str, Any]:
    schema: dict[str, Any] = {"type": "string", "minLength": 1}
    if pattern is not None:
        schema["pattern"] = pattern
    return schema


def assessment_scalar_schema(schema: dict[str, Any]) -> dict[str, Any]:
    """Copy a Core evidence scalar into the executable Operation Schema."""
    result = copy.deepcopy(schema)
    pattern = result.get("pattern")
    if pattern is not None:
        if not isinstance(pattern, str):
            raise ValueError("evidence scalar pattern must be text")
        if pattern == r"^\S(?:[\s\S]*\S)?$":
            result["pattern"] = PORTABLE_CANONICAL_TEXT_PATTERN
            result["allOf"] = [
                {"not": {"pattern": "^" + ECMA_WHITESPACE_CLASS}},
                {"not": {"pattern": ECMA_WHITESPACE_CLASS + "$"}},
            ]
        else:
            result["pattern"] = pattern.replace("(?:", "(")
    return result


def object_schema(
    properties: dict[str, Any], required: list[str] | None = None
) -> dict[str, Any]:
    return {
        "type": "object",
        "additionalProperties": False,
        "required": required if required is not None else list(properties),
        "properties": properties,
    }


def array_schema(items: dict[str, Any], *, minimum: int = 0) -> dict[str, Any]:
    schema: dict[str, Any] = {"type": "array", "items": items}
    if minimum:
        schema["minItems"] = minimum
    return schema


def reference(name: str) -> dict[str, str]:
    return {"$ref": f"#/$defs/{name}"}


def nullable(schema: dict[str, Any]) -> dict[str, Any]:
    return {"oneOf": [schema, {"type": "null"}]}


def variant(
    document: MachineDocument,
    kind: str,
    members: dict[str, Any],
    required: list[str] | None = None,
) -> dict[str, Any]:
    properties = {
        "schema": {"const": document.reference},
        "kind": {"const": kind},
    }
    properties.update(members)
    return object_schema(properties, required=required)


def operation_variant(
    document: MachineDocument,
    operation: str,
    kind: str,
    members: dict[str, Any],
) -> dict[str, Any]:
    properties = {
        "schema": {"const": document.reference},
        "operation": {"const": operation},
        "tool": reference("toolDescriptor"),
        "kind": {"const": kind},
    }
    properties.update(members)
    return object_schema(properties)


def tool_descriptor() -> dict[str, Any]:
    return object_schema(
        {
            "identity": text_schema(pattern=TOOL_TEXT_PATTERN),
            "version": text_schema(pattern=TOOL_TEXT_PATTERN),
        }
    )


def adapter_descriptor() -> dict[str, Any]:
    return object_schema(
        {
            "id": text_schema(),
            "name": text_schema(),
            "version": text_schema(),
            "notation": text_schema(),
        }
    )


def contract_binding_with_digest() -> dict[str, Any]:
    return object_schema(
        {
            "identity": text_schema(),
            "version": text_schema(),
            "digest": text_schema(pattern=SHA256_PATTERN),
        }
    )


def contract_binding_without_digest() -> dict[str, Any]:
    return object_schema(
        {
            "identity": text_schema(),
            "version": text_schema(),
            "digest": {"type": "null"},
        }
    )


def rule_authority() -> dict[str, Any]:
    digest_binding = reference("digestContractBinding")
    undigested_binding = reference("undigestedContractBinding")
    return {
        "oneOf": [
            object_schema(
                {
                    "kind": {"const": "operation"},
                    "label": {"const": "Operation"},
                    "subject": {"type": "null"},
                    "contract": digest_binding,
                }
            ),
            object_schema(
                {
                    "kind": {"const": "core"},
                    "label": {"const": "Core"},
                    "subject": {"type": "null"},
                    "contract": digest_binding,
                }
            ),
            object_schema(
                {
                    "kind": {"const": "profile"},
                    "label": text_schema(),
                    "subject": text_schema(),
                    "contract": digest_binding,
                }
            ),
            object_schema(
                {
                    "kind": {"const": "adapter"},
                    "label": text_schema(),
                    "subject": text_schema(),
                    "contract": undigested_binding,
                }
            ),
        ]
    }


def rule_row() -> dict[str, Any]:
    return object_schema(
        {
            "id": text_schema(),
            "stage": text_schema(),
            "expectation": text_schema(),
            "meaning": text_schema(),
            "action": text_schema(),
        }
    )


def adapter_occurrence(*, path_pattern: str | None = None) -> dict[str, Any]:
    return {
        "oneOf": [
            {"type": "null"},
            object_schema(
                {
                    "kind": {"const": "byte-offset"},
                    "offset": {"type": "integer", "minimum": 0},
                }
            ),
            object_schema(
                {
                    "kind": {"const": "line-column"},
                    "line": {"type": "integer", "minimum": 1},
                    "column": {"type": "integer", "minimum": 1},
                }
            ),
            object_schema(
                {
                    "kind": {"const": "path"},
                    "steps": array_schema(
                        text_schema(pattern=path_pattern), minimum=1
                    ),
                }
            ),
        ]
    }


def adapter_rule(stage: str) -> dict[str, Any]:
    return object_schema(
        {
            "id": text_schema(),
            "stage": {"const": stage},
            "expectation": text_schema(),
            "meaning": text_schema(),
            "action": text_schema(),
        }
    )


def adapter_diagnostic(rule: str) -> dict[str, Any]:
    return object_schema(
        {
            "rule": reference(rule),
            "occurrences": array_schema(reference("adapterOccurrence"), minimum=1),
        }
    )


def source_identity() -> dict[str, Any]:
    return object_schema(
        {
            "role": {"const": "model"},
            "ordinal": {"const": 0},
            "reference": text_schema(),
            "sha256": text_schema(pattern=SHA256_PATTERN),
        }
    )


def diagnostic_source_identity() -> dict[str, Any]:
    return object_schema(
        {
            "role": {
                "enum": ["model", "supplemental", "readiness", "assessment"]
            },
            "ordinal": {"type": "integer", "minimum": 0},
            "reference": text_schema(pattern=TOOL_TEXT_PATTERN),
            "sha256": text_schema(pattern=SHA256_PATTERN),
        }
    )


def native_name() -> dict[str, Any]:
    return object_schema(
        {
            "namespace": nullable({"type": "string"}),
            "localName": {"type": "string"},
        }
    )


def source_position() -> dict[str, Any]:
    return object_schema(
        {
            "line": {"type": "integer", "minimum": 0},
            "column": {"type": "integer", "minimum": 0},
            "offset": nullable({"type": "integer", "minimum": 0}),
        }
    )


def source_location() -> dict[str, Any]:
    path_step = object_schema(
        {
            "name": reference("nativeName"),
            "ordinal": {"type": "integer", "minimum": 1},
        }
    )
    span = object_schema(
        {"start": reference("sourcePosition"), "end": reference("sourcePosition")}
    )
    return object_schema(
        {
            "path": array_schema(path_step, minimum=1),
            "span": nullable(span),
        }
    )


def draft_scalar() -> dict[str, Any]:
    scalar_value = {
        "oneOf": [
            object_schema(
                {"kind": {"const": "text"}, "value": {"type": "string"}}
            ),
            object_schema(
                {"kind": {"const": "boolean"}, "value": {"type": "boolean"}}
            ),
            object_schema(
                {"kind": {"const": "number"}, "value": {"type": "string"}}
            ),
            object_schema(
                {"kind": {"const": "native-name"}, "value": reference("nativeName")}
            ),
            object_schema(
                {
                    "kind": {"const": "other"},
                    "nativeKind": {"type": "string"},
                    "value": {"type": "string"},
                }
            ),
        ]
    }
    return {
        **object_schema(
            {"value": scalar_value, "location": reference("sourceLocation")}
        )
    }


def identity_invalid_reason() -> dict[str, Any]:
    return {
        "oneOf": [
            object_schema(
                {
                    "kind": {"const": "non-text"},
                    "observedKind": {"type": "string"},
                }
            ),
            object_schema({"kind": {"const": "empty"}}),
            object_schema({"kind": {"const": "u0000"}}),
            object_schema({"kind": {"const": "surrogate"}}),
        ]
    }


def identity_outcome() -> dict[str, Any]:
    return {
        "oneOf": [
            object_schema({"kind": {"const": "missing"}}),
            object_schema(
                {
                    "kind": {"const": "multiple"},
                    "values": array_schema(reference("draftScalar"), minimum=2),
                }
            ),
            object_schema(
                {
                    "kind": {"const": "invalid"},
                    "value": reference("draftScalar"),
                    "reason": reference("identityInvalidReason"),
                }
            ),
            object_schema(
                {
                    "kind": {"const": "resolved"},
                    "value": reference("draftScalar"),
                    "identity": text_schema(),
                }
            ),
        ]
    }


def view_name_field() -> dict[str, Any]:
    return object_schema(
        {
            "kind": {"const": "name"},
            "values": array_schema(reference("draftScalar")),
            "location": reference("sourceLocation"),
        }
    )


def view_descriptor() -> dict[str, Any]:
    return object_schema(
        {
            "occurrence": object_schema(
                {
                    "kind": {"const": "record"},
                    "ordinal": {"type": "integer", "minimum": 0},
                }
            ),
            "identity": reference("identityOutcome"),
            "nameFields": array_schema(reference("viewNameField")),
            "location": reference("sourceLocation"),
        }
    )


def canonical_occurrence() -> dict[str, Any]:
    return object_schema(
        {
            "kind": {"enum": ["record", "property", "reference"]},
            "ordinal": {"type": "integer", "minimum": 0},
        }
    )


def diagnostic_occurrence() -> dict[str, Any]:
    source = reference("diagnosticSourceIdentity")
    return {
        "oneOf": [
            object_schema({"kind": {"const": "source"}, "source": source}),
            object_schema(
                {
                    "kind": {"const": "native"},
                    "source": source,
                    "location": reference("adapterOccurrence"),
                }
            ),
            object_schema(
                {
                    "kind": {"const": "draft"},
                    "source": source,
                    "location": reference("sourceLocation"),
                }
            ),
            object_schema(
                {
                    "kind": {"const": "canonical"},
                    "source": source,
                    "occurrence": reference("canonicalOccurrence"),
                }
            ),
            object_schema(
                {
                    "kind": {"const": "subject"},
                    "source": source,
                    "identity": text_schema(pattern=TOOL_TEXT_PATTERN),
                }
            ),
            object_schema(
                {
                    "kind": {"const": "occurrence"},
                    "source": source,
                    "identity": text_schema(pattern=TOOL_TEXT_PATTERN),
                }
            ),
        ]
    }


def diagnostic_provenance() -> dict[str, Any]:
    rule_identity = text_schema(pattern=TOOL_TEXT_PATTERN)
    return {
        "oneOf": [
            object_schema(
                {
                    "owner": {"const": "operation"},
                    "ruleId": rule_identity,
                }
            ),
            object_schema(
                {
                    "owner": {"const": "adapter"},
                    "adapterId": text_schema(pattern=TOOL_TEXT_PATTERN),
                    "ruleId": rule_identity,
                }
            ),
            object_schema(
                {
                    "owner": {"const": "profile"},
                    "profileReference": text_schema(pattern=TOOL_TEXT_PATTERN),
                    "ruleId": rule_identity,
                }
            ),
            object_schema(
                {
                    "owner": {"const": "core"},
                    "ruleId": rule_identity,
                }
            ),
        ]
    }


def diagnostic_value() -> dict[str, Any]:
    return object_schema(
        {
            "severity": {"enum": ["debug", "info", "warning", "error"]},
            "disposition": {"enum": ["model-finding", "process-failure"]},
            "provenance": reference("diagnosticProvenance"),
            "occurrences": array_schema(
                reference("diagnosticOccurrence"), minimum=1
            ),
        }
    )


def adapter_inventory_schema(document: MachineDocument) -> dict[str, Any]:
    return schema_document(
        document,
        "Compiled adapter inventory",
        {
            "adapterDescriptor": adapter_descriptor(),
            "adapterInventory": variant(
                document,
                "adapter-inventory",
                {
                    "authority": {"const": "Operation"},
                    "adapters": array_schema(
                        reference("adapterDescriptor"), minimum=1
                    )
                },
            ),
        },
        ["adapterInventory"],
    )


def profile_inventory_schema(document: MachineDocument) -> dict[str, Any]:
    profile_row = object_schema(
        {
            "identity": text_schema(),
            "token": text_schema(),
            "reference": text_schema(),
            "version": text_schema(),
            "notation": text_schema(),
            "adapterIds": {
                **array_schema(text_schema(), minimum=1),
                "uniqueItems": True,
            },
            "contractDigest": text_schema(pattern=SHA256_PATTERN),
        }
    )
    defect = {
        "oneOf": [
            object_schema(
                {
                    "code": {"const": "missing-adapter-id"},
                    "profileReference": text_schema(),
                }
            ),
            object_schema(
                {
                    "code": {"const": "duplicate-adapter-id"},
                    "profileReference": text_schema(),
                    "adapterId": text_schema(),
                }
            ),
        ]
    }
    return schema_document(
        document,
        "Compiled Profile inventory",
        {
            "profileRow": profile_row,
            "profileDefect": defect,
            "profileInventory": variant(
                document,
                "profile-inventory",
                {
                    "authority": {"const": "Operation"},
                    "profiles": array_schema(reference("profileRow"), minimum=1),
                },
            ),
            "profileInvalid": variant(
                document,
                "profile-static-definition-invalid",
                {
                    "authority": {"const": "Operation"},
                    "diagnostics": array_schema(
                        reference("profileDefect"), minimum=1
                    ),
                },
            ),
        },
        ["profileInventory", "profileInvalid"],
    )


def rule_definitions() -> dict[str, Any]:
    return {
        "digestContractBinding": contract_binding_with_digest(),
        "undigestedContractBinding": contract_binding_without_digest(),
        "ruleAuthority": rule_authority(),
        "ruleRow": rule_row(),
    }


def rule_inventory_schema(document: MachineDocument) -> dict[str, Any]:
    definitions = rule_definitions()
    definitions.update(
        {
            "ruleDefect": {
                "oneOf": [
                    object_schema(
                        {
                            "code": {"const": "profile-catalog-mismatch"},
                            "expectedReference": text_schema(),
                            "actualReference": text_schema(),
                            "expectedDigest": text_schema(pattern=SHA256_PATTERN),
                            "actualDigest": text_schema(pattern=SHA256_PATTERN),
                        }
                    ),
                    object_schema(
                        {
                            "code": {"const": "duplicate-rule-id"},
                            "authority": text_schema(),
                            "ruleId": text_schema(),
                        }
                    ),
                ]
            },
            "ruleInventory": variant(
                document,
                "rule-inventory",
                {
                    "authority": reference("ruleAuthority"),
                    "rules": array_schema(reference("ruleRow"), minimum=1),
                },
            ),
            "ruleInvalid": variant(
                document,
                "rule-static-definition-invalid",
                {
                    "diagnostics": array_schema(reference("ruleDefect"), minimum=1),
                },
            ),
        }
    )
    return schema_document(
        document,
        "Authority-local rule inventory",
        definitions,
        ["ruleInventory", "ruleInvalid"],
    )


def rule_explanation_schema(document: MachineDocument) -> dict[str, Any]:
    definitions = rule_definitions()
    definitions.update(
        {
            "ruleFound": variant(
                document,
                "rule-explanation-found",
                {
                    "authority": reference("ruleAuthority"),
                    "requestedRuleId": text_schema(),
                    "rule": reference("ruleRow"),
                },
            ),
            "ruleNotFound": variant(
                document,
                "rule-explanation-not-found",
                {
                    "authority": reference("ruleAuthority"),
                    "requestedRuleId": text_schema(),
                },
            ),
        }
    )
    return schema_document(
        document,
        "Exact rule explanation",
        definitions,
        ["ruleFound", "ruleNotFound"],
    )


def view_discovery_schema(document: MachineDocument) -> dict[str, Any]:
    selection_failure = {
        "oneOf": [
            object_schema(
                {
                    "kind": {"const": "unknown-adapter"},
                    "adapterId": text_schema(),
                }
            ),
            object_schema(
                {
                    "kind": {"const": "recognition-failed"},
                    "failures": array_schema(
                        object_schema(
                            {
                                "adapter": reference("adapterDescriptor"),
                                "diagnostics": array_schema(
                                    reference("recognitionAdapterDiagnostic"),
                                    minimum=1,
                                ),
                            }
                        ),
                        minimum=1,
                    ),
                }
            ),
            object_schema({"kind": {"const": "no-match"}}),
            object_schema(
                {
                    "kind": {"const": "multiple-matches"},
                    "adapters": array_schema(
                        reference("adapterDescriptor"), minimum=2
                    ),
                }
            ),
        ]
    }
    definitions = {
        "toolDescriptor": tool_descriptor(),
        "adapterDescriptor": adapter_descriptor(),
        "recognitionAdapterRule": adapter_rule("preparation"),
        "decodeAdapterRule": adapter_rule("preparation"),
        "adapterOccurrence": adapter_occurrence(),
        "recognitionAdapterDiagnostic": adapter_diagnostic(
            "recognitionAdapterRule"
        ),
        "decodeAdapterDiagnostic": adapter_diagnostic("decodeAdapterRule"),
        "sourceIdentity": source_identity(),
        "nativeName": native_name(),
        "sourcePosition": source_position(),
        "sourceLocation": source_location(),
        "draftScalar": draft_scalar(),
        "identityInvalidReason": identity_invalid_reason(),
        "identityOutcome": identity_outcome(),
        "viewNameField": view_name_field(),
        "viewDescriptor": view_descriptor(),
        "selectionFailure": selection_failure,
        "viewsDiscovered": operation_variant(
            document,
            "views",
            "views-discovered",
            {
                "source": reference("sourceIdentity"),
                "adapter": reference("adapterDescriptor"),
                "authorities": {
                    "type": "array",
                    "minItems": 2,
                    "maxItems": 2,
                    "prefixItems": [
                        object_schema({"kind": {"const": "operation"}}),
                        object_schema(
                            {
                                "kind": {"const": "adapter"},
                                "adapterId": text_schema(),
                            }
                        ),
                    ],
                    "items": False,
                },
                "views": array_schema(reference("viewDescriptor")),
            },
        ),
        "acquisitionFailed": variant(
            document,
            "view-acquisition-failed",
            {
                "failure": object_schema(
                    {
                        "sourceKind": {"enum": ["file", "stdin"]},
                        "sourceReference": text_schema(),
                        "message": text_schema(),
                    }
                ),
            },
        ),
        "selectionFailed": variant(
            document,
            "view-adapter-selection-failed",
            {
                "source": reference("sourceIdentity"),
                "failure": reference("selectionFailure"),
            },
        ),
        "decodeFailed": variant(
            document,
            "view-adapter-decode-failed",
            {
                "source": reference("sourceIdentity"),
                "adapter": reference("adapterDescriptor"),
                "diagnostics": array_schema(
                    reference("decodeAdapterDiagnostic"), minimum=1
                ),
            },
        ),
    }
    return schema_document(
        document,
        "Profile-neutral View discovery",
        definitions,
        [
            "viewsDiscovered",
            "acquisitionFailed",
            "selectionFailed",
            "decodeFailed",
        ],
    )


def exact_text_array(values: list[str]) -> dict[str, Any]:
    schema = {
        "type": "array",
        "minItems": len(values),
        "maxItems": len(values),
    }
    if values:
        schema["prefixItems"] = [{"const": value} for value in values]
    schema["items"] = False
    return schema


def diagnostic_value_schema(value_kind: str) -> dict[str, Any]:
    if value_kind == "canonical-occurrence":
        return reference("canonicalOccurrence")
    if value_kind == "draft-scalar":
        return reference("draftScalar")
    if value_kind in {"occurrence-identity", "model-identity", "text"}:
        return text_schema(pattern=TOOL_TEXT_PATTERN)
    raise ValueError(f"unsupported diagnostic value kind: {value_kind!r}")


def diagnostic_evidence_alternative(
    row: dict[str, Any], alternative: dict[str, Any]
) -> dict[str, Any]:
    properties: dict[str, Any] = {}
    if "branch" in alternative:
        properties["branch"] = {"const": alternative["branch"]}
        properties["sourceRuleIds"] = exact_text_array(
            alternative["sourceRuleIds"]
        )
    if "classification" in row:
        classification = row["classification"]
        properties.update(
            {
                "class": {"const": classification["class"]},
                "graphMembership": {
                    "const": classification["graphMembership"]
                },
                "qualificationMembership": {
                    "const": classification["qualificationMembership"]
                },
            }
        )
    if "mappingId" in row:
        properties["mappingId"] = {"const": row["mappingId"]}
    fields = []
    for field in alternative["fields"]:
        values = {
            "type": "array",
            "items": diagnostic_value_schema(field["valueKind"]),
            "minItems": field["minimum"],
        }
        if field["maximum"] is not None:
            values["maxItems"] = field["maximum"]
        fields.append(
            object_schema(
                {
                    "role": {"const": field["roleId"]},
                    "values": values,
                }
            )
        )
    properties["fields"] = {
        "type": "array",
        "minItems": len(fields),
        "maxItems": len(fields),
        "prefixItems": fields,
        "items": False,
    }
    return object_schema(properties)


def owner_diagnostic_schema(
    row: dict[str, Any], *, owner: str, stage: str, producer: str,
    disposition: str = "model-finding"
) -> dict[str, Any]:
    polarity = row["polarity"]
    severity = "info" if polarity == "acceptance" else "error"
    return object_schema(
        {
            "producer": {"const": producer},
            "owner": {"const": owner},
            "stage": {"const": stage},
            "ruleId": {"const": row["ruleId"]},
            "evidenceKind": {"const": row["evidenceKind"]},
            "severity": {"const": severity},
            "disposition": {"const": disposition},
            "evidence": {
                "oneOf": [
                    diagnostic_evidence_alternative(row, alternative)
                    for alternative in row["alternatives"]
                ]
            },
        }
    )


def notation_observation_schema(kind: str) -> dict[str, Any]:
    if kind == "occurrence":
        return object_schema(
            {
                "kind": {"const": "occurrence"},
                "location": reference("sourceLocation"),
            }
        )
    if kind == "value":
        return object_schema(
            {
                "kind": {"const": "value"},
                "location": reference("sourceLocation"),
                "valueKind": {"type": "string"},
                "value": {"type": "string"},
            }
        )
    if kind == "reference":
        return object_schema(
            {
                "kind": {"const": "reference"},
                "location": reference("sourceLocation"),
                "value": {"type": "string"},
                "targets": array_schema(reference("sourceLocation")),
            }
        )
    raise ValueError(f"unknown Notation observation kind: {kind}")


NOTATION_OBSERVATION_KINDS: dict[str, tuple[str, ...]] = {
    "model-identity-missing": ("occurrence",),
    "model-identity-multiplicity": ("occurrence", "value"),
    "model-identity-value-kind-invalid": ("value",),
    "model-identity-grammar-invalid": ("value",),
    "model-identity-duplicate": ("reference",),
    "view-identity-missing": ("occurrence",),
    "view-identity-multiplicity": ("occurrence", "value"),
    "view-identity-value-kind-invalid": ("value",),
    "view-identity-grammar-invalid": ("value",),
    "view-identity-duplicate": ("reference",),
    "view-name-missing": ("occurrence",),
    "view-name-multiplicity": ("occurrence", "value"),
    "view-name-value-kind-invalid": ("value",),
    "marker-key-missing": ("occurrence",),
    "marker-key-multiplicity": ("occurrence", "value"),
    "marker-key-value-kind-invalid": ("value",),
    "marker-reference-identity-missing": ("occurrence",),
    "marker-reference-identity-multiplicity": ("occurrence", "value"),
    "marker-reference-identity-value-kind-invalid": ("value",),
    "marker-reference-identity-grammar-invalid": ("value",),
    "marker-reference-target-missing": ("reference",),
    "marker-reference-target-wrong-family": ("reference",),
    "marker-reference-target-ambiguous": ("reference",),
    "marker-definition-name-missing": ("occurrence",),
    "marker-definition-name-multiplicity": ("occurrence", "value"),
    "marker-definition-name-value-kind-invalid": ("value",),
    "record-identity-missing": ("occurrence",),
    "record-identity-multiplicity": ("occurrence", "value"),
    "record-identity-value-kind-invalid": ("value",),
    "record-identity-grammar-invalid": ("value",),
    "record-identity-duplicate": ("reference",),
    "reference-identity-missing": ("occurrence",),
    "reference-identity-multiplicity": ("occurrence", "value"),
    "reference-identity-value-kind-invalid": ("value",),
    "reference-identity-grammar-invalid": ("value",),
    "reference-target-missing": ("reference",),
    "reference-target-wrong-family": ("reference",),
    "reference-target-ambiguous": ("reference",),
}


def notation_observation_kinds(token: str) -> tuple[str, ...]:
    try:
        return NOTATION_OBSERVATION_KINDS[token]
    except KeyError as error:
        raise ValueError(f"unclassified Notation issue token: {token}") from error


def notation_evidence_schema(observation_kind: str) -> dict[str, Any]:
    observation = notation_observation_schema(observation_kind)
    return object_schema(
        {
            "fields": {
                "type": "array",
                "minItems": 2,
                "maxItems": 2,
                "prefixItems": [
                    object_schema(
                        {
                            "role": {"const": "subject"},
                            "values": {
                                "type": "array",
                                "minItems": 1,
                                "maxItems": 1,
                                "items": reference("sourceLocation"),
                            },
                        }
                    ),
                    object_schema(
                        {
                            "role": {"const": "observations"},
                            "values": array_schema(observation, minimum=1),
                        }
                    ),
                ],
                "items": False,
            }
        }
    )


def notation_diagnostic_schema(token: str) -> dict[str, Any]:
    observation_kinds = notation_observation_kinds(token)
    evidence_alternatives = [
        reference("notation" + kind.capitalize() + "Evidence")
        for kind in observation_kinds
    ]
    evidence_schema = (
        evidence_alternatives[0]
        if len(evidence_alternatives) == 1
        else {"oneOf": evidence_alternatives}
    )
    return object_schema(
        {
            "producer": {"const": "notation-assessment"},
            "owner": {"const": "adapter"},
            "stage": {"const": "notation"},
            "evidenceKind": {"const": f"archimate-notation-{token}"},
            "severity": {"const": "error"},
            "disposition": {"const": "model-finding"},
            "evidence": evidence_schema,
        }
    )


def diagnostic_schema_groups(
    profile_inventory: Optional[dict[str, Any]] = None,
    core_inventory: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    if profile_inventory is None:
        profile_inventory, _ = load_object(DEFAULT_PROFILE_DIAGNOSTIC_INVENTORY)
    if core_inventory is None:
        core_inventory, _ = load_object(DEFAULT_CORE_OWNER_DIAGNOSTIC_INVENTORY)
    profile = profile_inventory["profile"]
    owners = core_inventory["owners"]
    profile_rows = [
        (
            row,
            owner_diagnostic_schema(
                row,
                owner="profile",
                stage="profile",
                producer=row["producer"],
            ),
        )
        for row in profile_inventory["diagnostics"]
    ]
    structure_diagnostics = [
        owner_diagnostic_schema(
            row,
            owner="core",
            stage="structure",
            producer="structure-assessment",
        )
        for row in owners["structure"]
    ]
    semantics_diagnostics = [
        owner_diagnostic_schema(
            row,
            owner="core",
            stage="semantics",
            producer="semantics-assessment",
        )
        for row in owners["semantics"]
    ]
    binding_diagnostics = [
        owner_diagnostic_schema(
            row,
            owner="core",
            stage="capability-input",
            producer="supplemental-binding",
            disposition="process-failure",
        )
        for row in owners["binding"]
    ]
    notation_diagnostics = [
        notation_diagnostic_schema(token) for token in NOTATION_ISSUE_TOKENS
    ]
    return {
        "profile": profile,
        "notation": notation_diagnostics,
        "profileAll": [schema for _, schema in profile_rows],
        "profileAcceptance": [
            schema
            for row, schema in profile_rows
            if row["polarity"] == "acceptance"
        ],
        "profileActivation": [
            schema
            for row, schema in profile_rows
            if row["producer"] == "profile-activation"
        ],
        "profileRejection": [
            schema
            for row, schema in profile_rows
            if row["polarity"] == "rejection"
        ],
        "structure": structure_diagnostics,
        "semantics": semantics_diagnostics,
        "binding": binding_diagnostics,
    }


def diagnostic_definitions(
    profile_inventory: Optional[dict[str, Any]] = None,
    core_inventory: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    """Generate v2 exclusively from the two explicit owner inventories."""
    if profile_inventory is None:
        profile_inventory, _ = load_object(DEFAULT_PROFILE_DIAGNOSTIC_INVENTORY)
    if core_inventory is None:
        core_inventory, _ = load_object(DEFAULT_CORE_OWNER_DIAGNOSTIC_INVENTORY)
    groups = diagnostic_schema_groups(profile_inventory, core_inventory)
    profile = groups["profile"]
    notation_diagnostics = groups["notation"]
    profile_diagnostics = groups["profileAll"]
    structure_diagnostics = groups["structure"]
    semantics_diagnostics = groups["semantics"]
    binding_diagnostics = groups["binding"]
    source_entry = object_schema(
        {
            "reference": text_schema(pattern=TOOL_TEXT_PATTERN),
            "sha256": text_schema(pattern=SHA256_PATTERN),
            "diagnostics": {
                "type": "array",
                "items": {"oneOf": binding_diagnostics},
            },
        }
    )
    supplemental_sources = {
        "type": "object",
        "propertyNames": {"pattern": "^(0|[1-9][0-9]*)$"},
        "patternProperties": {"^(0|[1-9][0-9]*)$": source_entry},
        "additionalProperties": False,
    }
    return {
        "adapterDescriptor": adapter_descriptor(),
        "canonicalOccurrence": canonical_occurrence(),
        "nativeName": native_name(),
        "sourcePosition": source_position(),
        "sourceLocation": source_location(),
        "draftScalar": draft_scalar(),
        "notationOccurrenceEvidence": notation_evidence_schema("occurrence"),
        "notationValueEvidence": notation_evidence_schema("value"),
        "notationReferenceEvidence": notation_evidence_schema("reference"),
        "preparedAuthority": object_schema(
            {
                "adapter": reference("adapterDescriptor"),
                "notationRules": {
                    "type": "array",
                    "minItems": len(NOTATION_ISSUE_TOKENS),
                    "maxItems": len(NOTATION_ISSUE_TOKENS),
                    "prefixItems": [
                        object_schema(
                            {
                                "evidenceKind": {
                                    "const": f"archimate-notation-{token}"
                                },
                                "ruleId": text_schema(
                                    pattern=TOOL_TEXT_PATTERN
                                ),
                            }
                        )
                        for token in NOTATION_ISSUE_TOKENS
                    ],
                    "items": False,
                },
                "profile": object_schema(
                    {
                        "identity": {"const": profile["identity"]},
                        "token": {"const": profile["token"]},
                        "version": {"const": profile["version"]},
                        "notation": {"const": profile["notation"]},
                        "adapterIds": exact_text_array(profile["adapterIds"]),
                        "contractDigest": {
                            "const": profile_inventory["companion"]["rawSha256"]
                        },
                    }
                ),
                "model": object_schema(
                    {
                        "role": {"const": "model"},
                        "ordinal": {"type": "integer", "minimum": 0},
                        "reference": text_schema(pattern=TOOL_TEXT_PATTERN),
                        "sha256": text_schema(pattern=SHA256_PATTERN),
                    }
                ),
            }
        ),
        "modelDiagnostic": {
            "oneOf": [
                *notation_diagnostics,
                *profile_diagnostics,
                *structure_diagnostics,
                *semantics_diagnostics,
            ]
        },
        "supplementalSources": supplemental_sources,
        "preparedDiagnosticDocument": object_schema(
            {
                "schema": {"const": "o2i.operation.diagnostic/v2"},
                "authority": reference("preparedAuthority"),
                "modelDiagnostics": array_schema(reference("modelDiagnostic")),
                "supplementalSources": reference("supplementalSources"),
            }
        ),
    }


def validate_result_schema(
    document: MachineDocument,
    profile_inventory: Optional[dict[str, Any]] = None,
    core_inventory: Optional[dict[str, Any]] = None,
    operation_contract: Optional[dict[str, Any]] = None,
    operation_digest: Optional[str] = None,
) -> dict[str, Any]:
    if profile_inventory is None:
        profile_inventory, _ = load_object(DEFAULT_PROFILE_DIAGNOSTIC_INVENTORY)
    if core_inventory is None:
        core_inventory, _ = load_object(DEFAULT_CORE_OWNER_DIAGNOSTIC_INVENTORY)
    if operation_contract is None or operation_digest is None:
        operation_companion, operation_payload = load_object(COMPANION)
        operation_contract = operation_companion["contract"]
        operation_digest = hashlib.sha256(operation_payload).hexdigest()
    definitions = diagnostic_definitions(profile_inventory, core_inventory)
    groups = diagnostic_schema_groups(profile_inventory, core_inventory)
    for generic_document_definition in (
        "preparedAuthority",
        "modelDiagnostic",
        "supplementalSources",
        "preparedDiagnosticDocument",
    ):
        del definitions[generic_document_definition]
    profile = profile_inventory["profile"]
    profile_digest = profile_inventory["companion"]["rawSha256"]
    core = core_inventory["core"]
    core_digest = core_inventory["companions"]["semantics"]["rawSha256"]

    selector = {
        "oneOf": [
            object_schema(
                {"kind": {"const": "name"}, "value": text_schema()}
            ),
            object_schema(
                {"kind": {"const": "identity"}, "value": text_schema()}
            ),
        ]
    }
    input_reference = {
        "oneOf": [
            object_schema(
                {"kind": {"const": "file"}, "path": text_schema()}
            ),
            object_schema({"kind": {"const": "stdin"}}),
        ]
    }
    model_source = object_schema(
        {
            "role": {"const": "model"},
            "ordinal": {"const": 0},
            "reference": text_schema(pattern=TOOL_TEXT_PATTERN),
            "sha256": text_schema(pattern=SHA256_PATTERN),
        }
    )
    profile_authority = object_schema(
        {
            "identity": {"const": profile["identity"]},
            "token": {"const": profile["token"]},
            "version": {"const": profile["version"]},
            "notation": {"const": profile["notation"]},
            "adapterIds": exact_text_array(profile["adapterIds"]),
            "contractDigest": {"const": profile_digest},
        }
    )
    operation_contract = object_schema(
        {
            "kind": {"const": "operation"},
            "identity": {"const": operation_contract["identity"]},
            "version": {"const": operation_contract["version"]},
            "digest": {"const": operation_digest},
        }
    )
    adapter_contract = object_schema({"kind": {"const": "adapter"}})
    profile_contract = object_schema({"kind": {"const": "profile"}})
    core_contract = object_schema(
        {
            "kind": {"const": "core"},
            "identity": {"const": core["identity"]},
            "version": {"const": core["version"]},
            "digest": {"const": core_digest},
        }
    )

    def contract_sequence(level: str) -> dict[str, Any]:
        entries = [operation_contract, adapter_contract, profile_contract]
        if level in {"structure", "semantics"}:
            entries.append(core_contract)
        return {
            "type": "array",
            "minItems": len(entries),
            "maxItems": len(entries),
            "prefixItems": entries,
            "items": False,
        }

    def validation_request(level: str) -> dict[str, Any]:
        supplements = (
            array_schema(input_reference)
            if level == "semantics"
            else {"type": "array", "maxItems": 0}
        )
        return object_schema(
            {
                "level": {"const": level},
                "view": selector,
                "adapterId": nullable(text_schema()),
                "supplements": supplements,
            }
        )

    prepared_authority = object_schema(
        {
            "adapter": reference("adapterDescriptor"),
            "notationRules": {
                "type": "array",
                "minItems": len(NOTATION_ISSUE_TOKENS),
                "maxItems": len(NOTATION_ISSUE_TOKENS),
                "prefixItems": [
                    object_schema(
                        {
                            "evidenceKind": {
                                "const": f"archimate-notation-{token}"
                            },
                            "ruleId": text_schema(pattern=TOOL_TEXT_PATTERN),
                        }
                    )
                    for token in NOTATION_ISSUE_TOKENS
                ],
                "items": False,
            },
            "profile": profile_authority,
            "model": reference("validateModelSource"),
        }
    )

    def supplemental_groups(binding: str) -> dict[str, Any]:
        diagnostics = {
            "type": "array",
            "items": reference("validateBindingDiagnostic"),
        }
        if binding != "admitted":
            diagnostics["maxItems"] = 0
        source_entry = object_schema(
            {
                "reference": text_schema(pattern=TOOL_TEXT_PATTERN),
                "sha256": text_schema(pattern=SHA256_PATTERN),
                "diagnostics": diagnostics,
            }
        )
        result = array_schema(source_entry)
        if binding == "forbidden":
            result["maxItems"] = 0
        return result

    def diagnostic_document(
        allowed: list[str],
        required: list[str],
    ) -> dict[str, Any]:
        items = (
            {"oneOf": [reference(name) for name in allowed]}
            if allowed
            else False
        )
        model_diagnostics: dict[str, Any] = {"type": "array", "items": items}
        if not allowed:
            model_diagnostics["maxItems"] = 0
        if required:
            model_diagnostics["contains"] = {
                "oneOf": [reference(name) for name in required]
            }
            model_diagnostics["minContains"] = 1
        return object_schema(
            {
                "schema": {"const": "o2i.operation.diagnostic/v2"},
                "modelDiagnostics": model_diagnostics,
            }
        )

    diagnostic_shapes = {
        ("notation", "accepted"): diagnostic_document([], []),
        ("notation", "rejected"): diagnostic_document(
            ["validateNotationDiagnostic"],
            ["validateNotationDiagnostic"],
        ),
        ("profile", "accepted"): diagnostic_document(
            ["validateProfileAcceptanceDiagnostic"], []
        ),
        ("profile", "rejected"): diagnostic_document(
            [
                "validateProfileActivationDiagnostic",
                "validateProfileRejectionDiagnostic",
            ],
            ["validateProfileRejectionDiagnostic"],
        ),
        ("structure", "accepted"): diagnostic_document(
            ["validateProfileAcceptanceDiagnostic"], []
        ),
        ("structure", "rejected"): diagnostic_document(
            [
                "validateProfileAcceptanceDiagnostic",
                "validateStructureDiagnostic",
            ],
            ["validateStructureDiagnostic"],
        ),
        ("semantics", "accepted"): diagnostic_document(
            ["validateProfileAcceptanceDiagnostic"], []
        ),
        ("semantics", "rejected"): diagnostic_document(
            [
                "validateProfileAcceptanceDiagnostic",
                "validateSemanticsDiagnostic",
            ],
            ["validateSemanticsDiagnostic"],
        ),
        ("semantics", "unavailable"): diagnostic_document(
            [
                "validateProfileAcceptanceDiagnostic",
                "validateSemanticsDiagnostic",
            ],
            [],
        ),
    }

    collective_reasons = {
        "enum": [
            "collective-fit-input-missing",
            "collective-fit-identity-unresolved",
            "participant-strategy-formulation-unavailable",
            "participant-strategy-formulation-invalid",
            "target-strategy-formulation-unavailable",
            "target-strategy-formulation-invalid",
        ]
    }
    model_identities = array_schema(text_schema(pattern=TOOL_TEXT_PATTERN))
    unavailability_witness = {
        "oneOf": [
            object_schema(
                {
                    "kind": {"const": "strategy-formulation"},
                    "subject": text_schema(pattern=TOOL_TEXT_PATTERN),
                    "reason": {
                        "enum": ["input-missing", "identity-unresolved"]
                    },
                }
            ),
            object_schema(
                {
                    "kind": {"const": "collective-fit"},
                    "subject": text_schema(pattern=TOOL_TEXT_PATTERN),
                    "reasons": array_schema(collective_reasons, minimum=1),
                    "blockers": model_identities,
                }
            ),
            object_schema(
                {
                    "kind": {"const": "collective-coverage"},
                    "subject": text_schema(pattern=TOOL_TEXT_PATTERN),
                    "blockers": model_identities,
                }
            ),
            object_schema(
                {
                    "kind": {"const": "primitive-support"},
                    "subject": text_schema(pattern=TOOL_TEXT_PATTERN),
                    "participant": text_schema(pattern=TOOL_TEXT_PATTERN),
                    "reasons": array_schema(collective_reasons, minimum=1),
                    "blockers": model_identities,
                }
            ),
        ]
    }

    levels = ["notation", "profile", "structure", "semantics"]

    def report(
        stage: str, status: str, requested_level: str
    ) -> dict[str, Any]:
        kind = f"{stage}-validation-{status}"
        execution_members: dict[str, Any] = {"status": {"const": status}}
        if status == "unavailable":
            execution_members["coreWitnesses"] = array_schema(
                reference("validateCoreUnavailabilityWitness")
            )
        report_schema = operation_variant(
            document,
            "validate",
            kind,
            {
                "context": object_schema(
                    {
                        "authority": reference("validatePreparedAuthority"),
                        "view": reference("viewDescriptor"),
                        "supplements": supplemental_groups(
                            "admitted"
                            if status == "unavailable"
                            else (
                                "empty"
                                if requested_level == "semantics"
                                and stage not in {"notation", "profile"}
                                else "forbidden"
                            )
                        ),
                    }
                ),
                "request": validation_request(requested_level),
                "execution": object_schema(execution_members),
                "diagnostics": diagnostic_shapes[(stage, status)],
                "provenance": object_schema(
                    {"contracts": contract_sequence(requested_level)}
                ),
            },
        )
        if status == "unavailable":
            report_schema["anyOf"] = [
                {
                    "properties": {
                        "context": {
                            "properties": {
                                "supplements": {
                                    "contains": {
                                        "properties": {
                                            "diagnostics": {"minItems": 1}
                                        }
                                    }
                                }
                            }
                        }
                    }
                },
                {
                    "properties": {
                        "execution": {
                            "properties": {
                                "coreWitnesses": {"minItems": 1}
                            }
                        }
                    }
                },
            ]
        return report_schema

    def reports(stage: str, status: str) -> dict[str, Any]:
        if status == "rejected":
            requested_levels = levels[levels.index(stage):]
        else:
            requested_levels = [stage]
        alternatives = [
            report(stage, status, requested_level)
            for requested_level in requested_levels
        ]
        if len(alternatives) == 1:
            return alternatives[0]
        return {"oneOf": alternatives}

    definitions.update(
        {
            "toolDescriptor": tool_descriptor(),
            "validateNotationDiagnostic": {"oneOf": groups["notation"]},
            "validateProfileAcceptanceDiagnostic": {
                "oneOf": groups["profileAcceptance"]
            },
            "validateProfileActivationDiagnostic": {
                "oneOf": groups["profileActivation"]
            },
            "validateProfileRejectionDiagnostic": {
                "oneOf": groups["profileRejection"]
            },
            "validateStructureDiagnostic": {"oneOf": groups["structure"]},
            "validateSemanticsDiagnostic": {"oneOf": groups["semantics"]},
            "validateBindingDiagnostic": {"oneOf": groups["binding"]},
            "validateCoreUnavailabilityWitness": unavailability_witness,
            "validateModelSource": model_source,
            "validatePreparedAuthority": prepared_authority,
            "identityInvalidReason": identity_invalid_reason(),
            "identityOutcome": identity_outcome(),
            "viewNameField": view_name_field(),
            "viewDescriptor": view_descriptor(),
            "notationAccepted": reports("notation", "accepted"),
            "notationRejected": reports("notation", "rejected"),
            "profileAccepted": reports("profile", "accepted"),
            "profileRejected": reports("profile", "rejected"),
            "structureAccepted": reports("structure", "accepted"),
            "structureRejected": reports("structure", "rejected"),
            "semanticsAccepted": reports("semantics", "accepted"),
            "semanticsRejected": reports("semantics", "rejected"),
            "semanticsUnavailable": reports("semantics", "unavailable"),
        }
    )
    return schema_document(
        document,
        "Cumulative Validate result",
        definitions,
        [
            "notationAccepted",
            "notationRejected",
            "profileAccepted",
            "profileRejected",
            "structureAccepted",
            "structureRejected",
            "semanticsAccepted",
            "semanticsRejected",
            "semanticsUnavailable",
        ],
    )


def load_bound_core_companion(
    path: Path, core_inventory: dict[str, Any]
) -> dict[str, Any]:
    companion, payload = load_object(path)
    binding = core_inventory.get("companions", {}).get("semantics", {})
    if companion.get("schema") != binding.get("schema"):
        raise ValueError("Core companion schema differs from owner inventory")
    if hashlib.sha256(payload).hexdigest() != binding.get("rawSha256"):
        raise ValueError("Core companion digest differs from owner inventory")
    if not isinstance(companion.get("traceSemantics"), dict):
        raise ValueError("Core companion Trace semantics must be an object")
    return companion


def trace_result_schema(
    document: MachineDocument,
    profile_inventory: Optional[dict[str, Any]] = None,
    core_inventory: Optional[dict[str, Any]] = None,
    operation_contract: Optional[dict[str, Any]] = None,
    operation_digest: Optional[str] = None,
    core_companion: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    if profile_inventory is None:
        profile_inventory, _ = load_object(DEFAULT_PROFILE_DIAGNOSTIC_INVENTORY)
    if core_inventory is None:
        core_inventory, _ = load_object(DEFAULT_CORE_OWNER_DIAGNOSTIC_INVENTORY)
    if operation_contract is None or operation_digest is None:
        operation_companion, operation_payload = load_object(COMPANION)
        operation_contract = operation_companion["contract"]
        operation_digest = hashlib.sha256(operation_payload).hexdigest()
    if core_companion is None:
        core_companion, _ = load_object(DEFAULT_CORE_COMPANION)
    trace_contract = core_companion["traceSemantics"]
    variables = trace_contract["variableCatalog"]
    relation_slots = trace_contract["relationSlots"]
    ownership_slots = trace_contract["ownershipSlots"]

    definitions = diagnostic_definitions(profile_inventory, core_inventory)
    groups = diagnostic_schema_groups(profile_inventory, core_inventory)
    for generic_document_definition in (
        "preparedAuthority",
        "modelDiagnostic",
        "supplementalSources",
        "preparedDiagnosticDocument",
    ):
        del definitions[generic_document_definition]
    profile = profile_inventory["profile"]
    core = core_inventory["core"]

    def exact_array(items: list[dict[str, Any]]) -> dict[str, Any]:
        schema = {
            "type": "array",
            "minItems": len(items),
            "maxItems": len(items),
            "items": False,
        }
        if items:
            schema["prefixItems"] = items
        return schema

    def binding(variable: dict[str, Any]) -> dict[str, Any]:
        return object_schema(
            {
                "variable": {"const": variable["id"]},
                "identity": text_schema(pattern=TOOL_TEXT_PATTERN),
            }
        )

    def slot_support(
        kind: str, slot: dict[str, Any], occurrence_minimum: int = 0
    ) -> dict[str, Any]:
        return object_schema(
            {
                "slotKind": {"const": kind},
                "slotId": {"const": slot["id"]},
                "ruleId": {"const": slot["ruleRef"]},
                "occurrences": array_schema(
                    text_schema(pattern=TOOL_TEXT_PATTERN),
                    minimum=occurrence_minimum,
                ),
            }
        )

    def projection(
        variable: dict[str, Any], require_empty: bool = False
    ) -> dict[str, Any]:
        return object_schema(
            {
                "variable": {"const": variable["id"]},
                "identities": (
                    exact_array([])
                    if require_empty
                    else array_schema(text_schema(pattern=TOOL_TEXT_PATTERN))
                ),
            }
        )

    slots = [
        (
            "relation",
            slot,
            slot["sourceVariable"],
            slot["targetVariable"],
        )
        for slot in relation_slots
    ] + [
        (
            "ownership",
            slot,
            slot["contextVariable"],
            slot["memberVariable"],
        )
        for slot in ownership_slots
    ]
    local_gap_disposition = {
        "enum": ["missing-support", "candidate-only"]
    }

    def slot_descriptor(kind: str, slot: dict[str, Any]) -> dict[str, Any]:
        return object_schema(
            {
                "slotKind": {"const": kind},
                "slotId": {"const": slot["id"]},
                "ruleId": {"const": slot["ruleRef"]},
            }
        )

    any_slot_descriptor = {
        "oneOf": [slot_descriptor(kind, slot) for kind, slot, _, _ in slots]
    }
    bound_gap = {
        "oneOf": [
            object_schema(
                {
                    "kind": {"const": "bound-slot"},
                    "slot": slot_descriptor(kind, slot),
                    "disposition": local_gap_disposition,
                    "endpoints": exact_array(
                        [
                            object_schema(
                                {
                                    "variable": {"const": source},
                                    "identity": text_schema(
                                        pattern=TOOL_TEXT_PATTERN
                                    ),
                                }
                            ),
                            object_schema(
                                {
                                    "variable": {"const": target},
                                    "identity": text_schema(
                                        pattern=TOOL_TEXT_PATTERN
                                    ),
                                }
                            ),
                        ]
                    ),
                }
            )
            for kind, slot, source, target in slots
        ]
    }
    unbound_gap = {
        "oneOf": [
            object_schema(
                {
                    "kind": {"const": "unbound-slot"},
                    "slot": slot_descriptor(kind, slot),
                    "disposition": local_gap_disposition,
                    "establishedBindings": exact_array(
                        [
                            object_schema(
                                {
                                    "variable": {"const": variable},
                                    "identity": text_schema(
                                        pattern=TOOL_TEXT_PATTERN
                                    ),
                                }
                            )
                            for variable in established
                        ]
                    ),
                    "unresolvedVariables": exact_array(
                        [{"const": variable} for variable in unresolved]
                    ),
                }
            )
            for kind, slot, source, target in slots
            for established, unresolved in (
                ([source], [target]),
                ([target], [source]),
                ([], [source, target]),
            )
        ]
    }
    local_gap = {"oneOf": [bound_gap, unbound_gap]}
    global_gap = object_schema(
        {
            "kind": {"const": "global-consistency-obstruction"},
            "disposition": {"const": "globally-inconsistent"},
            "slots": array_schema(any_slot_descriptor, minimum=1),
        }
    )
    trace_identity = object_schema(
        {
            "graphIdentity": text_schema(pattern=TOOL_TEXT_PATTERN),
            "bindings": exact_array([binding(variable) for variable in variables]),
        }
    )
    partial_relation_support = exact_array(
        [slot_support("relation", slot) for slot in relation_slots]
    )
    partial_ownership_support = exact_array(
        [slot_support("ownership", slot) for slot in ownership_slots]
    )
    complete_relation_support = exact_array(
        [slot_support("relation", slot, 1) for slot in relation_slots]
    )
    complete_ownership_support = exact_array(
        [slot_support("ownership", slot, 1) for slot in ownership_slots]
    )
    complete_witness = object_schema(
        {
            "kind": {"const": "complete-witness"},
            "identity": trace_identity,
            "relationSupport": complete_relation_support,
            "ownershipSupport": complete_ownership_support,
        }
    )
    partial_trace = {
        "oneOf": [
            object_schema(
                {
                    "kind": {"const": "partial-trace"},
                    "variableProjections": exact_array(
                        [projection(variable) for variable in variables]
                    ),
                    "relationSupport": partial_relation_support,
                    "ownershipSupport": partial_ownership_support,
                    "gaps": array_schema(local_gap, minimum=1),
                }
            ),
            object_schema(
                {
                    "kind": {"const": "partial-trace"},
                    "variableProjections": exact_array(
                        [projection(variable, True) for variable in variables]
                    ),
                    "relationSupport": partial_relation_support,
                    "ownershipSupport": partial_ownership_support,
                    "gaps": exact_array([global_gap]),
                }
            ),
        ]
    }

    def root(result: dict[str, Any]) -> dict[str, Any]:
        return object_schema(
            {
                "graphIdentity": text_schema(pattern=TOOL_TEXT_PATTERN),
                "intervention": text_schema(pattern=TOOL_TEXT_PATTERN),
                "need": text_schema(pattern=TOOL_TEXT_PATTERN),
                "rootSupport": array_schema(
                    text_schema(pattern=TOOL_TEXT_PATTERN), minimum=1
                ),
                "result": result,
            }
        )

    no_root = object_schema(
        {
            "kind": {"const": "no-asserted-root"},
            "graphIdentity": text_schema(pattern=TOOL_TEXT_PATTERN),
            "disposition": {"const": "rejected"},
        }
    )
    accepted_core_result = object_schema(
        {
            "kind": {"const": "root-traces"},
            "graphIdentity": text_schema(pattern=TOOL_TEXT_PATTERN),
            "disposition": {"const": "accepted"},
            "roots": array_schema(root(complete_witness), minimum=1),
        }
    )
    rejected_roots = array_schema(
        root({"oneOf": [complete_witness, partial_trace]}), minimum=1
    )
    rejected_roots["contains"] = root(partial_trace)
    rejected_core_result = {
        "oneOf": [
            no_root,
            object_schema(
                {
                    "kind": {"const": "root-traces"},
                    "graphIdentity": text_schema(pattern=TOOL_TEXT_PATTERN),
                    "disposition": {"const": "rejected"},
                    "roots": rejected_roots,
                }
            ),
        ]
    }

    selector = {
        "oneOf": [
            object_schema(
                {"kind": {"const": "name"}, "value": text_schema()}
            ),
            object_schema(
                {"kind": {"const": "identity"}, "value": text_schema()}
            ),
        ]
    }
    prepared_authority = object_schema(
        {
            "adapter": reference("adapterDescriptor"),
            "notationRules": exact_array(
                [
                    object_schema(
                        {
                            "evidenceKind": {
                                "const": f"archimate-notation-{token}"
                            },
                            "ruleId": text_schema(pattern=TOOL_TEXT_PATTERN),
                        }
                    )
                    for token in NOTATION_ISSUE_TOKENS
                ]
            ),
            "profile": object_schema(
                {
                    "identity": {"const": profile["identity"]},
                    "token": {"const": profile["token"]},
                    "version": {"const": profile["version"]},
                    "notation": {"const": profile["notation"]},
                    "adapterIds": exact_text_array(profile["adapterIds"]),
                    "contractDigest": {
                        "const": profile_inventory["companion"]["rawSha256"]
                    },
                }
            ),
            "model": object_schema(
                {
                    "role": {"const": "model"},
                    "ordinal": {"const": 0},
                    "reference": text_schema(pattern=TOOL_TEXT_PATTERN),
                    "sha256": text_schema(pattern=SHA256_PATTERN),
                }
            ),
        }
    )

    def diagnostic_document(
        allowed: list[str], required: list[str]
    ) -> dict[str, Any]:
        items = (
            {"oneOf": [reference(name) for name in allowed]}
            if allowed
            else False
        )
        diagnostics: dict[str, Any] = {"type": "array", "items": items}
        if not allowed:
            diagnostics["maxItems"] = 0
        if required:
            diagnostics["contains"] = {
                "oneOf": [reference(name) for name in required]
            }
            diagnostics["minContains"] = 1
        return object_schema(
            {
                "schema": {"const": "o2i.operation.diagnostic/v2"},
                "modelDiagnostics": diagnostics,
            }
        )

    diagnostic_shapes = {
        "notation": diagnostic_document(
            ["traceNotationDiagnostic"], ["traceNotationDiagnostic"]
        ),
        "profile": diagnostic_document(
            [
                "traceProfileActivationDiagnostic",
                "traceProfileRejectionDiagnostic",
            ],
            ["traceProfileRejectionDiagnostic"],
        ),
        "structure": diagnostic_document(
            [
                "traceProfileAcceptanceDiagnostic",
                "traceStructureDiagnostic",
            ],
            ["traceStructureDiagnostic"],
        ),
        "semantics": diagnostic_document(
            [
                "traceProfileAcceptanceDiagnostic",
                "traceSemanticsDiagnostic",
            ],
            ["traceSemanticsDiagnostic"],
        ),
        "trace": diagnostic_document(
            ["traceProfileAcceptanceDiagnostic"], []
        ),
    }
    operation_binding = object_schema(
        {
            "kind": {"const": "operation"},
            "identity": {"const": operation_contract["identity"]},
            "version": {"const": operation_contract["version"]},
            "digest": {"const": operation_digest},
        }
    )
    adapter_binding = object_schema({"kind": {"const": "adapter"}})
    profile_binding = object_schema({"kind": {"const": "profile"}})
    core_binding = object_schema(
        {
            "kind": {"const": "core"},
            "identity": {"const": core["identity"]},
            "version": {"const": core["version"]},
            "digest": {
                "const": core_inventory["companions"]["semantics"]["rawSha256"]
            },
        }
    )

    def contract_sequence(include_core: bool) -> dict[str, Any]:
        entries = [operation_binding, adapter_binding, profile_binding]
        if include_core:
            entries.append(core_binding)
        return exact_array(entries)

    common_members = {
        "context": object_schema(
            {
                "authority": reference("tracePreparedAuthority"),
                "view": reference("viewDescriptor"),
            }
        ),
        "request": object_schema(
            {"view": selector, "adapterId": nullable(text_schema())}
        ),
    }

    def prerequisite(stage: str) -> dict[str, Any]:
        return operation_variant(
            document,
            "trace",
            "trace-prerequisite-rejected",
            {
                **common_members,
                "execution": object_schema(
                    {
                        "status": {"const": "prerequisite-rejected"},
                        "prerequisite": {"const": stage},
                    }
                ),
                "trace": {"type": "null"},
                "diagnostics": diagnostic_shapes[stage],
                "provenance": object_schema(
                    {
                        "contracts": contract_sequence(
                            stage in {"structure", "semantics"}
                        )
                    }
                ),
            },
        )

    def completed(
        status: str, trace_schema: dict[str, Any]
    ) -> dict[str, Any]:
        return operation_variant(
            document,
            "trace",
            f"trace-{status}",
            {
                **common_members,
                "execution": object_schema({"status": {"const": status}}),
                "trace": trace_schema,
                "diagnostics": diagnostic_shapes["trace"],
                "provenance": object_schema(
                    {"contracts": contract_sequence(True)}
                ),
            },
        )

    definitions.update(
        {
            "toolDescriptor": tool_descriptor(),
            "traceNotationDiagnostic": {"oneOf": groups["notation"]},
            "traceProfileAcceptanceDiagnostic": {
                "oneOf": groups["profileAcceptance"]
            },
            "traceProfileActivationDiagnostic": {
                "oneOf": groups["profileActivation"]
            },
            "traceProfileRejectionDiagnostic": {
                "oneOf": groups["profileRejection"]
            },
            "traceStructureDiagnostic": {"oneOf": groups["structure"]},
            "traceSemanticsDiagnostic": {"oneOf": groups["semantics"]},
            "tracePreparedAuthority": prepared_authority,
            "identityInvalidReason": identity_invalid_reason(),
            "identityOutcome": identity_outcome(),
            "viewNameField": view_name_field(),
            "viewDescriptor": view_descriptor(),
            "prerequisiteRejected": {
                "oneOf": [
                    prerequisite("notation"),
                    prerequisite("profile"),
                    prerequisite("structure"),
                    prerequisite("semantics"),
                ]
            },
            "traceRejected": completed("rejected", rejected_core_result),
            "traceAccepted": completed("accepted", accepted_core_result),
        }
    )
    return schema_document(
        document,
        "Selected-View Trace result",
        definitions,
        ["prerequisiteRejected", "traceRejected", "traceAccepted"],
    )


def qualification_schema_support(
    profile_inventory: dict[str, Any],
    core_inventory: dict[str, Any],
    operation_contract: dict[str, Any],
    operation_digest: str,
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    definitions = diagnostic_definitions(profile_inventory, core_inventory)
    definitions.update(
        {
            "identityInvalidReason": identity_invalid_reason(),
            "identityOutcome": identity_outcome(),
            "viewNameField": view_name_field(),
        }
    )
    selector = {
        "oneOf": [
            object_schema(
                {"kind": {"const": "name"}, "value": text_schema()}
            ),
            object_schema(
                {"kind": {"const": "identity"}, "value": text_schema()}
            ),
        ]
    }
    exact_contracts = {
        "type": "array",
        "minItems": 4,
        "maxItems": 4,
        "prefixItems": [
            object_schema(
                {
                    "kind": {"const": "operation"},
                    "identity": {"const": operation_contract["identity"]},
                    "version": {"const": operation_contract["version"]},
                    "digest": {"const": operation_digest},
                }
            ),
            object_schema({"kind": {"const": "adapter"}}),
            object_schema({"kind": {"const": "profile"}}),
            object_schema(
                {
                    "kind": {"const": "core"},
                    "identity": {
                        "const": core_inventory["core"]["identity"]
                    },
                    "version": {
                        "const": core_inventory["core"]["version"]
                    },
                    "digest": {
                        "const": core_inventory["companions"]["semantics"][
                            "rawSha256"
                        ]
                    },
                }
            ),
        ],
        "items": False,
    }
    return definitions, selector, exact_contracts


def qualification_subjects_schema(
    document: MachineDocument,
    profile_inventory: Optional[dict[str, Any]] = None,
    core_inventory: Optional[dict[str, Any]] = None,
    operation_contract: Optional[dict[str, Any]] = None,
    operation_digest: Optional[str] = None,
) -> dict[str, Any]:
    if profile_inventory is None:
        profile_inventory, _ = load_object(DEFAULT_PROFILE_DIAGNOSTIC_INVENTORY)
    if core_inventory is None:
        core_inventory, _ = load_object(DEFAULT_CORE_OWNER_DIAGNOSTIC_INVENTORY)
    if operation_contract is None or operation_digest is None:
        operation_companion, operation_payload = load_object(COMPANION)
        operation_contract = operation_companion["contract"]
        operation_digest = hashlib.sha256(operation_payload).hexdigest()
    definitions, selector, contracts = qualification_schema_support(
        profile_inventory,
        core_inventory,
        operation_contract,
        operation_digest,
    )
    groups = diagnostic_schema_groups(profile_inventory, core_inventory)
    identity = text_schema(pattern=TOOL_TEXT_PATTERN)
    source_input = {
        "oneOf": [
            object_schema(
                {"kind": {"const": "file"}, "path": text_schema()}
            ),
            object_schema({"kind": {"const": "stdin"}}),
        ]
    }

    def subject(category: str, qualified_type: str) -> dict[str, Any]:
        return object_schema(
            {
                "category": {"const": category},
                "identity": identity,
                "occurrence": identity,
                "qualifiedType": {"const": qualified_type},
                "displayName": nullable(text_schema()),
                "eligibility": {
                    "enum": [
                        "eligible",
                        "ineligible",
                        "eligibility-unavailable",
                    ]
                },
            }
        )

    subjects = object_schema(
        {
            "needs": array_schema(subject("need", "context.need")),
            "strategies": array_schema(
                subject("strategy", "context.strategy")
            ),
        }
    )
    diagnostics = object_schema(
        {
            "schema": {"const": "o2i.operation.diagnostic/v2"},
            "modelDiagnostics": array_schema(reference("modelDiagnostic")),
        }
    )
    common = {
        "context": object_schema(
            {
                "authority": reference("preparedAuthority"),
                "view": reference("qualificationViewDescriptor"),
                "supplements": array_schema(
                    object_schema(
                        {
                            "reference": text_schema(pattern=TOOL_TEXT_PATTERN),
                            "sha256": text_schema(pattern=SHA256_PATTERN),
                            "diagnostics": {
                                "type": "array",
                                "items": {"oneOf": groups["binding"]},
                            },
                        }
                    )
                ),
            }
        ),
        "request": object_schema(
            {
                "view": selector,
                "adapterId": nullable(text_schema()),
                "supplements": array_schema(source_input),
            }
        ),
        "diagnostics": diagnostics,
        "provenance": object_schema({"contracts": contracts}),
    }

    def prerequisite(stage: str) -> dict[str, Any]:
        return operation_variant(
            document,
            "qualification-subjects",
            "qualification-subjects-prerequisite-rejected",
            {
                **common,
                "execution": object_schema(
                    {
                        "status": {"const": "prerequisite-rejected"},
                        "prerequisite": {"const": stage},
                    }
                ),
                "subjects": {"type": "null"},
            },
        )

    discovered = operation_variant(
        document,
        "qualification-subjects",
        "qualification-subjects-discovered",
        {
            **common,
            "execution": object_schema({"status": {"const": "discovered"}}),
            "subjects": subjects,
        },
    )
    definitions.update(
        {
            "toolDescriptor": tool_descriptor(),
            "qualificationViewDescriptor": view_descriptor(),
            "prerequisiteRejected": {
                "oneOf": [
                    prerequisite("notation"),
                    prerequisite("profile"),
                    prerequisite("structure"),
                ]
            },
            "subjectsDiscovered": discovered,
        }
    )
    return schema_document(
        document,
        "Selected-View qualification subjects",
        definitions,
        ["prerequisiteRejected", "subjectsDiscovered"],
    )


def qualify_result_schema(
    document: MachineDocument,
    profile_inventory: Optional[dict[str, Any]] = None,
    core_inventory: Optional[dict[str, Any]] = None,
    operation_contract: Optional[dict[str, Any]] = None,
    operation_digest: Optional[str] = None,
) -> dict[str, Any]:
    if profile_inventory is None:
        profile_inventory, _ = load_object(DEFAULT_PROFILE_DIAGNOSTIC_INVENTORY)
    if core_inventory is None:
        core_inventory, _ = load_object(DEFAULT_CORE_OWNER_DIAGNOSTIC_INVENTORY)
    if operation_contract is None or operation_digest is None:
        operation_companion, operation_payload = load_object(COMPANION)
        operation_contract = operation_companion["contract"]
        operation_digest = hashlib.sha256(operation_payload).hexdigest()
    definitions, selector, contracts = qualification_schema_support(
        profile_inventory,
        core_inventory,
        operation_contract,
        operation_digest,
    )
    groups = diagnostic_schema_groups(profile_inventory, core_inventory)
    identity = text_schema(pattern=TOOL_TEXT_PATTERN)
    source_input = {
        "oneOf": [
            object_schema(
                {"kind": {"const": "file"}, "path": text_schema()}
            ),
            object_schema({"kind": {"const": "stdin"}}),
        ]
    }
    request = object_schema(
        {
            "view": selector,
            "adapterId": nullable(text_schema()),
            "strategies": {
                **array_schema(identity, minimum=1),
                "uniqueItems": True,
            },
            "needs": {**array_schema(identity), "uniqueItems": True},
            "supplements": array_schema(source_input),
        }
    )
    diagnostic_subject = {
        "oneOf": [
            object_schema(
                {
                    "kind": {"const": kind},
                    "label": text_schema(),
                    "value": identity,
                }
            )
            for kind in ("model", "occurrence", "role", "text")
        ]
    }
    qualification_diagnostic = object_schema(
        {
            "ruleId": identity,
            "evidenceKind": {
                "enum": [
                    "proposal",
                    "proposal-role",
                    "proposal-role-target",
                    "selected-need",
                    "selected-strategy",
                    "pair",
                    "proposal-relation",
                ]
            },
            "subjects": array_schema(diagnostic_subject, minimum=1),
            "occurrenceGroups": array_schema(
                object_schema(
                    {
                        "role": text_schema(),
                        "occurrences": array_schema(identity),
                    }
                ),
                minimum=1,
            ),
        }
    )
    admissible = object_schema(
        {
            "proposal": identity,
            "occurrence": identity,
            "need": identity,
            "strategy": identity,
            "keyResult": identity,
            "objective": identity,
            "rationale": text_schema(),
            "sources": array_schema(text_schema(), minimum=1),
            "witnesses": array_schema(identity),
        }
    )
    empty_diagnostics = {
        "type": "array",
        "items": qualification_diagnostic,
        "maxItems": 0,
    }

    def proposal_variant(
        disposition: str,
        diagnostics: dict[str, Any],
        admissible_value: dict[str, Any],
    ) -> dict[str, Any]:
        return object_schema(
            {
                "identity": identity,
                "occurrence": identity,
                "disposition": {"const": disposition},
                "diagnostics": diagnostics,
                "admissible": admissible_value,
            }
        )

    unrouted_proposal = proposal_variant(
        "route-invalid",
        array_schema(qualification_diagnostic, minimum=1),
        {"type": "null"},
    )
    pair_proposal = {
        "oneOf": [
            proposal_variant(
                "formally-invalid",
                array_schema(qualification_diagnostic, minimum=1),
                {"type": "null"},
            ),
            proposal_variant(
                "formally-admissible", empty_diagnostics, admissible
            ),
        ]
    }
    empty_pair_proposals = {
        "type": "array",
        "items": pair_proposal,
        "maxItems": 0,
    }

    def pair_variant(
        disposition: str,
        diagnostics: dict[str, Any],
        proposals: dict[str, Any],
    ) -> dict[str, Any]:
        return object_schema(
            {
                "need": identity,
                "strategy": identity,
                "disposition": {"const": disposition},
                "diagnostics": diagnostics,
                "proposals": proposals,
            }
        )

    pair = {
        "oneOf": [
            pair_variant(
                "invalid-selected-subjects",
                array_schema(qualification_diagnostic, minimum=1),
                empty_pair_proposals,
            ),
            pair_variant(
                "proposal-missing",
                array_schema(qualification_diagnostic, minimum=1),
                empty_pair_proposals,
            ),
            pair_variant(
                "proposals-assessed",
                empty_diagnostics,
                array_schema(pair_proposal, minimum=1),
            ),
        ]
    }
    empty_occurrences = {**array_schema(identity), "maxItems": 0}
    one_occurrence = {
        **array_schema(identity, minimum=1),
        "maxItems": 1,
    }

    def unavailable_variant(
        reason: str, occurrences: dict[str, Any]
    ) -> dict[str, Any]:
        return object_schema(
            {
                "category": {"enum": ["need", "strategy"]},
                "identity": identity,
                "reason": {"const": reason},
                "occurrences": occurrences,
            }
        )

    subject_unavailable = {
        "oneOf": [
            unavailable_variant("unknown", empty_occurrences),
            unavailable_variant(
                "ambiguous", array_schema(identity, minimum=2)
            ),
            unavailable_variant("out-of-selected-view", one_occurrence),
            unavailable_variant("wrong-type-or-family", one_occurrence),
            unavailable_variant(
                "eligibility-prerequisite-unavailable", one_occurrence
            ),
        ]
    }
    empty_unavailable = {
        **array_schema(subject_unavailable),
        "maxItems": 0,
    }
    empty_pairs = {**array_schema(pair), "maxItems": 0}
    empty_unrouted = {**array_schema(unrouted_proposal), "maxItems": 0}
    selected_needs = {**array_schema(identity), "uniqueItems": True}
    selected_strategies = {**array_schema(identity), "uniqueItems": True}
    qualification = {
        "oneOf": [
            object_schema(
                {
                    "graphIdentity": identity,
                    "disposition": {"const": "subjects-unavailable"},
                    "selectedNeeds": selected_needs,
                    "selectedStrategies": selected_strategies,
                    "subjectUnavailable": array_schema(
                        subject_unavailable, minimum=1
                    ),
                    "unroutedProposals": empty_unrouted,
                    "pairs": empty_pairs,
                }
            ),
            object_schema(
                {
                    "graphIdentity": identity,
                    "disposition": {
                        "const": "pair-outcomes-available"
                    },
                    "selectedNeeds": selected_needs,
                    "selectedStrategies": {
                        **selected_strategies,
                        "minItems": 1,
                    },
                    "subjectUnavailable": empty_unavailable,
                    "unroutedProposals": array_schema(unrouted_proposal),
                    "pairs": array_schema(pair),
                }
            ),
        ]
    }
    common = {
        "context": object_schema(
            {
                "authority": reference("preparedAuthority"),
                "view": reference("qualifyViewDescriptor"),
                "supplements": array_schema(
                    object_schema(
                        {
                            "reference": text_schema(pattern=TOOL_TEXT_PATTERN),
                            "sha256": text_schema(pattern=SHA256_PATTERN),
                            "diagnostics": {
                                "type": "array",
                                "items": {"oneOf": groups["binding"]},
                            },
                        }
                    )
                ),
            }
        ),
        "request": request,
        "diagnostics": object_schema(
            {
                "schema": {"const": "o2i.operation.diagnostic/v2"},
                "modelDiagnostics": array_schema(reference("modelDiagnostic")),
            }
        ),
        "provenance": object_schema({"contracts": contracts}),
    }

    def prerequisite(stage: str) -> dict[str, Any]:
        return operation_variant(
            document,
            "qualify",
            "qualify-prerequisite-rejected",
            {
                **common,
                "execution": object_schema(
                    {
                        "status": {"const": "prerequisite-rejected"},
                        "prerequisite": {"const": stage},
                    }
                ),
                "qualification": {"type": "null"},
            },
        )

    completed = operation_variant(
        document,
        "qualify",
        "qualify-completed",
        {
            **common,
            "execution": object_schema({"status": {"const": "completed"}}),
            "qualification": qualification,
        },
    )
    definitions.update(
        {
            "toolDescriptor": tool_descriptor(),
            "qualifyViewDescriptor": view_descriptor(),
            "prerequisiteRejected": {
                "oneOf": [
                    prerequisite("notation"),
                    prerequisite("profile"),
                    prerequisite("structure"),
                ]
            },
            "qualifyCompleted": completed,
        }
    )
    return schema_document(
        document,
        "Selected-View formal qualification result",
        definitions,
        ["prerequisiteRejected", "qualifyCompleted"],
    )


def readiness_result_schema(
    document: MachineDocument,
    profile_inventory: Optional[dict[str, Any]] = None,
    core_inventory: Optional[dict[str, Any]] = None,
    operation_contract: Optional[dict[str, Any]] = None,
    operation_digest: Optional[str] = None,
    core_companion: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    if profile_inventory is None:
        profile_inventory, _ = load_object(DEFAULT_PROFILE_DIAGNOSTIC_INVENTORY)
    if core_inventory is None:
        core_inventory, _ = load_object(DEFAULT_CORE_OWNER_DIAGNOSTIC_INVENTORY)
    if operation_contract is None or operation_digest is None:
        operation_companion, operation_payload = load_object(COMPANION)
        operation_contract = operation_companion["contract"]
        operation_digest = hashlib.sha256(operation_payload).hexdigest()
    if core_companion is None:
        core_companion, _ = load_object(DEFAULT_CORE_COMPANION)
    definitions, selector, contracts = qualification_schema_support(
        profile_inventory,
        core_inventory,
        operation_contract,
        operation_digest,
    )
    groups = diagnostic_schema_groups(profile_inventory, core_inventory)
    identity = text_schema(pattern=TOOL_TEXT_PATTERN)
    source_input = {
        "oneOf": [
            object_schema(
                {"kind": {"const": "file"}, "path": text_schema()}
            ),
            object_schema({"kind": {"const": "stdin"}}),
        ]
    }
    variables = core_companion["traceSemantics"]["variableCatalog"]
    relation_slots = core_companion["traceSemantics"]["relationSlots"]
    ownership_slots = core_companion["traceSemantics"]["ownershipSlots"]

    def exact_array(items: list[dict[str, Any]]) -> dict[str, Any]:
        schema = {
            "type": "array",
            "minItems": len(items),
            "maxItems": len(items),
            "items": False,
        }
        if items:
            schema["prefixItems"] = items
        return schema

    trace_identity = object_schema(
        {
            "graphIdentity": identity,
            "bindings": exact_array(
                [
                    object_schema(
                        {
                            "variable": {"const": variable["id"]},
                            "identity": identity,
                        }
                    )
                    for variable in variables
                ]
            ),
        }
    )
    readiness_rules = core_companion["evidenceReadinessSemantics"]["ruleIds"]
    evidence_key_by_rule = core_companion["evidenceReadinessSemantics"][
        "evidenceKeyByRule"
    ]
    kpi_rules = [
        readiness_rules[name]
        for name, key in evidence_key_by_rule.items()
        if key == "KPIDefinitionSlotKey"
    ]
    planned_start_rules = [
        readiness_rules[name]
        for name, key in evidence_key_by_rule.items()
        if key == "PlannedStartSlotKey"
    ]
    evidence_plan_rules = [
        readiness_rules[name]
        for name, key in evidence_key_by_rule.items()
        if key == "EvidencePlanSlotKey"
    ]
    readiness_diagnostic = {
        "oneOf": [
            object_schema(
                {
                    "ruleId": {"enum": kpi_rules},
                    "evidenceKey": object_schema(
                        {"kind": {"const": "kpi-definition"}, "kpi": identity}
                    ),
                }
            ),
            object_schema(
                {
                    "ruleId": {"enum": planned_start_rules},
                    "evidenceKey": object_schema(
                        {
                            "kind": {"const": "planned-start"},
                            "intervention": identity,
                        }
                    ),
                }
            ),
            object_schema(
                {
                    "ruleId": {"enum": evidence_plan_rules},
                    "evidenceKey": object_schema(
                        {"kind": {"const": "evidence-plan"}, "trace": trace_identity}
                    ),
                }
            ),
        ]
    }
    evidence_subject = {
        "oneOf": [
            object_schema(
                {
                    "kind": {"const": "text"},
                    "label": text_schema(pattern=TOOL_TEXT_PATTERN),
                    "value": text_schema(),
                }
            ),
            object_schema(
                {
                    "kind": {"const": "natural"},
                    "label": text_schema(pattern=TOOL_TEXT_PATTERN),
                    "value": {"type": "integer", "minimum": 0},
                }
            ),
            *[
                object_schema(
                    {
                        "kind": {"const": kind},
                        "label": text_schema(pattern=TOOL_TEXT_PATTERN),
                        "value": identity,
                    }
                )
                for kind in (
                    "model-identity",
                    "occurrence-identity",
                    "qualified-type",
                )
            ],
        ]
    }
    binding_rule_ids = core_companion["evidenceInputDecoderContract"][
        "ruleIds"
    ]
    binding_reason_rules = (
        ("unknown", binding_rule_ids["identityUnknown"]),
        ("ambiguous", binding_rule_ids["identityAmbiguous"]),
        (
            "out-of-selected-view",
            binding_rule_ids["identityOutOfSelectedView"],
        ),
        ("wrong-type", binding_rule_ids["identityWrongType"]),
    )
    binding_unavailable = {
        "oneOf": [
            object_schema(
                {
                    "phase": {"const": "binding"},
                    "ruleId": {"const": rule_id},
                    "reason": {"const": reason},
                    "jsonPointer": text_schema(),
                    "subjects": array_schema(evidence_subject, minimum=1),
                }
            )
            for reason, rule_id in binding_reason_rules
        ]
    }

    def trace_slot(
        kind: str, slot: dict[str, Any], source: str, target: str
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        descriptor = object_schema(
            {
                "slotKind": {"const": kind},
                "slotId": {"const": slot["id"]},
                "ruleId": {"const": slot["ruleRef"]},
            }
        )
        endpoints = exact_array(
            [
                object_schema(
                    {
                        "variable": {"const": source},
                        "identity": identity,
                    }
                ),
                object_schema(
                    {
                        "variable": {"const": target},
                        "identity": identity,
                    }
                ),
            ]
        )
        return descriptor, endpoints

    trace_slots = [
        trace_slot(
            "relation", slot, slot["sourceVariable"], slot["targetVariable"]
        )
        for slot in relation_slots
    ] + [
        trace_slot(
            "ownership", slot, slot["contextVariable"], slot["memberVariable"]
        )
        for slot in ownership_slots
    ]
    supplied_trace_unavailable = {
        "oneOf": [
            object_schema(
                {
                    "phase": {"const": "supplied-trace"},
                    "reason": {"const": "graph-identity-mismatch"},
                    "expectedGraphIdentity": identity,
                    "suppliedGraphIdentity": identity,
                }
            ),
            *[
                object_schema(
                    {
                        "phase": {"const": "supplied-trace"},
                        "reason": {"const": "exact-slot-unsupported"},
                        "slot": descriptor,
                        "endpoints": endpoints,
                        "disposition": {
                            "enum": ["missing-support", "candidate-only"]
                        },
                    }
                )
                for descriptor, endpoints in trace_slots
            ],
        ]
    }
    promotion_unavailable = object_schema(
        {
            "phase": {"const": "promotion"},
            "reason": {
                "enum": [
                    "strategy-assessment-unavailable",
                    "strategy-assessment-invalid",
                    "strategy-proof-model-mismatch",
                    "strategy-identity-mismatch",
                    "strategy-diagnosis-mismatch",
                    "strategy-intent-mismatch",
                    "strategy-action-not-in-formulation",
                    "strategy-key-result-not-in-formulation",
                ]
            },
        }
    )
    subject = {
        "graphIdentity": identity,
        "traceIdentity": trace_identity,
    }
    binding_subject_unavailable = object_schema(
        {
            "suppliedTraceIdentity": trace_identity,
            "disposition": {"const": "subject-unavailable"},
            "reasons": array_schema(binding_unavailable, minimum=1),
        }
    )

    def reconstruction_subject_unavailable(
        reason: dict[str, Any],
    ) -> dict[str, Any]:
        return object_schema(
            {
                **subject,
                "disposition": {"const": "subject-unavailable"},
                "reasons": array_schema(reason, minimum=1),
            }
        )
    not_ready = object_schema(
        {
            **subject,
            "disposition": {"const": "not-ready"},
            "diagnostics": array_schema(readiness_diagnostic, minimum=1),
        }
    )
    ready = object_schema(
        {
            **subject,
            "disposition": {"const": "ready"},
            "diagnostics": {
                **array_schema(readiness_diagnostic),
                "maxItems": 0,
            },
        }
    )
    readiness_source = object_schema(
        {
            "role": {"const": "readiness"},
            "ordinal": {"const": 0},
            "reference": text_schema(pattern=TOOL_TEXT_PATTERN),
            "sha256": text_schema(pattern=SHA256_PATTERN),
        }
    )
    supplemental_group = object_schema(
        {
            "reference": text_schema(pattern=TOOL_TEXT_PATTERN),
            "sha256": text_schema(pattern=SHA256_PATTERN),
            "diagnostics": {
                "type": "array",
                "items": {"oneOf": groups["binding"]},
            },
        }
    )
    shared = {
        "request": object_schema(
            {
                "view": selector,
                "adapterId": nullable(text_schema()),
                "readiness": source_input,
                "supplements": array_schema(source_input),
            }
        ),
        "diagnostics": object_schema(
            {
                "schema": {"const": "o2i.operation.diagnostic/v2"},
                "modelDiagnostics": array_schema(reference("modelDiagnostic")),
            }
        ),
        "provenance": object_schema({"contracts": contracts}),
    }

    def context(
        prerequisite: Optional[str],
        supplemental_diagnostics: bool = True,
    ) -> dict[str, Any]:
        if prerequisite in {"notation", "profile"}:
            readiness_context = {"type": "null"}
            supplements = {**array_schema(supplemental_group), "maxItems": 0}
        else:
            readiness_context = readiness_source
            group = supplemental_group
            if prerequisite == "structure" or not supplemental_diagnostics:
                group = copy.deepcopy(supplemental_group)
                group["properties"]["diagnostics"]["maxItems"] = 0
            supplements = array_schema(group)
        return object_schema(
            {
                "authority": reference("preparedAuthority"),
                "view": reference("readinessViewDescriptor"),
                "readiness": readiness_context,
                "supplements": supplements,
            }
        )

    def variant(
        kind: str,
        status: str,
        readiness: dict[str, Any],
        prerequisite: Optional[str] = None,
        supplemental_diagnostics: bool = True,
    ) -> dict[str, Any]:
        execution = {"status": {"const": status}}
        if prerequisite is not None:
            execution["prerequisite"] = {"const": prerequisite}
        return operation_variant(
            document,
            "readiness",
            kind,
            {
                "context": context(prerequisite, supplemental_diagnostics),
                **shared,
                "execution": object_schema(execution),
                "readiness": readiness,
            },
        )

    prerequisite = {
        "oneOf": [
            variant(
                "readiness-prerequisite-rejected",
                "prerequisite-rejected",
                {"type": "null"},
                stage,
            )
            for stage in ("notation", "profile", "structure", "semantics")
        ]
    }
    definitions.update(
        {
            "toolDescriptor": tool_descriptor(),
            "readinessViewDescriptor": view_descriptor(),
            "prerequisiteRejected": prerequisite,
            "subjectUnavailable": {
                "oneOf": [
                    variant(
                        "readiness-subject-unavailable",
                        "subject-unavailable",
                        binding_subject_unavailable,
                        supplemental_diagnostics=False,
                    ),
                    variant(
                        "readiness-subject-unavailable",
                        "subject-unavailable",
                        reconstruction_subject_unavailable(
                            supplied_trace_unavailable
                        ),
                    ),
                    variant(
                        "readiness-subject-unavailable",
                        "subject-unavailable",
                        reconstruction_subject_unavailable(
                            promotion_unavailable
                        ),
                    ),
                ]
            },
            "notReady": variant(
                "readiness-not-ready", "not-ready", not_ready
            ),
            "ready": variant("readiness-ready", "ready", ready),
        }
    )
    return schema_document(
        document,
        "Selected-View evidence-readiness result",
        definitions,
        ["prerequisiteRejected", "subjectUnavailable", "notReady", "ready"],
    )


def assess_result_schema(
    document: MachineDocument,
    profile_inventory: Optional[dict[str, Any]] = None,
    core_inventory: Optional[dict[str, Any]] = None,
    operation_contract: Optional[dict[str, Any]] = None,
    operation_digest: Optional[str] = None,
    core_companion: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    if profile_inventory is None:
        profile_inventory, _ = load_object(DEFAULT_PROFILE_DIAGNOSTIC_INVENTORY)
    if core_inventory is None:
        core_inventory, _ = load_object(DEFAULT_CORE_OWNER_DIAGNOSTIC_INVENTORY)
    if operation_contract is None or operation_digest is None:
        operation_companion, operation_payload = load_object(COMPANION)
        operation_contract = operation_companion["contract"]
        operation_digest = hashlib.sha256(operation_payload).hexdigest()
    if core_companion is None:
        core_companion, _ = load_object(DEFAULT_CORE_COMPANION)
    definitions, selector, contracts = qualification_schema_support(
        profile_inventory,
        core_inventory,
        operation_contract,
        operation_digest,
    )
    groups = diagnostic_schema_groups(profile_inventory, core_inventory)
    identity = text_schema(pattern=TOOL_TEXT_PATTERN)
    source_input = {
        "oneOf": [
            object_schema(
                {"kind": {"const": "file"}, "path": text_schema()}
            ),
            object_schema({"kind": {"const": "stdin"}}),
        ]
    }
    variables = core_companion["traceSemantics"]["variableCatalog"]
    relation_slots = core_companion["traceSemantics"]["relationSlots"]
    ownership_slots = core_companion["traceSemantics"]["ownershipSlots"]

    def exact_array(items: list[dict[str, Any]]) -> dict[str, Any]:
        schema = {
            "type": "array",
            "minItems": len(items),
            "maxItems": len(items),
            "items": False,
        }
        if items:
            schema["prefixItems"] = items
        return schema

    trace_identity = object_schema(
        {
            "graphIdentity": identity,
            "bindings": exact_array(
                [
                    object_schema(
                        {
                            "variable": {"const": variable["id"]},
                            "identity": identity,
                        }
                    )
                    for variable in variables
                ]
            ),
        }
    )
    evidence_subject = {
        "oneOf": [
            object_schema(
                {
                    "kind": {"const": "text"},
                    "label": text_schema(pattern=TOOL_TEXT_PATTERN),
                    "value": text_schema(),
                }
            ),
            object_schema(
                {
                    "kind": {"const": "natural"},
                    "label": text_schema(pattern=TOOL_TEXT_PATTERN),
                    "value": {"type": "integer", "minimum": 0},
                }
            ),
            *[
                object_schema(
                    {
                        "kind": {"const": kind},
                        "label": text_schema(pattern=TOOL_TEXT_PATTERN),
                        "value": identity,
                    }
                )
                for kind in (
                    "model-identity",
                    "occurrence-identity",
                    "qualified-type",
                )
            ],
        ]
    }
    decoder_rules = core_companion["evidenceInputDecoderContract"]["ruleIds"]
    binding_reason_rules = (
        ("unknown", decoder_rules["identityUnknown"]),
        ("ambiguous", decoder_rules["identityAmbiguous"]),
        (
            "out-of-selected-view",
            decoder_rules["identityOutOfSelectedView"],
        ),
        ("wrong-type", decoder_rules["identityWrongType"]),
    )
    binding_reason = {
        "oneOf": [
            object_schema(
                {
                    "phase": {"const": "binding"},
                    "ruleId": {"const": rule_id},
                    "reason": {"const": reason},
                    "jsonPointer": text_schema(),
                    "subjects": array_schema(evidence_subject, minimum=1),
                }
            )
            for reason, rule_id in binding_reason_rules
        ]
    }

    def trace_slot(
        kind: str, slot: dict[str, Any], source: str, target: str
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        return (
            object_schema(
                {
                    "slotKind": {"const": kind},
                    "slotId": {"const": slot["id"]},
                    "ruleId": {"const": slot["ruleRef"]},
                }
            ),
            exact_array(
                [
                    object_schema(
                        {
                            "variable": {"const": source},
                            "identity": identity,
                        }
                    ),
                    object_schema(
                        {
                            "variable": {"const": target},
                            "identity": identity,
                        }
                    ),
                ]
            ),
        )

    trace_slots = [
        trace_slot(
            "relation", slot, slot["sourceVariable"], slot["targetVariable"]
        )
        for slot in relation_slots
    ] + [
        trace_slot(
            "ownership", slot, slot["contextVariable"], slot["memberVariable"]
        )
        for slot in ownership_slots
    ]
    supplied_trace_reason = {
        "oneOf": [
            object_schema(
                {
                    "phase": {"const": "supplied-trace"},
                    "reason": {"const": "graph-identity-mismatch"},
                    "expectedGraphIdentity": identity,
                    "suppliedGraphIdentity": identity,
                }
            ),
            *[
                object_schema(
                    {
                        "phase": {"const": "supplied-trace"},
                        "reason": {"const": "exact-slot-unsupported"},
                        "slot": descriptor,
                        "endpoints": endpoints,
                        "disposition": {
                            "enum": ["missing-support", "candidate-only"]
                        },
                    }
                )
                for descriptor, endpoints in trace_slots
            ],
        ]
    }
    promotion_reason = object_schema(
        {
            "phase": {"const": "promotion"},
            "reason": {
                "enum": [
                    "strategy-assessment-unavailable",
                    "strategy-assessment-invalid",
                    "strategy-proof-model-mismatch",
                    "strategy-identity-mismatch",
                    "strategy-diagnosis-mismatch",
                    "strategy-intent-mismatch",
                    "strategy-action-not-in-formulation",
                    "strategy-key-result-not-in-formulation",
                ]
            },
        }
    )
    readiness_rules = core_companion["evidenceReadinessSemantics"]["ruleIds"]
    readiness_key_by_rule = core_companion["evidenceReadinessSemantics"][
        "evidenceKeyByRule"
    ]
    readiness_rule_groups = {
        key: [
            readiness_rules[name]
            for name, mapped_key in readiness_key_by_rule.items()
            if mapped_key == key
        ]
        for key in (
            "KPIDefinitionSlotKey",
            "PlannedStartSlotKey",
            "EvidencePlanSlotKey",
        )
    }
    readiness_diagnostic = {
        "oneOf": [
            object_schema(
                {
                    "ruleId": {
                        "enum": readiness_rule_groups["KPIDefinitionSlotKey"]
                    },
                    "evidenceKey": object_schema(
                        {"kind": {"const": "kpi-definition"}, "kpi": identity}
                    ),
                }
            ),
            object_schema(
                {
                    "ruleId": {
                        "enum": readiness_rule_groups["PlannedStartSlotKey"]
                    },
                    "evidenceKey": object_schema(
                        {
                            "kind": {"const": "planned-start"},
                            "intervention": identity,
                        }
                    ),
                }
            ),
            object_schema(
                {
                    "ruleId": {
                        "enum": readiness_rule_groups["EvidencePlanSlotKey"]
                    },
                    "evidenceKey": object_schema(
                        {
                            "kind": {"const": "evidence-plan"},
                            "trace": trace_identity,
                        }
                    ),
                }
            ),
        ]
    }
    readiness_criterion_reason = object_schema(
        {
            "phase": {"const": "readiness-criterion"},
            "diagnostic": readiness_diagnostic,
        }
    )
    subject = {"graphIdentity": identity, "traceIdentity": trace_identity}
    binding_unavailable = object_schema(
        {
            "suppliedTraceIdentity": trace_identity,
            "disposition": {"const": "subject-unavailable"},
            "reasons": array_schema(binding_reason, minimum=1),
        }
    )

    def reconstruction_unavailable(reason: dict[str, Any]) -> dict[str, Any]:
        return object_schema(
            {
                **subject,
                "disposition": {"const": "subject-unavailable"},
                "reasons": array_schema(reason, minimum=1),
            }
        )

    assessment_rules = core_companion["evidenceAssessmentSemantics"]["ruleIds"]
    assessment_key_by_rule = core_companion["evidenceAssessmentSemantics"][
        "evidenceKeyByRule"
    ]

    def rules_for(key: str) -> list[str]:
        return [
            assessment_rules[name]
            for name, mapped_key in assessment_key_by_rule.items()
            if mapped_key == key
        ]

    evidence_definitions = core_companion["evidenceInputSchema"]["$defs"]
    utc_timestamp = assessment_scalar_schema(
        evidence_definitions["UtcTimestamp"]
    )
    canonical_decimal = assessment_scalar_schema(
        evidence_definitions["CanonicalDecimal"]
    )
    canonical_text = assessment_scalar_schema(
        evidence_definitions["CanonicalText"]
    )
    unit = assessment_scalar_schema(evidence_definitions["Unit"])
    domain_value = {
        "oneOf": [
            object_schema(
                {
                    "kind": {"const": "quantitative"},
                    "value": canonical_decimal,
                    "unit": unit,
                }
            ),
            object_schema(
                {
                    "kind": {"const": "ordinal"},
                    "scaleId": canonical_text,
                    "level": canonical_text,
                }
            ),
            object_schema(
                {
                    "kind": {"const": "categorical"},
                    "value": canonical_text,
                }
            ),
        ]
    }

    assessment_diagnostic = {
        "oneOf": [
            object_schema(
                {
                    "ruleId": {"enum": rules_for("AssessmentSubjectKey")},
                    "evidenceKey": object_schema(
                        {"kind": {"const": "assessment-subject"}, **subject}
                    ),
                }
            ),
            object_schema(
                {
                    "ruleId": {"enum": rules_for("ActualStartKey")},
                    "evidenceKey": object_schema(
                        {"kind": {"const": "actual-start"}, "intervention": identity}
                    ),
                }
            ),
            object_schema(
                {
                    "ruleId": {"enum": rules_for("ObservationSetKey")},
                    "evidenceKey": object_schema(
                        {"kind": {"const": "observation-set"}, **subject}
                    ),
                }
            ),
            object_schema(
                {
                    "ruleId": {"enum": rules_for("ObservationKey")},
                    "evidenceKey": object_schema(
                        {
                            "kind": {"const": "observation"},
                            "traceIdentity": trace_identity,
                            "observedAt": utc_timestamp,
                        }
                    ),
                }
            ),
        ]
    }
    observation_key = {
        "sourceOrdinal": {"type": "integer", "minimum": 0},
        "traceIdentity": trace_identity,
        "observedAt": utc_timestamp,
        "source": canonical_text,
        "value": domain_value,
    }
    invalid_observation = object_schema(
        {
            **observation_key,
            "disposition": {"const": "invalid-observation"},
            "diagnostics": array_schema(assessment_diagnostic, minimum=1),
        }
    )
    assessed_observation = object_schema(
        {
            **observation_key,
            "disposition": {"const": "assessed-observation"},
            "effect": {
                "enum": [
                    "satisfied",
                    "not-satisfied",
                    "not-assessable-zero-baseline",
                ]
            },
            "target": {
                "enum": [
                    "satisfied-in-observation-by-due",
                    "satisfied-in-observation-after-due",
                    "not-satisfied-in-observation",
                ]
            },
            "limitations": exact_array(
                [
                    {"const": "causality-not-established"},
                    {"const": "first-target-attainment-time-not-established"},
                ]
            ),
        }
    )
    mixed_observations = array_schema(
        {"oneOf": [invalid_observation, assessed_observation]}, minimum=1
    )
    mixed_observations["contains"] = invalid_observation
    mixed_observations["minContains"] = 1
    assessed_observations = array_schema(assessed_observation, minimum=1)
    proof = object_schema(
        {
            **subject,
            "observationCount": {"type": "integer", "minimum": 1},
        }
    )
    assessment_source = object_schema(
        {
            "role": {"const": "assessment"},
            "ordinal": {"const": 0},
            "reference": text_schema(pattern=TOOL_TEXT_PATTERN),
            "sha256": text_schema(pattern=SHA256_PATTERN),
        }
    )
    supplemental_group = object_schema(
        {
            "reference": text_schema(pattern=TOOL_TEXT_PATTERN),
            "sha256": text_schema(pattern=SHA256_PATTERN),
            "diagnostics": {
                "type": "array",
                "items": {"oneOf": groups["binding"]},
            },
        }
    )
    shared = {
        "request": object_schema(
            {
                "view": selector,
                "adapterId": nullable(text_schema()),
                "assessment": source_input,
                "supplements": array_schema(source_input),
            }
        ),
        "diagnostics": object_schema(
            {
                "schema": {"const": "o2i.operation.diagnostic/v2"},
                "modelDiagnostics": array_schema(reference("modelDiagnostic")),
            }
        ),
        "provenance": object_schema({"contracts": contracts}),
    }

    def context(
        prerequisite: Optional[str],
        supplemental_diagnostics: bool = True,
    ) -> dict[str, Any]:
        if prerequisite in {"notation", "profile"}:
            assessment_context = {"type": "null"}
            supplements = {**array_schema(supplemental_group), "maxItems": 0}
        else:
            assessment_context = assessment_source
            group = supplemental_group
            if prerequisite == "structure" or not supplemental_diagnostics:
                group = copy.deepcopy(supplemental_group)
                group["properties"]["diagnostics"]["maxItems"] = 0
            supplements = array_schema(group)
        return object_schema(
            {
                "authority": reference("preparedAuthority"),
                "view": reference("assessViewDescriptor"),
                "assessment": assessment_context,
                "supplements": supplements,
            }
        )

    def variant(
        kind: str,
        status: str,
        exit_class: str,
        exit_code: int,
        assessment: dict[str, Any],
        prerequisite: Optional[str] = None,
        supplemental_diagnostics: bool = True,
    ) -> dict[str, Any]:
        execution = {
            "status": {"const": status},
            "exitClass": {"const": exit_class},
            "exitCode": {"const": exit_code},
        }
        if prerequisite is not None:
            execution["prerequisite"] = {"const": prerequisite}
        return operation_variant(
            document,
            "assess",
            kind,
            {
                "context": context(prerequisite, supplemental_diagnostics),
                **shared,
                "execution": object_schema(execution),
                "assessment": assessment,
            },
        )

    prerequisite = {
        "oneOf": [
            variant(
                "assess-prerequisite-rejected",
                "prerequisite-rejected",
                "subject-unavailable",
                3,
                {"type": "null"},
                stage,
            )
            for stage in ("notation", "profile", "structure", "semantics")
        ]
    }
    collection_invalid = object_schema(
        {
            **subject,
            "disposition": {"const": "collection-invalid"},
            "diagnostics": array_schema(assessment_diagnostic, minimum=1),
            "observations": {**array_schema(assessed_observation), "maxItems": 0},
            "proof": {"type": "null"},
        }
    )
    observations_invalid = object_schema(
        {
            **subject,
            "disposition": {"const": "observations-invalid"},
            "diagnostics": {**array_schema(assessment_diagnostic), "maxItems": 0},
            "observations": mixed_observations,
            "proof": {"type": "null"},
        }
    )
    completed = object_schema(
        {
            **subject,
            "disposition": {"const": "completed"},
            "diagnostics": {**array_schema(assessment_diagnostic), "maxItems": 0},
            "observations": assessed_observations,
            "proof": proof,
        }
    )
    definitions.update(
        {
            "toolDescriptor": tool_descriptor(),
            "assessViewDescriptor": view_descriptor(),
            "prerequisiteRejected": prerequisite,
            "subjectUnavailable": {
                "oneOf": [
                    variant(
                        "assess-subject-unavailable",
                        "subject-unavailable",
                        "subject-unavailable",
                        3,
                        binding_unavailable,
                        supplemental_diagnostics=False,
                    ),
                    *[
                        variant(
                            "assess-subject-unavailable",
                            "subject-unavailable",
                            "subject-unavailable",
                            3,
                            reconstruction_unavailable(reason),
                        )
                        for reason in (
                            supplied_trace_reason,
                            promotion_reason,
                            readiness_criterion_reason,
                        )
                    ],
                ]
            },
            "collectionInvalid": variant(
                "assess-collection-invalid",
                "collection-invalid",
                "primary-negative",
                1,
                collection_invalid,
            ),
            "observationsInvalid": variant(
                "assess-observations-invalid",
                "observations-invalid",
                "primary-negative",
                1,
                observations_invalid,
            ),
            "completed": variant(
                "assess-completed",
                "completed",
                "success",
                0,
                completed,
            ),
        }
    )
    return schema_document(
        document,
        "Selected-View evidence-assessment result",
        definitions,
        [
            "prerequisiteRejected",
            "subjectUnavailable",
            "collectionInvalid",
            "observationsInvalid",
            "completed",
        ],
    )


def diagnostic_schema(
    fragment: SchemaFragment,
    profile_inventory: Optional[dict[str, Any]] = None,
    core_inventory: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    return schema_fragment_document(
        fragment,
        "Prepared owner-bound Operation diagnostic document",
        diagnostic_definitions(profile_inventory, core_inventory),
        "preparedDiagnosticDocument",
    )


def command_error_schema(document: MachineDocument) -> dict[str, Any]:
    command_error, _ = load_object(COMMAND_ERROR_COMPANION)
    owner_branches = validate_command_error_owner_branches(
        command_error["ownerBranches"]
    )
    def input_failure(category: str) -> dict[str, Any]:
        return object_schema(
            {
                "category": {"const": category},
                "diagnostics": array_schema(
                    reference("inputFailureDiagnostic"), minimum=1
                ),
            }
        )

    def owner_failure(branches: list[str]) -> dict[str, Any]:
        return object_schema(
            {
                "category": {"const": "owner-contract"},
                "branch": {"enum": branches},
                "evidence": array_schema(
                    reference("commandOwnerEvidence"), minimum=1
                ),
            }
        )

    validate_owner_branches = [
        row["token"] for row in owner_branches["validate"]
    ]
    qualify_owner_branches = [
        row["token"] for row in owner_branches["qualify"]
    ]
    readiness_owner_branches = [
        row["token"] for row in owner_branches["readiness"]
    ]
    assess_owner_branches = [
        row["token"] for row in owner_branches["assess"]
    ]
    input_reasons = [
        "invalid-utf8",
        "invalid-json-syntax",
        "duplicate-object-member",
        "top-level-object-required",
        "type-member-invalid",
        "payload-type-not-admitted",
        "required-member-missing",
        "unknown-member",
        "value-kind-invalid",
        "scalar-grammar-invalid",
        "array-cardinality-invalid",
        "array-distinctness-invalid",
        "subject-cardinality-invalid",
        "identity-unknown",
        "identity-ambiguous",
        "identity-wrong-type",
        "identity-out-of-selected-view",
        "model-identity-unicode-scalar-invalid",
        "model-identity-contains-nul",
        "discriminator-invalid",
        "normalization-collision",
    ]
    field_names = [
        "jsonPointer",
        "expectedSchema",
        "payloadType",
        "subject",
        "identity",
        "unicodeScalars",
        "nulIndexes",
        "member",
        "observed",
        "expected",
        "minimum",
        "duplicate",
        "schema",
        "modelIdentity",
        "expectedGraphIdentity",
        "occurrence",
        "expectedQualifiedType",
        "zeroBasedIndex",
        "codePoint",
        "source",
        "adapter",
        "authorityAdapter",
        "contractAdapter",
        "notationIssueKind",
        "ruleId",
        "evidenceKind",
        "binding",
        "details",
        "modelIdentities",
        "cardinality",
        "projectionKinds",
        "owner",
        "endpointRole",
        "endpoint",
        "proposition",
        "sourceKey",
        "sources",
        "occurrences",
    ]
    owner_evidence_kinds = [
        "source-identity",
        "adapter-descriptor",
        "adapter-authority-mismatch",
        "adapter-notation-rule-missing",
        "unknown-generated-profile-rule",
        "generated-profile-evidence-mismatch",
        "missing-core-contract-binding",
        "impossible-occurrence-identity",
        "duplicate-model-identity",
        "unknown-selected-view-subject-occurrence",
        "selected-view-subject-identity-mismatch",
        "unknown-selected-view-occurrence",
        "duplicate-selected-view-occurrence",
        "projection-outside-selected-view",
        "duplicate-structure-projection",
        "missing-carrier-projection",
        "missing-structured-proposition-projection",
        "model-source-is-not-supplemental",
        "duplicate-supplemental-source",
        "semantic-occurrences",
        "semantic-graph-mismatch",
    ]
    scalar_values = [
        ("text", {"type": "string"}),
        ("natural", {"type": "integer", "minimum": 0}),
        ("model-identity", text_schema(pattern=TOOL_TEXT_PATTERN)),
        ("occurrence-identity", text_schema(pattern=TOOL_TEXT_PATTERN)),
        ("qualified-type", text_schema(pattern=TOOL_TEXT_PATTERN)),
    ]
    command_diagnostic_values = [
        object_schema({"kind": {"const": kind}, "value": value})
        for kind, value in scalar_values
    ] + [
        object_schema(
            {
                "kind": {"const": "source-key"},
                "role": {
                    "enum": ["model", "supplemental", "readiness", "assessment"]
                },
                "ordinal": {"type": "integer", "minimum": 0},
            }
        ),
        object_schema(
            {
                "kind": {"const": "source-identity"},
                "role": {
                    "enum": ["model", "supplemental", "readiness", "assessment"]
                },
                "ordinal": {"type": "integer", "minimum": 0},
                "reference": {"type": "string"},
                "sha256": text_schema(pattern="^[0-9a-f]{64}$"),
            }
        ),
        object_schema(
            {
                "kind": {"const": "adapter-descriptor"},
                "id": text_schema(pattern=TOOL_TEXT_PATTERN),
                "name": text_schema(pattern=TOOL_TEXT_PATTERN),
                "version": text_schema(pattern=TOOL_TEXT_PATTERN),
                "notation": text_schema(pattern=TOOL_TEXT_PATTERN),
            }
        ),
        object_schema(
            {
                "kind": {"const": "canonical-occurrence"},
                "occurrenceKind": {"enum": ["record", "property", "reference"]},
                "ordinal": {"type": "integer", "minimum": 0},
            }
        ),
        object_schema(
            {
                "kind": {"const": "unicode-scalar"},
                "index": {"type": "integer", "minimum": 0},
                "codePoint": {"type": "integer", "minimum": 0},
            }
        ),
    ]
    definitions = {
        "toolDescriptor": tool_descriptor(),
        "acquisitionFailure": object_schema(
            {
                "sourceKind": {"enum": ["file", "stdin"]},
                "sourceReference": text_schema(pattern=TOOL_TEXT_PATTERN),
                "message": {"type": "string"},
            }
        ),
        "inputFailureDiagnostic": object_schema(
            {
                "ruleId": text_schema(pattern=TOOL_TEXT_PATTERN),
                "inputOrdinals": array_schema(
                    {"type": "integer", "minimum": 0}, minimum=1
                ),
                "reason": {"enum": input_reasons},
                "fields": array_schema(reference("commandDiagnosticField")),
            }
        ),
        "commandDiagnosticValue": {"oneOf": command_diagnostic_values},
        "commandDiagnosticField": object_schema(
            {
                "name": {"enum": field_names},
                "values": array_schema(reference("commandDiagnosticValue")),
            }
        ),
        "commandOwnerEvidence": object_schema(
            {
                "kind": {"enum": owner_evidence_kinds},
                "fields": array_schema(reference("commandDiagnosticField")),
            }
        ),
        "validateFailure": {
            "oneOf": [
                input_failure("supplemental-input"),
                owner_failure(validate_owner_branches),
            ]
        },
        "qualifyFailure": {
            "oneOf": [
                input_failure("supplemental-input"),
                owner_failure(qualify_owner_branches),
            ]
        },
        "readinessFailure": {
            "oneOf": [
                input_failure("evidence-input"),
                input_failure("supplemental-input"),
                owner_failure(readiness_owner_branches),
            ]
        },
        "assessFailure": {
            "oneOf": [
                input_failure("assessment-input"),
                input_failure("supplemental-input"),
                owner_failure(assess_owner_branches),
            ]
        },
        "argumentInvalid": variant(
            document,
            "argument-invalid",
            {
                "tool": reference("toolDescriptor"),
                "code": text_schema(
                    pattern="^cli\\.argument\\.[a-z][a-z0-9]*(-[a-z0-9]+)*$"
                ),
                "message": text_schema(pattern=TOOL_TEXT_PATTERN),
            },
        ),
        "commandFailed": variant(
            document,
            "command-failed",
            {
                "tool": reference("toolDescriptor"),
                "code": {"const": "command.input-io"},
                "failure": reference("acquisitionFailure"),
            },
        ),
        "preparationFailed": variant(
            document,
            "preparation-failed",
            {
                "tool": reference("toolDescriptor"),
                "code": text_schema(pattern=TOOL_TEXT_PATTERN),
                "stage": {
                    "enum": [
                        "adapter-selection",
                        "adapter-decode",
                        "profile-marker",
                        "profile-resolution",
                        "profile-compatibility",
                        "view-selection",
                    ]
                },
            },
        ),
        "validateFailed": variant(
            document,
            "validate-failed",
            {
                "tool": reference("toolDescriptor"),
                "code": text_schema(pattern=TOOL_TEXT_PATTERN),
                "failure": reference("validateFailure"),
            },
        ),
        "qualifyFailed": variant(
            document,
            "qualify-failed",
            {
                "tool": reference("toolDescriptor"),
                "code": text_schema(pattern=TOOL_TEXT_PATTERN),
                "failure": reference("qualifyFailure"),
            },
        ),
        "readinessFailed": variant(
            document,
            "readiness-failed",
            {
                "tool": reference("toolDescriptor"),
                "code": text_schema(pattern=TOOL_TEXT_PATTERN),
                "failure": reference("readinessFailure"),
            },
        ),
        "assessFailed": variant(
            document,
            "assess-failed",
            {
                "tool": reference("toolDescriptor"),
                "code": text_schema(pattern=TOOL_TEXT_PATTERN),
                "failure": reference("assessFailure"),
            },
        ),
    }
    return schema_document(
        document,
        "Closed O2I command error",
        definitions,
        [
            "argumentInvalid",
            "commandFailed",
            "preparationFailed",
            "validateFailed",
            "qualifyFailed",
            "readinessFailed",
            "assessFailed",
        ],
    )


def schema_document(
    document: MachineDocument,
    title: str,
    definitions: dict[str, Any],
    roots: list[str],
) -> dict[str, Any]:
    return {
        "$schema": SCHEMA_DRAFT,
        "$id": document.reference,
        "title": title,
        "oneOf": [reference(root) for root in roots],
        "$defs": definitions,
    }


SCHEMA_BUILDERS: dict[str, Callable[..., dict[str, Any]]] = {
    "adapterInventory": adapter_inventory_schema,
    "profileInventory": profile_inventory_schema,
    "ruleInventory": rule_inventory_schema,
    "ruleExplanation": rule_explanation_schema,
    "viewDiscovery": view_discovery_schema,
    "qualificationSubjects": qualification_subjects_schema,
    "commandError": command_error_schema,
    "validateResult": validate_result_schema,
    "traceResult": trace_result_schema,
    "qualifyResult": qualify_result_schema,
    "readinessResult": readiness_result_schema,
    "assessResult": assess_result_schema,
}

SCHEMA_FRAGMENT_BUILDERS: dict[
    str, Callable[[SchemaFragment], dict[str, Any]]
] = {"diagnostic": diagnostic_schema}


def schema_fragment_document(
    fragment: SchemaFragment,
    title: str,
    definitions: dict[str, Any],
    root: str,
) -> dict[str, Any]:
    return {
        "$schema": SCHEMA_DRAFT,
        "$id": fragment.reference,
        "title": title,
        "$ref": f"#/$defs/{root}",
        "$defs": definitions,
    }


def verify_closed_objects(value: Any, subject: str) -> None:
    if isinstance(value, dict):
        if value.get("type") == "object" and value.get("additionalProperties") is not False:
            raise ValueError(f"{subject}: open object schema")
        for key, nested in value.items():
            verify_closed_objects(nested, f"{subject}/{key}")
    elif isinstance(value, list):
        for index, nested in enumerate(value):
            verify_closed_objects(nested, f"{subject}/{index}")


def verify_referenced_definitions(value: dict[str, Any], subject: str) -> None:
    definitions = value.get("$defs", {})
    root = value.get("$ref")
    if not isinstance(definitions, dict) or not isinstance(root, str):
        raise ValueError(f"{subject}: invalid Schema fragment root")
    pending = [root]
    reachable: set[str] = set()
    while pending:
        current = pending.pop()
        prefix = "#/$defs/"
        if not current.startswith(prefix):
            raise ValueError(f"{subject}: non-local Schema fragment reference")
        name = current.removeprefix(prefix)
        if name in reachable:
            continue
        if name not in definitions:
            raise ValueError(f"{subject}: missing Schema definition {name}")
        reachable.add(name)
        pending.extend(local_references(definitions[name]))
    unused = set(definitions) - reachable
    if unused:
        raise ValueError(
            f"{subject}: unreferenced Schema definitions {sorted(unused)!r}"
        )


def local_references(value: Any) -> list[str]:
    if isinstance(value, dict):
        references = [value["$ref"]] if isinstance(value.get("$ref"), str) else []
        return references + [
            reference
            for key, nested in value.items()
            if key != "$ref"
            for reference in local_references(nested)
        ]
    if isinstance(value, list):
        return [reference for nested in value for reference in local_references(nested)]
    return []


def render_schema(
    document: MachineDocument,
    profile_inventory: Optional[dict[str, Any]] = None,
    core_inventory: Optional[dict[str, Any]] = None,
    operation_contract: Optional[dict[str, Any]] = None,
    operation_digest: Optional[str] = None,
    core_companion: Optional[dict[str, Any]] = None,
) -> bytes:
    if document.name in (
        "qualificationSubjects",
        "validateResult",
        "qualifyResult",
    ):
        schema = SCHEMA_BUILDERS[document.name](
            document,
            profile_inventory,
            core_inventory,
            operation_contract,
            operation_digest,
        )
    elif document.name in ("traceResult", "readinessResult", "assessResult"):
        schema = SCHEMA_BUILDERS[document.name](
            document,
            profile_inventory,
            core_inventory,
            operation_contract,
            operation_digest,
            core_companion,
        )
    else:
        schema = SCHEMA_BUILDERS[document.name](document)
    verify_closed_objects(schema, document.name)
    return (
        json.dumps(schema, ensure_ascii=False, indent=2, separators=(",", ": "))
        + "\n"
    ).encode("utf-8")


def render_schema_fragment(
    fragment: SchemaFragment,
    profile_inventory: Optional[dict[str, Any]] = None,
    core_inventory: Optional[dict[str, Any]] = None,
) -> bytes:
    if fragment.name == "diagnostic":
        schema = diagnostic_schema(fragment, profile_inventory, core_inventory)
    else:
        schema = SCHEMA_FRAGMENT_BUILDERS[fragment.name](fragment)
    verify_closed_objects(schema, fragment.name)
    verify_referenced_definitions(schema, fragment.name)
    return (
        json.dumps(schema, ensure_ascii=False, indent=2, separators=(",", ": "))
        + "\n"
    ).encode("utf-8")


def hs_text(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def hs_embedded_schema(path: Path) -> str:
    relative = path.relative_to(PACKAGE_ROOT).as_posix()
    return f'$(embedSchemaBytes "../../../../{relative}")'


def projection_cases(rules: list[dict[str, str]], field: str) -> str:
    lines: list[str] = []
    for rule in rules:
        constructor = "Generated" + rule["constructor"]
        literal = hs_text(rule[field])
        branch = f"    {constructor} -> {literal}"
        if len(branch) <= 80:
            lines.append(branch)
        else:
            lines.extend([f"    {constructor} ->", f"      {literal}"])
    return "\n".join(lines)


def render_rules(contract: dict[str, str], rules: list[dict[str, str]], digest: str) -> str:
    constructors = "\n".join(
        ["  = Generated" + rules[0]["constructor"]]
        + ["  | Generated" + rule["constructor"] for rule in rules[1:]]
    )
    inventory = "\n       , ".join(
        "Generated" + rule["constructor"] for rule in rules[1:]
    )
    return f'''{{-# LANGUAGE OverloadedStrings #-}}

-- This module is generated by contract/compile.py. Do not edit.
module O2I.Operation.Rule.Generated where

import Data.List.NonEmpty (NonEmpty(..))
import Data.Text (Text)

operationContractIdentity :: Text
operationContractIdentity = {hs_text(contract['identity'])}

operationContractVersion :: Text
operationContractVersion = {hs_text(contract['version'])}

operationContractSha256 :: Text
operationContractSha256 =
  {hs_text(digest)}

data GeneratedOperationRuleStage =
  GeneratedPreparationStage
  deriving (Bounded, Enum, Eq, Ord, Show)

data GeneratedOperationRule
{constructors}
  deriving (Bounded, Enum, Eq, Ord, Show)

generatedOperationRuleId :: GeneratedOperationRule -> Text
generatedOperationRuleId value =
  case value of
{projection_cases(rules, 'id')}

generatedOperationRuleExpectation :: GeneratedOperationRule -> Text
generatedOperationRuleExpectation value =
  case value of
{projection_cases(rules, 'expectation')}

generatedOperationRuleMeaning :: GeneratedOperationRule -> Text
generatedOperationRuleMeaning value =
  case value of
{projection_cases(rules, 'meaning')}

generatedOperationRuleAction :: GeneratedOperationRule -> Text
generatedOperationRuleAction value =
  case value of
{projection_cases(rules, 'action')}

generatedOperationRuleStage ::
     GeneratedOperationRule -> GeneratedOperationRuleStage
generatedOperationRuleStage _ = GeneratedPreparationStage

generatedOperationRules :: NonEmpty GeneratedOperationRule
generatedOperationRules =
  Generated{rules[0]['constructor']}
    :| [ {inventory}
       ]
'''


def hs_machine_schema(document: MachineDocument, schema_bytes: bytes) -> str:
    variants = document.variants
    variant_names = [VARIANT_BINDINGS[variant] for variant in variants]
    if len(variant_names) == 1:
        inventory = f"    , machineSchemaVariantsValue = {variant_names[0]} :| []"
    elif len(variant_names) == 2:
        inventory = (
            "    , machineSchemaVariantsValue =\n"
            f"        {variant_names[0]} :| [{variant_names[1]}]"
        )
    else:
        tail = "\n             , ".join(variant_names[1:])
        inventory = (
            "    , machineSchemaVariantsValue =\n"
            f"        {variant_names[0]}\n"
            f"          :| [ {tail}\n             ]"
        )
    digest = hashlib.sha256(schema_bytes).hexdigest()
    rendered_variants = []
    for variant in variants:
        binding = VARIANT_BINDINGS[variant]
        assignment = f"{binding} = SchemaVariant {hs_text(variant)}"
        if len(assignment) <= 80:
            rendered_variants.append(f"{binding} :: SchemaVariant\n{assignment}")
        else:
            rendered_variants.append(
                f"{binding} :: SchemaVariant\n"
                f"{binding} =\n"
                f"  SchemaVariant {hs_text(variant)}"
            )
    variant_bindings = "\n\n".join(rendered_variants)
    identity_assignment = (
        "          { schemaAuthorityIdentityValue = "
        f"SchemaIdentity {hs_text(document.identity)}"
    )
    if len(identity_assignment) <= 80:
        identity = identity_assignment
    else:
        identity = (
            "          { schemaAuthorityIdentityValue =\n"
            f"              SchemaIdentity {hs_text(document.identity)}"
        )
    schema_bytes_binding = ""
    if document.name == "commandError":
        schema_bytes_binding = f'''\n\ncommandErrorSchemaBytes :: ByteString
commandErrorSchemaBytes = {hs_embedded_schema(document.schema_path)}'''
    return f'''{variant_bindings}

{document.binding} :: MachineSchema
{document.binding} =
  MachineSchema
    {{ machineSchemaAuthorityValue =
        SchemaAuthority
{identity}
          , schemaAuthorityVersionValue = SchemaVersion {document.version}
          , schemaAuthorityDigestValue =
              SchemaDigest
                {hs_text(digest)}
          }}
{inventory}
    }}{schema_bytes_binding}'''


def hs_schema_fragment_authority(
    fragment: SchemaFragment, schema_bytes: bytes
) -> str:
    digest = hashlib.sha256(schema_bytes).hexdigest()
    return f'''{fragment.binding} :: SchemaAuthority
{fragment.binding} =
  SchemaAuthority
    {{ schemaAuthorityIdentityValue = SchemaIdentity {hs_text(fragment.identity)}
    , schemaAuthorityVersionValue = SchemaVersion {fragment.version}
    , schemaAuthorityDigestValue = SchemaDigest {hs_text(digest)}
    }}'''


def render_schema_module(
    documents: list[MachineDocument],
    schemas: dict[str, bytes],
    fragments: list[SchemaFragment],
    fragment_schemas: dict[str, bytes],
) -> str:
    bindings = "\n\n".join(
        [
            hs_machine_schema(document, schemas[document.name])
            for document in documents
        ]
        + [
            hs_schema_fragment_authority(
                fragment, fragment_schemas[fragment.name]
            )
            for fragment in fragments
        ]
    )
    return f'''{{-# LANGUAGE OverloadedStrings #-}}
{{-# LANGUAGE TemplateHaskell #-}}

-- This module is generated by contract/compile.py. Do not edit.
module O2I.Operation.Schema.Generated where

import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty(..))
import O2I.Operation.Schema.Embed (embedSchemaBytes)
import O2I.Operation.Schema.Internal

{bindings}
'''


def render_command_error_branch_module(
    branches: dict[str, list[dict[str, str]]],
) -> str:
    capabilities = ["validate", "qualify", "readiness", "assess"]
    type_names = {
        capability: capability.capitalize() + "OwnerBranch"
        for capability in capabilities
    }
    module_names = {
        "validate": "ValidateInternal",
        "qualify": "QualifyInternal",
        "readiness": "ReadinessInternal",
        "assess": "AssessInternal",
    }

    def generated_constructor(row: dict[str, str]) -> str:
        return "Generated" + row["constructor"].removesuffix("Failure")

    declarations: list[str] = []
    for capability in capabilities:
        type_name = type_names[capability]
        rows = branches[capability]
        constructors = "\n".join(
            [f"  = {generated_constructor(rows[0])}"]
            + [f"  | {generated_constructor(row)}" for row in rows[1:]]
        )
        token_cases = "\n".join(
            f"    {generated_constructor(row)} -> {hs_text(row['token'])}"
            for row in rows
        )
        inventory_tail = "\n           , ".join(
            generated_constructor(row) for row in rows[1:]
        )
        module_name = module_names[capability]
        projector_cases = "\n".join(
            f"    {module_name}.{row['constructor']} _ -> "
            f"{generated_constructor(row)}"
            for row in rows
        )
        declarations.append(
            f'''data {type_name}
{constructors}
  deriving (Bounded, Enum, Eq, Ord, Show)

{capability}OwnerBranchToken :: {type_name} -> Text
{capability}OwnerBranchToken branch =
  case branch of
{token_cases}

{capability}OwnerBranches :: NonEmpty {type_name}
{capability}OwnerBranches =
  {generated_constructor(rows[0])}
    :| [ {inventory_tail}
       ]

{capability}OwnerBranch ::
     {module_name}.{capability.capitalize()}InternalFailure -> {type_name}
{capability}OwnerBranch failure =
  case failure of
{projector_cases}'''
        )

    union_constructors = "\n".join(
        ["  = ValidateCommandOwnerBranch !ValidateOwnerBranch"]
        + [
            f"  | {capability.capitalize()}CommandOwnerBranch "
            f"!{type_names[capability]}"
            for capability in capabilities[1:]
        ]
    )
    union_cases = "\n".join(
        f"    {capability.capitalize()}CommandOwnerBranch capabilityBranch ->\n"
        f"      {capability}OwnerBranchToken capabilityBranch"
        for capability in capabilities
    )
    declarations.append(
        f'''data CommandOwnerBranch
{union_constructors}
  deriving (Eq, Ord, Show)

commandOwnerBranchToken :: CommandOwnerBranch -> Text
commandOwnerBranchToken branch =
  case branch of
{union_cases}'''
    )
    body = "\n\n".join(declarations)
    return f'''{{-# LANGUAGE OverloadedStrings #-}}

-- This module is generated by contract/compile.py. Do not edit.
module O2I.Operation.Command.Error.Branch.Generated where

import Data.List.NonEmpty (NonEmpty(..))
import Data.Text (Text)
import qualified O2I.Operation.Assess.Result.Internal as AssessInternal
import qualified O2I.Operation.Qualify.Result.Internal as QualifyInternal
import qualified O2I.Operation.Readiness.Result.Internal as ReadinessInternal
import qualified O2I.Operation.Validate.Result.Internal as ValidateInternal

{body}
'''


def format_generated_haskell(rendered: str, subject: str) -> bytes:
    formatted = subprocess.run(
        ["hindent", "--line-length", "80"],
        input=rendered,
        text=True,
        capture_output=True,
        check=False,
    )
    if formatted.returncode != 0:
        raise ValueError(f"hindent rejected generated {subject}: {formatted.stderr}")
    return formatted.stdout.encode("utf-8")


def render_outputs(
    profile_companion: Path = DEFAULT_PROFILE_COMPANION,
    profile_diagnostic_inventory: Path = DEFAULT_PROFILE_DIAGNOSTIC_INVENTORY,
    core_owner_diagnostic_inventory: Path = DEFAULT_CORE_OWNER_DIAGNOSTIC_INVENTORY,
    core_companion: Path = DEFAULT_CORE_COMPANION,
) -> dict[Path, bytes]:
    (
        contract,
        rules,
        digest,
        documents,
        fragments,
        profile_inventory,
        core_inventory,
    ) = validate(
        profile_companion,
        profile_diagnostic_inventory,
        core_owner_diagnostic_inventory,
    )
    bound_core_companion = load_bound_core_companion(
        core_companion, core_inventory
    )
    schemas = {
        document.name: render_schema(
            document,
            profile_inventory,
            core_inventory,
            contract,
            digest,
            bound_core_companion,
        )
        for document in documents
    }
    fragment_schemas = {
        fragment.name: render_schema_fragment(
            fragment, profile_inventory, core_inventory
        )
        for fragment in fragments
    }
    command_error, _ = load_object(COMMAND_ERROR_COMPANION)
    owner_branches = validate_command_error_owner_branches(
        command_error["ownerBranches"]
    )
    outputs: dict[Path, bytes] = {
        RULE_GENERATED: render_rules(contract, rules, digest).encode("utf-8"),
        SCHEMA_GENERATED: format_generated_haskell(
            render_schema_module(
                documents, schemas, fragments, fragment_schemas
            ),
            "Schema authority",
        ),
        COMMAND_ERROR_BRANCH_GENERATED: format_generated_haskell(
            render_command_error_branch_module(owner_branches),
            "command-error owner branches",
        ),
    }
    outputs.update(
        {document.schema_path: schemas[document.name] for document in documents}
    )
    outputs.update(
        {
            fragment.schema_path: fragment_schemas[fragment.name]
            for fragment in fragments
        }
    )
    return outputs


def render() -> str:
    """Preserve the focused rule-rendering seam used by existing callers."""
    return render_outputs()[RULE_GENERATED].decode("utf-8")


def check_outputs(outputs: dict[Path, bytes]) -> None:
    missing = [path for path in outputs if not path.exists()]
    stale = [
        path for path, expected in outputs.items()
        if path.exists() and path.read_bytes() != expected
    ]
    if missing or stale:
        details = [f"missing: {path}" for path in missing]
        details.extend(f"stale: {path}" for path in stale)
        raise SystemExit("generated Operation contract is stale\n" + "\n".join(details))


def write_outputs(outputs: dict[Path, bytes]) -> None:
    staged: list[tuple[Path, Path]] = []
    try:
        for destination, payload in outputs.items():
            destination.parent.mkdir(parents=True, exist_ok=True)
            descriptor, temporary = tempfile.mkstemp(
                prefix=f".{destination.name}.", dir=destination.parent
            )
            temporary_path = Path(temporary)
            try:
                with os.fdopen(descriptor, "wb") as handle:
                    handle.write(payload)
                    handle.flush()
                    os.fsync(handle.fileno())
            except Exception:
                temporary_path.unlink(missing_ok=True)
                raise
            staged.append((temporary_path, destination))
        for temporary, destination in staged:
            os.replace(temporary, destination)
    finally:
        for temporary, _ in staged:
            temporary.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--write", action="store_true")
    parser.add_argument(
        "--profile-companion",
        type=Path,
        required=True,
        help="path to the exact authoritative ArchiMate Profile companion",
    )
    parser.add_argument(
        "--profile-diagnostic-inventory",
        type=Path,
        required=True,
        help="path to the exact Profile diagnostic evidence inventory",
    )
    parser.add_argument(
        "--core-owner-diagnostic-inventory",
        type=Path,
        required=True,
        help="path to the exact Core owner diagnostic evidence inventory",
    )
    parser.add_argument(
        "--core-companion",
        type=Path,
        required=True,
        help="path to the exact authoritative Core semantic companion",
    )
    args = parser.parse_args()
    outputs = render_outputs(
        args.profile_companion,
        args.profile_diagnostic_inventory,
        args.core_owner_diagnostic_inventory,
        args.core_companion,
    )
    if args.write:
        write_outputs(outputs)
    else:
        check_outputs(outputs)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
