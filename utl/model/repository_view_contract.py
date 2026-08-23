"""Project current Profile/Core authority for repository View verification."""

from __future__ import annotations

from dataclasses import dataclass
import importlib.util
from pathlib import Path
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


def load_repository_view_contract(
    profile_path: Path | str = PROFILE_PATH,
    core_path: Path | str = CORE_PATH,
) -> RepositoryViewContract:
    """Validate exact companions and project only repository-View facts."""
    compiler = _load_profile_compiler()
    try:
        profile, payload = compiler.load_object(
            Path(profile_path),
            "Profile companion",
        )
        core = compiler.validate_companion(
            profile,
            payload,
            Path(core_path),
        )
        return _project_contract(profile, core)
    except (KeyError, OSError, UnicodeError, ValueError) as error:
        raise ProfileContractError(str(error)) from error


def _project_contract(
    profile: dict[str, Any],
    core: dict[str, Any],
) -> RepositoryViewContract:
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
    patterns = _project_patterns(profile, core)
    identity = profile["profileIdentity"]
    return RepositoryViewContract(
        schema=profile["schema"],
        profile_version=identity["version"],
        carrier_mappings=carriers,
        relation_mappings=relations,
        pattern_mappings=patterns,
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
        syntax = syntax_by_id[subject["relationMappingId"]]
        semantic = semantic_by_id[subject["coreRelationSemanticsId"]]
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
) -> tuple[FrozenObject, ...]:
    patterns = _rows_by_id(profile["patternMappings"], "pattern mapping")
    contextualization = patterns["contextualization"]
    contextualization_semantics = core["contextualizationSemantics"]

    collective = patterns["collective-strategy-realization"]
    families = _rows_by_id(
        core["structuredPropositionFamilies"],
        "structured proposition family",
    )
    family = families[collective["propositionFamily"]]

    return (
        _freeze(
            {
                "id": "contextualization",
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
            }
        ),
        _freeze(
            {
                "id": "collective-strategy-realization",
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
            }
        ),
    )


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
    if isinstance(value, list):
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
