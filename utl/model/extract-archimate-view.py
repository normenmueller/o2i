#!/usr/bin/env python3
"""Extract reviewable Markdown snapshots from O2I ArchiMate views."""

from __future__ import annotations

import argparse
from collections import Counter
import difflib
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from archimate_profile import (
    ArchimateProfileContract,
    FrozenObject,
    ProfileContractError,
    load_profile_contract,
)


XSI_TYPE = "{http://www.w3.org/2001/XMLSchema-instance}type"
REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MODEL = REPOSITORY_ROOT / "mdl" / "o2i.archimate"
PROFILE_CONTRACT = (
    REPOSITORY_ROOT / "spc" / "ctr" / "archimate" / "profile.json"
)
SYNTAX_VIEW = "O2I Syntax"
MAPS_TO = "maps-to"
GENERIC_RELATION_NAME = "<O2I relation name>"
CONTEXT_RELATION_FAMILY = "Context"
CONTENT_RELATION_FAMILY = "Primitive/Structuring"
ANCHOR_RELATION_FAMILY = "Situation Anchor"
ENDPOINT_KIND_TO_O2I_KIND = {
    "context": "Context",
    "primitive": "Primitive",
    "structuring": "Structuring",
    "situation-anchor": "SituationAnchor",
}
CONTENT_ENDPOINT_KINDS = frozenset({"primitive", "structuring"})

PRESETS = {
    "strategy-constituents": (
        "O2I Strategy Constituents",
        Path("mdl/o2i-strategy-constituents.md"),
    ),
    "semantics-situation": (
        "O2I Semantics - Situation",
        Path("mdl/o2i-semantics-situation.md"),
    ),
    "situation-anchoring": (
        "O2I Situation Anchoring",
        Path("mdl/o2i-situation-anchoring.md"),
    ),
    "orientation": ("O2I Orientierung", Path("mdl/o2i-orientation.md")),
    "semantics-context": (
        "O2I Semantics - Context",
        Path("mdl/o2i-semantics-context.md"),
    ),
    "semantics-primitives": (
        "O2I Semantics - Primitives",
        Path("mdl/o2i-semantics-primitives.md"),
    ),
    "syntax": (
        SYNTAX_VIEW,
        Path("mdl/o2i-syntax.md"),
    ),
    "syntax-contextualization": (
        "O2I Syntax - Contextualization",
        Path("mdl/o2i-syntax-contextualization.md"),
    ),
    "syntax-collective-strategy-realization": (
        "O2I Syntax - Collective Strategy Realization",
        Path("mdl/o2i-syntax-collective-strategy-realization.md"),
    ),
    "layered-cake": ("O2I Layered Cake", Path("mdl/o2i-layered-cake.md")),
}

REQUIRED_CONTEXTUALIZATION_DOCUMENTATION = (
    "Visualizes the executable ArchiMate conformance pattern for "
    "contextualizing O2I Primitives and PerformanceDimensions.",
    "composition[contextualizes]",
    "visual nesting has no contextualization semantics",
    "spc/ctr/archimate/profile.json",
    "Candidate syntax exemplars, not fachliche model instances",
)

REQUIRED_COLLECTIVE_REALIZATION_DOCUMENTATION = (
    "Visualizes the executable ArchiMate conformance pattern for one O2I "
    "CollectiveStrategyRealization.",
    "realizes segments and one AND Junction",
    "StructuredProposition carrier",
    "spc/ctr/archimate/profile.json",
    "syntax exemplars, not fachliche model instances",
)

REQUIRED_COLLECTIVE_REALIZATION_ELEMENT_DOCUMENTATION = (
    "Candidate ArchiMate AND Junction carrier",
    "CollectiveStrategyRealization StructuredProposition",
    "roles follow from realizes topology",
    "spc/ctr/archimate/profile.json",
    "syntax exemplar is not a fachliche model instance",
)

REQUIRED_VIEW_DOCUMENTATION = {
    (
        "O2I Syntax - Contextualization"
    ): REQUIRED_CONTEXTUALIZATION_DOCUMENTATION,
    (
        "O2I Syntax - Collective Strategy Realization"
    ): REQUIRED_COLLECTIVE_REALIZATION_DOCUMENTATION,
}

REQUIRED_ELEMENT_DOCUMENTATION = {
    (
        "O2I Syntax - Collective Strategy Realization",
        "<Name> :: O2I Collective Strategy Realization",
        "Junction",
    ): REQUIRED_COLLECTIVE_REALIZATION_ELEMENT_DOCUMENTATION,
}


def contract_edge(
    source: str,
    relation: str,
    target: str,
    *,
    source_type: str = "Grouping",
    relation_type: str = "InfluenceRelationship",
    directed: bool = False,
    target_type: str = "Grouping",
) -> tuple[str, str, str, str, bool, str, str]:
    """Declare one exact relation in a normative ArchiMate view."""
    return (
        source,
        source_type,
        relation,
        relation_type,
        directed,
        target,
        target_type,
    )


RELATION_CONTRACTS = {
    "O2I Semantics - Context": frozenset(
        {
            contract_edge("Ethos", "guides", "Mission"),
            contract_edge("Ethos", "guides", "Vision"),
            contract_edge("Intervention", "addresses", "Need"),
            contract_edge("Intervention", "changes", "Situation"),
            contract_edge("Intervention", "sets-target-for", "Measure"),
            contract_edge("Measure", "measures", "Situation"),
            contract_edge("Mission", "grounds", "Vision"),
            contract_edge("Situation", "surfaces", "Need"),
            contract_edge("Strategy", "contributes-to", "Strategy"),
            contract_edge("Strategy", "directs", "Intervention"),
            contract_edge("Strategy", "directs", "Strategy"),
            contract_edge("Strategy", "frames", "Measure"),
            contract_edge("Strategy", "qualifies", "Need"),
            contract_edge("Vision", "orients", "Strategy"),
        }
    ),
    "O2I Semantics - Primitives": frozenset(
        {
            contract_edge("Action", "contributes-to", "Action"),
            contract_edge("Action", "contributes-to", "Key Result"),
            contract_edge("Action", "guides", "Action"),
            contract_edge("Driver", "grounds", "Objective"),
            contract_edge("Driver", "indicates", "Performance Dimension"),
            contract_edge("Key Result", "contributes-to", "Key Result"),
            contract_edge("Key Result", "determines", "Performance Dimension"),
            contract_edge("Key Result", "sets-target-for", "KPI"),
            contract_edge("Key Result", "substantiates", "Objective"),
            contract_edge("Key Result", "translates-into", "Objective"),
            contract_edge("Objective", "orients", "Objective"),
            contract_edge(
                "Performance Dimension",
                "contains",
                "KPI",
                relation_type="AggregationRelationship",
            ),
            contract_edge(
                "Performance Dimension",
                "contains",
                "Key Result",
                relation_type="AggregationRelationship",
            ),
            contract_edge("Principle", "guides", "Action"),
            contract_edge("Principle", "guides", "Driver"),
            contract_edge("Principle", "guides", "Objective"),
            contract_edge("Principle", "guides", "Principle"),
        }
    ),
    "O2I Semantics - Situation": frozenset(
        {
            contract_edge(
                anchor,
                "kind-of",
                "Situation Anchor",
                relation_type="SpecializationRelationship",
            )
            for anchor in (
                "Business Capability",
                "Business Object",
                "Business Process",
                "Value Stream",
            )
        }
        | {
            contract_edge(
                "Situation",
                "is-constituted-by",
                "Situation Anchor",
                relation_type="AggregationRelationship",
            )
        }
    ),
    "O2I Situation Anchoring": frozenset(
        {
            contract_edge(
                "Action",
                "changes",
                "Situation Anchor",
                relation_type="AssociationRelationship",
                directed=True,
            ),
            contract_edge(
                "KPI",
                "measures",
                "Situation Anchor",
                relation_type="AssociationRelationship",
                directed=True,
            ),
            contract_edge(
                "Situation",
                "is-constituted-by",
                "Situation Anchor",
                relation_type="AggregationRelationship",
            ),
            contract_edge(
                "Situation Anchor",
                "anchors",
                "Driver",
                relation_type="AssociationRelationship",
                directed=True,
            ),
        }
    ),
    "O2I Strategy Constituents": frozenset(
        {
            contract_edge(
                "Strategy#Anchoring",
                "enables",
                "Strategy#Coherent Action Commitments",
            ),
            contract_edge(
                "Strategy#Coherent Action Commitments",
                "contributes-to",
                "Strategy#Success Reference",
            ),
            contract_edge(
                "Strategy#Derived Guardrails",
                "constrain",
                "Strategy#Guiding Policy",
            ),
            contract_edge(
                "Strategy#Diagnosis", "justifies", "Strategy#Guiding Policy"
            ),
            contract_edge("Strategy#Diagnosis", "justifies", "Strategy#Intent"),
            contract_edge(
                "Strategy#Fit",
                "validates",
                "Strategy#Coherent Action Commitments",
            ),
            contract_edge(
                "Strategy#Fit", "validates", "Strategy#Positioning"
            ),
            contract_edge(
                "Strategy#Fit", "validates", "Strategy#Success Reference"
            ),
            contract_edge("Strategy#Fit", "validates", "Strategy#Trade-offs"),
            contract_edge(
                "Strategy#Guiding Policy",
                "guides",
                "Strategy#Coherent Action Commitments",
            ),
            contract_edge(
                "Strategy#Guiding Policy", "guides", "Strategy#Positioning"
            ),
            contract_edge(
                "Strategy#Intent", "orients", "Strategy#Guiding Policy"
            ),
            contract_edge(
                "Strategy#Positioning",
                "orients",
                "Strategy#Coherent Action Commitments",
            ),
            contract_edge(
                "Strategy#Positioning", "requires", "Strategy#Trade-offs"
            ),
            contract_edge("Strategy#Scope", "frames", "Strategy#Diagnosis"),
            contract_edge(
                "Strategy#Success Reference", "substantiates", "Strategy#Intent"
            ),
            contract_edge(
                "Strategy#Trade-offs",
                "constrain",
                "Strategy#Coherent Action Commitments",
            ),
        }
    ),
}


def profile_pattern(
    contract: ArchimateProfileContract,
    identifier: str,
) -> FrozenObject:
    """Resolve one unique structured pattern from the profile authority."""
    matches = [
        pattern
        for pattern in contract.pattern_mappings
        if pattern["id"] == identifier
    ]
    if len(matches) != 1:
        raise ProfileContractError(
            f"profile contract requires exactly one {identifier!r} pattern"
        )
    return matches[0]


def words(identifier: str) -> str:
    """Render one closed contract identifier as a repository View label."""
    value = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", identifier)
    return value.replace("Course Of Action", "Course of Action")


def kebab(identifier: str) -> str:
    """Normalize one CamelCase contract type for endpoint comparison."""
    return re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "-", identifier).lower()


def carrier_mapping_edges(
    contract: ArchimateProfileContract,
) -> frozenset[tuple[str, str, str, str, bool, str, str]]:
    """Project carrier facts into the repository's mapping-only notation."""
    edges = set()
    for mapping in contract.carrier_mappings:
        source_types = (
            ("Context",)
            if mapping["id"] == "context"
            else tuple(words(value) for value in mapping["o2iTypes"])
        )
        archimate_element = mapping["archimateElement"]
        for source in source_types:
            edges.add(
                contract_edge(
                    source,
                    MAPS_TO,
                    f"ArchiMate {words(archimate_element)}",
                    relation_type="AssociationRelationship",
                    directed=True,
                    target_type=archimate_element,
                )
            )
    return frozenset(edges)


def endpoint_archimate_element(
    contract: ArchimateProfileContract,
    endpoint: str,
) -> str:
    """Resolve one notation-independent endpoint to its carrier mapping."""
    endpoint_kind = endpoint.split(".", 1)[0]
    kind = ENDPOINT_KIND_TO_O2I_KIND.get(endpoint_kind)
    if kind is None:
        raise ProfileContractError(
            f"profile relation has unsupported endpoint: {endpoint!r}"
        )

    endpoint_type = endpoint.rsplit(".", 1)[-1]
    return carrier_archimate_element(contract, kind, endpoint_type)


def carrier_archimate_element(
    contract: ArchimateProfileContract,
    kind: str,
    o2i_type: str,
) -> str:
    """Resolve one O2I constructor to its unique ArchiMate carrier."""
    matches = [
        mapping["archimateElement"]
        for mapping in contract.carrier_mappings
        if mapping["o2iKind"] == kind
        and (
            kind == "Context"
            or any(
                kebab(candidate) == kebab(o2i_type)
                for candidate in mapping["o2iTypes"]
            )
        )
    ]
    if len(matches) != 1:
        raise ProfileContractError(
            "profile constructor has no unique carrier mapping: "
            f"{kind}.{o2i_type}"
        )
    return matches[0]


def relation_mapping_edges(
    contract: ArchimateProfileContract,
) -> frozenset[tuple[str, str, str, str, bool, str, str]]:
    """Project exact relation representations as generic View exemplars."""
    return frozenset(
        contract_edge(
            f"ArchiMate {words(source)}",
            GENERIC_RELATION_NAME,
            f"ArchiMate {words(target)}",
            source_type=source,
            relation_type=mapping["archimateRelationship"],
            directed=mapping["associationDirected"],
            target_type=target,
        )
        for mapping in contract.relation_mappings
        for source in (
            endpoint_archimate_element(contract, mapping["source"]),
        )
        for target in (
            endpoint_archimate_element(contract, mapping["target"]),
        )
    )


def relation_mapping_families(
    contract: ArchimateProfileContract,
) -> dict[
    tuple[str, str, str, bool],
    frozenset[tuple[str, str, str, str, bool, str, str]],
]:
    """Group exact mappings into deterministic representation families."""
    grouped: dict[
        tuple[str, str, str, bool],
        set[tuple[str, str, str, str, bool, str, str]],
    ] = {}
    for mapping in contract.relation_mappings:
        endpoint_domain = relation_mapping_domain(
            mapping["source"],
            mapping["target"],
        )
        relation_label = (
            mapping["label"]
            if endpoint_domain == ANCHOR_RELATION_FAMILY
            else GENERIC_RELATION_NAME
        )
        source = endpoint_archimate_element(contract, mapping["source"])
        target = endpoint_archimate_element(contract, mapping["target"])
        family = (
            endpoint_domain,
            relation_label,
            mapping["archimateRelationship"],
            mapping["associationDirected"],
        )
        grouped.setdefault(family, set()).add(
            contract_edge(
                f"ArchiMate {words(source)}",
                GENERIC_RELATION_NAME,
                f"ArchiMate {words(target)}",
                source_type=source,
                relation_type=mapping["archimateRelationship"],
                directed=mapping["associationDirected"],
                target_type=target,
            )
        )
    return {
        family: frozenset(edges)
        for family, edges in grouped.items()
    }


def relation_mapping_domain(source: str, target: str) -> str:
    """Classify one declared endpoint pair into the closed View domain."""
    endpoint_kinds = tuple(
        endpoint.split(".", 1)[0] for endpoint in (source, target)
    )
    if any(kind not in ENDPOINT_KIND_TO_O2I_KIND for kind in endpoint_kinds):
        raise ProfileContractError(
            "profile relation has unsupported endpoint-domain combination: "
            f"{source} -> {target}"
        )
    if "situation-anchor" in endpoint_kinds:
        return ANCHOR_RELATION_FAMILY
    if endpoint_kinds == ("context", "context"):
        return CONTEXT_RELATION_FAMILY
    if all(kind in CONTENT_ENDPOINT_KINDS for kind in endpoint_kinds):
        return CONTENT_RELATION_FAMILY
    raise ProfileContractError(
        "profile relation has unsupported endpoint-domain combination: "
        f"{source} -> {target}"
    )


def format_mapping_family(family: tuple[str, str, str, bool]) -> str:
    """Render one relation-representation family obligation."""
    endpoint_domain, relation, relationship, directed = family
    direction = ", directed" if directed else ""
    relation_label = (
        f" --{relation}-->"
        if relation != GENERIC_RELATION_NAME
        else ""
    )
    return (
        f"{endpoint_domain}{relation_label} "
        f"[{relationship}{direction}]"
    )


def syntax_mapping_edges(
    contract: ArchimateProfileContract,
) -> frozenset[tuple[str, str, str, str, bool, str, str]]:
    """Return every exact mapping usable by one family exemplar."""
    return carrier_mapping_edges(contract) | relation_mapping_edges(contract)


def canonical_mapping_edge(
    edge: tuple[str, str, str, str, bool, str, str],
) -> tuple[str, str, str, str, bool, str, str]:
    """Validate and remove roles from one generic relation exemplar."""
    (
        source,
        source_type,
        relation,
        relation_type,
        directed,
        target,
        target_type,
    ) = edge
    if relation == GENERIC_RELATION_NAME:
        source_suffix = " (source)"
        target_suffix = " (target)"
        if source.endswith(target_suffix):
            raise ProfileContractError(
                "generic relation mapping source uses the target role: "
                f"{source!r}"
            )
        if target.endswith(source_suffix):
            raise ProfileContractError(
                "generic relation mapping target uses the source role: "
                f"{target!r}"
            )
        source = source.removesuffix(source_suffix)
        target = target.removesuffix(target_suffix)
    elif any(
        re.search(r" \((?:source|target)\)$", endpoint)
        for endpoint in (source, target)
    ):
        raise ProfileContractError(
            "endpoint roles are reserved for generic relation mappings"
        )

    return (
        source,
        source_type,
        relation,
        relation_type,
        directed,
        target,
        target_type,
    )


def syntax_pattern_contracts(
    contract: ArchimateProfileContract,
) -> dict[str, frozenset[tuple[str, str, str, str, bool, str, str]]]:
    """Project exact binary syntax exemplars into repository Views."""
    contextualization = profile_pattern(contract, "contextualization")
    context_carrier = carrier_archimate_element(
        contract,
        contextualization["sourceKind"],
        "Mission",
    )
    driver_carrier = carrier_archimate_element(
        contract,
        "Primitive",
        "Driver",
    )
    dimension_carrier = carrier_archimate_element(
        contract,
        "Structuring",
        "PerformanceDimension",
    )
    return {
        "O2I Syntax - Contextualization": frozenset(
            {
                contract_edge(
                    "<Name> :: O2I Mission",
                    contextualization["label"],
                    "<Name> :: O2I Driver",
                    source_type=context_carrier,
                    relation_type=contextualization[
                        "archimateRelationship"
                    ],
                    directed=contextualization["associationDirected"],
                    target_type=driver_carrier,
                ),
                contract_edge(
                    "<Name> :: O2I Strategy",
                    contextualization["label"],
                    "<Name> :: O2I Performance Dimension",
                    source_type=context_carrier,
                    relation_type=contextualization[
                        "archimateRelationship"
                    ],
                    directed=contextualization["associationDirected"],
                    target_type=dimension_carrier,
                ),
            }
        ),
    }


def syntax_pattern_nodes(
    contract: ArchimateProfileContract,
) -> dict[str, frozenset[tuple[str, str]]]:
    """Derive the carrier types of repository pattern exemplars."""
    contextualization = profile_pattern(contract, "contextualization")
    collective = profile_pattern(
        contract,
        "collective-strategy-realization",
    )
    context_carrier = carrier_archimate_element(
        contract,
        contextualization["sourceKind"],
        "Mission",
    )
    return {
        "O2I Syntax - Contextualization": frozenset(
            {
                (
                    "<Name> :: O2I Driver",
                    carrier_archimate_element(
                        contract,
                        "Primitive",
                        "Driver",
                    ),
                ),
                ("<Name> :: O2I Mission", context_carrier),
                (
                    "<Name> :: O2I Performance Dimension",
                    carrier_archimate_element(
                        contract,
                        "Structuring",
                        "PerformanceDimension",
                    ),
                ),
                ("<Name> :: O2I Strategy", context_carrier),
            }
        ),
        "O2I Syntax - Collective Strategy Realization": frozenset(
            {
                (
                    "<Contributor Strategy 1> :: O2I Strategy",
                    endpoint_archimate_element(
                        contract,
                        collective["contributors"]["endpoint"],
                    ),
                ),
                (
                    "<Contributor Strategy 2> :: O2I Strategy",
                    endpoint_archimate_element(
                        contract,
                        collective["contributors"]["endpoint"],
                    ),
                ),
                (
                    "<Name> :: O2I Collective Strategy Realization",
                    collective["carrier"]["archimateElement"],
                ),
                (
                    "<Target Strategy> :: O2I Strategy",
                    endpoint_archimate_element(
                        contract,
                        collective["target"]["endpoint"],
                    ),
                ),
            }
        ),
    }


def xtype(element: ET.Element) -> str:
    return element.get(XSI_TYPE, "").split(":")[-1]


def collect_model(root: ET.Element):
    elements: dict[str, tuple[str, str]] = {}
    relations: dict[
        str,
        tuple[str, str, str | None, str | None, bool],
    ] = {}

    for element in root.iter("element"):
        element_id = element.get("id")
        if not element_id:
            continue

        element_type = xtype(element)
        name = element.get("name", "")
        elements[element_id] = (name, element_type)

        if element_type.endswith("Relationship"):
            relation_name = name or element_type.removesuffix("Relationship")
            relations[element_id] = (
                relation_name,
                element_type,
                element.get("source"),
                element.get("target"),
                element.get("directed") == "true",
            )

    return elements, relations


def find_view(root: ET.Element, view_name: str) -> ET.Element:
    for element in root.iter("element"):
        if (
            xtype(element) == "ArchimateDiagramModel"
            and element.get("name") == view_name
        ):
            return element
    raise SystemExit(f"view not found: {view_name}")


def collect_view(view: ET.Element):
    object_targets: dict[str, str] = {}
    object_parents: dict[str, str | None] = {}
    object_labels: dict[str, str] = {}
    notes: list[str] = []

    def walk(node: ET.Element, parent: str | None) -> None:
        node_id = node.get("id")
        if node_id:
            object_parents[node_id] = parent
            target = node.get("archimateElement")
            if target:
                object_targets[node_id] = target
                label = next(
                    (
                        feature.get("value", "")
                        for feature in node.findall("feature")
                        if feature.get("name") == "labelExpression"
                    ),
                    "",
                )
                if label:
                    object_labels[node_id] = " ".join(label.split())
            if xtype(node) == "Note":
                content = (node.findtext("content") or "").strip()
                if content:
                    notes.append(content)

        for child in node:
            if child.tag == "child":
                walk(child, node_id)

    for child in view:
        if child.tag == "child":
            walk(child, None)

    connections: list[tuple[str | None, str | None, str | None]] = []
    for connection in view.iter("sourceConnection"):
        connections.append(
            (
                connection.get("source"),
                connection.get("archimateRelationship"),
                connection.get("target"),
            )
        )

    documentation = (view.findtext("documentation") or "").strip()
    return (
        object_targets,
        object_parents,
        object_labels,
        connections,
        notes,
        documentation,
    )


def visible_element_ids(
    object_targets: dict[str, str],
    elements: dict[str, tuple[str, str]],
) -> frozenset[str]:
    """Return persisted non-annotation elements displayed by one View."""
    return frozenset(
        element_id
        for element_id in object_targets.values()
        if element_id in elements and elements[element_id][1] != "Meaning"
    )


def collective_pattern_errors(
    root: ET.Element,
    contract: ArchimateProfileContract,
    view_name: str,
    object_targets: dict[str, str],
    relation_records: list[
        tuple[str, str, str, str, str, bool, str, str, str]
    ],
    elements: dict[str, tuple[str, str]],
) -> list[str]:
    """Validate one displayed collective realization against its pattern."""
    collective = profile_pattern(
        contract,
        "collective-strategy-realization",
    )
    carrier = collective["carrier"]
    segments = collective["segments"]
    carrier_type = carrier["archimateElement"]
    contributor_type = endpoint_archimate_element(
        contract,
        collective["contributors"]["endpoint"],
    )
    target_type = endpoint_archimate_element(
        contract,
        collective["target"]["endpoint"],
    )
    visible = visible_element_ids(object_targets, elements)
    carrier_ids = {
        element_id
        for element_id in visible
        if elements[element_id][1] == carrier_type
    }
    errors: list[str] = []
    if len(carrier_ids) != 1:
        return [
            f"{view_name} requires exactly one {carrier_type} carrier; "
            f"found {len(carrier_ids)}"
        ]

    carrier_id = next(iter(carrier_ids))
    model_elements = {
        element.get("id"): element
        for element in root.iter("element")
        if element.get("id")
    }
    carrier_element = model_elements[carrier_id]
    expected_junction = carrier["junctionType"]
    actual_junction = carrier_element.get("type")
    if not (
        expected_junction == "and" and actual_junction is None
    ) and actual_junction != expected_junction:
        errors.append(
            f"{view_name} carrier is not the contracted "
            f"{expected_junction.upper()} Junction"
        )

    contributor_ids: list[str] = []
    target_ids: list[str] = []
    participating_ids = {carrier_id}
    expected_relation = (
        segments["label"],
        segments["archimateRelationship"],
        segments["associationDirected"],
    )
    for (
        source_id,
        source_name,
        source_type,
        relation_name,
        relation_type,
        directed,
        target_id,
        target_name,
        target_element_type,
    ) in relation_records:
        actual_relation = (relation_name, relation_type, directed)
        if target_id == carrier_id and source_id != carrier_id:
            participating_ids.add(source_id)
            contributor_ids.append(source_id)
            if source_type != contributor_type:
                errors.append(
                    f"{view_name} contributor {source_name} uses "
                    f"{source_type}; expected {contributor_type}"
                )
            if actual_relation != expected_relation:
                errors.append(
                    f"{view_name} contributor segment is not contracted: "
                    f"{source_name} --{relation_name}--> "
                    f"{elements[carrier_id][0]}"
                )
        elif source_id == carrier_id and target_id != carrier_id:
            participating_ids.add(target_id)
            target_ids.append(target_id)
            if target_element_type != target_type:
                errors.append(
                    f"{view_name} target {target_name} uses "
                    f"{target_element_type}; expected {target_type}"
                )
            if actual_relation != expected_relation:
                errors.append(
                    f"{view_name} target segment is not contracted: "
                    f"{elements[carrier_id][0]} --{relation_name}--> "
                    f"{target_name}"
                )
        else:
            errors.append(
                f"{view_name} relation does not participate in the "
                "collective realization carrier topology: "
                f"{source_name} --{relation_name}--> {target_name}"
            )

    if collective["contributors"]["cardinality"] != "at-least-two":
        raise ProfileContractError(
            "unsupported contributor cardinality in profile contract"
        )
    if len(set(contributor_ids)) < 2:
        errors.append(
            f"{view_name} requires at least two distinct contributors; "
            f"found {len(set(contributor_ids))}"
        )
    if (
        collective["contributors"]["distinct"] == "required"
        and len(contributor_ids) != len(set(contributor_ids))
    ):
        errors.append(f"{view_name} repeats a contributor")

    if collective["target"]["cardinality"] != "exactly-one":
        raise ProfileContractError(
            "unsupported target cardinality in profile contract"
        )
    if len(target_ids) != 1:
        errors.append(
            f"{view_name} requires exactly one target; "
            f"found {len(target_ids)}"
        )
    if (
        collective["target"]["distinctFromContributors"] == "required"
        and set(target_ids) & set(contributor_ids)
    ):
        errors.append(f"{view_name} target also participates as contributor")

    for element_id in sorted(visible - participating_ids):
        name, element_type = elements[element_id]
        errors.append(
            f"{view_name} contains unrelated node {name} ({element_type})"
        )
    return errors


def contextualization_pattern_errors(
    contract: ArchimateProfileContract,
    view_name: str,
    relation_records: list[
        tuple[str, str, str, str, str, bool, str, str, str]
    ],
) -> list[str]:
    """Validate displayed contextualization carriers and target cardinality."""
    contextualization = profile_pattern(contract, "contextualization")
    source_types = {
        mapping["archimateElement"]
        for mapping in contract.carrier_mappings
        if mapping["o2iKind"] == contextualization["sourceKind"]
    }
    target_types = {
        mapping["archimateElement"]
        for mapping in contract.carrier_mappings
        if mapping["o2iKind"] in contextualization["targetKinds"]
    }
    expected_relation = (
        contextualization["label"],
        contextualization["archimateRelationship"],
        contextualization["associationDirected"],
    )
    incoming = Counter(record[6] for record in relation_records)
    errors: list[str] = []

    for (
        _,
        source_name,
        source_type,
        relation_name,
        relation_type,
        directed,
        _,
        target_name,
        target_type,
    ) in relation_records:
        if source_type not in source_types:
            errors.append(
                f"{view_name} source {source_name} uses {source_type}; "
                f"expected one of {sorted(source_types)}"
            )
        if target_type not in target_types:
            errors.append(
                f"{view_name} target {target_name} uses {target_type}; "
                f"expected one of {sorted(target_types)}"
            )
        if (relation_name, relation_type, directed) != expected_relation:
            errors.append(
                f"{view_name} has an uncontracted contextualization: "
                f"{source_name} --{relation_name}--> {target_name}"
            )

    if contextualization["targetIncomingCardinality"] != "exactly-one":
        raise ProfileContractError(
            "unsupported contextualization cardinality in profile contract"
        )
    for target_id, count in sorted(incoming.items()):
        if count != 1:
            errors.append(
                f"{view_name} target {target_id!r} requires exactly one "
                f"incoming contextualization; found {count}"
            )
    return errors


def top_container(
    object_id: str,
    object_targets: dict[str, str],
    object_parents: dict[str, str | None],
    elements: dict[str, tuple[str, str]],
) -> str:
    current = object_id
    container = object_id
    while object_parents.get(current) is not None:
        current = object_parents[current] or current
        if current in object_targets:
            container = current
    element_id = object_targets.get(container)
    if not element_id:
        return ""
    return elements.get(element_id, ("", ""))[0]


def render(
    elements: dict[str, tuple[str, str]],
    relations: dict[
        str,
        tuple[str, str, str | None, str | None, bool],
    ],
    object_targets: dict[str, str],
    object_parents: dict[str, str | None],
    object_labels: dict[str, str],
    connections: list[tuple[str | None, str | None, str | None]],
    notes: list[str],
    documentation: str,
    source_path: Path,
    view_name: str,
    include_meaning: bool,
) -> str:
    visible_occurrences = [
        (
            object_id,
            element_id,
            top_container(object_id, object_targets, object_parents, elements),
        )
        for object_id, element_id in object_targets.items()
        if include_meaning or elements.get(element_id, ("", ""))[1] != "Meaning"
    ]
    visible_objects = {object_id for object_id, _, _ in visible_occurrences}

    lines: list[str] = [
        f"# {view_name}",
        "",
        f"> Generated review snapshot of `{view_name}` from `{source_path}`.",
        (
            "> Review artifact only; exact syntax mapping authority is "
            "`spc/ctr/archimate/profile.json`."
            if view_name.startswith("O2I Syntax")
            else "> Review artifact only; semantic authority remains the "
            "O2I metamodel."
        ),
        "",
    ]

    if documentation:
        lines.extend(["## View Contract", "", documentation, ""])

    if notes:
        lines.extend(["## Notes", ""])
        lines.extend(f"- {note}" for note in sorted(notes))
        lines.append("")

    lines.extend(["## Nodes", ""])

    for object_id, element_id, context in sorted(
        visible_occurrences,
        key=lambda occurrence: (
            occurrence[2],
            object_labels.get(
                occurrence[0],
                elements.get(occurrence[1], ("", ""))[0],
            ),
            elements.get(occurrence[1], ("", ""))[0],
            elements.get(occurrence[1], ("", ""))[1],
            occurrence[0],
        ),
    ):
        name, element_type = elements[element_id]
        display_name = object_labels.get(object_id, name)
        lines.append(f"- [{context}] `{display_name}` ({element_type})")

    lines.extend(["", "## Relations", ""])

    rendered_relations = []
    for source_object, relation_id, target_object in connections:
        if (
            source_object not in visible_objects
            or target_object not in visible_objects
        ):
            continue
        source = object_targets.get(source_object or "")
        target = object_targets.get(target_object or "")
        if relation_id is None or source is None or target is None:
            continue
        relation_name, relation_type, _, _, directed = relations.get(
            relation_id,
            ("?", "?", None, None, False),
        )
        source_name = object_labels.get(
            source_object or "",
            elements.get(source, ("?", ""))[0],
        )
        target_name = object_labels.get(
            target_object or "",
            elements.get(target, ("?", ""))[0],
        )
        rendered_relations.append(
            (source_name, relation_name, target_name, relation_type, directed)
        )

    for source_name, relation_name, target_name, relation_type, directed in sorted(
        rendered_relations
    ):
        relation_description = relation_type
        if relation_type == "AssociationRelationship":
            relation_description += ", directed" if directed else ", undirected"
        lines.append(
            f"- `{source_name}` --{relation_name}--> `{target_name}` "
            f"({relation_description})"
        )

    if not rendered_relations and lines[-1] == "":
        lines.pop()

    return "\n".join(lines) + "\n"


def rendered_view(
    root: ET.Element,
    source_path: Path,
    view_name: str,
    include_meaning: bool,
) -> str:
    elements, relations = collect_model(root)
    view = find_view(root, view_name)
    (
        object_targets,
        object_parents,
        object_labels,
        connections,
        notes,
        documentation,
    ) = collect_view(view)
    return render(
        elements,
        relations,
        object_targets,
        object_parents,
        object_labels,
        connections,
        notes,
        documentation,
        source_path,
        view_name,
        include_meaning,
    )


def validate_model(root: ET.Element) -> list[str]:
    """Validate repository View contracts without validating O2I semantics."""
    try:
        profile_contract = load_profile_contract(PROFILE_CONTRACT)
        pattern_contracts = syntax_pattern_contracts(profile_contract)
        pattern_nodes = syntax_pattern_nodes(profile_contract)
        expected_carrier_mappings = carrier_mapping_edges(profile_contract)
        relation_families = relation_mapping_families(profile_contract)
        expected_relation_families = frozenset(relation_families)
        admissible_mappings = syntax_mapping_edges(profile_contract)
    except (OSError, ProfileContractError) as error:
        return [f"cannot read ArchiMate profile contract: {error}"]

    elements, relations = collect_model(root)
    errors: list[str] = []
    expected_views = {view_name for view_name, _ in PRESETS.values()}
    view_counts = Counter(
        element.get("name", "")
        for element in root.iter("element")
        if xtype(element) == "ArchimateDiagramModel"
    )
    actual_views = set(view_counts)

    for view_name in sorted(expected_views - actual_views):
        errors.append(f"missing required view: {view_name}")
    for view_name in sorted(expected_views):
        if view_counts[view_name] > 1:
            errors.append(
                f"duplicate repository view: {view_name} "
                f"({view_counts[view_name]} occurrences)"
            )
    for view_name in sorted(actual_views - expected_views):
        errors.append(f"unregistered repository view: {view_name}")

    for view_name, _ in PRESETS.values():
        try:
            view = find_view(root, view_name)
        except SystemExit:
            continue

        (
            object_targets,
            _,
            _,
            connections,
            notes,
            documentation,
        ) = collect_view(view)

        relation_signatures = []
        relation_records = []
        for source_object, relation_id, target_object in connections:
            invalid_reference = False
            if source_object is None:
                errors.append(f"{view_name} connection has no source reference")
                invalid_reference = True
            elif source_object not in object_targets:
                errors.append(
                    f"{view_name} connection has unresolved source reference: "
                    f"{source_object!r}"
                )
                invalid_reference = True

            if relation_id is None:
                errors.append(
                    f"{view_name} connection has no relationship reference"
                )
                invalid_reference = True
            elif relation_id not in relations:
                errors.append(
                    f"{view_name} connection has unresolved relationship "
                    f"reference: {relation_id!r}"
                )
                invalid_reference = True

            if target_object is None:
                errors.append(f"{view_name} connection has no target reference")
                invalid_reference = True
            elif target_object not in object_targets:
                errors.append(
                    f"{view_name} connection has unresolved target reference: "
                    f"{target_object!r}"
                )
                invalid_reference = True

            if invalid_reference:
                continue

            source = object_targets[source_object]
            target = object_targets[target_object]
            if source not in elements:
                errors.append(
                    f"{view_name} source object {source_object!r} refers to "
                    f"unknown model element {source!r}"
                )
                continue
            if target not in elements:
                errors.append(
                    f"{view_name} target object {target_object!r} refers to "
                    f"unknown model element {target!r}"
                )
                continue

            source_name, source_type = elements.get(source, ("?", "?"))
            target_name, target_type = elements.get(target, ("?", "?"))
            (
                relation_name,
                relation_type,
                relation_source,
                relation_target,
                directed,
            ) = relations.get(relation_id, ("?", "?", None, None, False))
            if source != relation_source:
                errors.append(
                    f"{view_name} connection source {source!r} does not match "
                    f"relationship {relation_id!r} source {relation_source!r}"
                )
            if target != relation_target:
                errors.append(
                    f"{view_name} connection target {target!r} does not match "
                    f"relationship {relation_id!r} target {relation_target!r}"
                )
            if source_type == "Meaning" or target_type == "Meaning":
                continue
            relation_signatures.append(
                (
                    source_name,
                    source_type,
                    relation_name,
                    relation_type,
                    directed,
                    target_name,
                    target_type,
                )
            )
            relation_records.append(
                (
                    source,
                    source_name,
                    source_type,
                    relation_name,
                    relation_type,
                    directed,
                    target,
                    target_name,
                    target_type,
                )
            )

        expected_relations = RELATION_CONTRACTS.get(
            view_name,
            pattern_contracts.get(view_name),
        )
        if view_name == SYNTAX_VIEW:
            canonical_relations = []
            for signature in relation_signatures:
                try:
                    canonical_relations.append(
                        canonical_mapping_edge(signature)
                    )
                except ProfileContractError as error:
                    errors.append(
                        f"{view_name} has invalid mapping endpoint roles: "
                        f"{error}"
                    )
            actual_relations = frozenset(canonical_relations)
            actual_carrier_mappings = frozenset(
                relation
                for relation in actual_relations
                if relation[2] == MAPS_TO
            )
            for missing in sorted(
                expected_carrier_mappings - actual_carrier_mappings
            ):
                errors.append(
                    f"{view_name} is missing contracted mapping: "
                    + format_contract_edge(missing)
                )
            for unexpected in sorted(
                actual_relations - admissible_mappings
            ):
                errors.append(
                    f"{view_name} has contract-inconsistent mapping: "
                    + format_contract_edge(unexpected)
                )
            represented_families: dict[
                tuple[str, str, str, bool],
                set[tuple[str, str, str, str, bool, str, str]],
            ] = {}
            for relation in actual_relations:
                if relation[2] != GENERIC_RELATION_NAME:
                    continue
                matching_families = [
                    family
                    for family, mappings in relation_families.items()
                    if relation in mappings
                ]
                for family in matching_families:
                    represented_families.setdefault(family, set()).add(
                        relation
                    )
            for missing in sorted(
                expected_relation_families - frozenset(represented_families)
            ):
                errors.append(
                    f"{view_name} is missing relation-mapping family: "
                    + format_mapping_family(missing)
                )
            for family, mappings in sorted(represented_families.items()):
                if len(mappings) > 1:
                    errors.append(
                        f"{view_name} duplicates relation-mapping family: "
                        + format_mapping_family(family)
                    )
            duplicates = [
                signature
                for signature, count in Counter(canonical_relations).items()
                if count > 1
            ]
            for duplicate in sorted(duplicates):
                errors.append(
                    f"{view_name} duplicates contracted mapping: "
                    + format_contract_edge(duplicate)
                )
            expected_relations = None

        if view_name == "O2I Syntax - Contextualization":
            errors.extend(
                contextualization_pattern_errors(
                    profile_contract,
                    view_name,
                    relation_records,
                )
            )
        if view_name == "O2I Syntax - Collective Strategy Realization":
            errors.extend(
                collective_pattern_errors(
                    root,
                    profile_contract,
                    view_name,
                    object_targets,
                    relation_records,
                    elements,
                )
            )

        if expected_relations is not None:
            actual_relations = frozenset(relation_signatures)
            for missing in sorted(expected_relations - actual_relations):
                errors.append(
                    f"{view_name} is missing contracted relation: "
                    + format_contract_edge(missing)
                )
            for unexpected in sorted(actual_relations - expected_relations):
                errors.append(
                    f"{view_name} has uncontracted relation: "
                    + format_contract_edge(unexpected)
                )

            duplicates = [
                signature
                for signature, count in Counter(relation_signatures).items()
                if count > 1
            ]
            for duplicate in sorted(duplicates):
                errors.append(
                    f"{view_name} duplicates contracted relation: "
                    + format_contract_edge(duplicate)
                )

        required_nodes = pattern_nodes.get(view_name, frozenset())
        if required_nodes:
            visible_nodes = {
                elements[element_id]
                for element_id in object_targets.values()
                if element_id in elements
                and elements[element_id][1] != "Meaning"
            }
            for required in sorted(required_nodes):
                if required not in visible_nodes:
                    errors.append(
                        f"{view_name} is missing node "
                        f"{required[0]} ({required[1]})"
                    )

        for fragment in REQUIRED_VIEW_DOCUMENTATION.get(view_name, ()):
            if fragment not in documentation:
                errors.append(
                    f"{view_name} documentation is missing: {fragment}"
                )

        errors.extend(
            required_element_documentation_errors(
                root,
                view_name,
                object_targets,
            )
        )

    return errors


def required_element_documentation_errors(
    root: ET.Element,
    view_name: str,
    object_targets: dict[str, str],
) -> list[str]:
    """Check documentation selected as part of a repository View contract."""
    by_id = {
        element_id: element
        for element in root.iter("element")
        if (element_id := element.get("id"))
    }
    visible = [
        by_id[element_id]
        for element_id in object_targets.values()
        if element_id in by_id
    ]
    errors: list[str] = []

    for (contract_view, name, element_type), fragments in (
        REQUIRED_ELEMENT_DOCUMENTATION.items()
    ):
        if contract_view != view_name:
            continue
        matches = [
            element
            for element in visible
            if element.get("name", "") == name
            and xtype(element) == element_type
        ]
        if len(matches) != 1:
            errors.append(
                f"{view_name} expected exactly one documented element "
                f"{name} ({element_type}); found {len(matches)}"
            )
            continue
        documentation = (matches[0].findtext("documentation") or "").strip()
        for fragment in fragments:
            if fragment not in documentation:
                errors.append(
                    f"{view_name} element {name} ({element_type}) "
                    f"documentation is missing: {fragment}"
                )

    return errors


def format_contract_edge(
    edge: tuple[str, str, str, str, bool, str, str],
) -> str:
    source, source_type, relation, relation_type, directed, target, target_type = edge
    direction = ", directed" if directed else ""
    return (
        f"{source} ({source_type}) --{relation} [{relation_type}{direction}]--> "
        f"{target} ({target_type})"
    )


def snapshot_diff(output_path: Path, expected: str) -> list[str]:
    if not output_path.exists():
        return [f"missing snapshot: {output_path}"]

    try:
        actual = output_path.read_text(encoding="utf-8")
    except OSError as error:
        return [f"cannot read snapshot {output_path}: {error}"]
    if actual == expected:
        return []

    diff = "".join(
        difflib.unified_diff(
            actual.splitlines(keepends=True),
            expected.splitlines(keepends=True),
            fromfile=str(output_path),
            tofile=f"generated:{output_path}",
        )
    )
    return [f"snapshot drift: {output_path}\n{diff}"]


def snapshot_contract_errors() -> list[str]:
    expected = {
        (REPOSITORY_ROOT / output_path).resolve()
        for _, output_path in PRESETS.values()
    }
    actual = {
        path.resolve()
        for path in (REPOSITORY_ROOT / "mdl").glob("o2i-*.md")
    }
    errors = []
    for path in sorted(expected - actual):
        errors.append(f"missing registered snapshot: {path}")
    for path in sorted(actual - expected):
        errors.append(f"unregistered repository snapshot: {path}")
    return errors


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Extract repository review snapshots from O2I ArchiMate views."
    )
    parser.add_argument(
        "--model",
        type=Path,
        default=DEFAULT_MODEL,
        help="Path to the ArchiMate model.",
    )
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument(
        "--preset",
        choices=[*PRESETS.keys(), "all"],
        help="Named O2I view preset to extract.",
    )
    selection.add_argument(
        "--view",
        default=None,
        help="ArchiMate view name to extract.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Markdown output path.",
    )
    parser.add_argument(
        "--include-meaning",
        action="store_true",
        help="Include ArchiMate Meaning elements used as visual labels.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Validate model invariants and fail on snapshot drift.",
    )
    return parser


def parse_args(
    argv: list[str] | None = None,
) -> tuple[argparse.ArgumentParser, argparse.Namespace]:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.preset is not None:
        if args.output is not None:
            parser.error("--output is only valid with --view")
        if args.include_meaning:
            parser.error("--include-meaning is only valid with --view")
    elif args.output is None:
        parser.error("--view requires --output")
    return parser, args


def display_path(path: Path) -> Path:
    resolved = path.resolve()
    try:
        return resolved.relative_to(REPOSITORY_ROOT)
    except ValueError:
        return path


def run(args: argparse.Namespace) -> list[str]:
    try:
        root = ET.parse(args.model).getroot()
    except (ET.ParseError, OSError) as error:
        return [f"cannot read model {args.model}: {error}"]

    errors = (
        [*validate_model(root), *snapshot_contract_errors()]
        if args.check
        else []
    )

    if args.preset == "all":
        for view_name, output_path in PRESETS.values():
            output_path = REPOSITORY_ROOT / output_path
            try:
                content = rendered_view(
                    root,
                    display_path(args.model),
                    view_name,
                    False,
                )
            except SystemExit as error:
                errors.append(str(error))
                continue
            if args.check:
                errors.extend(snapshot_diff(output_path, content))
            else:
                try:
                    output_path.write_text(content, encoding="utf-8")
                except OSError as error:
                    errors.append(f"cannot write snapshot {output_path}: {error}")
        return errors

    if args.preset:
        view_name, output_path = PRESETS[args.preset]
        output_path = REPOSITORY_ROOT / output_path
        include_meaning = False
    else:
        view_name = args.view
        output_path = args.output
        include_meaning = args.include_meaning

    try:
        content = rendered_view(
            root,
            display_path(args.model),
            view_name,
            include_meaning,
        )
    except SystemExit as error:
        errors.append(str(error))
        return errors
    if args.check:
        errors.extend(snapshot_diff(output_path, content))
    else:
        try:
            output_path.write_text(content, encoding="utf-8")
        except OSError as error:
            errors.append(f"cannot write snapshot {output_path}: {error}")
    return errors


def main(argv: list[str] | None = None) -> None:
    _, args = parse_args(argv)
    errors = run(args)
    if errors:
        print(
            "\n\n".join(f"[o2i|error] {error}" for error in errors),
            file=sys.stderr,
        )
        raise SystemExit(1)


if __name__ == "__main__":
    main()
