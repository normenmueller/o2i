"""Repository-hygiene tests for the O2I ArchiMate model."""

from __future__ import annotations

import copy
import importlib.util
from pathlib import Path
import sys
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "utl" / "audit-archimate-model.py"
MODEL = ROOT / "mdl" / "o2i.archimate"
SPEC = importlib.util.spec_from_file_location("audit_archimate_model", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load {SCRIPT}")
AUDIT = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = AUDIT
SPEC.loader.exec_module(AUDIT)


class ArchiMateModelHygieneTest(unittest.TestCase):
    """Check whole-model repository hygiene without O2I semantics."""

    def setUp(self) -> None:
        self.root = ET.parse(MODEL).getroot()

    def test_repository_model_is_clean(self) -> None:
        self.assertEqual([], AUDIT.audit_model(self.root))

    def test_duplicate_identifier_is_reported(self) -> None:
        root = copy.deepcopy(self.root)
        element = next(root.iter("element"))
        duplicate = copy.deepcopy(element)
        self._other_folder(root).append(duplicate)

        errors = AUDIT.audit_model(root)

        self.assertTrue(any("duplicate model id:" in error for error in errors))

    def test_unresolved_reference_is_reported(self) -> None:
        root = copy.deepcopy(self.root)
        relationship = next(
            element
            for element in root.iter("element")
            if AUDIT.xtype(element).endswith("Relationship")
        )
        relationship.set("target", "id-does-not-exist")

        errors = AUDIT.audit_model(root)

        self.assertIn(
            "unresolved target reference: id-does-not-exist",
            errors,
        )

    def test_unused_element_is_reported(self) -> None:
        root = copy.deepcopy(self.root)
        ET.SubElement(
            self._other_folder(root),
            "element",
            {
                AUDIT.XSI_TYPE: "archimate:Meaning",
                "id": "id-unused",
                "name": "Unused",
            },
        )

        errors = AUDIT.audit_model(root)

        self.assertTrue(any("unused model element:" in error for error in errors))

    def test_undisplayed_relationship_is_reported(self) -> None:
        root = copy.deepcopy(self.root)
        definitions = AUDIT.model_definitions(root)
        endpoints = [
            identifier
            for identifier, element in definitions.items()
            if AUDIT.xtype(element) == "Grouping"
        ][:2]
        ET.SubElement(
            self._relations_folder(root),
            "element",
            {
                AUDIT.XSI_TYPE: "archimate:AssociationRelationship",
                "id": "id-undisplayed",
                "source": endpoints[0],
                "target": endpoints[1],
            },
        )

        errors = AUDIT.audit_model(root)

        self.assertTrue(
            any(
                "relationship is not displayed in any View:" in error
                for error in errors
            )
        )

    def test_undocumented_view_is_reported(self) -> None:
        root = copy.deepcopy(self.root)
        view = next(
            element
            for element in root.iter("element")
            if AUDIT.xtype(element) == "ArchimateDiagramModel"
        )
        documentation = view.find("documentation")
        self.assertIsNotNone(documentation)
        view.remove(documentation)

        errors = AUDIT.audit_model(root)

        self.assertIn(
            f"undocumented repository View: {view.get('name', '')}",
            errors,
        )

    def test_empty_custom_folder_is_reported(self) -> None:
        root = copy.deepcopy(self.root)
        ET.SubElement(
            self._other_folder(root),
            "folder",
            {"id": "id-empty-folder", "name": "Empty"},
        )

        errors = AUDIT.audit_model(root)

        self.assertIn(
            "empty custom folder: Empty (id-empty-folder)",
            errors,
        )

    @staticmethod
    def _other_folder(root: ET.Element) -> ET.Element:
        return next(
            folder
            for folder in root.findall("folder")
            if folder.get("type") == "other"
        )

    @staticmethod
    def _relations_folder(root: ET.Element) -> ET.Element:
        return next(
            folder
            for folder in root.findall("folder")
            if folder.get("type") == "relations"
        )


if __name__ == "__main__":
    unittest.main()
