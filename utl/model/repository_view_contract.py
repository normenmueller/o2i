"""Project current Profile/Core authority for repository View verification."""

from __future__ import annotations

from dataclasses import dataclass
import importlib.util
from pathlib import Path
import re
import sys
from types import ModuleType
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[2]
PROFILE_PATH = ROOT / "spc/ctr/archimate/profile.json"
CORE_PATH = ROOT / "spc/lib/core/semantics.json"
PROFILE_COMPILER_PATH = ROOT / "spc/ctr/archimate/contract/compile.py"


class ProfileContractError(ValueError):
    """The current Profile/Core authority cannot be projected safely."""


@dataclass(frozen=True)
class FrozenObject:
    """Deterministically ordered immutable JSON object."""

    fields: tuple[tuple[str, Any], ...]

    def __getitem__(self, key: str) -> Any:
        for name, value in self.fields:
            if name == key:
                return value
        raise KeyError(key)


@dataclass(frozen=True)
class RepositoryViewContract:
    """Current authoritative facts consumed by repository View checks."""

    schema: str
    profile_version: str
    carrier_mappings: tuple[FrozenObject, ...]
    relation_mappings: tuple[FrozenObject, ...]
    pattern_mappings: tuple[FrozenObject, ...]
    typed_claim_metadata: FrozenObject
    qualification_proposal: FrozenObject


def load_repository_view_contract(
    profile_path: Path | str = PROFILE_PATH,
    core_path: Path | str = CORE_PATH,
) -> RepositoryViewContract:
    """Validate exact companions and project only repository-View facts."""
    try:
        compiler = _load_profile_compiler()
        profile, payload = compiler.load_object(
            Path(profile_path),
            "Profile companion",
        )
        core = compiler.validate_companion(
            profile,
            payload,
            Path(core_path),
        )
        return _project_validated_repository_view_contract(profile, core)
    except ProfileContractError:
        raise
    except Exception as error:
        raise ProfileContractError(
            f"cannot load current Profile/Core authority: {error}"
        ) from error


def _project_validated_repository_view_contract(
    profile: dict[str, Any],
    core: dict[str, Any],
) -> RepositoryViewContract:
    """Project repository-View facts from companions validated together."""
    carriers = tuple(
        _freeze(
            {
                "id": row["id"],
                "o2iKind": row["carrierCategory"],
                "o2iTypes": row["o2iTypes"],
                "archimateElement": row["archimateElement"],
            }
        )
        for row in profile["carrierMappings"]
    )
    relations = _project_relations(profile, core)
    typed_claim_metadata = _project_typed_claim_metadata(profile)
    patterns = _project_patterns(
        profile,
        core,
        typed_claim_metadata,
    )
    qualification_proposal = _project_qualification_proposal(
        profile,
        core,
        typed_claim_metadata,
    )
    identity = profile["profileIdentity"]
    return RepositoryViewContract(
        schema=profile["schema"],
        profile_version=identity["version"],
        carrier_mappings=carriers,
        relation_mappings=relations,
        pattern_mappings=patterns,
        typed_claim_metadata=typed_claim_metadata,
        qualification_proposal=qualification_proposal,
    )


def _project_typed_claim_metadata(
    profile: dict[str, Any],
) -> FrozenObject:
    metadata = profile["metadata"]
    typed = metadata["typedCarrier"]
    claim = metadata["claimCarrier"]
    return _metadata_contract(
        (
            _property_requirement(
                "type",
                typed["typeKey"],
                typed["cardinality"],
            ),
            _property_requirement(
                "commitment",
                claim["commitmentKey"],
                claim["cardinality"],
                claim["commitmentValues"],
            ),
        )
    )


def _project_relations(
    profile: dict[str, Any],
    core: dict[str, Any],
) -> tuple[FrozenObject, ...]:
    syntax_by_id = _rows_by_id(profile["relationMappings"], "relation mapping")
    semantic_by_id = _rows_by_id(core["relationSemantics"], "Core relation")
    projected = []
    for decision in profile["applicabilityProvenance"]["decisions"]:
        subject = decision["subject"]
        if (
            subject["kind"] != "core-relation-mapping-pair"
            or decision["outcome"] != "applicable"
        ):
            continue
        syntax = _required_row(
            syntax_by_id,
            subject["relationMappingId"],
            "relation mapping",
        )
        semantic = _required_row(
            semantic_by_id,
            subject["coreRelationSemanticsId"],
            "Core relation",
        )
        projected.append(
            _freeze(
                {
                    "id": f"{semantic['id']}@{syntax['id']}",
                    "relationName": semantic["id"],
                    "source": semantic["source"],
                    "target": semantic["target"],
                    "label": syntax["label"],
                    "archimateRelationship": syntax[
                        "archimateRelationship"
                    ],
                    "associationDirected": syntax[
                        "associationDirected"
                    ],
                }
            )
        )
    if not projected:
        raise ProfileContractError(
            "Profile applicability has no applicable Core relation mapping"
        )
    return tuple(projected)


def _project_patterns(
    profile: dict[str, Any],
    core: dict[str, Any],
    typed_claim_metadata: FrozenObject,
) -> tuple[FrozenObject, ...]:
    patterns = _rows_by_id(profile["patternMappings"], "pattern mapping")
    contextualization = _required_row(
        patterns,
        "contextualization",
        "pattern mapping",
    )
    contextualization_semantics = core["contextualizationSemantics"]

    collective = _required_row(
        patterns,
        "collective-strategy-realization",
        "pattern mapping",
    )
    families = _rows_by_id(
        core["structuredPropositionFamilies"],
        "structured proposition family",
    )
    family = _required_row(
        families,
        collective["propositionFamily"],
        "structured proposition family",
    )
    completeness = _required_row(
        _rows_by_id(profile["propertyMappings"], "property mapping"),
        collective["carrier"][
            "participantCompletenessPropertyMapping"
        ],
        "property mapping",
    )
    collective_metadata = _metadata_contract(
        (
            _property_requirement(
                "type",
                profile["metadata"]["typedCarrier"]["typeKey"],
                profile["metadata"]["typedCarrier"]["cardinality"],
                (collective["carrier"]["o2iType"]["expected"],),
            ),
            _property_requirement(
                "commitment",
                collective["carrier"]["commitmentKey"]["expected"],
                "exactly-one",
                collective["carrier"]["commitmentValues"]["expected"],
            ),
            _property_requirement(
                "participant-completeness",
                completeness["key"],
                completeness["multiplicity"]["propertyOccurrences"][
                    "expected"
                ],
                completeness["value"]["admittedValues"]["expected"],
            ),
        ),
        collective["carrier"]["additionalO2IProperties"]["expected"],
    )
    contextualization_metadata = _metadata_contract(
        (
            _property_requirement(
                "commitment",
                profile["metadata"]["claimCarrier"]["commitmentKey"],
                contextualization["metadata"]["commitmentCardinality"][
                    "expected"
                ],
                contextualization["metadata"]["commitmentValue"][
                    "expected"
                ],
            ),
        ),
        additional_policy=contextualization["metadata"][
            "additionalProperties"
        ]["expected"],
    )

    return (
        _freeze(
            {
                "id": contextualization["id"],
                "archimateRelationship": contextualization[
                    "relationship"
                ]["archimateRelationship"]["expected"],
                "label": contextualization["relationship"]["label"][
                    "expected"
                ],
                "associationDirected": contextualization[
                    "relationship"
                ]["associationDirected"]["expected"],
                "sourceKind": contextualization_semantics[
                    "sourceCategory"
                ],
                "targetKinds": contextualization_semantics[
                    "targetCategories"
                ],
                "targetIncomingCardinality": contextualization_semantics[
                    "targetOwnerCardinality"
                ],
                "carrierMetadata": typed_claim_metadata,
                "relationshipMetadata": contextualization_metadata,
            }
        ),
        _freeze(
            {
                "id": collective["id"],
                "carrier": {
                    "o2iType": collective["carrier"]["o2iType"][
                        "expected"
                    ],
                    "archimateElement": collective["carrier"][
                        "archimateElement"
                    ]["expected"],
                    "junctionType": collective["carrier"]["junctionType"][
                        "expected"
                    ],
                },
                "segments": {
                    "archimateRelationship": collective["segments"][
                        "archimateRelationship"
                    ]["expected"],
                    "label": collective["segments"]["label"]["expected"],
                    "associationDirected": collective["segments"][
                        "associationDirected"
                    ]["expected"],
                },
                "contributors": {
                    "endpoint": family["participant"]["target"],
                    "cardinality": family["participant"]["cardinality"],
                    "distinct": _requirement(
                        family["participant"]["uniqueness"] == "distinct"
                    ),
                },
                "target": {
                    "endpoint": family["target"]["target"],
                    "cardinality": family["target"]["cardinality"],
                    "distinctFromContributors": _requirement(
                        family["target"]["distinctFromParticipants"]
                    ),
                },
                "endpointMetadata": typed_claim_metadata,
                "carrierMetadata": collective_metadata,
                "segmentMetadata": _metadata_contract(
                    (),
                    additional_policy=collective["segments"][
                        "o2iMetadata"
                    ]["expected"],
                ),
            }
        ),
    )


def _project_qualification_proposal(
    profile: dict[str, Any],
    core: dict[str, Any],
    typed_claim_metadata: FrozenObject,
) -> FrozenObject:
    proposal = profile["qualificationProposalMapping"]
    semantics = core["qualificationProposalSemantics"]
    source = _required_row(
        _rows_by_id(profile["propertyMappings"], "property mapping"),
        proposal["carrier"]["sourceProjection"]["propertyMapping"],
        "property mapping",
    )
    endpoints = _rows_by_id(
        core["qualifiedEndpointCatalog"],
        "qualified endpoint",
    )
    roles = []
    for role in semantics["routingContract"]["roleOrder"]:
        mapping = proposal["references"]["roles"].get(role)
        if mapping is None:
            raise ProfileContractError(
                f"missing qualification proposal role mapping: {role}"
            )
        semantic_role = semantics["roles"].get(role)
        if semantic_role is None:
            raise ProfileContractError(
                f"missing qualification proposal Core role: {role}"
            )
        endpoint = _required_row(
            endpoints,
            semantic_role["target"],
            "qualified endpoint",
        )
        roles.append(
            {
                "role": role,
                "endpoint": semantic_role["target"],
                "cardinality": semantic_role["cardinality"],
                "o2iKind": endpoint["carrierCategory"],
                "o2iType": endpoint["o2iType"],
                "contextType": endpoint.get("contextType"),
            }
        )

    type_key = profile["metadata"]["typedCarrier"]["typeKey"]
    commitment_key = profile["metadata"]["claimCarrier"]["commitmentKey"]
    role_key = proposal["references"]["roleProperty"]["expected"]
    carrier_metadata = _metadata_contract(
        (
            _property_requirement(
                "type",
                type_key,
                profile["metadata"]["typedCarrier"]["cardinality"],
                (proposal["carrier"]["o2iType"]["expected"],),
            ),
            _property_requirement(
                "source",
                source["key"],
                _qualification_source_cardinality(semantics["sources"]),
                value_kind=source["value"]["kind"]["expected"],
                grammar=source["value"]["grammar"]["expected"],
                profile_cardinality=source["multiplicity"][
                    "propertyOccurrences"
                ]["expected"],
                value_cardinality=source["multiplicity"][
                    "valuesPerPropertyOccurrence"
                ]["expected"],
            ),
            _property_requirement(
                "commitment",
                commitment_key,
                proposal["carrier"]["commitment"]["expected"],
            ),
        )
    )
    reference_metadata = _metadata_contract(
        (
            _property_requirement(
                "role",
                role_key,
                "exactly-one",
                tuple(role["role"] for role in roles),
            ),
            _property_requirement(
                "commitment",
                commitment_key,
                proposal["references"]["commitment"]["expected"],
            ),
        )
    )
    return _freeze(
        {
            "id": proposal["id"],
            "carrier": {
                "archimateElement": proposal["carrier"][
                    "archimateElement"
                ]["expected"],
                "o2iType": proposal["carrier"]["o2iType"]["expected"],
                "rationale": semantics["rationale"],
                "metadata": carrier_metadata,
            },
            "references": {
                "archimateRelationship": proposal["references"][
                    "archimateRelationship"
                ]["expected"],
                "associationDirected": proposal["references"][
                    "associationDirected"
                ]["expected"],
                "direction": proposal["references"]["direction"][
                    "expected"
                ],
                "metadata": reference_metadata,
                "roles": roles,
            },
            "endpointMetadata": typed_claim_metadata,
        }
    )


def _qualification_source_cardinality(value: str) -> str:
    if value != "one-or-more-normalized-source-identities":
        raise ProfileContractError(
            f"unsupported qualification source cardinality: {value}"
        )
    return "one-or-more"


def _metadata_contract(
    properties: Iterable[dict[str, Any]],
    declared_allowed: Iterable[str] | None = None,
    *,
    additional_policy: str = "forbidden",
) -> FrozenObject:
    rows = tuple(properties)
    allowed = tuple(
        row["key"]
        for row in rows
        if row["cardinality"] != "forbidden"
    )
    if declared_allowed is not None and set(declared_allowed) != set(allowed):
        raise ProfileContractError(
            "metadata property projection does not match declared allowed keys"
        )
    return _freeze(
        {
            "additionalO2IProperties": additional_policy,
            "allowedO2IProperties": allowed,
            "properties": rows,
        }
    )


def _property_requirement(
    role: str,
    key: str,
    cardinality: str,
    admitted_values: Iterable[str] = (),
    *,
    value_kind: str | None = None,
    grammar: str | None = None,
    profile_cardinality: str | None = None,
    value_cardinality: str | None = None,
) -> dict[str, Any]:
    return {
        "role": role,
        "key": key,
        "cardinality": cardinality,
        "admittedValues": tuple(admitted_values),
        "valueKind": value_kind,
        "grammar": grammar,
        "profileCardinality": profile_cardinality,
        "valueCardinality": value_cardinality,
    }


def carrier_archimate_element(
    contract: RepositoryViewContract,
    kind: str,
    o2i_type: str,
) -> str:
    """Resolve one O2I constructor to its unique current Profile carrier."""
    matches = [
        mapping["archimateElement"]
        for mapping in contract.carrier_mappings
        if mapping["o2iKind"] == kind
        and (
            kind == "Context"
            or any(
                _kebab(candidate) == _kebab(o2i_type)
                for candidate in mapping["o2iTypes"]
            )
        )
    ]
    if len(matches) != 1:
        raise ProfileContractError(
            "Profile constructor has no unique carrier mapping: "
            f"{kind}.{o2i_type}"
        )
    return matches[0]


def endpoint_archimate_element(
    contract: RepositoryViewContract,
    endpoint: str,
) -> str:
    """Resolve one bound Core endpoint to its current Profile carrier."""
    endpoint_kind = endpoint.split(".", 1)[0]
    kind = {
        "context": "Context",
        "primitive": "Primitive",
        "structuring": "Structuring",
        "situation-anchor": "SituationAnchor",
    }.get(endpoint_kind)
    if kind is None:
        raise ProfileContractError(
            f"Profile relation has unsupported endpoint: {endpoint!r}"
        )
    return carrier_archimate_element(
        contract,
        kind,
        endpoint.rsplit(".", 1)[-1],
    )


def _kebab(identifier: str) -> str:
    return re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "-", identifier).lower()


def _rows_by_id(
    rows: Iterable[dict[str, Any]],
    subject: str,
) -> dict[str, dict[str, Any]]:
    result = {}
    for row in rows:
        identifier = row["id"]
        if identifier in result:
            raise ProfileContractError(
                f"duplicate {subject} identity: {identifier}"
            )
        result[identifier] = row
    return result


def _required_row(
    rows: dict[str, dict[str, Any]],
    identifier: str,
    subject: str,
) -> dict[str, Any]:
    try:
        return rows[identifier]
    except KeyError as error:
        raise ProfileContractError(
            f"missing {subject} identity: {identifier}"
        ) from error


def _requirement(value: bool) -> str:
    return "required" if value else "forbidden"


def _freeze(value: Any) -> Any:
    if isinstance(value, dict):
        return FrozenObject(
            tuple(
                (key, _freeze(item))
                for key, item in sorted(value.items())
            )
        )
    if isinstance(value, (list, tuple)):
        return tuple(_freeze(item) for item in value)
    return value


def _load_profile_compiler() -> ModuleType:
    name = "o2i_current_archimate_profile_compiler"
    loaded = sys.modules.get(name)
    if loaded is not None:
        return loaded
    spec = importlib.util.spec_from_file_location(name, PROFILE_COMPILER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(
            f"cannot load Profile compiler: {PROFILE_COMPILER_PATH}"
        )
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    try:
        spec.loader.exec_module(module)
    except BaseException:
        sys.modules.pop(name, None)
        raise
    return module
