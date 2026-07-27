"""Strict structural decoder for an O2I ArchiMate profile contract."""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import re
from typing import Any, Dict, Iterable, List, Optional, Tuple, Union


SUPPORTED_SCHEMA = "o2i.archimate-profile/v1"

ARCHIMATE_ELEMENTS = frozenset(
    {
        "Assessment", "BusinessObject", "BusinessProcess", "BusinessRole",
        "Capability", "CourseOfAction", "Driver", "Goal", "Grouping",
        "Junction", "Outcome", "Principle", "Requirement", "ValueStream",
    }
)
ARCHIMATE_RELATIONSHIPS = frozenset(
    {
        "AggregationRelationship", "AssociationRelationship",
        "CompositionRelationship", "InfluenceRelationship",
        "RealizationRelationship",
    }
)
JUNCTION_TYPES = frozenset({"and", "or"})

ROOT_FIELDS = (
    "schema", "profileVersion", "metadata", "carrierMappings",
    "relationMappings", "patternMappings",
)
MODEL_ROOT_FIELDS = ("profileKey", "cardinality", "additionalO2IProperties")
TYPED_CARRIER_FIELDS = (
    "kindKey", "typeKey", "commitmentKey", "commitmentValues", "cardinality",
    "additionalO2IProperties",
)
SEMANTIC_RELATION_FIELDS = (
    "commitmentKey", "commitmentValues", "cardinality",
    "additionalO2IProperties",
)
CARRIER_FIELDS = (
    "id", "o2iKind", "o2iTypes", "archimateElement", "contextOwnership",
)
RELATION_FIELDS = (
    "id", "relationName", "source", "target", "label",
    "archimateRelationship", "associationDirected",
)
CONTEXTUALIZATION_FIELDS = (
    "id", "archimateRelationship", "label", "associationDirected",
    "sourceKind", "targetKinds", "targetIncomingCardinality", "o2iMetadata",
    "projection",
)
COLLECTIVE_FIELDS = (
    "id", "carrier", "segments", "contributors", "target",
    "junctionChains", "projection",
)
COLLECTIVE_CARRIER_FIELDS = (
    "o2iKind", "o2iType", "archimateElement", "junctionType",
    "commitmentKey", "commitmentValues", "fitEvidenceKey",
    "fitEvidenceCardinality", "additionalO2IProperties",
)
COLLECTIVE_SEGMENT_FIELDS = (
    "archimateRelationship", "label", "associationDirected", "o2iMetadata",
)
COLLECTIVE_CONTRIBUTOR_FIELDS = ("endpoint", "cardinality", "distinct")
COLLECTIVE_TARGET_FIELDS = (
    "endpoint", "cardinality", "distinctFromContributors",
)

IDENTIFIER = re.compile(r"^[a-z][a-z0-9]*(?:[.-][a-z0-9]+)*$")
PROPERTY_KEY = re.compile(r"^o2i\.[a-z][a-z0-9.-]*$")


class ProfileContractError(ValueError):
    """The document does not satisfy the supported contract structure."""


@dataclass(frozen=True)
class FrozenObject:
    """Deterministically ordered immutable JSON object."""

    fields: Tuple[Tuple[str, Any], ...]

    def __getitem__(self, key: str) -> Any:
        for name, value in self.fields:
            if name == key:
                return value
        raise KeyError(key)


@dataclass(frozen=True)
class ArchimateProfileContract:
    """Normalized contract ready for equality against another authority."""

    schema: str
    profile_version: str
    metadata: FrozenObject
    carrier_mappings: Tuple[FrozenObject, ...]
    relation_mappings: Tuple[FrozenObject, ...]
    pattern_mappings: Tuple[FrozenObject, ...]


@dataclass(frozen=True)
class _MetadataReferences:
    commitment_key: str
    commitment_values: Tuple[str, ...]
    additional_properties: str


@dataclass(frozen=True)
class _Carrier:
    identifier: str
    kind: str
    types: Tuple[str, ...]


@dataclass(frozen=True)
class _Contextualization:
    source_kind: str
    target_kinds: Tuple[str, ...]


def load_profile_contract(path: Union[Path, str]) -> ArchimateProfileContract:
    """Load and structurally validate one UTF-8 profile contract."""
    try:
        source = Path(path).read_text(encoding="utf-8")
    except UnicodeDecodeError as error:
        raise ProfileContractError(f"invalid UTF-8: {error}") from error
    return decode_profile_contract(source)


def decode_profile_contract(source: str) -> ArchimateProfileContract:
    """Decode unambiguous JSON into deterministic immutable records."""
    try:
        value = json.loads(
            source,
            object_pairs_hook=_unique_object,
            parse_constant=_reject_constant,
        )
    except json.JSONDecodeError as error:
        raise ProfileContractError(f"invalid JSON: {error}") from error

    root = _record(value, ROOT_FIELDS, "$")
    schema = _exact_text(root["schema"], SUPPORTED_SCHEMA, "$.schema")
    profile_version = _text(root["profileVersion"], "$.profileVersion")
    metadata = _validate_metadata(root["metadata"])
    carriers = _validate_carriers(root["carrierMappings"])
    patterns, contextualization = _validate_patterns(
        root["patternMappings"],
        metadata,
        carriers,
    )
    endpoints = _declared_endpoints(carriers, contextualization)
    _validate_relations(root["relationMappings"], endpoints)
    _validate_pattern_endpoints(patterns, endpoints)

    return ArchimateProfileContract(
        schema=schema,
        profile_version=profile_version,
        metadata=_freeze(root["metadata"]),
        carrier_mappings=_freeze_records(root["carrierMappings"]),
        relation_mappings=_freeze_records(root["relationMappings"]),
        pattern_mappings=_freeze_records(root["patternMappings"]),
    )


def _validate_metadata(value: Any) -> _MetadataReferences:
    metadata = _record(
        value,
        ("modelRoot", "typedCarrier", "semanticRelation"),
        "$.metadata",
    )
    model = _record(
        metadata["modelRoot"],
        MODEL_ROOT_FIELDS,
        "$.metadata.modelRoot",
    )
    _property_key(model["profileKey"], "$.metadata.modelRoot.profileKey")
    _text(model["cardinality"], "$.metadata.modelRoot.cardinality")
    _text(
        model["additionalO2IProperties"],
        "$.metadata.modelRoot.additionalO2IProperties",
    )

    carrier = _record(
        metadata["typedCarrier"],
        TYPED_CARRIER_FIELDS,
        "$.metadata.typedCarrier",
    )
    kind_key = _property_key(
        carrier["kindKey"],
        "$.metadata.typedCarrier.kindKey",
    )
    type_key = _property_key(
        carrier["typeKey"],
        "$.metadata.typedCarrier.typeKey",
    )
    carrier_key = _property_key(
        carrier["commitmentKey"],
        "$.metadata.typedCarrier.commitmentKey",
    )
    carrier_values = _texts(
        carrier["commitmentValues"],
        "$.metadata.typedCarrier.commitmentValues",
    )
    _text(carrier["cardinality"], "$.metadata.typedCarrier.cardinality")
    additional = _text(
        carrier["additionalO2IProperties"],
        "$.metadata.typedCarrier.additionalO2IProperties",
    )
    if len({kind_key, type_key, carrier_key}) != 3:
        raise ProfileContractError(
            "$.metadata.typedCarrier property keys must be distinct"
        )

    relation = _record(
        metadata["semanticRelation"],
        SEMANTIC_RELATION_FIELDS,
        "$.metadata.semanticRelation",
    )
    relation_key = _property_key(
        relation["commitmentKey"],
        "$.metadata.semanticRelation.commitmentKey",
    )
    relation_values = _texts(
        relation["commitmentValues"],
        "$.metadata.semanticRelation.commitmentValues",
    )
    _text(
        relation["cardinality"],
        "$.metadata.semanticRelation.cardinality",
    )
    _text(
        relation["additionalO2IProperties"],
        "$.metadata.semanticRelation.additionalO2IProperties",
    )
    if (carrier_key, carrier_values) != (relation_key, relation_values):
        raise ProfileContractError(
            "$.metadata commitment contracts must agree"
        )
    return _MetadataReferences(carrier_key, carrier_values, additional)


def _validate_carriers(value: Any) -> Tuple[_Carrier, ...]:
    entries = _array(value, "$.carrierMappings")
    identifiers = set()
    declarations = set()
    carriers = []
    for index, value in enumerate(entries):
        path = f"$.carrierMappings[{index}]"
        entry = _record(value, CARRIER_FIELDS, path)
        identifier = _identifier(entry["id"], f"{path}.id")
        kind = _text(entry["o2iKind"], f"{path}.o2iKind")
        types = _texts(entry["o2iTypes"], f"{path}.o2iTypes")
        _enum(
            entry["archimateElement"],
            ARCHIMATE_ELEMENTS,
            f"{path}.archimateElement",
        )
        _text(entry["contextOwnership"], f"{path}.contextOwnership")
        _add_unique(identifiers, identifier, f"{path}.id")
        for o2i_type in types:
            _add_unique(
                declarations,
                (kind, o2i_type),
                f"{path}.o2iTypes",
            )
        carriers.append(_Carrier(identifier, kind, types))
    return tuple(carriers)


def _validate_relations(value: Any, endpoints: frozenset) -> None:
    entries = _array(value, "$.relationMappings")
    identifiers = set()
    for index, value in enumerate(entries):
        path = f"$.relationMappings[{index}]"
        entry = _record(value, RELATION_FIELDS, path)
        identifier = _identifier(entry["id"], f"{path}.id")
        _add_unique(identifiers, identifier, f"{path}.id")
        _identifier(entry["relationName"], f"{path}.relationName")
        source = _identifier(entry["source"], f"{path}.source")
        target = _identifier(entry["target"], f"{path}.target")
        _reference(source, endpoints, f"{path}.source")
        _reference(target, endpoints, f"{path}.target")
        _identifier(entry["label"], f"{path}.label")
        _validate_relationship(entry, path)


def _validate_patterns(
    value: Any,
    metadata: _MetadataReferences,
    carriers: Tuple[_Carrier, ...],
) -> Tuple[Dict[str, Dict[str, Any]], Optional[_Contextualization]]:
    entries = _array(value, "$.patternMappings")
    identifiers = set()
    patterns = {}
    contextualization = None
    carrier_kinds = frozenset(carrier.kind for carrier in carriers)
    for index, value in enumerate(entries):
        path = f"$.patternMappings[{index}]"
        entry = _object(value, path)
        identifier = _identifier(entry.get("id"), f"{path}.id")
        _add_unique(identifiers, identifier, f"{path}.id")
        if identifier == "contextualization":
            contextualization = _validate_contextualization(
                entry,
                path,
                carrier_kinds,
            )
        elif identifier == "collective-strategy-realization":
            _validate_collective(entry, path, metadata)
        else:
            raise ProfileContractError(
                f"{path}.id has no supported pattern shape: {identifier}"
            )
        patterns[identifier] = entry
    return patterns, contextualization


def _validate_contextualization(
    entry: Dict[str, Any],
    path: str,
    carrier_kinds: frozenset,
) -> _Contextualization:
    _exact_fields(entry, CONTEXTUALIZATION_FIELDS, path)
    _validate_relationship(entry, path)
    _identifier(entry["label"], f"{path}.label")
    source = _text(entry["sourceKind"], f"{path}.sourceKind")
    targets = _texts(entry["targetKinds"], f"{path}.targetKinds")
    _reference(source, carrier_kinds, f"{path}.sourceKind")
    for index, target in enumerate(targets):
        _reference(target, carrier_kinds, f"{path}.targetKinds[{index}]")
    _text(
        entry["targetIncomingCardinality"],
        f"{path}.targetIncomingCardinality",
    )
    _text(entry["o2iMetadata"], f"{path}.o2iMetadata")
    _identifier(entry["projection"], f"{path}.projection")
    return _Contextualization(source, targets)


def _validate_collective(
    entry: Dict[str, Any],
    path: str,
    metadata: _MetadataReferences,
) -> None:
    _exact_fields(entry, COLLECTIVE_FIELDS, path)
    carrier_path = f"{path}.carrier"
    carrier = _record(
        entry["carrier"],
        COLLECTIVE_CARRIER_FIELDS,
        carrier_path,
    )
    _text(carrier["o2iKind"], f"{carrier_path}.o2iKind")
    _text(carrier["o2iType"], f"{carrier_path}.o2iType")
    carrier_element = _enum(
        carrier["archimateElement"],
        ARCHIMATE_ELEMENTS,
        f"{carrier_path}.archimateElement",
    )
    _enum(
        carrier["junctionType"],
        JUNCTION_TYPES,
        f"{carrier_path}.junctionType",
    )
    if carrier_element != "Junction":
        raise ProfileContractError(
            f"{carrier_path}.junctionType requires a Junction"
        )
    commitment_key = _property_key(
        carrier["commitmentKey"],
        f"{carrier_path}.commitmentKey",
    )
    commitment_values = _texts(
        carrier["commitmentValues"],
        f"{carrier_path}.commitmentValues",
    )
    fit_evidence_key = _property_key(
        carrier["fitEvidenceKey"],
        f"{carrier_path}.fitEvidenceKey",
    )
    _text(
        carrier["fitEvidenceCardinality"],
        f"{carrier_path}.fitEvidenceCardinality",
    )
    additional = _text(
        carrier["additionalO2IProperties"],
        f"{carrier_path}.additionalO2IProperties",
    )
    if (
        commitment_key,
        commitment_values,
        additional,
    ) != (
        metadata.commitment_key,
        metadata.commitment_values,
        metadata.additional_properties,
    ):
        raise ProfileContractError(
            f"{carrier_path} must use the typed-carrier metadata contract"
        )
    if fit_evidence_key == commitment_key:
        raise ProfileContractError(
            f"{carrier_path} property keys must be distinct"
        )

    segment_path = f"{path}.segments"
    segments = _record(
        entry["segments"],
        COLLECTIVE_SEGMENT_FIELDS,
        segment_path,
    )
    _validate_relationship(segments, segment_path)
    _identifier(segments["label"], f"{segment_path}.label")
    _text(segments["o2iMetadata"], f"{segment_path}.o2iMetadata")

    contributors = _record(
        entry["contributors"],
        COLLECTIVE_CONTRIBUTOR_FIELDS,
        f"{path}.contributors",
    )
    _identifier(
        contributors["endpoint"],
        f"{path}.contributors.endpoint",
    )
    _text(
        contributors["cardinality"],
        f"{path}.contributors.cardinality",
    )
    _text(contributors["distinct"], f"{path}.contributors.distinct")

    target = _record(
        entry["target"],
        COLLECTIVE_TARGET_FIELDS,
        f"{path}.target",
    )
    _identifier(target["endpoint"], f"{path}.target.endpoint")
    _text(target["cardinality"], f"{path}.target.cardinality")
    _text(
        target["distinctFromContributors"],
        f"{path}.target.distinctFromContributors",
    )
    _text(entry["junctionChains"], f"{path}.junctionChains")
    _identifier(entry["projection"], f"{path}.projection")


def _declared_endpoints(
    carriers: Tuple[_Carrier, ...],
    contextualization: Optional[_Contextualization],
) -> frozenset:
    if contextualization is None:
        return frozenset(carrier.identifier for carrier in carriers)

    context_tokens = tuple(
        _type_token(o2i_type)
        for carrier in carriers
        if carrier.kind == contextualization.source_kind
        for o2i_type in carrier.types
    )
    endpoints = set()
    for carrier in carriers:
        if carrier.kind == contextualization.source_kind:
            generated = (
                f"{carrier.identifier}.{token}" for token in context_tokens
            )
        elif carrier.kind in contextualization.target_kinds:
            prefix, separator, suffix = carrier.identifier.partition(".")
            if not separator:
                raise ProfileContractError(
                    f"carrier {carrier.identifier} cannot be contextualized"
                )
            generated = (
                f"{prefix}.{context}.{suffix}"
                for context in context_tokens
            )
        else:
            generated = iter((carrier.identifier,))
        for endpoint in generated:
            _add_unique(endpoints, endpoint, "$.carrierMappings")
    return frozenset(endpoints)


def _validate_pattern_endpoints(
    patterns: Dict[str, Dict[str, Any]],
    endpoints: frozenset,
) -> None:
    collective = patterns.get("collective-strategy-realization")
    if collective is None:
        return
    _reference(
        collective["contributors"]["endpoint"],
        endpoints,
        "$.patternMappings.collective.contributors.endpoint",
    )
    _reference(
        collective["target"]["endpoint"],
        endpoints,
        "$.patternMappings.collective.target.endpoint",
    )


def _validate_relationship(entry: Dict[str, Any], path: str) -> None:
    relationship = _enum(
        entry["archimateRelationship"],
        ARCHIMATE_RELATIONSHIPS,
        f"{path}.archimateRelationship",
    )
    directed = _boolean(
        entry["associationDirected"],
        f"{path}.associationDirected",
    )
    if relationship != "AssociationRelationship" and directed:
        raise ProfileContractError(
            f"{path}.associationDirected is only valid for an Association"
        )


def _freeze_records(value: Any) -> Tuple[FrozenObject, ...]:
    return tuple(_freeze(item) for item in value)


def _freeze(value: Any) -> Any:
    if isinstance(value, dict):
        return FrozenObject(
            tuple((key, _freeze(value[key])) for key in sorted(value))
        )
    if isinstance(value, list):
        return tuple(_freeze(item) for item in value)
    if isinstance(value, (str, bool)):
        return value
    raise ProfileContractError("contract contains an unsupported JSON value")


def _unique_object(pairs: List[Tuple[str, Any]]) -> Dict[str, Any]:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ProfileContractError(f"duplicate object key: {key}")
        result[key] = value
    return result


def _reject_constant(value: str) -> None:
    raise ProfileContractError(f"invalid JSON constant: {value}")


def _record(
    value: Any,
    fields: Tuple[str, ...],
    path: str,
) -> Dict[str, Any]:
    result = _object(value, path)
    _exact_fields(result, fields, path)
    return result


def _exact_fields(
    value: Dict[str, Any],
    fields: Tuple[str, ...],
    path: str,
) -> None:
    actual = set(value)
    expected = set(fields)
    if actual != expected:
        missing = sorted(expected - actual)
        unknown = sorted(actual - expected)
        details = []
        if missing:
            details.append(f"missing {', '.join(missing)}")
        if unknown:
            details.append(f"unknown {', '.join(unknown)}")
        raise ProfileContractError(
            f"{path} must have exact fields ({'; '.join(details)})"
        )


def _object(value: Any, path: str) -> Dict[str, Any]:
    if not isinstance(value, dict):
        raise ProfileContractError(f"{path} must be an object")
    return value


def _array(value: Any, path: str) -> List[Any]:
    if not isinstance(value, list):
        raise ProfileContractError(f"{path} must be an array")
    return value


def _text(value: Any, path: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ProfileContractError(f"{path} must be a nonempty string")
    return value


def _texts(value: Any, path: str) -> Tuple[str, ...]:
    result = tuple(
        _text(item, f"{path}[{index}]")
        for index, item in enumerate(_array(value, path))
    )
    if not result:
        raise ProfileContractError(f"{path} must be nonempty")
    if len(result) != len(set(result)):
        raise ProfileContractError(f"{path} must contain unique values")
    return result


def _exact_text(value: Any, expected: str, path: str) -> str:
    result = _text(value, path)
    if result != expected:
        raise ProfileContractError(f"{path} has unsupported value: {result}")
    return result


def _identifier(value: Any, path: str) -> str:
    result = _text(value, path)
    if not IDENTIFIER.fullmatch(result):
        raise ProfileContractError(f"{path} must be a stable identifier")
    return result


def _property_key(value: Any, path: str) -> str:
    result = _text(value, path)
    if not PROPERTY_KEY.fullmatch(result):
        raise ProfileContractError(f"{path} must be an O2I property key")
    return result


def _enum(value: Any, allowed: Iterable[str], path: str) -> str:
    result = _text(value, path)
    if result not in allowed:
        raise ProfileContractError(f"{path} has an unknown notation value")
    return result


def _boolean(value: Any, path: str) -> bool:
    if not isinstance(value, bool):
        raise ProfileContractError(f"{path} must be a boolean")
    return value


def _reference(value: Any, registry: Iterable[Any], path: str) -> None:
    if value not in registry:
        raise ProfileContractError(f"{path} is not internally declared")


def _add_unique(registry: set, value: Any, path: str) -> None:
    if value in registry:
        raise ProfileContractError(f"{path} duplicates {value}")
    registry.add(value)


def _type_token(value: str) -> str:
    token = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "-", value).lower()
    if not IDENTIFIER.fullmatch(token):
        raise ProfileContractError(
            f"O2I type cannot form a stable endpoint token: {value}"
        )
    return token
