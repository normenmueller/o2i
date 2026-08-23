"""Repository-contract tests for the O2I ArchiMate snapshot extractor."""

from __future__ import annotations

import copy
from contextlib import redirect_stderr
import importlib.util
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "utl" / "model" / "extract-archimate-view.py"
MODEL = ROOT / "mdl" / "o2i.archimate"
sys.path.insert(0, str(ROOT / "utl" / "model"))
EXPECTED_PRESET_KEYS = {
    "strategy-constituents",
    "semantics-situation",
    "situation-anchoring",
    "orientation",
    "semantics-context",
    "semantics-primitives",
    "syntax-carriers",
    "syntax-relations",
    "syntax-contextualization",
    "syntax-collective-strategy-realization",
    "layered-cake",
}

SPEC = importlib.util.spec_from_file_location("extract_archimate_view", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load {SCRIPT}")
EXTRACTOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(EXTRACTOR)


class RepositoryViewContractTest(unittest.TestCase):
    """Validate deterministic repository Views without duplicating semantics."""

    def setUp(self) -> None:
        self.root = ET.parse(MODEL).getroot()

    def test_repository_model_satisfies_view_contracts(self) -> None:
        self.assertEqual([], EXTRACTOR.validate_model(self.root))

    def test_all_presets_are_named_and_target_distinct_snapshots(self) -> None:
        view_names = [view for view, _ in EXTRACTOR.PRESETS.values()]
        snapshots = [snapshot for _, snapshot in EXTRACTOR.PRESETS.values()]
        model_views = {
            element.get("name", "")
            for element in self.root.iter("element")
            if EXTRACTOR.xtype(element) == "ArchimateDiagramModel"
        }
        repository_snapshots = {
            path.relative_to(ROOT)
            for path in (ROOT / "mdl").glob("o2i-*.md")
        }

        self.assertEqual(EXPECTED_PRESET_KEYS, set(EXTRACTOR.PRESETS))
        self.assertEqual(len(view_names), len(set(view_names)))
        self.assertEqual(len(snapshots), len(set(snapshots)))
        self.assertEqual(model_views, set(view_names))
        self.assertEqual(
            repository_snapshots,
            set(snapshots),
        )

    def test_missing_required_view_is_reported(self) -> None:
        root = copy.deepcopy(self.root)
        view = EXTRACTOR.find_view(root, EXTRACTOR.SYNTAX_CARRIERS_VIEW)
        self._remove_element(root, view)

        errors = EXTRACTOR.validate_model(root)

        self.assertIn(
            "missing required view: O2I Syntax - Carriers",
            errors,
        )

    def test_duplicate_required_view_is_reported(self) -> None:
        root = copy.deepcopy(self.root)
        view = EXTRACTOR.find_view(root, EXTRACTOR.SYNTAX_RELATIONS_VIEW)
        duplicate = copy.deepcopy(view)
        duplicate.set("id", "duplicate-syntax-view")
        self._parent_of(root, view).append(duplicate)

        errors = EXTRACTOR.validate_model(root)

        self.assertIn(
            "duplicate repository view: O2I Syntax - Relations (2 occurrences)",
            errors,
        )

    def test_required_node_is_view_scoped(self) -> None:
        root = copy.deepcopy(self.root)
        self._remove_view_node(
            root,
            "O2I Syntax - Contextualization",
            "<Name> :: O2I Mission",
            "Grouping",
        )

        errors = EXTRACTOR.validate_model(root)

        self.assertIn(
            "O2I Syntax - Contextualization is missing node "
            "<Name> :: O2I Mission (Grouping)",
            errors,
        )

    def test_required_view_documentation_is_reported(self) -> None:
        root = copy.deepcopy(self.root)
        view = EXTRACTOR.find_view(root, "O2I Syntax - Contextualization")
        documentation = view.find("documentation")
        self.assertIsNotNone(documentation)
        documentation.text = "Defines an incomplete repository View."

        errors = EXTRACTOR.validate_model(root)

        self.assertTrue(
            any(
                "O2I Syntax - Contextualization documentation is missing:"
                in error
                for error in errors
            ),
            errors,
        )

    def test_layered_cake_cannot_claim_profile_instance_status(self) -> None:
        root = copy.deepcopy(self.root)
        view = EXTRACTOR.find_view(root, "O2I Layered Cake")
        documentation = view.find("documentation")
        self.assertIsNotNone(documentation)
        documentation.text = (
            "Illustrates a fictitious graph as an O2I profile instance."
        )

        errors = EXTRACTOR.validate_model(root)

        self.assertTrue(
            any(
                "O2I Layered Cake documentation does not match its canonical "
                "non-executable illustrative classification" in error
                for error in errors
            ),
            errors,
        )

    def test_layered_cake_rejects_a_contradictory_classification(self) -> None:
        root = copy.deepcopy(self.root)
        view = EXTRACTOR.find_view(root, "O2I Layered Cake")
        documentation = view.find("documentation")
        self.assertIsNotNone(documentation)
        documentation.text = (
            EXTRACTOR.EXPECTED_LAYERED_CAKE_DOCUMENTATION
            + "\n\nThis View is an executable O2I profile instance."
        )

        errors = EXTRACTOR.validate_model(root)

        self.assertIn(
            "O2I Layered Cake documentation does not match its canonical "
            "non-executable illustrative classification",
            errors,
        )

    def test_required_element_documentation_is_reported(self) -> None:
        root = copy.deepcopy(self.root)
        proposition = self._model_element(
            root,
            "<Name> :: O2I Collective Strategy Realization",
            "Junction",
        )
        documentation = proposition.find("documentation")
        self.assertIsNotNone(documentation)
        documentation.text = "Incomplete."

        errors = EXTRACTOR.validate_model(root)

        self.assertTrue(
            any(
                "O2I Syntax - Collective Strategy Realization element "
                "<Name> :: O2I Collective Strategy Realization (Junction) "
                "documentation is missing:"
                in error
                for error in errors
            ),
            errors,
        )

    def test_missing_collective_contributor_segment_is_reported(self) -> None:
        root = copy.deepcopy(self.root)
        view = EXTRACTOR.find_view(
            root,
            "O2I Syntax - Collective Strategy Realization",
        )
        connection = next(view.iter("sourceConnection"))
        self._remove_element(view, connection)

        errors = EXTRACTOR.validate_model(root)

        self.assertTrue(
            any(
                "O2I Syntax - Collective Strategy Realization requires at "
                "least two distinct contributors; found 1"
                in error
                for error in errors
            ),
            errors,
        )

    def test_duplicate_displayed_relation_is_reported(self) -> None:
        root = copy.deepcopy(self.root)
        view = EXTRACTOR.find_view(root, "O2I Semantics - Primitives")
        connection = self._connection(root, view, "substantiates")
        parent = self._parent_of(view, connection)
        parent.append(copy.deepcopy(connection))

        errors = EXTRACTOR.validate_model(root)

        self.assertTrue(
            any(
                "O2I Semantics - Primitives duplicates contracted relation:"
                in error
                for error in errors
            ),
            errors,
        )

    def test_relationship_type_drift_is_reported(self) -> None:
        root = copy.deepcopy(self.root)
        view = EXTRACTOR.find_view(root, "O2I Semantics - Primitives")
        connection = self._connection(root, view, "substantiates")
        relationship = self._relationship_for(root, connection)
        relationship.set(
            EXTRACTOR.XSI_TYPE,
            "archimate:AssociationRelationship",
        )
        relationship.set("directed", "true")

        errors = EXTRACTOR.validate_model(root)

        self.assertTrue(
            any(
                "O2I Semantics - Primitives is missing contracted relation:"
                in error
                for error in errors
            ),
            errors,
        )
        self.assertTrue(
            any(
                "O2I Semantics - Primitives has uncontracted relation:"
                in error
                for error in errors
            ),
            errors,
        )

    def test_syntax_carrier_mapping_drift_is_reported(self) -> None:
        root = copy.deepcopy(self.root)
        carrier = self._model_element(
            root,
            "ArchiMate Principle",
            "Principle",
        )
        carrier.set(EXTRACTOR.XSI_TYPE, "archimate:Goal")

        errors = EXTRACTOR.validate_model(root)

        self.assertTrue(
            any(
                "O2I Syntax - Carriers has contract-inconsistent mapping:"
                in error
                and "Principle (Grouping) --maps-to" in error
                for error in errors
            ),
            errors,
        )

    def test_syntax_relation_mapping_drift_is_reported(self) -> None:
        root = copy.deepcopy(self.root)
        view = EXTRACTOR.find_view(root, EXTRACTOR.SYNTAX_RELATIONS_VIEW)
        connection = self._mapping_connection(
            root,
            view,
            "ArchiMate Driver",
            EXTRACTOR.GENERIC_RELATION_NAME,
            "ArchiMate Goal",
        )
        relationship = self._relationship_for(root, connection)
        relationship.set(
            EXTRACTOR.XSI_TYPE,
            "archimate:RealizationRelationship",
        )

        errors = EXTRACTOR.validate_model(root)

        self.assertTrue(
            any(
                "O2I Syntax - Relations has contract-inconsistent mapping:"
                in error
                and "ArchiMate Driver" in error
                for error in errors
            ),
            errors,
        )

    def test_matching_syntax_connection_label_expression_is_accepted(
        self,
    ) -> None:
        for expression in ("maps-to", "  maps-to\n"):
            with self.subTest(expression=expression):
                root = copy.deepcopy(self.root)
                view = EXTRACTOR.find_view(
                    root,
                    EXTRACTOR.SYNTAX_CARRIERS_VIEW,
                )
                connection = self._mapping_connection(
                    root,
                    view,
                    "Principle",
                    EXTRACTOR.MAPS_TO,
                    "ArchiMate Principle",
                )
                self._set_connection_label_expression(connection, expression)

                self.assertEqual([], EXTRACTOR.validate_model(root))

    def test_divergent_syntax_connection_label_expression_is_reported(
        self,
    ) -> None:
        for expression in ("<O2I rel>", ""):
            with self.subTest(expression=expression):
                root = copy.deepcopy(self.root)
                view = EXTRACTOR.find_view(
                    root,
                    EXTRACTOR.SYNTAX_CARRIERS_VIEW,
                )
                connection = self._mapping_connection(
                    root,
                    view,
                    "Principle",
                    EXTRACTOR.MAPS_TO,
                    "ArchiMate Principle",
                )
                self._set_connection_label_expression(connection, expression)

                errors = EXTRACTOR.validate_model(root)

                relation_id = connection.get("archimateRelationship")
                expected = (
                    "O2I Syntax - Carriers connection "
                    f"{connection.get('id')!r} "
                    "from 'Principle' (Grouping) to "
                    "'ArchiMate Principle' (Principle) labelExpression "
                    f"normalizes to {expression!r}, but referenced "
                    f"relationship {relation_id!r} is named 'maps-to'; "
                    "remove labelExpression or set it to 'maps-to'"
                )

                self.assertEqual(
                    1,
                    sum(
                        "labelExpression normalizes to" in error
                        for error in errors
                    ),
                    errors,
                )
                self.assertIn(expected, errors)
                self.assertTrue(
                    any(
                        f"labelExpression normalizes to {expression!r}"
                        in error
                        and "is named 'maps-to'" in error
                        for error in errors
                    ),
                    errors,
                )

    def test_connection_label_contract_is_syntax_view_scoped(self) -> None:
        root = copy.deepcopy(self.root)
        view = EXTRACTOR.find_view(root, "O2I Semantics - Primitives")
        connection = self._connection(root, view, "substantiates")
        self._set_connection_label_expression(connection, "visual override")

        errors = EXTRACTOR.validate_model(root)

        self.assertFalse(
            any("labelExpression normalizes to" in error for error in errors),
            errors,
        )

    def test_unresolved_relationship_owns_connection_label_defect(self) -> None:
        root = copy.deepcopy(self.root)
        view = EXTRACTOR.find_view(
            root,
            EXTRACTOR.SYNTAX_CARRIERS_VIEW,
        )
        connection = self._mapping_connection(
            root,
            view,
            "Principle",
            EXTRACTOR.MAPS_TO,
            "ArchiMate Principle",
        )
        connection.set("archimateRelationship", "missing-relationship")
        self._set_connection_label_expression(connection, "visual override")

        errors = EXTRACTOR.validate_model(root)

        self.assertTrue(
            any(
                "unresolved relationship reference" in error
                for error in errors
            ),
            errors,
        )
        self.assertFalse(
            any("labelExpression normalizes to" in error for error in errors),
            errors,
        )

    def test_unresolved_endpoint_owns_connection_label_defect(self) -> None:
        root = copy.deepcopy(self.root)
        view = EXTRACTOR.find_view(
            root,
            EXTRACTOR.SYNTAX_CARRIERS_VIEW,
        )
        connection = self._mapping_connection(
            root,
            view,
            "Principle",
            EXTRACTOR.MAPS_TO,
            "ArchiMate Principle",
        )
        source_id = connection.get("source")
        source = next(
            child
            for child in view.iter("child")
            if child.get("id") == source_id
        )
        source.set("archimateElement", "missing-element")
        self._set_connection_label_expression(connection, "visual override")

        errors = EXTRACTOR.validate_model(root)

        self.assertTrue(
            any(
                "refers to unknown model element 'missing-element'" in error
                for error in errors
            ),
            errors,
        )
        self.assertFalse(
            any("labelExpression normalizes to" in error for error in errors),
            errors,
        )

    def test_unexpected_syntax_mapping_is_reported(self) -> None:
        root = copy.deepcopy(self.root)
        view = EXTRACTOR.find_view(root, EXTRACTOR.SYNTAX_CARRIERS_VIEW)
        connection = self._mapping_connection(
            root,
            view,
            "Principle",
            EXTRACTOR.MAPS_TO,
            "ArchiMate Principle",
        )
        relationship = self._relationship_for(root, connection)
        relationship.set("name", "unexpected-mapping")

        errors = EXTRACTOR.validate_model(root)

        self.assertTrue(
            any(
                "O2I Syntax - Carriers has contract-inconsistent mapping:"
                in error
                and "unexpected-mapping" in error
                for error in errors
            ),
            errors,
        )

    def test_missing_syntax_mapping_is_reported(self) -> None:
        root = copy.deepcopy(self.root)
        view = EXTRACTOR.find_view(root, EXTRACTOR.SYNTAX_CARRIERS_VIEW)
        connection = self._mapping_connection(
            root,
            view,
            "Principle",
            EXTRACTOR.MAPS_TO,
            "ArchiMate Principle",
        )
        self._remove_element(self._parent_of(view, connection), connection)

        errors = EXTRACTOR.validate_model(root)

        self.assertTrue(
            any(
                "O2I Syntax - Carriers is missing contracted mapping:" in error
                and "Principle (Grouping) --maps-to" in error
                for error in errors
            ),
            errors,
        )

    def test_relation_mapping_domain_is_a_total_closed_partition(self) -> None:
        context = EXTRACTOR.CONTEXT_RELATION_FAMILY
        content = EXTRACTOR.CONTENT_RELATION_FAMILY
        anchor = EXTRACTOR.ANCHOR_RELATION_FAMILY
        cases = {
            ("context", "context"): context,
            ("context", "primitive"): None,
            ("context", "structuring"): None,
            ("context", "situation-anchor"): anchor,
            ("primitive", "context"): None,
            ("primitive", "primitive"): content,
            ("primitive", "structuring"): content,
            ("primitive", "situation-anchor"): anchor,
            ("structuring", "context"): None,
            ("structuring", "primitive"): content,
            ("structuring", "structuring"): content,
            ("structuring", "situation-anchor"): anchor,
            ("situation-anchor", "context"): anchor,
            ("situation-anchor", "primitive"): anchor,
            ("situation-anchor", "structuring"): anchor,
            ("situation-anchor", "situation-anchor"): anchor,
        }

        self.assertEqual(
            len(EXTRACTOR.ENDPOINT_KIND_TO_O2I_KIND) ** 2,
            len(cases),
        )
        for (source_kind, target_kind), expected in cases.items():
            source = f"{source_kind}.source"
            target = f"{target_kind}.target"
            with self.subTest(source=source, target=target):
                if expected is None:
                    with self.assertRaisesRegex(
                        EXTRACTOR.ProfileContractError,
                        "unsupported endpoint-domain combination",
                    ):
                        EXTRACTOR.relation_mapping_domain(source, target)
                else:
                    self.assertEqual(
                        expected,
                        EXTRACTOR.relation_mapping_domain(source, target),
                    )

    def test_relation_mapping_domain_rejects_unknown_endpoint_kind(self) -> None:
        with self.assertRaisesRegex(
            EXTRACTOR.ProfileContractError,
            "unsupported endpoint-domain combination",
        ):
            EXTRACTOR.relation_mapping_domain(
                "unknown.value",
                "situation-anchor.business-object",
            )

    def test_each_syntax_relation_family_is_required(self) -> None:
        families = self._relation_mapping_families()
        generic = EXTRACTOR.GENERIC_RELATION_NAME
        self.assertEqual(
            {
                (
                    EXTRACTOR.CONTEXT_RELATION_FAMILY,
                    generic,
                    "AssociationRelationship",
                    True,
                ),
                (
                    EXTRACTOR.CONTEXT_RELATION_FAMILY,
                    generic,
                    "InfluenceRelationship",
                    False,
                ),
                (
                    EXTRACTOR.CONTEXT_RELATION_FAMILY,
                    generic,
                    "RealizationRelationship",
                    False,
                ),
                *{
                    (
                        EXTRACTOR.CONTENT_RELATION_FAMILY,
                        generic,
                        relationship,
                        directed,
                    )
                    for relationship, directed in (
                        ("AggregationRelationship", False),
                        ("AssociationRelationship", True),
                        ("InfluenceRelationship", False),
                        ("RealizationRelationship", False),
                    )
                },
                *{
                    (
                        EXTRACTOR.ANCHOR_RELATION_FAMILY,
                        label,
                        relationship,
                        directed,
                    )
                    for label, relationship, directed in (
                        ("anchors", "AssociationRelationship", True),
                        ("changes", "AssociationRelationship", True),
                        ("is-constituted-by", "AggregationRelationship", False),
                        ("measures", "AssociationRelationship", True),
                    )
                },
            },
            set(families),
        )

        for family, admissible in sorted(families.items()):
            with self.subTest(family=EXTRACTOR.format_mapping_family(family)):
                root = copy.deepcopy(self.root)
                view = EXTRACTOR.find_view(
                    root,
                    EXTRACTOR.SYNTAX_RELATIONS_VIEW,
                )
                _, connection = self._displayed_family_mapping(
                    root,
                    view,
                    admissible,
                )
                self._remove_element(view, connection)

                errors = EXTRACTOR.validate_model(root)

                self.assertIn(
                    f"{EXTRACTOR.SYNTAX_RELATIONS_VIEW} is missing "
                    "relation-mapping family: "
                    + EXTRACTOR.format_mapping_family(family),
                    errors,
                )

    def test_each_syntax_relation_family_rejects_duplicate_representation(
        self,
    ) -> None:
        families = self._relation_mapping_families()
        self.assertEqual(11, len(families))

        for family, admissible in sorted(families.items()):
            with self.subTest(family=EXTRACTOR.format_mapping_family(family)):
                root = copy.deepcopy(self.root)
                view = EXTRACTOR.find_view(
                    root,
                    EXTRACTOR.SYNTAX_RELATIONS_VIEW,
                )
                displayed, _ = self._displayed_family_mapping(
                    root,
                    view,
                    admissible,
                )
                elements, _ = EXTRACTOR.collect_model(root)
                object_targets, _, _, _, _, _ = EXTRACTOR.collect_view(view)
                visible_endpoints = {
                    elements[element_id]
                    for element_id in object_targets.values()
                    if element_id in elements
                }
                alternatives = {
                    mapping
                    for mapping in admissible - {displayed}
                    if (mapping[0], mapping[1]) in visible_endpoints
                    and (mapping[5], mapping[6]) in visible_endpoints
                }
                alternative = min(alternatives) if alternatives else displayed
                self._append_syntax_mapping(root, view, alternative)

                errors = EXTRACTOR.validate_model(root)

                if alternatives:
                    expected = (
                        f"{EXTRACTOR.SYNTAX_RELATIONS_VIEW} duplicates "
                        "relation-mapping family: "
                        + EXTRACTOR.format_mapping_family(family)
                    )
                else:
                    expected = (
                        f"{EXTRACTOR.SYNTAX_RELATIONS_VIEW} duplicates "
                        "contracted mapping: "
                        + EXTRACTOR.format_contract_edge(displayed)
                    )
                self.assertIn(
                    expected,
                    errors,
                )

    def test_connection_reference_defects_are_reported(self) -> None:
        mutations = (
            (
                "source",
                None,
                "connection has no source reference",
            ),
            (
                "source",
                "missing-source-object",
                "connection has unresolved source reference",
            ),
            (
                "archimateRelationship",
                None,
                "connection has no relationship reference",
            ),
            (
                "archimateRelationship",
                "missing-relationship",
                "connection has unresolved relationship reference",
            ),
            (
                "target",
                None,
                "connection has no target reference",
            ),
            (
                "target",
                "missing-target-object",
                "connection has unresolved target reference",
            ),
        )

        for attribute, value, expected in mutations:
            with self.subTest(attribute=attribute, value=value):
                root = copy.deepcopy(self.root)
                view = EXTRACTOR.find_view(
                    root,
                    "O2I Semantics - Primitives",
                )
                connection = self._connection(root, view, "substantiates")
                if value is None:
                    connection.attrib.pop(attribute)
                else:
                    connection.set(attribute, value)

                errors = EXTRACTOR.validate_model(root)

                self.assertTrue(
                    any(expected in error for error in errors),
                    errors,
                )

    def test_connection_endpoint_drift_is_reported(self) -> None:
        root = copy.deepcopy(self.root)
        view = EXTRACTOR.find_view(root, "O2I Semantics - Primitives")
        connection = self._connection(root, view, "substantiates")
        relationship = self._relationship_for(root, connection)
        relationship.set("source", relationship.get("target", ""))

        errors = EXTRACTOR.validate_model(root)

        self.assertTrue(
            any(
                "connection source" in error
                and "does not match relationship" in error
                for error in errors
            ),
            errors,
        )

    def test_profile_metadata_is_outside_extractor_authority(self) -> None:
        baseline_validation = EXTRACTOR.validate_model(self.root)
        baseline_snapshot = self._snapshot(
            self.root,
            "O2I Syntax - Collective Strategy Realization",
        )
        root = copy.deepcopy(self.root)
        proposition = self._model_element(
            root,
            "<Name> :: O2I Collective Strategy Realization",
            "Junction",
        )
        for prop in proposition.findall("property"):
            key = prop.get("key")
            if key == "o2i.kind":
                prop.set("value", "InvalidKind")
            elif key == "o2i.type":
                prop.set("value", "UnknownStructuredProposition")
            elif key == "o2i.commitment":
                prop.set("value", "tentative")
        ET.SubElement(
            proposition,
            "property",
            {"key": "o2i.owner", "value": "invalid-owner"},
        )

        self.assertEqual(baseline_validation, EXTRACTOR.validate_model(root))
        self.assertEqual(
            baseline_snapshot,
            self._snapshot(
                root,
                "O2I Syntax - Collective Strategy Realization",
            ),
        )

    def test_hidden_profile_topology_is_outside_extractor_authority(self) -> None:
        baseline_validation = EXTRACTOR.validate_model(self.root)
        baseline_snapshot = self._snapshot(
            self.root,
            "O2I Syntax - Contextualization",
        )
        root = copy.deepcopy(self.root)
        relations_folder = next(
            folder
            for folder in root.iter("folder")
            if folder.get("type") == "relations"
        )
        source = self._model_element(
            root,
            "<Name> :: O2I Mission",
            "Grouping",
        )
        target = self._model_element(
            root,
            "<Name> :: O2I Driver",
            "Driver",
        )
        ET.SubElement(
            relations_folder,
            "element",
            {
                EXTRACTOR.XSI_TYPE: "archimate:CompositionRelationship",
                "id": "hidden-contextualization",
                "name": "contextualizes",
                "source": source.get("id", ""),
                "target": target.get("id", ""),
            },
        )

        self.assertEqual(baseline_validation, EXTRACTOR.validate_model(root))
        self.assertEqual(
            baseline_snapshot,
            self._snapshot(root, "O2I Syntax - Contextualization"),
        )

    def test_irrelevant_model_order_and_content_do_not_affect_snapshot(
        self,
    ) -> None:
        view_name = "O2I Semantics - Context"
        baseline_validation = EXTRACTOR.validate_model(self.root)
        baseline_snapshot = self._snapshot(self.root, view_name)
        root = copy.deepcopy(self.root)
        elements_folder = next(
            folder
            for folder in root.iter("folder")
            if folder.get("type") == "other"
        )
        ET.SubElement(
            elements_folder,
            "element",
            {
                EXTRACTOR.XSI_TYPE: "archimate:Meaning",
                "id": "irrelevant-hidden-meaning",
                "name": "Irrelevant hidden meaning",
            },
        )
        elements_folder[:] = reversed(list(elements_folder))

        self.assertEqual(baseline_validation, EXTRACTOR.validate_model(root))
        self.assertEqual(baseline_snapshot, self._snapshot(root, view_name))

    def test_snapshot_preserves_each_displayed_element_occurrence(self) -> None:
        root = copy.deepcopy(self.root)
        view = EXTRACTOR.find_view(root, "O2I Semantics - Context")
        elements, _ = EXTRACTOR.collect_model(root)
        object_targets, _, _, _, _, _ = EXTRACTOR.collect_view(view)
        ethos_id = next(
            element_id
            for element_id, value in elements.items()
            if value == ("Ethos", "Grouping")
        )
        mission_id = next(
            element_id
            for element_id, value in elements.items()
            if value == ("Mission", "Grouping")
        )
        ethos_occurrence = self._view_occurrence(
            view,
            object_targets,
            ethos_id,
        )
        mission_occurrence = self._view_occurrence(
            view,
            object_targets,
            mission_id,
        )
        duplicate = copy.deepcopy(ethos_occurrence)
        duplicate.set("id", "duplicate-ethos-occurrence")
        for connection in list(duplicate.findall("sourceConnection")):
            duplicate.remove(connection)
        mission_occurrence.append(duplicate)

        snapshot = self._snapshot(root, "O2I Semantics - Context")

        self.assertIn("- [Ethos] `Ethos` (Grouping)", snapshot)
        self.assertIn("- [Mission] `Ethos` (Grouping)", snapshot)

    def test_snapshot_uses_view_specific_labels(self) -> None:
        snapshot = self._snapshot(
            self.root,
            "O2I Semantics - Situation Anchoring",
        )

        self.assertIn("- [Driver] `Driver @ Need` (Grouping)", snapshot)
        self.assertIn(
            "`Action @ Intervention` --changes--> `Situation Anchor`",
            snapshot,
        )
        self.assertIn(
            "`KPI @ Measure` --measures--> `Situation Anchor`",
            snapshot,
        )

    def test_visual_group_is_transparent_for_snapshot_context(self) -> None:
        self.assertEqual(
            "ArchiMate Capability",
            EXTRACTOR.top_container(
                "capability-occurrence",
                {"capability-occurrence": "capability"},
                {
                    "capability-occurrence": "visual-group",
                    "visual-group": None,
                },
                {"capability": ("ArchiMate Capability", "Capability")},
            ),
        )

    def test_cli_rejects_ambiguous_or_incomplete_selection(self) -> None:
        invalid_arguments = (
            ["--preset", "all", "--view", "ignored"],
            ["--preset", "all", "--output", "ignored.md"],
            ["--preset", "syntax-carriers", "--include-meaning"],
            ["--view", "O2I Semantics - Context"],
            ["--output", "ignored.md"],
            [],
        )

        for arguments in invalid_arguments:
            with self.subTest(arguments=arguments):
                stderr = io.StringIO()
                with redirect_stderr(stderr), self.assertRaises(SystemExit) as caught:
                    EXTRACTOR.parse_args(arguments)
                self.assertEqual(2, caught.exception.code)

    def test_cli_check_is_independent_of_current_working_directory(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            completed = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--preset",
                    "all",
                    "--check",
                ],
                cwd=directory,
                check=False,
                capture_output=True,
                text=True,
            )

        self.assertEqual(0, completed.returncode, completed.stderr)

    def test_cli_reports_invalid_xml_without_traceback(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            model = Path(directory) / "invalid.archimate"
            output = Path(directory) / "snapshot.md"
            model.write_text("<model>", encoding="utf-8")
            completed = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--model",
                    str(model),
                    "--view",
                    "Any View",
                    "--output",
                    str(output),
                    "--check",
                ],
                cwd=directory,
                check=False,
                capture_output=True,
                text=True,
            )

        self.assertEqual(1, completed.returncode)
        self.assertIn("[o2i|error] cannot read model", completed.stderr)
        self.assertNotIn("Traceback", completed.stderr)
        self.assertFalse(output.exists())

    def test_cli_reports_snapshot_read_error_without_traceback(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            completed = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--view",
                    "O2I Semantics - Context",
                    "--output",
                    directory,
                    "--check",
                ],
                cwd=ROOT,
                check=False,
                capture_output=True,
                text=True,
            )

        self.assertEqual(1, completed.returncode)
        self.assertIn("[o2i|error] cannot read snapshot", completed.stderr)
        self.assertNotIn("Traceback", completed.stderr)

    def test_snapshot_comparison_is_exact_and_deterministic(self) -> None:
        content = EXTRACTOR.rendered_view(
            self.root,
            MODEL,
            "O2I Semantics - Context",
            False,
        )
        repeated = EXTRACTOR.rendered_view(
            self.root,
            MODEL,
            "O2I Semantics - Context",
            False,
        )
        self.assertEqual(content, repeated)

        with tempfile.TemporaryDirectory() as directory:
            snapshot = Path(directory) / "snapshot.md"
            snapshot.write_text(content, encoding="utf-8")
            self.assertEqual([], EXTRACTOR.snapshot_diff(snapshot, content))

            snapshot.write_text("drift\n", encoding="utf-8")
            errors = EXTRACTOR.snapshot_diff(snapshot, content)
            self.assertEqual(1, len(errors))
            self.assertIn("snapshot drift:", errors[0])

    def _connection(
        self,
        root: ET.Element,
        view: ET.Element,
        relation_name: str,
    ) -> ET.Element:
        _, relations = EXTRACTOR.collect_model(root)
        matches = [
            connection
            for connection in view.iter("sourceConnection")
            if (
                relation_id := connection.get("archimateRelationship")
            ) in relations
            and relations[relation_id][0] == relation_name
        ]
        self.assertEqual(1, len(matches), relation_name)
        return matches[0]

    def _mapping_connection(
        self,
        root: ET.Element,
        view: ET.Element,
        source_name: str,
        relation_name: str,
        target_name: str,
    ) -> ET.Element:
        elements, relations = EXTRACTOR.collect_model(root)
        object_targets, _, _, connections, _, _ = EXTRACTOR.collect_view(view)
        matches = []
        for source_object, relation_id, target_object in connections:
            if (
                source_object not in object_targets
                or target_object not in object_targets
                or relation_id not in relations
            ):
                continue
            source = elements.get(
                object_targets[source_object],
                ("", ""),
            )[0]
            target = elements.get(
                object_targets[target_object],
                ("", ""),
            )[0]
            relation = relations[relation_id][0]
            if (source, relation, target) == (
                source_name,
                relation_name,
                target_name,
            ):
                matches.append(
                    next(
                        connection
                        for connection in view.iter("sourceConnection")
                        if connection.get("archimateRelationship")
                        == relation_id
                        and connection.get("source") == source_object
                        and connection.get("target") == target_object
                    )
                )
        self.assertEqual(
            1,
            len(matches),
            (source_name, relation_name, target_name),
        )
        return matches[0]

    def _snapshot(self, root: ET.Element, view_name: str) -> str:
        return EXTRACTOR.rendered_view(
            root,
            Path("mdl/o2i.archimate"),
            view_name,
            False,
        )

    def _relation_mapping_families(
        self,
    ) -> dict[
        tuple[str, str, str, bool],
        frozenset[tuple[str, str, str, str, bool, str, str]],
    ]:
        contract = EXTRACTOR.load_repository_view_contract(
            EXTRACTOR.PROFILE_PATH,
        )
        return EXTRACTOR.relation_mapping_families(contract)

    def _displayed_family_mapping(
        self,
        root: ET.Element,
        view: ET.Element,
        admissible: frozenset[
            tuple[str, str, str, str, bool, str, str]
        ],
    ) -> tuple[
        tuple[str, str, str, str, bool, str, str],
        ET.Element,
    ]:
        elements, relations = EXTRACTOR.collect_model(root)
        object_targets, _, _, _, _, _ = EXTRACTOR.collect_view(view)
        matches = []
        for connection in view.iter("sourceConnection"):
            source_object = connection.get("source")
            target_object = connection.get("target")
            relation_id = connection.get("archimateRelationship")
            if (
                source_object not in object_targets
                or target_object not in object_targets
                or relation_id not in relations
            ):
                continue
            source_name, source_type = elements[object_targets[source_object]]
            target_name, target_type = elements[object_targets[target_object]]
            relation_name, relation_type, _, _, directed = relations[relation_id]
            mapping = EXTRACTOR.canonical_mapping_edge(
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
            if mapping in admissible:
                matches.append((mapping, connection))
        self.assertEqual(1, len(matches), admissible)
        return matches[0]

    def _append_syntax_mapping(
        self,
        root: ET.Element,
        view: ET.Element,
        mapping: tuple[str, str, str, str, bool, str, str],
    ) -> None:
        (
            source_name,
            source_type,
            relation_name,
            relation_type,
            directed,
            target_name,
            target_type,
        ) = mapping
        elements, _ = EXTRACTOR.collect_model(root)
        object_targets, _, _, _, _, _ = EXTRACTOR.collect_view(view)

        def occurrence(
            name: str,
            element_type: str,
        ) -> tuple[str, str, ET.Element]:
            matches = [
                (
                    object_id,
                    element_id,
                    next(
                        child
                        for child in view.iter()
                        if child.get("id") == object_id
                    ),
                )
                for object_id, element_id in object_targets.items()
                if elements.get(element_id) == (name, element_type)
            ]
            self.assertTrue(matches, (name, element_type))
            return min(matches, key=lambda match: match[0])

        source_object, source_element, source_occurrence = occurrence(
            source_name,
            source_type,
        )
        target_object, target_element, _ = occurrence(
            target_name,
            target_type,
        )
        suffix = f"family-duplicate-{len(list(view.iter('sourceConnection')))}"
        relation_id = f"{suffix}-relationship"
        relations_folder = next(
            folder
            for folder in root.iter("folder")
            if folder.get("type") == "relations"
        )
        attributes = {
            EXTRACTOR.XSI_TYPE: f"archimate:{relation_type}",
            "id": relation_id,
            "name": relation_name,
            "source": source_element,
            "target": target_element,
        }
        if relation_type == "AssociationRelationship":
            attributes["directed"] = str(directed).lower()
        ET.SubElement(relations_folder, "element", attributes)
        ET.SubElement(
            source_occurrence,
            "sourceConnection",
            {
                EXTRACTOR.XSI_TYPE: "archimate:Connection",
                "id": f"{suffix}-connection",
                "source": source_object,
                "target": target_object,
                "archimateRelationship": relation_id,
            },
        )

    def _view_occurrence(
        self,
        view: ET.Element,
        object_targets: dict[str, str],
        element_id: str,
    ) -> ET.Element:
        object_ids = {
            object_id
            for object_id, target in object_targets.items()
            if target == element_id
        }
        matches = [
            occurrence
            for occurrence in view.iter("child")
            if occurrence.get("id") in object_ids
        ]
        self.assertEqual(1, len(matches), element_id)
        return matches[0]

    def _relationship_for(
        self,
        root: ET.Element,
        connection: ET.Element,
    ) -> ET.Element:
        relation_id = connection.get("archimateRelationship")
        matches = [
            element
            for element in root.iter("element")
            if element.get("id") == relation_id
        ]
        self.assertEqual(1, len(matches), relation_id)
        return matches[0]

    def _set_connection_label_expression(
        self,
        connection: ET.Element,
        value: str,
    ) -> None:
        ET.SubElement(
            connection,
            "feature",
            {"name": "labelExpression", "value": value},
        )

    def _model_element(
        self,
        root: ET.Element,
        name: str,
        element_type: str,
    ) -> ET.Element:
        matches = [
            element
            for element in root.iter("element")
            if element.get("name", "") == name
            and EXTRACTOR.xtype(element) == element_type
        ]
        self.assertEqual(1, len(matches), (name, element_type))
        return matches[0]

    def _remove_view_node(
        self,
        root: ET.Element,
        view_name: str,
        name: str,
        element_type: str,
    ) -> None:
        elements, _ = EXTRACTOR.collect_model(root)
        view = EXTRACTOR.find_view(root, view_name)

        for parent in view.iter():
            for child in list(parent):
                target = child.get("archimateElement")
                if target is not None and elements.get(target) == (
                    name,
                    element_type,
                ):
                    parent.remove(child)
                    return
        self.fail(f"{view_name} has no node {name} ({element_type})")

    def _parent_of(
        self,
        root: ET.Element,
        target: ET.Element,
    ) -> ET.Element:
        for parent in root.iter():
            if target in list(parent):
                return parent
        self.fail(f"cannot find parent of {target.tag}")

    def _remove_element(
        self,
        root: ET.Element,
        target: ET.Element,
    ) -> None:
        self._parent_of(root, target).remove(target)


if __name__ == "__main__":
    unittest.main()
