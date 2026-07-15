"""Negative contract tests for the O2I ArchiMate model validator."""

from __future__ import annotations

import copy
import importlib.util
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "utl" / "extract-archimate-view.py"
MODEL = ROOT / "mdl" / "o2i.archimate"

SPEC = importlib.util.spec_from_file_location("extract_archimate_view", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load {SCRIPT}")
EXTRACTOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(EXTRACTOR)


class RelationshipEndpointContractTest(unittest.TestCase):
    """A diagram connection must preserve its Relationship endpoints."""

    def setUp(self) -> None:
        self.root = ET.parse(MODEL).getroot()

    def test_current_model_is_valid(self) -> None:
        self.assertEqual([], EXTRACTOR.validate_model(self.root))

    def test_relationship_source_mismatch_is_rejected(self) -> None:
        root, relationship, source, target = self._substantiates_fixture()
        relationship.set("source", target)

        errors = EXTRACTOR.validate_model(root)

        self.assertTrue(
            any("connection source" in error for error in errors),
            errors,
        )
        self.assertNotEqual(source, relationship.get("source"))

    def test_relationship_target_mismatch_is_rejected(self) -> None:
        root, relationship, source, target = self._substantiates_fixture()
        relationship.set("target", source)

        errors = EXTRACTOR.validate_model(root)

        self.assertTrue(
            any("connection target" in error for error in errors),
            errors,
        )
        self.assertNotEqual(target, relationship.get("target"))

    def test_missing_relationship_reference_is_rejected(self) -> None:
        self._assert_connection_reference_error(
            "archimateRelationship",
            None,
            "no relationship reference",
        )

    def test_unresolved_relationship_reference_is_rejected(self) -> None:
        self._assert_connection_reference_error(
            "archimateRelationship",
            "unknown-relationship",
            "unresolved relationship reference",
        )

    def test_missing_source_reference_is_rejected(self) -> None:
        self._assert_connection_reference_error(
            "source",
            None,
            "no source reference",
        )

    def test_unresolved_source_reference_is_rejected(self) -> None:
        self._assert_connection_reference_error(
            "source",
            "unknown-source",
            "unresolved source reference",
        )

    def test_missing_target_reference_is_rejected(self) -> None:
        self._assert_connection_reference_error(
            "target",
            None,
            "no target reference",
        )

    def test_unresolved_target_reference_is_rejected(self) -> None:
        self._assert_connection_reference_error(
            "target",
            "unknown-target",
            "unresolved target reference",
        )

    def _substantiates_fixture(self):
        root = copy.deepcopy(self.root)
        elements, relations = EXTRACTOR.collect_model(root)
        view = EXTRACTOR.find_view(root, "O2I Primitives")
        object_targets, _, connections, _, _ = EXTRACTOR.collect_view(view)

        for source_object, relation_id, target_object in connections:
            relation_name, _, _, _, _ = relations[relation_id]
            if relation_name == "substantiates":
                source = object_targets[source_object]
                target = object_targets[target_object]
                relationship = next(
                    element
                    for element in root.iter("element")
                    if element.get("id") == relation_id
                )
                self.assertIn(source, elements)
                self.assertIn(target, elements)
                self.assertNotEqual(source, target)
                return root, relationship, source, target

        self.fail("The O2I Primitives view has no substantiates relationship")

    def _assert_connection_reference_error(
        self,
        attribute: str,
        value: str | None,
        expected: str,
    ) -> None:
        root, connection = self._substantiates_connection_fixture()
        if value is None:
            connection.attrib.pop(attribute)
        else:
            connection.set(attribute, value)

        errors = EXTRACTOR.validate_model(root)

        self.assertTrue(any(expected in error for error in errors), errors)

    def _substantiates_connection_fixture(self):
        root = copy.deepcopy(self.root)
        _, relations = EXTRACTOR.collect_model(root)
        view = EXTRACTOR.find_view(root, "O2I Primitives")

        for connection in view.iter("sourceConnection"):
            relation_id = connection.get("archimateRelationship")
            if relation_id is None:
                continue
            relation_name, _, _, _, _ = relations[relation_id]
            if relation_name == "substantiates":
                return root, connection

        self.fail("The O2I Primitives view has no substantiates connection")


if __name__ == "__main__":
    unittest.main()
