#!/usr/bin/env python3
"""Audit repository-wide ArchiMate model hygiene."""

from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path
import sys
import xml.etree.ElementTree as ET


XSI_TYPE = "{http://www.w3.org/2001/XMLSchema-instance}type"
ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MODEL = ROOT / "mdl" / "o2i.archimate"
REFERENCE_ATTRIBUTES = frozenset(
    {
        "archimateElement",
        "archimateRelationship",
        "source",
        "target",
        "targetConnections",
    }
)


def xtype(element: ET.Element) -> str:
    """Return an Archi model type without its namespace prefix."""
    return element.get(XSI_TYPE, "").removeprefix("archimate:")


def model_definitions(root: ET.Element) -> dict[str, ET.Element]:
    """Return definitions stored directly in model folders."""
    return {
        identifier: element
        for folder in root.iter("folder")
        for element in folder.findall("element")
        if (identifier := element.get("id"))
    }


def audit_model(root: ET.Element) -> list[str]:
    """Return deterministic repository-hygiene defects."""
    errors: list[str] = []
    identifiers = [
        identifier
        for element in root.iter()
        if (identifier := element.get("id"))
    ]
    identifier_counts = Counter(identifiers)
    known_identifiers = set(identifier_counts)

    for identifier, count in sorted(identifier_counts.items()):
        if count > 1:
            errors.append(
                f"duplicate model id: {identifier} ({count} occurrences)"
            )

    for element in root.iter():
        for attribute, raw_value in element.attrib.items():
            if attribute not in REFERENCE_ATTRIBUTES:
                continue
            for reference in raw_value.split():
                if reference.startswith("id-") and reference not in known_identifiers:
                    errors.append(
                        f"unresolved {attribute} reference: {reference}"
                    )

    definitions = model_definitions(root)
    relationships = {
        identifier: element
        for identifier, element in definitions.items()
        if xtype(element).endswith("Relationship")
    }
    views = {
        identifier: element
        for identifier, element in definitions.items()
        if xtype(element) == "ArchimateDiagramModel"
    }
    nodes = {
        identifier: element
        for identifier, element in definitions.items()
        if identifier not in relationships and identifier not in views
    }

    displayed_nodes = Counter(
        reference
        for view in views.values()
        for child in view.iter("child")
        if (reference := child.get("archimateElement"))
    )
    relation_endpoints = Counter(
        reference
        for relationship in relationships.values()
        for reference in (
            relationship.get("source"),
            relationship.get("target"),
        )
        if reference
    )
    displayed_relationships = Counter(
        reference
        for view in views.values()
        for connection in view.iter("sourceConnection")
        if (reference := connection.get("archimateRelationship"))
    )

    for identifier, element in sorted(nodes.items()):
        if not displayed_nodes[identifier] and not relation_endpoints[identifier]:
            errors.append(
                "unused model element: "
                f"{element.get('name', '')} ({xtype(element)}, {identifier})"
            )

    for identifier, relationship in sorted(relationships.items()):
        if not displayed_relationships[identifier]:
            errors.append(
                "relationship is not displayed in any View: "
                f"{relationship.get('name', '')} "
                f"({xtype(relationship)}, {identifier})"
            )

    for view in views.values():
        name = view.get("name", "")
        if not any(child.get("archimateElement") for child in view.iter("child")):
            errors.append(f"empty repository View: {name}")
        if not (view.findtext("documentation") or "").strip():
            errors.append(f"undocumented repository View: {name}")

    for folder in root.iter("folder"):
        if folder.get("type"):
            continue
        if not any(child.tag in {"folder", "element"} for child in folder):
            errors.append(
                "empty custom folder: "
                f"{folder.get('name', '')} ({folder.get('id', '')})"
            )

    return errors


def parse_args(arguments: list[str] | None = None) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Audit repository-wide ArchiMate model hygiene."
    )
    parser.add_argument(
        "--model",
        type=Path,
        default=DEFAULT_MODEL,
        help="Path to the ArchiMate model.",
    )
    return parser.parse_args(arguments)


def main(arguments: list[str] | None = None) -> int:
    """Run the model hygiene audit."""
    args = parse_args(arguments)
    try:
        root = ET.parse(args.model).getroot()
    except (OSError, ET.ParseError) as error:
        print(f"[o2i|error] Cannot read ArchiMate model: {error}", file=sys.stderr)
        return 2

    errors = audit_model(root)
    if errors:
        for error in errors:
            print(f"[o2i|error] {error}", file=sys.stderr)
        return 1

    print("[o2i|info] ArchiMate model hygiene is valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
