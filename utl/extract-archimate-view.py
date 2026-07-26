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
REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MODEL = REPOSITORY_ROOT / "mdl" / "o2i.archimate"

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
    "syntax-context": (
        "O2I Syntax - Context",
        Path("mdl/o2i-syntax-context.md"),
    ),
    "syntax-contextualization": (
        "O2I Syntax - Contextualization",
        Path("mdl/o2i-syntax-contextualization.md"),
    ),
    "syntax-collective-strategy-realization": (
        "O2I Syntax - Collective Strategy Realization",
        Path("mdl/o2i-syntax-collective-strategy-realization.md"),
    ),
    "syntax-primitives": (
        "O2I Syntax - Primitives",
        Path("mdl/o2i-syntax-primitives.md"),
    ),
    "syntax-situation": (
        "O2I Syntax - Situation",
        Path("mdl/o2i-syntax-situation.md"),
    ),
    "layered-cake": ("O2I Layered Cake", Path("mdl/o2i-layered-cake.md")),
}

REQUIRED_SYNTAX_NODES = {
    ("O2I Action", "CourseOfAction"),
    ("O2I Driver", "Driver"),
    ("O2I KPI", "Assessment"),
    ("O2I Key Result", "Outcome"),
    ("O2I Objective", "Goal"),
    ("O2I Performance Dimension", "Grouping"),
    ("O2I Principle", "Principle"),
}

REQUIRED_CONTEXTUALIZATION_NODES = {
    ("<Name> :: O2I Driver", "Driver"),
    ("<Name> :: O2I Mission", "Grouping"),
    ("<Name> :: O2I Performance Dimension", "Grouping"),
    ("<Name> :: O2I Strategy", "Grouping"),
}

REQUIRED_COLLECTIVE_REALIZATION_NODES = {
    ("<Contributor Strategy 1> :: O2I Strategy", "Grouping"),
    ("<Contributor Strategy 2> :: O2I Strategy", "Grouping"),
    ("<Name> :: O2I Collective Strategy Realization", "Junction"),
    ("<Target Strategy> :: O2I Strategy", "Grouping"),
}

REQUIRED_PRIMITIVE_SYNTAX_DOCUMENTATION = (
    "Defines the concrete ArchiMate element and relationship mappings for "
    "O2I Primitives and PerformanceDimensions.",
    "unannotated type-mapping exemplars",
    "O2I Principle -> ArchiMate Principle",
    "O2I Driver -> ArchiMate Driver",
    "O2I Objective -> ArchiMate Goal",
    "O2I Key Result -> ArchiMate Outcome",
    "O2I KPI -> ArchiMate Assessment",
    "O2I Action -> ArchiMate Course of Action",
    "O2I Performance Dimension -> ArchiMate Grouping",
    "The O2I relation name, direction, endpoint types, and ArchiMate "
    "relationship type jointly form each relationship syntax signature.",
    "Concrete admissibility remains context-sensitive",
    "O2I Syntax - Contextualization",
)

REQUIRED_CONTEXTUALIZATION_DOCUMENTATION = (
    "Defines the concrete ArchiMate syntax for contextualizing O2I Primitives "
    "and PerformanceDimensions by typed O2I Context instances.",
    "contextualized by exactly one Context through "
    "composition[contextualizes]",
    "Contexts and PerformanceDimensions are represented by ArchiMate "
    "Groupings; the Groupings introduce no O2I semantics.",
    "Visual nesting presents but never replaces explicit contextualization.",
    "The Interpretation registry admits Primitive @ Context.",
    "The role registry admits PerformanceDimension @ Context",
    "derived textual readings, not persisted element names",
    "typed syntax exemplars, not fachliche model instances",
)

REQUIRED_COLLECTIVE_REALIZATION_DOCUMENTATION = (
    "Defines the concrete ArchiMate syntax for one O2I "
    "CollectiveStrategyRealization.",
    "At least two distinct contributor Strategy Contexts",
    "Exactly one outgoing realizes segment",
    "Segment direction and topology determine contributor and target roles.",
    "The Junction carries the complete structured proposition",
    "The realizes segments are mandatory syntax components",
    "Candidate syntax exemplars, not fachliche model instances",
)

REQUIRED_COLLECTIVE_REALIZATION_ELEMENT_DOCUMENTATION = (
    "Represents one structured n-ary O2I proposition",
    "ArchiMate AND Junction is its concrete syntax carrier",
    "at least two distinct contributor Strategies",
    "exactly one distinct target Strategy",
    "roles follow exclusively from the direction and topology",
    "segments carry no independent Commitment",
    "o2i.collective-fit-evidence references the structured evidence",
)

REQUIRED_NODES_BY_VIEW = {
    "O2I Syntax - Primitives": REQUIRED_SYNTAX_NODES,
    "O2I Syntax - Contextualization": REQUIRED_CONTEXTUALIZATION_NODES,
    (
        "O2I Syntax - Collective Strategy Realization"
    ): REQUIRED_COLLECTIVE_REALIZATION_NODES,
}

REQUIRED_VIEW_DOCUMENTATION = {
    "O2I Syntax - Primitives": REQUIRED_PRIMITIVE_SYNTAX_DOCUMENTATION,
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


def syntax_context_edge(
    source: str,
    relation: str,
    target: str,
) -> tuple[str, str, str, str, bool, str, str]:
    """Declare one binary O2I Context relation in the ArchiMate syntax."""
    return contract_edge(
        f"<Name> :: O2I {source}",
        relation,
        f"<Name> :: O2I {target}",
        relation_type="AssociationRelationship",
        directed=True,
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
    "O2I Syntax - Context": frozenset(
        {
            syntax_context_edge("Ethos", "guides", "Mission"),
            syntax_context_edge("Ethos", "guides", "Vision"),
            syntax_context_edge("Intervention", "addresses", "Need"),
            syntax_context_edge("Intervention", "changes", "Situation"),
            syntax_context_edge(
                "Intervention",
                "sets-target-for",
                "Measure",
            ),
            syntax_context_edge("Measure", "measures", "Situation"),
            syntax_context_edge("Mission", "grounds", "Vision"),
            syntax_context_edge("Situation", "surfaces", "Need"),
            syntax_context_edge(
                "Strategy",
                "contributes-to",
                "Strategy",
            ),
            syntax_context_edge("Strategy", "directs", "Intervention"),
            syntax_context_edge("Strategy", "directs", "Strategy"),
            syntax_context_edge("Strategy", "frames", "Measure"),
            syntax_context_edge("Strategy", "qualifies", "Need"),
            syntax_context_edge("Vision", "orients", "Strategy"),
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
                "O2I Action",
                "contributes-to",
                "O2I Action",
                source_type="CourseOfAction",
                relation_type="AssociationRelationship",
                directed=True,
                target_type="CourseOfAction",
            ),
            contract_edge(
                "O2I Action",
                "contributes-to",
                "O2I Key Result",
                source_type="CourseOfAction",
                relation_type="RealizationRelationship",
                target_type="Outcome",
            ),
            contract_edge(
                "O2I Action",
                "guides",
                "O2I Action",
                source_type="CourseOfAction",
                relation_type="AssociationRelationship",
                directed=True,
                target_type="CourseOfAction",
            ),
            contract_edge(
                "O2I Driver",
                "grounds",
                "O2I Objective",
                source_type="Driver",
                target_type="Goal",
            ),
            contract_edge(
                "O2I Driver",
                "indicates",
                "O2I Performance Dimension",
                source_type="Driver",
            ),
            contract_edge(
                "O2I Objective",
                "orients",
                "O2I Objective",
                source_type="Goal",
                target_type="Goal",
            ),
            contract_edge(
                "O2I Key Result",
                "contributes-to",
                "O2I Key Result",
                source_type="Outcome",
                target_type="Outcome",
            ),
            contract_edge(
                "O2I Key Result",
                "determines",
                "O2I Performance Dimension",
                source_type="Outcome",
            ),
            contract_edge(
                "O2I Key Result",
                "sets-target-for",
                "O2I KPI",
                source_type="Outcome",
                relation_type="AssociationRelationship",
                directed=True,
                target_type="Assessment",
            ),
            contract_edge(
                "O2I Key Result",
                "substantiates",
                "O2I Objective",
                source_type="Outcome",
                relation_type="RealizationRelationship",
                target_type="Goal",
            ),
            contract_edge(
                "O2I Key Result",
                "translates-into",
                "O2I Objective",
                source_type="Outcome",
                target_type="Goal",
            ),
            contract_edge(
                "O2I Performance Dimension",
                "contains",
                "O2I KPI",
                relation_type="AggregationRelationship",
                target_type="Assessment",
            ),
            contract_edge(
                "O2I Performance Dimension",
                "contains",
                "O2I Key Result",
                relation_type="AggregationRelationship",
                target_type="Outcome",
            ),
            contract_edge(
                "O2I Principle",
                "guides",
                "O2I Action",
                source_type="Principle",
                relation_type="AssociationRelationship",
                directed=True,
                target_type="CourseOfAction",
            ),
            contract_edge(
                "O2I Principle",
                "guides",
                "O2I Driver",
                source_type="Principle",
                target_type="Driver",
            ),
            contract_edge(
                "O2I Principle",
                "guides",
                "O2I Objective",
                source_type="Principle",
                target_type="Goal",
            ),
            contract_edge(
                "O2I Principle",
                "guides",
                "O2I Principle",
                source_type="Principle",
                target_type="Principle",
            ),
        }
    ),
    "O2I Syntax - Contextualization": frozenset(
        {
            contract_edge(
                "<Name> :: O2I Mission",
                "contextualizes",
                "<Name> :: O2I Driver",
                relation_type="CompositionRelationship",
                target_type="Driver",
            ),
            contract_edge(
                "<Name> :: O2I Strategy",
                "contextualizes",
                "<Name> :: O2I Performance Dimension",
                relation_type="CompositionRelationship",
            ),
        }
    ),
    "O2I Syntax - Collective Strategy Realization": frozenset(
        {
            contract_edge(
                "<Contributor Strategy 1> :: O2I Strategy",
                "realizes",
                "<Name> :: O2I Collective Strategy Realization",
                relation_type="RealizationRelationship",
                target_type="Junction",
            ),
            contract_edge(
                "<Contributor Strategy 2> :: O2I Strategy",
                "realizes",
                "<Name> :: O2I Collective Strategy Realization",
                relation_type="RealizationRelationship",
                target_type="Junction",
            ),
            contract_edge(
                "<Name> :: O2I Collective Strategy Realization",
                "realizes",
                "<Target Strategy> :: O2I Strategy",
                source_type="Junction",
                relation_type="RealizationRelationship",
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

    for _, element_id, context in sorted(
        visible_occurrences,
        key=lambda occurrence: (
            occurrence[2],
            elements.get(occurrence[1], ("", ""))[0],
            elements.get(occurrence[1], ("", ""))[1],
            occurrence[0],
        ),
    ):
        name, element_type = elements[element_id]
        lines.append(f"- [{context}] `{name}` ({element_type})")

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
    object_targets, object_parents, connections, notes, documentation = (
        collect_view(view)
    )
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
    """Validate repository View contracts without validating O2I semantics."""
    elements, relations = collect_model(root)
    errors: list[str] = []
    expected_views = {view_name for view_name, _ in PRESETS.values()}
    actual_views = {
        element.get("name", "")
        for element in root.iter("element")
        if xtype(element) == "ArchimateDiagramModel"
    }

    for view_name in sorted(expected_views - actual_views):
        errors.append(f"missing required view: {view_name}")
    for view_name in sorted(actual_views - expected_views):
        errors.append(f"unregistered repository view: {view_name}")

    for view_name, _ in PRESETS.values():
        try:
            view = find_view(root, view_name)
        except SystemExit:
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

        required_nodes = REQUIRED_NODES_BY_VIEW.get(view_name, frozenset())
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
