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
    """Validate view contracts and model-wide O2I syntax structure."""

    def setUp(self) -> None:
        self.root = ET.parse(MODEL).getroot()

    def test_repository_model_is_valid(self) -> None:
        self.assertEqual([], EXTRACTOR.validate_model(self.root))

    def test_required_o2i_metadata_is_enforced(self) -> None:
        for identity, required in EXTRACTOR.REQUIRED_O2I_ELEMENT_METADATA.items():
            for key, expected in required.items():
                with self.subTest(element=identity, property=key):
                    root = copy.deepcopy(self.root)
                    element = self._model_element(root, *identity)
                    prop = next(
                        candidate
                        for candidate in element.findall("property")
                        if candidate.get("key") == key
                    )
                    element.remove(prop)

                    errors = EXTRACTOR.validate_model(root)

                    self.assertIn(
                        f"{EXTRACTOR.element_label(element)} must declare "
                        f"exactly one {key}={expected!r}; found []",
                        errors,
                    )

    def test_syntax_exemplar_metadata_pairs_are_exact(self) -> None:
        root = copy.deepcopy(self.root)
        driver = self._model_element(root, "Driver @ Mission", "Driver")
        primitive_type = next(
            prop
            for prop in driver.findall("property")
            if prop.get("key") == EXTRACTOR.O2I_TYPE_PROPERTY
        )
        primitive_type.set("value", "KPI")

        errors = EXTRACTOR.validate_model(root)

        self.assertIn(
            f"{EXTRACTOR.element_label(driver)} must declare exactly one "
            "o2i.type='Driver'; found ['KPI']",
            errors,
        )

    def test_forbidden_owner_and_semantic_metadata_is_rejected(self) -> None:
        for key in EXTRACTOR.FORBIDDEN_O2I_METADATA_PROPERTIES:
            with self.subTest(property=key):
                root = copy.deepcopy(self.root)
                driver = self._model_element(root, "Driver @ Mission", "Driver")
                ET.SubElement(
                    driver,
                    "property",
                    {"key": key, "value": "forbidden"},
                )

                errors = EXTRACTOR.validate_model(root)

                self.assertIn(
                    f"{EXTRACTOR.element_label(driver)} must not declare "
                    f"forbidden O2I metadata property {key!r}",
                    errors,
                )

    def test_kind_rejects_a_type_from_another_closed_universe(self) -> None:
        root = copy.deepcopy(self.root)
        anchor = self._model_element(root, "Business Capability", "Grouping")
        anchor_type = next(
            prop
            for prop in anchor.findall("property")
            if prop.get("key") == EXTRACTOR.O2I_TYPE_PROPERTY
        )
        anchor_type.set("value", "Driver")

        errors = EXTRACTOR.validate_model(root)

        self.assertIn(
            f"{EXTRACTOR.element_label(anchor)} has invalid o2i.type value "
            "'Driver' for o2i.kind='SituationAnchor'",
            errors,
        )

    def test_performance_dimension_is_a_structuring_type_not_a_kind(self) -> None:
        root = copy.deepcopy(self.root)
        dimension = self._model_element(
            root,
            "Performance Dimension @ Strategy",
            "Grouping",
        )
        kind = next(
            prop
            for prop in dimension.findall("property")
            if prop.get("key") == EXTRACTOR.O2I_KIND_PROPERTY
        )
        kind.set("value", "PerformanceDimension")

        errors = EXTRACTOR.validate_model(root)

        self.assertIn(
            f"{EXTRACTOR.element_label(dimension)} has invalid o2i.kind "
            "value 'PerformanceDimension'",
            errors,
        )

    def test_hidden_duplicate_ownership_is_rejected_model_wide(self) -> None:
        root = copy.deepcopy(self.root)
        owner = self._append_context_element(
            root,
            "hidden-mission-context",
            "Hidden Mission Context",
            "Mission",
        )
        target = self._model_element(root, "Driver @ Mission", "Driver")
        self._append_ownership_relationship(
            root,
            "hidden-duplicate-owner",
            owner,
            target,
        )

        errors = EXTRACTOR.validate_model(root)

        self.assertIn(
            f"{EXTRACTOR.element_label(target)} has 2 model-wide "
            "CompositionRelationship[contains] owners; expected exactly one",
            errors,
        )

    def test_hidden_anchor_ownership_is_rejected_model_wide(self) -> None:
        root = copy.deepcopy(self.root)
        owner = self._model_element(root, "O2I Context (Strategy)", "Grouping")
        anchor = self._model_element(root, "Business Capability", "Grouping")
        relation_id = "hidden-anchor-owner"
        self._append_ownership_relationship(root, relation_id, owner, anchor)

        errors = EXTRACTOR.validate_model(root)

        self.assertIn(
            f"{EXTRACTOR.element_label(anchor)} is ownerless but has "
            "model-wide CompositionRelationship[contains] owners "
            f"[{relation_id!r}]",
            errors,
        )
        self.assertIn(
            f"ownership relation {relation_id!r} must end at an element with "
            "o2i.kind='Primitive' or o2i.kind='Structuring'",
            errors,
        )

    def test_hidden_context_ownership_is_rejected_model_wide(self) -> None:
        root = copy.deepcopy(self.root)
        owner = self._model_element(root, "O2I Context (Mission)", "Grouping")
        target = self._model_element(root, "O2I Context (Strategy)", "Grouping")
        relation_id = "hidden-context-owner"
        self._append_ownership_relationship(root, relation_id, owner, target)

        errors = EXTRACTOR.validate_model(root)

        self.assertIn(
            f"{EXTRACTOR.element_label(target)} is ownerless but has "
            "model-wide CompositionRelationship[contains] owners "
            f"[{relation_id!r}]",
            errors,
        )

    def test_missing_primitive_ownership_is_rejected_model_wide(self) -> None:
        root = copy.deepcopy(self.root)
        primitive = self._append_o2i_element(
            root,
            "ownerless-primitive",
            "Ownerless Objective",
            "Primitive",
            "Objective",
        )

        errors = EXTRACTOR.validate_model(root)

        self.assertIn(
            f"{EXTRACTOR.element_label(primitive)} has 0 model-wide "
            "CompositionRelationship[contains] owners; expected exactly one",
            errors,
        )

    def test_missing_structuring_ownership_is_rejected_model_wide(self) -> None:
        root = copy.deepcopy(self.root)
        structuring = self._append_o2i_element(
            root,
            "ownerless-performance-dimension",
            "Ownerless PerformanceDimension",
            "Structuring",
            "PerformanceDimension",
        )

        errors = EXTRACTOR.validate_model(root)

        self.assertIn(
            f"{EXTRACTOR.element_label(structuring)} has 0 model-wide "
            "CompositionRelationship[contains] owners; expected exactly one",
            errors,
        )

    def test_performance_dimension_membership_requires_same_owner_id(self) -> None:
        root = copy.deepcopy(self.root)
        foreign_owner = self._append_context_element(
            root,
            "foreign-strategy",
            "Foreign Strategy Context",
            "Strategy",
        )
        member = self._append_o2i_element(
            root,
            "foreign-key-result",
            "Foreign Key Result",
            "Primitive",
            "KeyResult",
        )
        self._append_ownership_relationship(
            root,
            "foreign-key-result-owner",
            foreign_owner,
            member,
        )
        dimension = self._model_element(
            root,
            "Performance Dimension @ Strategy",
            "Grouping",
        )
        relation_id = "cross-owner-membership"
        self._append_membership_relationship(
            root,
            relation_id,
            dimension,
            member,
        )

        errors = EXTRACTOR.validate_model(root)

        self.assertIn(
            f"PerformanceDimension membership {relation_id!r} crosses owning "
            "Context element IDs: "
            "'id-9eb65bc4e62e42e9ad5375725305340c' != "
            "'foreign-strategy'",
            errors,
        )

    def test_generic_structure_does_not_replicate_registry_admissibility(
        self,
    ) -> None:
        root = copy.deepcopy(self.root)
        mission = self._model_element(root, "O2I Context (Mission)", "Grouping")
        kpi = self._append_o2i_element(
            root,
            "mission-kpi",
            "KPI owned by Mission",
            "Primitive",
            "KPI",
        )
        dimension = self._append_o2i_element(
            root,
            "mission-performance-dimension",
            "PerformanceDimension owned by Mission",
            "Structuring",
            "PerformanceDimension",
        )
        self._append_ownership_relationship(
            root,
            "mission-kpi-owner",
            mission,
            kpi,
        )
        self._append_ownership_relationship(
            root,
            "mission-dimension-owner",
            mission,
            dimension,
        )

        self.assertEqual([], EXTRACTOR.validate_model(root))

    def test_syntax_ownership_exemplar_nodes_are_required(self) -> None:
        required = (
            ("Driver @ Mission", "Driver"),
            ("O2I Context (Mission)", "Grouping"),
            ("O2I Context (Strategy)", "Grouping"),
            ("Performance Dimension @ Strategy", "Grouping"),
        )

        for expected in required:
            with self.subTest(node=expected):
                root = copy.deepcopy(self.root)
                self._remove_syntax_node(root, expected)

                errors = EXTRACTOR.validate_model(root)

                self.assertIn(
                    f"O2I Syntax is missing node {expected[0]} ({expected[1]})",
                    errors,
                )

    def test_syntax_ownership_edges_require_composition(self) -> None:
        ownership_edges = (
            ("O2I Context (Mission)", "Driver @ Mission"),
            ("O2I Context (Strategy)", "Performance Dimension @ Strategy"),
        )

        for source, target in ownership_edges:
            with self.subTest(source=source, target=target):
                root = copy.deepcopy(self.root)
                relationship = self._ownership_relationship(root, source, target)
                relationship.set(
                    EXTRACTOR.XSI_TYPE,
                    "archimate:AssignmentRelationship",
                )

                errors = EXTRACTOR.validate_model(root)

                self.assertTrue(
                    any(
                        "missing contracted relation" in error
                        and source in error
                        and target in error
                        and "CompositionRelationship" in error
                        for error in errors
                    ),
                    errors,
                )

    def test_syntax_placement_only_documentation_is_rejected(self) -> None:
        root = copy.deepcopy(self.root)
        view = EXTRACTOR.find_view(root, "O2I Syntax")
        documentation = view.find("documentation")
        self.assertIsNotNone(documentation)
        documentation.text = (
            "Every O2I Context is represented by an ArchiMate Grouping. "
            "An O2I Primitive is contextualized by placement inside its "
            "owning Context Grouping."
        )

        errors = EXTRACTOR.validate_model(root)

        self.assertTrue(
            any(
                "documentation is missing: Defines the concrete ArchiMate "
                "realization" in error
                for error in errors
            ),
            errors,
        )
        self.assertTrue(
            any(
                "documentation is missing: Visual nesting presents but never "
                "replaces persisted ownership." in error
                for error in errors
            ),
            errors,
        )

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

    def _remove_syntax_node(
        self,
        root: ET.Element,
        expected: tuple[str, str],
    ) -> None:
        elements, _ = EXTRACTOR.collect_model(root)
        view = EXTRACTOR.find_view(root, "O2I Syntax")

        for parent in view.iter():
            for child in list(parent):
                element_id = child.get("archimateElement")
                if element_id is not None and elements.get(element_id) == expected:
                    parent.remove(child)
                    return

        self.fail(f"The O2I Syntax view has no {expected[0]} ({expected[1]})")

    def _model_element(
        self,
        root: ET.Element,
        name: str,
        element_type: str,
    ) -> ET.Element:
        matches = [
            element
            for element in EXTRACTOR.model_elements(root).values()
            if element.get("name", "") == name
            and EXTRACTOR.xtype(element) == element_type
        ]
        self.assertEqual(
            1,
            len(matches),
            f"expected one {name} ({element_type})",
        )
        return matches[0]

    def _append_ownership_relationship(
        self,
        root: ET.Element,
        relation_id: str,
        source: ET.Element,
        target: ET.Element,
    ) -> None:
        relations_folder = next(
            folder
            for folder in root.iter("folder")
            if folder.get("type") == "relations"
        )
        ET.SubElement(
            relations_folder,
            "element",
            {
                EXTRACTOR.XSI_TYPE: "archimate:CompositionRelationship",
                "name": "contains",
                "id": relation_id,
                "source": source.get("id", ""),
                "target": target.get("id", ""),
            },
        )

    def _append_membership_relationship(
        self,
        root: ET.Element,
        relation_id: str,
        source: ET.Element,
        target: ET.Element,
    ) -> None:
        relations_folder = next(
            folder
            for folder in root.iter("folder")
            if folder.get("type") == "relations"
        )
        ET.SubElement(
            relations_folder,
            "element",
            {
                EXTRACTOR.XSI_TYPE: "archimate:AggregationRelationship",
                "name": "contains",
                "id": relation_id,
                "source": source.get("id", ""),
                "target": target.get("id", ""),
            },
        )

    def _append_context_element(
        self,
        root: ET.Element,
        element_id: str,
        name: str,
        context: str,
    ) -> ET.Element:
        return self._append_o2i_element(
            root,
            element_id,
            name,
            "Context",
            context,
        )

    def _append_o2i_element(
        self,
        root: ET.Element,
        element_id: str,
        name: str,
        kind: str,
        element_type: str,
    ) -> ET.Element:
        syntax_folder = next(
            folder
            for folder in root.iter("folder")
            if folder.get("name") == "Syntax"
            and folder.get("type") is None
        )
        element = ET.SubElement(
            syntax_folder,
            "element",
            {
                EXTRACTOR.XSI_TYPE: "archimate:Grouping",
                "name": name,
                "id": element_id,
            },
        )
        ET.SubElement(
            element,
            "property",
            {"key": EXTRACTOR.O2I_KIND_PROPERTY, "value": kind},
        )
        ET.SubElement(
            element,
            "property",
            {"key": EXTRACTOR.O2I_TYPE_PROPERTY, "value": element_type},
        )
        return element

    def _ownership_relationship(
        self,
        root: ET.Element,
        source_name: str,
        target_name: str,
    ) -> ET.Element:
        elements, _ = EXTRACTOR.collect_model(root)

        for element in root.iter("element"):
            source = element.get("source")
            target = element.get("target")
            if source is None or target is None:
                continue
            if (
                elements.get(source, (None, None))[0] == source_name
                and elements.get(target, (None, None))[0] == target_name
                and element.get("name") == "contains"
            ):
                return element

        self.fail(
            "The O2I Syntax view has no ownership relationship from "
            f"{source_name} to {target_name}"
        )

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
