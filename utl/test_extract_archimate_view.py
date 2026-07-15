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

    def _substantiates_fixture(self):
        root = copy.deepcopy(self.root)
        elements, relations = EXTRACTOR.collect_model(root)
        view = EXTRACTOR.find_view(root, "O2I Primitives")
        _, _, connections, _, _ = EXTRACTOR.collect_view(view)

        for source, relation_id, target in connections:
            relation_name, _, _, _, _ = relations[relation_id]
            if relation_name == "substantiates":
                relationship = next(
                    element
                    for element in root.iter("element")
                    if element.get("id") == relation_id
                )
                self.assertIn(source, elements)
                self.assertIn(target, elements)
                self.assertNotEqual(source, target)
                return root, relationship, source, target

        self.fail("O2I Primitives has no substantiates relationship")


if __name__ == "__main__":
    unittest.main()
