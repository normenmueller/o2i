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


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "utl" / "extract-archimate-view.py"
MODEL = ROOT / "mdl" / "o2i.archimate"
EXPECTED_PRESET_KEYS = {
    "strategy-constituents",
    "semantics-situation",
    "situation-anchoring",
    "orientation",
    "semantics-context",
    "semantics-primitives",
    "syntax-context",
    "syntax-contextualization",
    "syntax-collective-strategy-realization",
    "syntax-primitives",
    "syntax-situation",
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
        view = EXTRACTOR.find_view(root, "O2I Syntax - Context")
        self._remove_element(root, view)

        errors = EXTRACTOR.validate_model(root)

        self.assertIn(
            "missing required view: O2I Syntax - Context",
            errors,
        )

    def test_required_node_is_view_scoped(self) -> None:
        root = copy.deepcopy(self.root)
        self._remove_view_node(
            root,
            "O2I Syntax - Primitives",
            "O2I Principle",
            "Principle",
        )

        errors = EXTRACTOR.validate_model(root)

        self.assertIn(
            "O2I Syntax - Primitives is missing node "
            "O2I Principle (Principle)",
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

    def test_missing_contracted_relation_is_reported(self) -> None:
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
                "O2I Syntax - Collective Strategy Realization is missing "
                "contracted relation:"
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
        object_targets, _, _, _, _ = EXTRACTOR.collect_view(view)
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

    def test_cli_rejects_ambiguous_or_incomplete_selection(self) -> None:
        invalid_arguments = (
            ["--preset", "all", "--view", "ignored"],
            ["--preset", "all", "--output", "ignored.md"],
            ["--preset", "syntax-context", "--include-meaning"],
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

    def _snapshot(self, root: ET.Element, view_name: str) -> str:
        return EXTRACTOR.rendered_view(
            root,
            Path("mdl/o2i.archimate"),
            view_name,
            False,
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
