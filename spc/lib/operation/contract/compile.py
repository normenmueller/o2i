#!/usr/bin/env python3
"""Compile the authoritative Operation companion into static artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import tempfile
from pathlib import Path
from typing import Any, Callable, NamedTuple


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
COMPANION = PACKAGE_ROOT / "contract/operation.json"
DEFAULT_PROFILE_COMPANION = (
    PACKAGE_ROOT.parents[1] / "ctr/archimate/profile.json"
)
RULE_GENERATED = PACKAGE_ROOT / "src/O2I/Operation/Rule/Generated.hs"
SCHEMA_GENERATED = PACKAGE_ROOT / "src/O2I/Operation/Schema/Generated.hs"
SCHEMA_DIRECTORY = PACKAGE_ROOT / "contract/schema"
GENERATED = RULE_GENERATED

SCHEMA_DRAFT = "https://json-schema.org/draft/2020-12/schema"
SHA256_PATTERN = "^[0-9a-f]{64}$"
TOKEN_PATTERN = "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
IDENTITY_PATTERN = (
    "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*"
    "(?:\\.[a-z][a-z0-9]*(?:-[a-z0-9]+)*)+$"
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
)
EXPECTED_VARIANTS = dict(EXPECTED_DOCUMENTS)

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


def validate_machine_documents(value: Any) -> list[MachineDocument]:
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
    if tuple(names) != tuple(name for name, _ in EXPECTED_DOCUMENTS):
        raise ValueError("machine documents are not in canonical order")
    return documents


def validate(
    profile_companion: Path = DEFAULT_PROFILE_COMPANION,
) -> tuple[dict[str, str], list[dict[str, str]], str, list[MachineDocument]]:
    companion, payload = load_object(COMPANION)
    require_keys(
        companion,
        {"schema", "contract", "machineDocuments", "rules", "profileConformance"},
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

    return checked_contract, rules, hashlib.sha256(payload).hexdigest(), documents


def text_schema(*, pattern: str | None = None) -> dict[str, Any]:
    schema: dict[str, Any] = {"type": "string", "minLength": 1}
    if pattern is not None:
        schema["pattern"] = pattern
    return schema


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


def adapter_occurrence() -> dict[str, Any]:
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
                    "steps": array_schema(text_schema(), minimum=1),
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
        "viewsDiscovered": variant(
            document,
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


SCHEMA_BUILDERS: dict[str, Callable[[MachineDocument], dict[str, Any]]] = {
    "adapterInventory": adapter_inventory_schema,
    "profileInventory": profile_inventory_schema,
    "ruleInventory": rule_inventory_schema,
    "ruleExplanation": rule_explanation_schema,
    "viewDiscovery": view_discovery_schema,
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


def render_schema(document: MachineDocument) -> bytes:
    schema = SCHEMA_BUILDERS[document.name](document)
    verify_closed_objects(schema, document.name)
    return (
        json.dumps(schema, ensure_ascii=False, indent=2, separators=(",", ": "))
        + "\n"
    ).encode("utf-8")


def hs_text(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


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
    }}'''


def render_schema_module(
    documents: list[MachineDocument], schemas: dict[str, bytes]
) -> str:
    bindings = "\n\n".join(
        hs_machine_schema(document, schemas[document.name])
        for document in documents
    )
    return f'''{{-# LANGUAGE OverloadedStrings #-}}

-- This module is generated by contract/compile.py. Do not edit.
module O2I.Operation.Schema.Generated where

import Data.List.NonEmpty (NonEmpty(..))
import O2I.Operation.Schema.Internal

{bindings}
'''


def render_outputs(
    profile_companion: Path = DEFAULT_PROFILE_COMPANION,
) -> dict[Path, bytes]:
    contract, rules, digest, documents = validate(profile_companion)
    schemas = {document.name: render_schema(document) for document in documents}
    outputs: dict[Path, bytes] = {
        RULE_GENERATED: render_rules(contract, rules, digest).encode("utf-8"),
        SCHEMA_GENERATED: render_schema_module(documents, schemas).encode("utf-8"),
    }
    outputs.update(
        {document.schema_path: schemas[document.name] for document in documents}
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
    args = parser.parse_args()
    outputs = render_outputs(args.profile_companion)
    if args.write:
        write_outputs(outputs)
    else:
        check_outputs(outputs)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
