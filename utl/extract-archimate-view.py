#!/usr/bin/env python3
"""Extract reviewable Markdown snapshots from O2I ArchiMate views."""

from __future__ import annotations

import argparse
import xml.etree.ElementTree as ET
from pathlib import Path


XSI_TYPE = "{http://www.w3.org/2001/XMLSchema-instance}type"

PRESETS = {
    "strategy-constituents": (
        "O2I Strategy Constituents",
        Path("mdl/o2i-strategy-constituents.md"),
    ),
    "situation": ("O2I Situation", Path("mdl/o2i-situation.md")),
    "orientation": ("O2I Orientierung", Path("mdl/o2i-orientation.md")),
    "context": ("O2I Context", Path("mdl/o2i-context.md")),
    "primitives": ("O2I Primitives", Path("mdl/o2i-primitives.md")),
    "layered-cake": ("O2I Layered Cake", Path("mdl/o2i-layered-cake.md")),
}


def xtype(element: ET.Element) -> str:
    return element.get(XSI_TYPE, "").split(":")[-1]


def collect_model(root: ET.Element):
    elements: dict[str, tuple[str, str]] = {}
    relations: dict[str, tuple[str, str, str | None, str | None]] = {}

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

    def walk(node: ET.Element, parent: str | None) -> None:
        node_id = node.get("id")
        if node_id:
            object_parents[node_id] = parent
            target = node.get("archimateElement")
            if target:
                object_targets[node_id] = target

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

    return object_targets, object_parents, connections


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
    relations: dict[str, tuple[str, str, str | None, str | None]],
    object_targets: dict[str, str],
    object_parents: dict[str, str | None],
    connections: list[tuple[str, str, str]],
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
        "## Nodes",
        "",
    ]

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
        relation_name, relation_type, _, _ = relations.get(
            relation_id,
            ("?", "?", None, None),
        )
        source_name = elements.get(source, ("?", ""))[0]
        target_name = elements.get(target, ("?", ""))[0]
        rendered_relations.append(
            (source_name, relation_name, target_name, relation_type)
        )

    for source_name, relation_name, target_name, relation_type in sorted(rendered_relations):
        lines.append(
            f"- `{source_name}` --{relation_name}--> `{target_name}` ({relation_type})"
        )

    return "\n".join(lines) + "\n"


def extract(
    root: ET.Element,
    source_path: Path,
    view_name: str,
    output_path: Path,
    include_meaning: bool,
) -> None:
    elements, relations = collect_model(root)
    view = find_view(root, view_name)
    object_targets, object_parents, connections = collect_view(view)
    content = render(
        elements,
        relations,
        object_targets,
        object_parents,
        connections,
        source_path,
        view_name,
        include_meaning,
    )
    output_path.write_text(content, encoding="utf-8")


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
    args = parser.parse_args()

    root = ET.parse(args.model).getroot()

    if args.preset == "all":
        for view_name, output_path in PRESETS.values():
            extract(root, args.model, view_name, output_path, args.include_meaning)
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

    extract(root, args.model, view_name, output_path, args.include_meaning)


if __name__ == "__main__":
    main()
