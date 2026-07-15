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
    "situation": ("O2I Situation", Path("mdl/o2i-situation.md")),
    "situation-anchoring": (
        "O2I Situation Anchoring",
        Path("mdl/o2i-situation-anchoring.md"),
    ),
    "orientation": ("O2I Orientierung", Path("mdl/o2i-orientation.md")),
    "context": ("O2I Context", Path("mdl/o2i-context.md")),
    "primitives": ("O2I Primitives", Path("mdl/o2i-primitives.md")),
    "syntax": ("O2I Syntax", Path("mdl/o2i-syntax.md")),
    "layered-cake": ("O2I Layered Cake", Path("mdl/o2i-layered-cake.md")),
}

REQUIRED_SYNTAX_NODES = {
    ("Assessment", "Assessment"),
    ("Course of Action", "CourseOfAction"),
    ("Driver", "Driver"),
    ("Goal", "Goal"),
    ("Outcome", "Outcome"),
    ("Performance Dimension", "Grouping"),
    ("Principle", "Principle"),
}

REQUIRED_SYNTAX_DOCUMENTATION = (
    "Every O2I Context is represented by an ArchiMate Grouping.",
    "Primitive @ Context is the textual notation of this containment.",
    "O2I BusinessCapability -> ArchiMate Capability",
    "O2I BusinessProcess -> ArchiMate Process",
    "O2I BusinessObject -> ArchiMate Business Object",
    "O2I BusinessRole -> ArchiMate Role",
    "O2I ValueStream -> ArchiMate Value Stream",
    "O2I RegulatoryConstraint -> ArchiMate Requirement",
)


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
    "O2I Context": frozenset(
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
    "O2I Primitives": frozenset(
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
    "O2I Situation": frozenset(
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
    "O2I Syntax": frozenset(
        {
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

    connections: list[tuple[str, str, str]] = []
    for connection in view.iter("sourceConnection"):
        relation_id = connection.get("archimateRelationship")
        source_object = connection.get("source")
        target_object = connection.get("target")
        source = object_targets.get(source_object or "")
        target = object_targets.get(target_object or "")
        if relation_id and source and target:
            connections.append((source, relation_id, target))

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
    connections: list[tuple[str, str, str]],
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
    for source, relation_id, target in connections:
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

    model_versions = [
        prop.get("value", "")
        for prop in root.iter("property")
        if prop.get("key") == "version"
    ]
    if model_versions != ["0.2"]:
        errors.append(
            "expected exactly one canonical model version 0.2; found: "
            + repr(model_versions)
        )

    for view_name, _ in PRESETS.values():
        try:
            view = find_view(root, view_name)
        except SystemExit:
            errors.append(f"missing required view: {view_name}")
            continue

        object_targets, _, connections, notes, documentation = collect_view(view)

        relation_signatures = []
        for source, relation_id, target in connections:
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

        if view_name == "O2I Syntax":
            visible_nodes = {
                elements[element_id]
                for element_id in object_targets.values()
                if element_id in elements
                and elements[element_id][1] != "Meaning"
            }
            for required in sorted(REQUIRED_SYNTAX_NODES):
                if required not in visible_nodes:
                    errors.append(
                        "O2I Syntax is missing node "
                        f"{required[0]} ({required[1]})"
                    )

            for fragment in REQUIRED_SYNTAX_DOCUMENTATION:
                if fragment not in documentation:
                    errors.append(
                        "O2I Syntax documentation is missing: " + fragment
                    )

            context_note = (
                "Every O2I Context is represented by an ArchiMate Grouping."
            )
            if not any(context_note in note for note in notes):
                errors.append("O2I Syntax is missing its visible Context note")

        for _, relation_id, _ in connections:
            relation = relations.get(relation_id)
            if relation is None:
                errors.append(
                    f"{view_name} uses unknown relation: {relation_id}"
                )
                continue
            relation_name, relation_type, _, _, directed = relation
            if relation_type == "AssociationRelationship" and not directed:
                errors.append(
                    f"{view_name} uses undirected association: {relation_name}"
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
