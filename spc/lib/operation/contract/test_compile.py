#!/usr/bin/env python3

import copy
import hashlib
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import PropertyMock, patch


HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("compile_operation", HERE / "compile.py")
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("cannot load Operation contract compiler")
COMPILER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COMPILER)

PROFILE_COMPANION = Path(
    os.environ.get(
        "O2I_PROFILE_COMPANION", COMPILER.DEFAULT_PROFILE_COMPANION
    )
)


class OperationContractCompilerTest(unittest.TestCase):
    def setUp(self):
        self.companion = json.loads(COMPILER.COMPANION.read_text(encoding="utf-8"))

    def render_value(self, value):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "operation.json"
            path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
            with patch.object(COMPILER, "COMPANION", path):
                return COMPILER.render_outputs(PROFILE_COMPANION)

    def assert_invalid(self, value, pattern):
        with self.assertRaisesRegex(ValueError, pattern):
            self.render_value(value)

    def test_canonical_contract_compiles_deterministically(self):
        first = COMPILER.render_outputs(PROFILE_COMPANION)
        second = COMPILER.render_outputs(PROFILE_COMPANION)
        self.assertEqual(first, second)
        self.assertEqual(8, len(first))
        self.assertIn(b"data GeneratedOperationRule", first[COMPILER.RULE_GENERATED])
        self.assertIn(
            b"adapterInventoryMachineSchema :: MachineSchema",
            first[COMPILER.SCHEMA_GENERATED],
        )
        self.assertEqual(9, first[COMPILER.RULE_GENERATED].count(b'"bootstrap.'))

        documents = COMPILER.validate(PROFILE_COMPANION)[3]
        for document in documents:
            payload = first[document.schema_path]
            schema = json.loads(payload)
            self.assertEqual(COMPILER.SCHEMA_DRAFT, schema["$schema"])
            self.assertEqual(document.reference, schema["$id"])
            self.assertTrue(payload.endswith(b"\n"))
            self.assertIn(
                hashlib.sha256(payload).hexdigest().encode("ascii"),
                first[COMPILER.SCHEMA_GENERATED],
            )

    def test_schema_projection_closes_every_object_boundary(self):
        for document in COMPILER.validate(PROFILE_COMPANION)[3]:
            schema = json.loads(COMPILER.render_schema(document))
            self.assert_closed_objects(schema)
        for fragment in COMPILER.validate(PROFILE_COMPANION)[4]:
            schema = json.loads(COMPILER.render_schema_fragment(fragment))
            self.assert_closed_objects(schema)

    def assert_closed_objects(self, value):
        if isinstance(value, dict):
            if value.get("type") == "object":
                self.assertIs(False, value.get("additionalProperties"))
                self.assertLessEqual(
                    set(value["required"]), set(value["properties"])
                )
            for nested in value.values():
                self.assert_closed_objects(nested)
        elif isinstance(value, list):
            for nested in value:
                self.assert_closed_objects(nested)

    def test_rule_definition_failure_has_no_unencodable_authority(self):
        schema = json.loads(
            COMPILER.render_schema(COMPILER.validate(PROFILE_COMPANION)[3][2])
        )
        invalid = schema["$defs"]["ruleInvalid"]
        self.assertEqual(
            ["schema", "kind", "diagnostics"], invalid["required"]
        )
        self.assertNotIn("authority", invalid["properties"])

    def test_rule_authority_requires_only_available_contract_digests(self):
        schema = json.loads(
            COMPILER.render_schema(COMPILER.validate(PROFILE_COMPANION)[3][2])
        )
        authorities = schema["$defs"]["ruleAuthority"]["oneOf"]
        bindings = {
            authority["properties"]["kind"]["const"]:
                authority["properties"]["contract"]["$ref"]
            for authority in authorities
        }
        self.assertEqual(
            {
                "operation": "#/$defs/digestContractBinding",
                "core": "#/$defs/digestContractBinding",
                "profile": "#/$defs/digestContractBinding",
                "adapter": "#/$defs/undigestedContractBinding",
            },
            bindings,
        )

    def test_multiple_adapter_matches_require_at_least_two_descriptors(self):
        schema = json.loads(
            COMPILER.render_schema(COMPILER.validate(PROFILE_COMPANION)[3][4])
        )
        selection = schema["$defs"]["selectionFailure"]
        multiple = selection["oneOf"][3]
        self.assertEqual(2, multiple["properties"]["adapters"]["minItems"])

    def test_post_acquisition_view_failures_require_source_identity(self):
        schema = json.loads(
            COMPILER.render_schema(COMPILER.validate(PROFILE_COMPANION)[3][4])
        )
        self.assertIn("source", schema["$defs"]["selectionFailed"]["required"])
        self.assertIn("source", schema["$defs"]["decodeFailed"]["required"])

    def test_view_failure_diagnostics_share_adapter_preparation_stage(self):
        schema = json.loads(
            COMPILER.render_schema(COMPILER.validate(PROFILE_COMPANION)[3][4])
        )
        definitions = schema["$defs"]
        recognition = definitions["recognitionAdapterDiagnostic"]
        decode = definitions["decodeAdapterDiagnostic"]
        self.assertEqual(
            "#/$defs/recognitionAdapterRule",
            recognition["properties"]["rule"]["$ref"],
        )
        self.assertEqual(
            "#/$defs/decodeAdapterRule",
            decode["properties"]["rule"]["$ref"],
        )
        self.assertEqual(
            "preparation",
            definitions["recognitionAdapterRule"]["properties"]["stage"][
                "const"
            ],
        )
        self.assertEqual(
            "preparation",
            definitions["decodeAdapterRule"]["properties"]["stage"]["const"],
        )

    def test_view_schema_preserves_empty_native_lexemes(self):
        schema = json.loads(
            COMPILER.render_schema(COMPILER.validate(PROFILE_COMPANION)[3][4])
        )
        definitions = schema["$defs"]
        self.assertNotIn(
            "minLength", definitions["nativeName"]["properties"]["localName"]
        )
        scalar_variants = definitions["draftScalar"]["properties"]["value"][
            "oneOf"
        ]
        number = scalar_variants[2]["properties"]["value"]
        native_kind = scalar_variants[4]["properties"]["nativeKind"]
        observed_kind = definitions["identityInvalidReason"]["oneOf"][0][
            "properties"
        ]["observedKind"]
        for raw_text in (number, native_kind, observed_kind):
            self.assertEqual({"type": "string"}, raw_text)

    def test_view_source_path_uses_one_based_ordinals(self):
        schema = json.loads(
            COMPILER.render_schema(COMPILER.validate(PROFILE_COMPANION)[3][4])
        )
        path_step = schema["$defs"]["sourceLocation"]["properties"]["path"][
            "items"
        ]
        self.assertEqual(1, path_step["properties"]["ordinal"]["minimum"])

    def test_diagnostic_schema_closes_the_haskell_occurrence_algebra(self):
        fragment = COMPILER.validate(PROFILE_COMPANION)[4][0]
        schema = json.loads(COMPILER.render_schema_fragment(fragment))
        self.assertEqual("o2i.operation.diagnostic/v1", fragment.reference)
        self.assertEqual("#/$defs/diagnosticValue", schema["$ref"])
        self.assertEqual(COMPILER.diagnostic_definitions(), schema["$defs"])
        occurrences = schema["$defs"]["diagnosticOccurrence"]["oneOf"]
        self.assertEqual(
            ["source", "native", "draft", "canonical", "subject", "occurrence"],
            [branch["properties"]["kind"]["const"] for branch in occurrences],
        )
        provenances = schema["$defs"]["diagnosticProvenance"]["oneOf"]
        self.assertEqual(
            ["operation", "adapter", "profile", "core"],
            [branch["properties"]["owner"]["const"] for branch in provenances],
        )
        self.assertEqual(
            [
                ["owner", "ruleId"],
                ["owner", "adapterId", "ruleId"],
                ["owner", "profileReference", "ruleId"],
                ["owner", "ruleId"],
            ],
            [branch["required"] for branch in provenances],
        )
        diagnostic = schema["$defs"]["diagnosticValue"]
        self.assertEqual(
            ["severity", "disposition", "provenance", "occurrences"],
            diagnostic["required"],
        )
        for redundant in ("code", "ruleId", "authority", "stage"):
            self.assertNotIn(redundant, diagnostic["properties"])
        self.assertEqual(
            ["debug", "info", "warning", "error"],
            diagnostic["properties"]["severity"]["enum"],
        )
        self.assertEqual(
            ["model-finding", "process-failure"],
            diagnostic["properties"]["disposition"]["enum"],
        )
        self.assertEqual(
            1,
            schema["$defs"]["sourceLocation"]["properties"]["path"]["items"][
                "properties"
            ]["ordinal"]["minimum"],
        )

    def test_completed_views_alone_has_the_exact_operation_envelope(self):
        document = COMPILER.validate(PROFILE_COMPANION)[3][4]
        schema = json.loads(COMPILER.render_schema(document))
        definitions = schema["$defs"]
        self.assertEqual(2, document.version)
        completed = definitions["viewsDiscovered"]
        self.assertEqual(
            ["schema", "operation", "tool", "kind", "source", "adapter", "authorities", "views"],
            completed["required"],
        )
        self.assertEqual("views", completed["properties"]["operation"]["const"])
        self.assertEqual(
            "#/$defs/toolDescriptor", completed["properties"]["tool"]["$ref"]
        )
        for name in ("acquisitionFailed", "selectionFailed", "decodeFailed"):
            properties = definitions[name]["properties"]
            self.assertNotIn("operation", properties)
            self.assertNotIn("tool", properties)

    def test_tool_descriptor_schema_is_closed_and_nul_free(self):
        schema = json.loads(
            COMPILER.render_schema(COMPILER.validate(PROFILE_COMPANION)[3][4])
        )
        descriptor = schema["$defs"]["toolDescriptor"]
        self.assertEqual(["identity", "version"], descriptor["required"])
        self.assertIs(False, descriptor["additionalProperties"])
        for field in ("identity", "version"):
            self.assertEqual(
                COMPILER.TOOL_TEXT_PATTERN,
                descriptor["properties"][field]["pattern"],
            )

    def test_explicit_profile_companion_controls_conformance(self):
        profile = json.loads(PROFILE_COMPANION.read_text(encoding="utf-8"))
        profile["ruleIdentityContract"][
            "operationBootstrapRuleInventory"
        ].reverse()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "profile.json"
            path.write_text(json.dumps(profile) + "\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "conformance inventory"):
                COMPILER.validate(path)

    def test_machine_document_shape_is_closed(self):
        changed = copy.deepcopy(self.companion)
        changed["machineDocuments"][0]["description"] = "not admitted"
        self.assert_invalid(changed, "expected members")

    def test_duplicate_machine_document_name_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        changed["machineDocuments"].append(
            copy.deepcopy(changed["machineDocuments"][0])
        )
        self.assert_invalid(changed, "duplicate machine document name")

    def test_duplicate_machine_document_identity_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        changed["machineDocuments"][1]["identity"] = changed[
            "machineDocuments"
        ][0]["identity"]
        self.assert_invalid(changed, "duplicate machine document identity")

    def test_machine_document_and_fragment_reference_collision_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        changed["schemaFragments"][0]["identity"] = changed[
            "machineDocuments"
        ][0]["identity"]
        changed["schemaFragments"][0]["version"] = changed[
            "machineDocuments"
        ][0]["version"]
        self.assert_invalid(changed, "duplicate generated schema reference")

    def test_machine_document_and_fragment_output_path_collision_is_rejected(self):
        document = COMPILER.validate_machine_documents(
            self.companion["machineDocuments"]
        )[0]
        with patch.object(
            COMPILER.SchemaFragment,
            "schema_path",
            new_callable=PropertyMock,
            return_value=document.schema_path,
        ):
            self.assert_invalid(
                self.companion, "duplicate generated schema output path"
            )

    def test_duplicate_variant_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        changed["machineDocuments"][1]["variants"][1] = changed[
            "machineDocuments"
        ][1]["variants"][0]
        self.assert_invalid(changed, "duplicate variant")

    def test_invalid_schema_identity_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        changed["machineDocuments"][0]["identity"] = "O2I.invalid"
        self.assert_invalid(changed, "invalid schema identity")

    def test_invalid_schema_versions_are_rejected(self):
        for invalid in (0, -1, True, "1"):
            with self.subTest(invalid=invalid):
                changed = copy.deepcopy(self.companion)
                changed["machineDocuments"][0]["version"] = invalid
                self.assert_invalid(changed, "expected positive integer")

    def test_unknown_machine_document_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        changed["machineDocuments"][0]["name"] = "genericResult"
        self.assert_invalid(changed, "unsupported machine document")

    def test_closed_variant_inventory_is_enforced(self):
        changed = copy.deepcopy(self.companion)
        changed["machineDocuments"][0]["variants"] = ["another-result"]
        self.assert_invalid(changed, "unexpected closed variant inventory")

    def test_noncanonical_machine_document_order_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        changed["machineDocuments"][0], changed["machineDocuments"][1] = (
            changed["machineDocuments"][1],
            changed["machineDocuments"][0],
        )
        self.assert_invalid(changed, "canonical order")

    def test_duplicate_rule_identity_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        changed["rules"][1]["id"] = changed["rules"][0]["id"]
        self.assert_invalid(changed, "duplicate Operation rule identity")

    def test_empty_explanation_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        changed["rules"][0]["meaning"] = ""
        self.assert_invalid(changed, "non-empty NUL-free text")

    def test_noncanonical_rule_order_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        changed["rules"][0], changed["rules"][1] = (
            changed["rules"][1],
            changed["rules"][0],
        )
        self.assert_invalid(changed, "canonical identity order")

    def test_check_reports_missing_and_stale_outputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            missing = root / "missing"
            stale = root / "stale"
            stale.write_bytes(b"old")
            with self.assertRaisesRegex(SystemExit, "missing:[\\s\\S]*stale:"):
                COMPILER.check_outputs(
                    {missing: b"generated", stale: b"generated"}
                )

    def test_write_materializes_every_output_exactly(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            outputs = {
                root / "one/generated.json": b"one\n",
                root / "two/generated.hs": b"two\n",
            }
            COMPILER.write_outputs(outputs)
            self.assertEqual(
                {path: path.read_bytes() for path in outputs}, outputs
            )
            COMPILER.check_outputs(outputs)


if __name__ == "__main__":
    unittest.main()
