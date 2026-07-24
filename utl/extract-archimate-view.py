#!/usr/bin/env python3
"""Extract reviewable Markdown snapshots from O2I ArchiMate views."""

from __future__ import annotations

import argparse
from collections import Counter
import difflib
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


XSI_TYPE = "{http://www.w3.org/2001/XMLSchema-instance}type"

PRESETS = {
    "strategy-constituents": (
        "O2I Strategy Constituents",
        Path("mdl/o2i-strategy-constituents.md"),
    ),
    "situation": (
        "O2I Semantics - Situation",
        Path("mdl/o2i-situation.md"),
    ),
    "situation-anchoring": (
        "O2I Situation Anchoring",
        Path("mdl/o2i-situation-anchoring.md"),
    ),
    "orientation": ("O2I Orientierung", Path("mdl/o2i-orientation.md")),
    "context": ("O2I Semantics - Context", Path("mdl/o2i-context.md")),
    "primitives": (
        "O2I Semantics - Primitives",
        Path("mdl/o2i-primitives.md"),
    ),
    "syntax": (
        "O2I Syntax - Primitives",
        Path("mdl/o2i-syntax.md"),
    ),
    "layered-cake": ("O2I Layered Cake", Path("mdl/o2i-layered-cake.md")),
}

REQUIRED_SYNTAX_NODES = {
    ("Assessment", "Assessment"),
    ("Course of Action", "CourseOfAction"),
    ("Driver", "Driver"),
    ("Driver @ Mission", "Driver"),
    ("Goal", "Goal"),
    ("O2I Context (Mission)", "Grouping"),
    ("O2I Context (Strategy)", "Grouping"),
    ("Outcome", "Outcome"),
    ("Performance Dimension", "Grouping"),
    ("Performance Dimension @ Strategy", "Grouping"),
    ("Principle", "Principle"),
}

REQUIRED_SYNTAX_DOCUMENTATION = (
    "Defines the concrete ArchiMate realization of O2I Contexts, "
    "contextualized Primitives, PerformanceDimensions, Situation anchors, "
    "and their relation mappings.",
    "Every O2I Context and PerformanceDimension is represented by an "
    "ArchiMate Grouping.",
    "ArchiMate Groupings introduce no O2I semantics.",
    "Every concrete Primitive and PerformanceDimension instance is "
    "contextualized by exactly one Context through "
    "composition[contextualizes]",
    "The Interpretation registry admits Primitive @ Context;",
    "the role registry admits PerformanceDimension @ Context and constrains "
    "its member Primitive type and membership relation without interpreting "
    "the members.",
    "Visual nesting presents but never replaces explicit contextualization.",
    "Primitive @ Context and PerformanceDimension @ Context are the textual "
    "O2I notations.",
    "The bounded contextualization examples are syntax exemplars, not fachliche "
    "instances.",
    "Situation anchors are independent nodes and are not contextualized by a "
    "Context.",
    "O2I BusinessCapability -> ArchiMate Capability",
    "O2I BusinessProcess -> ArchiMate Process",
    "O2I BusinessObject -> ArchiMate Business Object",
    "O2I BusinessRole -> ArchiMate Role",
    "O2I ValueStream -> ArchiMate Value Stream",
    "O2I RegulatoryConstraint -> ArchiMate Requirement",
)

O2I_KIND_PROPERTY = "o2i.kind"
O2I_TYPE_PROPERTY = "o2i.type"
O2I_PROFILE_PROPERTY = "o2i.profile"
O2I_PROFILE_VERSION = "0.2"
O2I_TYPES_BY_KIND = {
    "Context": frozenset(
        {
            "Ethos",
            "Mission",
            "Vision",
            "Strategy",
            "Situation",
            "Need",
            "Intervention",
            "Measure",
        }
    ),
    "Primitive": frozenset(
        {"Principle", "Driver", "Objective", "KeyResult", "KPI", "Action"}
    ),
    "Structuring": frozenset({"PerformanceDimension"}),
    "SituationAnchor": frozenset(
        {
            "BusinessCapability",
            "BusinessProcess",
            "BusinessObject",
            "BusinessRole",
            "ValueStream",
            "RegulatoryConstraint",
        }
    ),
}
O2I_CONTEXTUALIZED_KINDS = frozenset({"Primitive", "Structuring"})
FORBIDDEN_O2I_METADATA_PROPERTIES = frozenset(
    {
        "o2i.context",
        "o2i.owner",
        "o2i.role",
        "o2i.interpretation",
        "o2i.member",
    }
)

REQUIRED_SYNTAX_EXEMPLAR_METADATA = {
    ("Driver @ Mission", "Driver"): {
        O2I_KIND_PROPERTY: "Primitive",
        O2I_TYPE_PROPERTY: "Driver",
    },
    ("O2I Context (Mission)", "Grouping"): {
        O2I_KIND_PROPERTY: "Context",
        O2I_TYPE_PROPERTY: "Mission",
    },
    ("O2I Context (Strategy)", "Grouping"): {
        O2I_KIND_PROPERTY: "Context",
        O2I_TYPE_PROPERTY: "Strategy",
    },
    ("Performance Dimension @ Strategy", "Grouping"): {
        O2I_KIND_PROPERTY: "Structuring",
        O2I_TYPE_PROPERTY: "PerformanceDimension",
    },
}

REQUIRED_SITUATION_ANCHOR_METADATA = {
    (anchor, "Grouping"): {
        O2I_KIND_PROPERTY: "SituationAnchor",
        O2I_TYPE_PROPERTY: anchor_type,
    }
    for anchor, anchor_type in (
        ("Business Capability", "BusinessCapability"),
        ("Business Object", "BusinessObject"),
        ("Business Process", "BusinessProcess"),
        ("Business Role", "BusinessRole"),
        ("Regulatory Constraint", "RegulatoryConstraint"),
        ("Value Stream", "ValueStream"),
    )
}

REQUIRED_O2I_ELEMENT_METADATA = {
    **REQUIRED_SYNTAX_EXEMPLAR_METADATA,
    **REQUIRED_SITUATION_ANCHOR_METADATA,
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
                "Business Role",
                "Regulatory Constraint",
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
            contract_edge("Intervention", "addresses", "Need"),
            contract_edge("Intervention", "changes", "Situation"),
            contract_edge("Intervention", "sets-target-for", "Measure"),
            contract_edge(
                "KPI",
                "measures",
                "Situation Anchor",
                relation_type="AssociationRelationship",
                directed=True,
            ),
            contract_edge("Measure", "measures", "Situation"),
            contract_edge(
                "Situation",
                "is-constituted-by",
                "Situation Anchor",
                relation_type="AggregationRelationship",
            ),
            contract_edge("Situation", "surfaces", "Need"),
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
    "O2I Syntax - Primitives": frozenset(
        {
            contract_edge(
                "O2I Context (Mission)",
                "contextualizes",
                "Driver @ Mission",
                relation_type="CompositionRelationship",
                target_type="Driver",
            ),
            contract_edge(
                "O2I Context (Strategy)",
                "contextualizes",
                "Performance Dimension @ Strategy",
                relation_type="CompositionRelationship",
            ),
            contract_edge(
                "Course of Action",
                "contributes-to",
                "Course of Action",
                source_type="CourseOfAction",
                relation_type="AssociationRelationship",
                directed=True,
                target_type="CourseOfAction",
            ),
            contract_edge(
                "Course of Action",
                "contributes-to",
                "Outcome",
                source_type="CourseOfAction",
                relation_type="RealizationRelationship",
                target_type="Outcome",
            ),
            contract_edge(
                "Course of Action",
                "guides",
                "Course of Action",
                source_type="CourseOfAction",
                relation_type="AssociationRelationship",
                directed=True,
                target_type="CourseOfAction",
            ),
            contract_edge(
                "Driver",
                "grounds",
                "Goal",
                source_type="Driver",
                target_type="Goal",
            ),
            contract_edge(
                "Driver",
                "indicates",
                "Performance Dimension",
                source_type="Driver",
            ),
            contract_edge(
                "Goal",
                "orients",
                "Goal",
                source_type="Goal",
                target_type="Goal",
            ),
            contract_edge(
                "Outcome",
                "contributes-to",
                "Outcome",
                source_type="Outcome",
                target_type="Outcome",
            ),
            contract_edge(
                "Outcome",
                "determines",
                "Performance Dimension",
                source_type="Outcome",
            ),
            contract_edge(
                "Outcome",
                "sets-target-for",
                "Assessment",
                source_type="Outcome",
                relation_type="AssociationRelationship",
                directed=True,
                target_type="Assessment",
            ),
            contract_edge(
                "Outcome",
                "substantiates",
                "Goal",
                source_type="Outcome",
                relation_type="RealizationRelationship",
                target_type="Goal",
            ),
            contract_edge(
                "Outcome",
                "translates-into",
                "Goal",
                source_type="Outcome",
                target_type="Goal",
            ),
            contract_edge(
                "Performance Dimension",
                "contains",
                "Assessment",
                relation_type="AggregationRelationship",
                target_type="Assessment",
            ),
            contract_edge(
                "Performance Dimension",
                "contains",
                "Outcome",
                relation_type="AggregationRelationship",
                target_type="Outcome",
            ),
            contract_edge(
                "Principle",
                "guides",
                "Course of Action",
                source_type="Principle",
                relation_type="AssociationRelationship",
                directed=True,
                target_type="CourseOfAction",
            ),
            contract_edge(
                "Principle",
                "guides",
                "Driver",
                source_type="Principle",
                target_type="Driver",
            ),
            contract_edge(
                "Principle",
                "guides",
                "Goal",
                source_type="Principle",
                target_type="Goal",
            ),
            contract_edge(
                "Principle",
                "guides",
                "Principle",
                source_type="Principle",
                target_type="Principle",
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


def model_elements(root: ET.Element) -> dict[str, ET.Element]:
    return {
        element_id: element
        for element in root.iter("element")
        if (element_id := element.get("id"))
        and not xtype(element).endswith("Relationship")
        and xtype(element) != "ArchimateDiagramModel"
    }


def property_values(element: ET.Element, key: str) -> list[str]:
    return [
        prop.get("value", "")
        for prop in element.findall("property")
        if prop.get("key") == key
    ]


def element_label(element: ET.Element) -> str:
    return (
        f"{element.get('name', '')} ({xtype(element)}, "
        f"{element.get('id', '?')})"
    )


def required_o2i_metadata_errors(root: ET.Element) -> list[str]:
    candidates = list(model_elements(root).values())
    errors: list[str] = []

    for identity, required in REQUIRED_O2I_ELEMENT_METADATA.items():
        name, element_type = identity
        matches = [
            element
            for element in candidates
            if element.get("name", "") == name
            and xtype(element) == element_type
        ]
        if len(matches) != 1:
            errors.append(
                "expected exactly one metadata-bearing O2I element "
                f"{name} ({element_type}); found {len(matches)}"
            )
            continue

        element = matches[0]
        for key, expected in required.items():
            values = property_values(element, key)
            if values != [expected]:
                errors.append(
                    f"{element_label(element)} must declare exactly one "
                    f"{key}={expected!r}; found {values!r}"
                )

    return errors


def collect_o2i_metadata(
    root: ET.Element,
) -> tuple[dict[str, tuple[str, str]], list[str]]:
    metadata: dict[str, tuple[str, str]] = {}
    errors: list[str] = []

    for element_id, element in model_elements(root).items():
        o2i_properties = [
            prop
            for prop in element.findall("property")
            if prop.get("key", "").startswith("o2i.")
        ]
        if not o2i_properties:
            continue

        for prop in o2i_properties:
            key = prop.get("key", "")
            if key in FORBIDDEN_O2I_METADATA_PROPERTIES:
                errors.append(
                    f"{element_label(element)} must not declare forbidden "
                    f"O2I metadata property {key!r}"
                )
            elif key not in {O2I_KIND_PROPERTY, O2I_TYPE_PROPERTY}:
                errors.append(
                    f"{element_label(element)} declares unsupported O2I "
                    f"metadata property {key!r}"
                )

        kind_values = property_values(element, O2I_KIND_PROPERTY)
        type_values = property_values(element, O2I_TYPE_PROPERTY)

        if len(kind_values) != 1:
            errors.append(
                f"{element_label(element)} must declare exactly one "
                f"{O2I_KIND_PROPERTY}; found {kind_values!r}"
            )
            continue

        kind = kind_values[0]
        if kind not in O2I_TYPES_BY_KIND:
            errors.append(
                f"{element_label(element)} has invalid {O2I_KIND_PROPERTY} "
                f"value {kind!r}"
            )
            continue

        if len(type_values) != 1:
            errors.append(
                f"{element_label(element)} must declare exactly one "
                f"{O2I_TYPE_PROPERTY}; found {type_values!r}"
            )
            continue

        element_type = type_values[0]
        if element_type not in O2I_TYPES_BY_KIND[kind]:
            errors.append(
                f"{element_label(element)} has invalid "
                f"{O2I_TYPE_PROPERTY} value {element_type!r} for "
                f"{O2I_KIND_PROPERTY}={kind!r}"
            )
            continue

        metadata[element_id] = (kind, element_type)

    return metadata, errors


def validate_o2i_contextualization(
    root: ET.Element,
    relations: dict[
        str,
        tuple[str, str, str | None, str | None, bool],
    ],
) -> list[str]:
    """Validate generic O2I metadata and structure, not registry semantics."""
    model_nodes = model_elements(root)
    metadata, errors = collect_o2i_metadata(root)

    for error in required_o2i_metadata_errors(root):
        if error not in errors:
            errors.append(error)

    contextualization_relations = [
        (relation_id, source, target)
        for relation_id, (
            relation_name,
            relation_type,
            source,
            target,
            _,
        ) in relations.items()
        if relation_name == "contextualizes"
        and relation_type == "CompositionRelationship"
    ]
    incoming: dict[str, list[tuple[str, str | None]]] = {}
    for relation_id, source, target in contextualization_relations:
        if target is not None:
            incoming.setdefault(target, []).append((relation_id, source))

        source_metadata = metadata.get(source or "")
        target_metadata = metadata.get(target or "")
        if source_metadata is None and target_metadata is None:
            continue

        if source_metadata is None or source_metadata[0] != "Context":
            errors.append(
                f"contextualization relation {relation_id!r} must start at an element "
                f"with {O2I_KIND_PROPERTY}='Context'"
            )
        if (
            target_metadata is None
            or target_metadata[0] not in O2I_CONTEXTUALIZED_KINDS
        ):
            errors.append(
                f"contextualization relation {relation_id!r} must end at an element "
                "with o2i.kind='Primitive' or o2i.kind='Structuring'"
            )

    for element_id, (kind, _) in metadata.items():
        contextualizations = incoming.get(element_id, [])
        label = element_label(model_nodes[element_id])
        if (
            kind in O2I_CONTEXTUALIZED_KINDS
            and len(contextualizations) != 1
        ):
            errors.append(
                f"{label} has {len(contextualizations)} model-wide "
                "CompositionRelationship[contextualizes] contextualizations; "
                "expected exactly one"
            )
        if kind in {"Context", "SituationAnchor"} and contextualizations:
            relation_ids = [
                relation_id for relation_id, _ in contextualizations
            ]
            errors.append(
                f"{label} must not be contextualized but has model-wide "
                "CompositionRelationship[contextualizes] contextualizations "
                f"{relation_ids!r}"
            )

    for relation_id, (
        relation_name,
        relation_type,
        source,
        target,
        _,
    ) in relations.items():
        if relation_name != "contains" or relation_type != "AggregationRelationship":
            continue
        if metadata.get(source or "") != (
            "Structuring",
            "PerformanceDimension",
        ):
            continue

        target_metadata = metadata.get(target or "")
        if target_metadata is None or target_metadata[0] != "Primitive":
            errors.append(
                f"PerformanceDimension membership {relation_id!r} must end "
                "at an element with o2i.kind='Primitive'"
            )
            continue

        dimension_owners = incoming.get(source or "", [])
        member_owners = incoming.get(target or "", [])
        if len(dimension_owners) == 1 and len(member_owners) == 1:
            dimension_owner = dimension_owners[0][1]
            member_owner = member_owners[0][1]
            if dimension_owner != member_owner:
                errors.append(
                    f"PerformanceDimension membership {relation_id!r} "
                    "crosses contextualizing Context element IDs: "
                    f"{dimension_owner!r} != {member_owner!r}"
                )

    return errors


def find_view(root: ET.Element, view_name: str) -> ET.Element:
    for element in root.iter("element"):
        if xtype(element) == "ArchimateDiagramModel" and element.get("name") == view_name:
            return element
    raise SystemExit(f"view not found: {view_name}")


def collect_view(view: ET.Element):
    object_targets: dict[str, str] = {}
    object_parents: dict[str, str | None] = {}
    notes: list[str] = []

    def walk(node: ET.Element, parent: str | None) -> None:
        node_id = node.get("id")
        if node_id:
            object_parents[node_id] = parent
            target = node.get("archimateElement")
            if target:
                object_targets[node_id] = target
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
    return object_targets, object_parents, connections, notes, documentation


def top_container(
    object_id: str,
    object_targets: dict[str, str],
    object_parents: dict[str, str | None],
    elements: dict[str, tuple[str, str]],
) -> str:
    current = object_id
    while object_parents.get(current) is not None:
        current = object_parents[current] or current
    element_id = object_targets.get(current)
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
    connections: list[tuple[str | None, str | None, str | None]],
    notes: list[str],
    documentation: str,
    source_path: Path,
    view_name: str,
    include_meaning: bool,
) -> str:
    context_by_element: dict[str, str] = {}
    for object_id, element_id in object_targets.items():
        context_by_element.setdefault(
            element_id,
            top_container(object_id, object_targets, object_parents, elements),
        )

    visible_elements = {
        element_id
        for element_id in object_targets.values()
        if include_meaning or elements.get(element_id, ("", ""))[1] != "Meaning"
    }

    lines: list[str] = [
        f"# {view_name}",
        "",
        f"> Generated review snapshot of `{view_name}` from `{source_path}`.",
        "> Review artifact only; source of truth remains the O2I metamodel.",
        "",
    ]

    if documentation:
        lines.extend(["## View Contract", "", documentation, ""])

    if notes:
        lines.extend(["## Notes", ""])
        lines.extend(f"- {note}" for note in sorted(notes))
        lines.append("")

    lines.extend(["## Nodes", ""])

    for element_id in sorted(
        visible_elements,
        key=lambda item: (context_by_element.get(item, ""), elements.get(item, ("", ""))[0]),
    ):
        name, element_type = elements[element_id]
        context = context_by_element.get(element_id, "")
        lines.append(f"- [{context}] `{name}` ({element_type})")

    lines.extend(["", "## Relations", ""])

    rendered_relations = []
    for source_object, relation_id, target_object in connections:
        source = object_targets.get(source_object or "")
        target = object_targets.get(target_object or "")
        if relation_id is None or source is None or target is None:
            continue
        if source not in visible_elements or target not in visible_elements:
            continue
        relation_name, relation_type, _, _, directed = relations.get(
            relation_id,
            ("?", "?", None, None, False),
        )
        source_name = elements.get(source, ("?", ""))[0]
        target_name = elements.get(target, ("?", ""))[0]
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

    return "\n".join(lines) + "\n"


def rendered_view(
    root: ET.Element,
    source_path: Path,
    view_name: str,
    include_meaning: bool,
) -> str:
    elements, relations = collect_model(root)
    view = find_view(root, view_name)
    object_targets, object_parents, connections, notes, documentation = collect_view(view)
    return render(
        elements,
        relations,
        object_targets,
        object_parents,
        connections,
        notes,
        documentation,
        source_path,
        view_name,
        include_meaning,
    )


def validate_model(root: ET.Element) -> list[str]:
    elements, relations = collect_model(root)
    errors: list[str] = []

    profile_versions = [
        prop.get("value", "")
        for prop in root.findall("property")
        if prop.get("key") == O2I_PROFILE_PROPERTY
    ]
    if profile_versions != [O2I_PROFILE_VERSION]:
        errors.append(
            "expected exactly one canonical O2I profile 0.2; found: "
            + repr(profile_versions)
        )

    legacy_profile_versions = [
        prop.get("value", "")
        for prop in root.findall("property")
        if prop.get("key") == "version"
    ]
    if legacy_profile_versions:
        errors.append(
            "generic model property 'version' is not an O2I profile alias; "
            "found: "
            + repr(legacy_profile_versions)
        )

    errors.extend(validate_o2i_contextualization(root, relations))

    for view_name, _ in PRESETS.values():
        try:
            view = find_view(root, view_name)
        except SystemExit:
            errors.append(f"missing required view: {view_name}")
            continue

        object_targets, _, connections, notes, documentation = collect_view(view)

        relation_signatures = []
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
            if relation_type == "AssociationRelationship" and not directed:
                errors.append(
                    f"{view_name} uses undirected association: {relation_name}"
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

        expected_relations = RELATION_CONTRACTS.get(view_name)
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

        if view_name == "O2I Syntax - Primitives":
            visible_nodes = {
                elements[element_id]
                for element_id in object_targets.values()
                if element_id in elements
                and elements[element_id][1] != "Meaning"
            }
            for required in sorted(REQUIRED_SYNTAX_NODES):
                if required not in visible_nodes:
                    errors.append(
                        f"{view_name} is missing node "
                        f"{required[0]} ({required[1]})"
                    )

            for fragment in REQUIRED_SYNTAX_DOCUMENTATION:
                if fragment not in documentation:
                    errors.append(
                        "O2I Syntax documentation is missing: " + fragment
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

    actual = output_path.read_text(encoding="utf-8")
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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--model",
        type=Path,
        default=Path("mdl/o2i.archimate"),
        help="Path to the ArchiMate model.",
    )
    parser.add_argument(
        "--preset",
        choices=[*PRESETS.keys(), "all"],
        help="Named O2I view preset to extract.",
    )
    parser.add_argument(
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
    args = parser.parse_args()

    root = ET.parse(args.model).getroot()
    errors = validate_model(root) if args.check else []

    if args.preset == "all":
        for view_name, output_path in PRESETS.values():
            content = rendered_view(
                root,
                args.model,
                view_name,
                args.include_meaning,
            )
            if args.check:
                errors.extend(snapshot_diff(output_path, content))
            else:
                output_path.write_text(content, encoding="utf-8")
        if errors:
            print("\n\n".join(errors), file=sys.stderr)
            raise SystemExit(1)
        return

    if args.preset:
        view_name, output_path = PRESETS[args.preset]
    else:
        view_name = args.view or PRESETS["layered-cake"][0]
        output_path = args.output or PRESETS["layered-cake"][1]

    if args.view:
        view_name = args.view
    if args.output:
        output_path = args.output

    content = rendered_view(
        root,
        args.model,
        view_name,
        args.include_meaning,
    )
    if args.check:
        errors.extend(snapshot_diff(output_path, content))
    else:
        output_path.write_text(content, encoding="utf-8")

    if errors:
        print("\n\n".join(errors), file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
