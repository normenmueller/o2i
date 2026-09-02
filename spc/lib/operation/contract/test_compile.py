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

from jsonschema import Draft202012Validator


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
PROFILE_DIAGNOSTIC_INVENTORY = Path(
    os.environ.get(
        "O2I_PROFILE_DIAGNOSTIC_INVENTORY",
        COMPILER.DEFAULT_PROFILE_DIAGNOSTIC_INVENTORY,
    )
)
CORE_OWNER_DIAGNOSTIC_INVENTORY = Path(
    os.environ.get(
        "O2I_CORE_OWNER_DIAGNOSTIC_INVENTORY",
        COMPILER.DEFAULT_CORE_OWNER_DIAGNOSTIC_INVENTORY,
    )
)
CORE_COMPANION = Path(
    os.environ.get("O2I_CORE_COMPANION", COMPILER.DEFAULT_CORE_COMPANION)
)


class OperationContractCompilerTest(unittest.TestCase):
    def setUp(self):
        self.companion = json.loads(COMPILER.COMPANION.read_text(encoding="utf-8"))
        self.command_error = json.loads(
            COMPILER.COMMAND_ERROR_COMPANION.read_text(encoding="utf-8")
        )
        self.profile_inventory = json.loads(
            PROFILE_DIAGNOSTIC_INVENTORY.read_text(encoding="utf-8")
        )
        self.core_inventory = json.loads(
            CORE_OWNER_DIAGNOSTIC_INVENTORY.read_text(encoding="utf-8")
        )
        self.core_companion = json.loads(
            CORE_COMPANION.read_text(encoding="utf-8")
        )

    def validate_contract(self, profile_companion=PROFILE_COMPANION):
        return COMPILER.validate(
            profile_companion,
            PROFILE_DIAGNOSTIC_INVENTORY,
            CORE_OWNER_DIAGNOSTIC_INVENTORY,
        )

    def render_contract(self):
        return COMPILER.render_outputs(
            PROFILE_COMPANION,
            PROFILE_DIAGNOSTIC_INVENTORY,
            CORE_OWNER_DIAGNOSTIC_INVENTORY,
            CORE_COMPANION,
        )

    def render_value(self, value):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "operation.json"
            path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
            with patch.object(COMPILER, "COMPANION", path):
                return self.render_contract()

    def assert_invalid(self, value, pattern):
        with self.assertRaisesRegex(ValueError, pattern):
            self.render_value(value)

    def render_command_error_value(self, value):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "command-error.json"
            path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
            with patch.object(COMPILER, "COMMAND_ERROR_COMPANION", path):
                return self.render_contract()

    def assert_command_error_invalid(self, value, pattern):
        with self.assertRaisesRegex(ValueError, pattern):
            self.render_command_error_value(value)

    def test_canonical_contract_compiles_deterministically(self):
        first = self.render_contract()
        second = self.render_contract()
        self.assertEqual(first, second)
        self.assertEqual(16, len(first))
        self.assertIn(b"data GeneratedOperationRule", first[COMPILER.RULE_GENERATED])
        self.assertIn(
            b"adapterInventoryMachineSchema :: MachineSchema",
            first[COMPILER.SCHEMA_GENERATED],
        )
        self.assertIn(
            b"diagnosticSchemaAuthority :: SchemaAuthority",
            first[COMPILER.SCHEMA_GENERATED],
        )
        self.assertEqual(9, first[COMPILER.RULE_GENERATED].count(b'"bootstrap.'))

        documents = self.validate_contract()[3]
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
        for document in self.validate_contract()[3]:
            schema = json.loads(
                COMPILER.render_schema(
                    document,
                    self.profile_inventory,
                    self.core_inventory,
                    core_companion=self.core_companion,
                )
            )
            self.assert_closed_objects(schema)
        for fragment in self.validate_contract()[4]:
            schema = json.loads(
                COMPILER.render_schema_fragment(
                    fragment, self.profile_inventory, self.core_inventory
                )
            )
            self.assert_closed_objects(schema)

    def test_every_rendered_schema_is_valid_draft_2020_12(self):
        rendered = self.render_contract()
        documents = self.validate_contract()[3]
        fragments = self.validate_contract()[4]
        for subject in [*documents, *fragments]:
            with self.subTest(schema=subject.name):
                schema = json.loads(rendered[subject.schema_path])
                self.assertEqual(COMPILER.SCHEMA_DRAFT, schema["$schema"])
                self.assertEqual(subject.reference, schema["$id"])
                Draft202012Validator.check_schema(schema)

    def test_command_error_schema_and_manifest_are_exact(self):
        rendered = self.render_contract()
        document = next(
            document
            for document in self.validate_contract()[3]
            if document.name == "commandError"
        )
        schema = json.loads(rendered[document.schema_path])
        self.assertEqual("o2i.command-error/v1", schema["$id"])
        self.assertEqual(
            [
                "argument-invalid",
                "command-failed",
                "preparation-failed",
                "validate-failed",
                "qualify-failed",
                "readiness-failed",
                "assess-failed",
            ],
            list(document.variants),
        )
        self.assertIn(
            b"commandErrorSchemaBytes :: ByteString",
            rendered[COMPILER.SCHEMA_GENERATED],
        )
        Draft202012Validator.check_schema(schema)

    def test_command_error_owner_branch_artifacts_are_exact_and_bijective(self):
        expected = {
            "validate": [
                ("ValidateAcquiredModelRoleFailure", "acquired-model-role"),
                ("ValidateAcquiredSupplementalRoleFailure", "acquired-supplemental-role"),
                ("ValidateSelectedAdapterContractFailure", "selected-adapter-contract"),
                ("ValidateNotationContractFailure", "notation-contract"),
                ("ValidateProfileContractFailure", "profile-contract"),
                ("ValidateIdentityIndexFailure", "identity-index"),
                ("ValidateSelectedViewScopeFailure", "selected-view-scope"),
                ("ValidateStructureInputFailure", "structure-input"),
                ("ValidateSupplementalProvenanceFailure", "supplemental-provenance"),
                ("ValidateSemanticUnavailableContractFailure", "semantic-unavailable-contract"),
            ],
            "qualify": [
                ("QualifyAcquiredModelRoleFailure", "acquired-model-role"),
                ("QualifyAcquiredSupplementalRoleFailure", "acquired-supplemental-role"),
                ("QualifySelectedAdapterContractFailure", "selected-adapter-contract"),
                ("QualifyNotationContractFailure", "notation-contract"),
                ("QualifyProfileContractFailure", "profile-contract"),
                ("QualifyIdentityIndexFailure", "identity-index"),
                ("QualifySelectedViewScopeFailure", "selected-view-scope"),
                ("QualifyStructureInputFailure", "structure-input"),
                ("QualifySupplementalProvenanceFailure", "supplemental-provenance"),
                ("QualifyContextFailure", "qualification-context"),
            ],
            "readiness": [
                ("ReadinessAcquiredModelRoleFailure", "acquired-model-role"),
                ("ReadinessAcquiredEvidenceRoleFailure", "acquired-readiness-role"),
                ("ReadinessAcquiredSupplementalRoleFailure", "acquired-supplemental-role"),
                ("ReadinessSelectedAdapterContractFailure", "selected-adapter-contract"),
                ("ReadinessNotationContractFailure", "notation-contract"),
                ("ReadinessProfileContractFailure", "profile-contract"),
                ("ReadinessIdentityIndexFailure", "identity-index"),
                ("ReadinessSelectedViewScopeFailure", "selected-view-scope"),
                ("ReadinessStructureInputFailure", "structure-input"),
                ("ReadinessSupplementalProvenanceFailure", "supplemental-provenance"),
                ("ReadinessSemanticModelContractFailure", "semantic-model-contract"),
            ],
            "assess": [
                ("AssessAcquiredModelRoleFailure", "acquired-model-role"),
                ("AssessAcquiredBundleRoleFailure", "acquired-assessment-role"),
                ("AssessAcquiredSupplementalRoleFailure", "acquired-supplemental-role"),
                ("AssessSelectedAdapterContractFailure", "selected-adapter-contract"),
                ("AssessNotationContractFailure", "notation-contract"),
                ("AssessProfileContractFailure", "profile-contract"),
                ("AssessIdentityIndexFailure", "identity-index"),
                ("AssessSelectedViewScopeFailure", "selected-view-scope"),
                ("AssessStructureInputFailure", "structure-input"),
                ("AssessSupplementalProvenanceFailure", "supplemental-provenance"),
                ("AssessSemanticModelContractFailure", "semantic-model-contract"),
            ],
        }
        actual = {
            capability: [
                (row["constructor"], row["token"])
                for row in self.command_error["ownerBranches"][capability]
            ]
            for capability in expected
        }
        self.assertEqual(expected, actual)

        rendered = self.render_contract()
        generated = rendered[COMPILER.COMMAND_ERROR_BRANCH_GENERATED]
        self.assertEqual(
            COMPILER.COMMAND_ERROR_BRANCH_GENERATED.read_bytes(), generated
        )
        command_document = next(
            document
            for document in self.validate_contract()[3]
            if document.name == "commandError"
        )
        command_schema_bytes = rendered[command_document.schema_path]
        self.assertEqual(
            command_document.schema_path.read_bytes(), command_schema_bytes
        )
        command_schema = json.loads(command_schema_bytes)
        for capability, rows in expected.items():
            with self.subTest(capability=capability):
                tokens = [token for _, token in rows]
                alternatives = command_schema["$defs"][
                    capability + "Failure"
                ]["oneOf"]
                owner = next(
                    alternative
                    for alternative in alternatives
                    if alternative["properties"]["category"].get("const")
                    == "owner-contract"
                )
                self.assertEqual(tokens, owner["properties"]["branch"]["enum"])
                self.assertEqual(len(tokens), len(set(tokens)))
                for constructor, token in rows:
                    self.assertIn(
                        f".{constructor} _ ->".encode("utf-8"), generated
                    )
                    self.assertIn(f'"{token}"'.encode("utf-8"), generated)

    def test_command_error_owner_branch_inventory_is_closed(self):
        changed = copy.deepcopy(self.command_error)
        changed["ownerBranches"]["validate"].pop()
        self.assert_command_error_invalid(changed, "unexpected branch cardinality")

        changed = copy.deepcopy(self.command_error)
        changed["ownerBranches"]["assess"][1]["token"] = changed[
            "ownerBranches"
        ]["assess"][0]["token"]
        self.assert_command_error_invalid(changed, "duplicate token")

    def test_command_error_companion_is_closed_and_ordered(self):
        changed = copy.deepcopy(self.command_error)
        changed["document"]["description"] = "not admitted"
        self.assert_command_error_invalid(changed, "expected members")

        changed = copy.deepcopy(self.command_error)
        changed["document"]["variants"].reverse()
        self.assert_command_error_invalid(
            changed, "unexpected closed variant inventory"
        )

        changed = copy.deepcopy(self.command_error)
        changed["schema"] = "o2i.command-error-contract/2"
        self.assert_command_error_invalid(
            changed, "unsupported Command-error companion schema"
        )

    def assert_closed_objects(self, value):
        if isinstance(value, dict):
            if value.get("type") == "object":
                self.assertIs(False, value.get("additionalProperties"))
                if "properties" in value:
                    self.assertLessEqual(
                        set(value["required"]), set(value["properties"])
                    )
            for nested in value.values():
                self.assert_closed_objects(nested)
        elif isinstance(value, list):
            for nested in value:
                self.assert_closed_objects(nested)

    def sample_schema_value(self, schema, definitions):
        if schema is False:
            raise AssertionError("cannot sample an impossible schema")
        if "$ref" in schema:
            return self.sample_schema_value(
                definitions[schema["$ref"].removeprefix("#/$defs/")],
                definitions,
            )
        if "const" in schema:
            return copy.deepcopy(schema["const"])
        if "oneOf" in schema:
            return self.sample_schema_value(schema["oneOf"][0], definitions)
        if "enum" in schema:
            return copy.deepcopy(schema["enum"][0])
        kind = schema.get("type")
        if kind == "object":
            properties = schema.get("properties", {})
            return {
                name: self.sample_schema_value(properties[name], definitions)
                for name in schema.get("required", [])
            }
        if kind == "array":
            values = [
                self.sample_schema_value(item, definitions)
                for item in schema.get("prefixItems", [])
            ]
            if "contains" in schema and not values:
                values.append(
                    self.sample_schema_value(schema["contains"], definitions)
                )
            minimum = schema.get("minItems", 0)
            while len(values) < minimum:
                values.append(
                    self.sample_schema_value(schema["items"], definitions)
                )
            return values
        if kind == "string":
            if schema.get("pattern") == COMPILER.SHA256_PATTERN:
                return "0" * 64
            return "x"
        if kind == "integer":
            return schema.get("minimum", 0)
        if kind == "boolean":
            return False
        if kind == "null":
            return None
        raise AssertionError(f"unsupported sample schema: {schema!r}")

    def resolve_local_schema(self, schema, definitions):
        while "$ref" in schema:
            schema = definitions[
                schema["$ref"].removeprefix("#/$defs/")
            ]
        return schema

    def validate_schema_fixture(self):
        document = next(
            document
            for document in self.validate_contract()[3]
            if document.name == "validateResult"
        )
        schema = json.loads(
            COMPILER.render_schema(
                document, self.profile_inventory, self.core_inventory
            )
        )
        self.assertEqual(document.reference, schema["$id"])
        Draft202012Validator.check_schema(schema)
        fixture_schema = copy.deepcopy(schema)
        # Fixture validation needs only local $defs; omitting the root identity
        # avoids deprecated resolver versions rebasing that valid relative ID.
        del fixture_schema["$id"]
        return schema, Draft202012Validator(fixture_schema)

    def validate_variant_schema(self, schema, name, requested_level=None):
        root = schema["$defs"][name]
        alternatives = root.get("oneOf", [root])
        if requested_level is None:
            return alternatives[0]
        return next(
            alternative
            for alternative in alternatives
            if alternative["properties"]["request"]["properties"]["level"][
                "const"
            ]
            == requested_level
        )

    def validate_variant_fixture(
        self, schema, name, requested_level=None
    ):
        return self.sample_schema_value(
            self.validate_variant_schema(schema, name, requested_level),
            schema["$defs"],
        )

    def trace_schema_fixture(self):
        document = next(
            document
            for document in self.validate_contract()[3]
            if document.name == "traceResult"
        )
        schema = json.loads(
            COMPILER.render_schema(
                document,
                self.profile_inventory,
                self.core_inventory,
                core_companion=self.core_companion,
            )
        )
        Draft202012Validator.check_schema(schema)
        fixture_schema = copy.deepcopy(schema)
        del fixture_schema["$id"]
        return schema, Draft202012Validator(fixture_schema)

    def qualification_schema_fixture(self, name):
        document = next(
            document
            for document in self.validate_contract()[3]
            if document.name == name
        )
        schema = json.loads(
            COMPILER.render_schema(
                document, self.profile_inventory, self.core_inventory
            )
        )
        Draft202012Validator.check_schema(schema)
        fixture_schema = copy.deepcopy(schema)
        del fixture_schema["$id"]
        return schema, Draft202012Validator(fixture_schema)

    def readiness_schema_fixture(self):
        document = next(
            document
            for document in self.validate_contract()[3]
            if document.name == "readinessResult"
        )
        schema = json.loads(
            COMPILER.render_schema(
                document,
                self.profile_inventory,
                self.core_inventory,
                core_companion=self.core_companion,
            )
        )
        Draft202012Validator.check_schema(schema)
        fixture_schema = copy.deepcopy(schema)
        del fixture_schema["$id"]
        return schema, Draft202012Validator(fixture_schema)

    def assessment_schema_fixture(self):
        document = next(
            document
            for document in self.validate_contract()[3]
            if document.name == "assessResult"
        )
        schema = json.loads(
            COMPILER.render_schema(
                document,
                self.profile_inventory,
                self.core_inventory,
                core_companion=self.core_companion,
            )
        )
        Draft202012Validator.check_schema(schema)
        fixture_schema = copy.deepcopy(schema)
        del fixture_schema["$id"]
        return schema, Draft202012Validator(fixture_schema)

    def test_qualification_subjects_schema_closes_prepared_discovery(self):
        schema, validator = self.qualification_schema_fixture(
            "qualificationSubjects"
        )
        definitions = schema["$defs"]
        discovered = self.sample_schema_value(
            definitions["subjectsDiscovered"], definitions
        )
        self.assertTrue(validator.is_valid(discovered))
        self.assertEqual(
            ["operation", "adapter", "profile", "core"],
            [
                contract["kind"]
                for contract in discovered["provenance"]["contracts"]
            ],
        )

        missing_contract = copy.deepcopy(discovered)
        missing_contract["provenance"]["contracts"].pop()
        self.assertFalse(validator.is_valid(missing_contract))

        invalid_subject = copy.deepcopy(discovered)
        invalid_subject["subjects"]["needs"].append(
            {"identity": "valid", "occurrence": "\x00"}
        )
        self.assertFalse(validator.is_valid(invalid_subject))

        wrong_category = copy.deepcopy(discovered)
        need_schema = definitions["subjectsDiscovered"]["properties"][
            "subjects"
        ]["properties"]["needs"]["items"]
        need = self.sample_schema_value(need_schema, definitions)
        need["category"] = "strategy"
        wrong_category["subjects"]["needs"] = [need]
        self.assertFalse(validator.is_valid(wrong_category))

        semantic_prerequisite = self.sample_schema_value(
            definitions["prerequisiteRejected"], definitions
        )
        semantic_prerequisite["execution"]["prerequisite"] = "semantics"
        self.assertFalse(validator.is_valid(semantic_prerequisite))

    def test_qualify_schema_binds_dispositions_to_exact_payloads(self):
        schema, validator = self.qualification_schema_fixture("qualifyResult")
        definitions = schema["$defs"]
        completed = self.sample_schema_value(
            definitions["qualifyCompleted"], definitions
        )
        self.assertTrue(validator.is_valid(completed))
        self.assertEqual(
            ["operation", "adapter", "profile", "core"],
            [
                contract["kind"]
                for contract in completed["provenance"]["contracts"]
            ],
        )

        qualification = definitions["qualifyCompleted"]["properties"][
            "qualification"
        ]
        available_qualification = qualification["oneOf"][1]
        completed["qualification"] = self.sample_schema_value(
            available_qualification, definitions
        )
        self.assertTrue(validator.is_valid(completed))
        duplicate_request = copy.deepcopy(completed)
        duplicate_request["request"]["strategies"] = ["same", "same"]
        self.assertFalse(validator.is_valid(duplicate_request))

        semantic_prerequisite = self.sample_schema_value(
            definitions["prerequisiteRejected"], definitions
        )
        semantic_prerequisite["execution"]["prerequisite"] = "semantics"
        self.assertFalse(validator.is_valid(semantic_prerequisite))
        unrouted_proposal_schema = available_qualification["properties"][
            "unroutedProposals"
        ]["items"]
        pair_schema = available_qualification["properties"]["pairs"][
            "items"
        ]
        pair_proposal_schema = pair_schema["oneOf"][2]["properties"][
            "proposals"
        ]["items"]

        route_invalid = self.sample_schema_value(
            unrouted_proposal_schema, definitions
        )
        routed = copy.deepcopy(completed)
        routed["qualification"]["unroutedProposals"] = [route_invalid]
        self.assertTrue(validator.is_valid(routed))
        route_invalid["disposition"] = "formally-invalid"
        self.assertFalse(validator.is_valid(routed))

        for index, disposition in enumerate(
            ("formally-invalid", "formally-admissible")
        ):
            with self.subTest(proposal=disposition):
                changed = copy.deepcopy(completed)
                proposal = self.sample_schema_value(
                    pair_proposal_schema["oneOf"][index], definitions
                )
                pair = self.sample_schema_value(
                    pair_schema["oneOf"][2], definitions
                )
                pair["proposals"] = [proposal]
                changed["qualification"]["pairs"] = [pair]
                self.assertTrue(validator.is_valid(changed))
                proposal["disposition"] = "route-invalid"
                self.assertFalse(validator.is_valid(changed))

                wrong_context = copy.deepcopy(completed)
                wrong_context["qualification"]["unroutedProposals"] = [
                    self.sample_schema_value(
                        pair_proposal_schema["oneOf"][index], definitions
                    )
                ]
                self.assertFalse(validator.is_valid(wrong_context))

        wrong_pair_context = copy.deepcopy(completed)
        pair = self.sample_schema_value(pair_schema["oneOf"][2], definitions)
        pair["proposals"] = [
            self.sample_schema_value(unrouted_proposal_schema, definitions)
        ]
        wrong_pair_context["qualification"]["pairs"] = [pair]
        self.assertFalse(validator.is_valid(wrong_pair_context))

        for index, disposition in enumerate(
            (
                "invalid-selected-subjects",
                "proposal-missing",
                "proposals-assessed",
            )
        ):
            with self.subTest(pair=disposition):
                changed = copy.deepcopy(completed)
                pair = self.sample_schema_value(
                    pair_schema["oneOf"][index], definitions
                )
                changed["qualification"]["pairs"] = [pair]
                self.assertTrue(validator.is_valid(changed))
                pair["disposition"] = (
                    "proposals-assessed"
                    if disposition != "proposals-assessed"
                    else "proposal-missing"
                )
                self.assertFalse(validator.is_valid(changed))

        unavailable = copy.deepcopy(completed)
        unavailable["qualification"] = self.sample_schema_value(
            qualification["oneOf"][0], definitions
        )
        self.assertTrue(validator.is_valid(unavailable))
        unavailable["qualification"]["pairs"] = [
            self.sample_schema_value(pair_schema["oneOf"][0], definitions)
        ]
        self.assertFalse(validator.is_valid(unavailable))
        unavailable["qualification"]["pairs"] = []
        unavailable["qualification"]["subjectUnavailable"] = []
        self.assertFalse(validator.is_valid(unavailable))

    def test_readiness_schema_binds_dispositions_and_evidence_keys(self):
        schema, validator = self.readiness_schema_fixture()
        definitions = schema["$defs"]
        ready = self.sample_schema_value(definitions["ready"], definitions)
        self.assertTrue(validator.is_valid(ready))
        self.assertEqual([], ready["readiness"]["diagnostics"])
        self.assertEqual(
            ["operation", "adapter", "profile", "core"],
            [
                contract["kind"]
                for contract in ready["provenance"]["contracts"]
            ],
        )

        prerequisite_schemas = definitions["prerequisiteRejected"]["oneOf"]
        for index, stage in enumerate(
            ("notation", "profile", "structure", "semantics")
        ):
            with self.subTest(prerequisite=stage):
                prerequisite = self.sample_schema_value(
                    prerequisite_schemas[index], definitions
                )
                self.assertTrue(validator.is_valid(prerequisite))
                self.assertEqual(
                    stage, prerequisite["execution"]["prerequisite"]
                )
                if stage in ("notation", "profile"):
                    self.assertIsNone(prerequisite["context"]["readiness"])
                    self.assertEqual(
                        [], prerequisite["context"]["supplements"]
                    )
                else:
                    self.assertEqual(
                        "readiness",
                        prerequisite["context"]["readiness"]["role"],
                    )

        not_ready = self.sample_schema_value(
            definitions["notReady"], definitions
        )
        self.assertTrue(validator.is_valid(not_ready))
        not_ready["readiness"]["disposition"] = "ready"
        self.assertFalse(validator.is_valid(not_ready))

        mismatched_key = self.sample_schema_value(
            definitions["notReady"], definitions
        )
        planned_start_rule = next(
            rule_id
            for name, rule_id in self.core_companion[
                "evidenceReadinessSemantics"
            ]["ruleIds"].items()
            if self.core_companion["evidenceReadinessSemantics"][
                "evidenceKeyByRule"
            ][name]
            == "PlannedStartSlotKey"
        )
        mismatched_key["readiness"]["diagnostics"][0][
            "ruleId"
        ] = planned_start_rule
        self.assertFalse(validator.is_valid(mismatched_key))

        subject_unavailable = definitions["subjectUnavailable"]["oneOf"]
        unavailable = self.sample_schema_value(
            subject_unavailable[0], definitions
        )
        self.assertTrue(validator.is_valid(unavailable))
        self.assertIn("suppliedTraceIdentity", unavailable["readiness"])
        self.assertNotIn("graphIdentity", unavailable["readiness"])
        reconstruction = self.sample_schema_value(
            subject_unavailable[1], definitions
        )
        self.assertTrue(validator.is_valid(reconstruction))
        self.assertIn("graphIdentity", reconstruction["readiness"])
        self.assertIn("traceIdentity", reconstruction["readiness"])
        self.assertNotIn(
            "suppliedTraceIdentity", reconstruction["readiness"]
        )
        unavailable["readiness"]["reasons"] = []
        self.assertFalse(validator.is_valid(unavailable))

    def test_readiness_schema_rejects_impossible_unavailability_states(self):
        schema, validator = self.readiness_schema_fixture()
        definitions = schema["$defs"]
        variants = definitions["subjectUnavailable"]["oneOf"]
        binding = self.sample_schema_value(variants[0], definitions)
        binding_group_schema = variants[0]["properties"]["context"][
            "properties"
        ]["supplements"]["items"]
        binding_group = self.sample_schema_value(
            binding_group_schema, definitions
        )
        binding_diagnostic_schema = binding_group_schema["properties"][
            "diagnostics"
        ]["items"]
        binding_group["diagnostics"] = [
            self.sample_schema_value(binding_diagnostic_schema, definitions)
        ]
        binding["context"]["supplements"].append(binding_group)
        self.assertFalse(validator.is_valid(binding))

        supplied_trace = self.sample_schema_value(variants[1], definitions)
        reconstruction_group_schema = variants[1]["properties"]["context"][
            "properties"
        ]["supplements"]["items"]
        reconstruction_group = self.sample_schema_value(
            reconstruction_group_schema, definitions
        )
        reconstruction_diagnostic_schema = reconstruction_group_schema[
            "properties"
        ]["diagnostics"]["items"]
        reconstruction_group["diagnostics"] = [
            self.sample_schema_value(
                reconstruction_diagnostic_schema, definitions
            )
        ]
        supplied_trace["context"]["supplements"].append(
            reconstruction_group
        )
        self.assertTrue(validator.is_valid(supplied_trace))

        promotion = self.sample_schema_value(variants[2], definitions)
        mixed_reasons = copy.deepcopy(supplied_trace)
        mixed_reasons["readiness"]["reasons"].append(
            promotion["readiness"]["reasons"][0]
        )
        self.assertFalse(validator.is_valid(mixed_reasons))

    def test_assessment_schema_binds_variants_and_exit_classification(self):
        schema, validator = self.assessment_schema_fixture()
        definitions = schema["$defs"]

        for index, stage in enumerate(
            ("notation", "profile", "structure", "semantics")
        ):
            with self.subTest(prerequisite=stage):
                rejected = self.sample_schema_value(
                    definitions["prerequisiteRejected"]["oneOf"][index],
                    definitions,
                )
                self.assertTrue(validator.is_valid(rejected))
                self.assertEqual(
                    {
                        "status": "prerequisite-rejected",
                        "prerequisite": stage,
                        "exitClass": "subject-unavailable",
                        "exitCode": 3,
                    },
                    rejected["execution"],
                )
                self.assertEqual(
                    stage in ("structure", "semantics"),
                    rejected["context"]["assessment"] is not None,
                )

        expected = (
            ("subjectUnavailable", "subject-unavailable", 3),
            ("collectionInvalid", "primary-negative", 1),
            ("observationsInvalid", "primary-negative", 1),
            ("completed", "success", 0),
        )
        for name, exit_class, exit_code in expected:
            with self.subTest(variant=name):
                variant = self.sample_schema_value(
                    definitions[name], definitions
                )
                if name in ("observationsInvalid", "completed"):
                    observation = variant["assessment"]["observations"][0]
                    observation["observedAt"] = "2026-08-28T12:34:56Z"
                    if observation["value"]["kind"] == "quantitative":
                        observation["value"]["value"] = "1.5"
                self.assertTrue(validator.is_valid(variant))
                self.assertEqual(
                    exit_class, variant["execution"]["exitClass"]
                )
                self.assertEqual(exit_code, variant["execution"]["exitCode"])

                changed = copy.deepcopy(variant)
                changed["execution"]["exitCode"] = 2
                self.assertFalse(validator.is_valid(changed))

    def test_assessment_schema_preserves_mixed_source_order_without_aggregation(self):
        schema, validator = self.assessment_schema_fixture()
        definitions = schema["$defs"]
        invalid = self.sample_schema_value(
            definitions["observationsInvalid"], definitions
        )
        invalid_observation = invalid["assessment"]["observations"][0]
        invalid_observation["sourceOrdinal"] = 2
        invalid_observation["observedAt"] = "2026-08-28T12:35:00Z"
        invalid_observation["value"]["value"] = "1.5"

        completed = self.sample_schema_value(
            definitions["completed"], definitions
        )
        assessed_observation = completed["assessment"]["observations"][0]
        assessed_observation["sourceOrdinal"] = 1
        assessed_observation["observedAt"] = "2026-08-28T12:34:56Z"
        assessed_observation["value"]["value"] = "1.25"
        invalid["assessment"]["observations"] = [
            assessed_observation,
            invalid_observation,
        ]
        self.assertTrue(validator.is_valid(invalid))
        self.assertEqual(
            [1, 2],
            [
                observation["sourceOrdinal"]
                for observation in invalid["assessment"]["observations"]
            ],
        )
        self.assertNotIn("score", invalid["assessment"])
        self.assertIsNone(invalid["assessment"]["proof"])

        no_invalid_observation = copy.deepcopy(invalid)
        no_invalid_observation["assessment"]["observations"] = [
            assessed_observation
        ]
        self.assertFalse(validator.is_valid(no_invalid_observation))

        collection_invalid = self.sample_schema_value(
            definitions["collectionInvalid"], definitions
        )
        self.assertTrue(validator.is_valid(collection_invalid))
        self.assertEqual([], collection_invalid["assessment"]["observations"])
        self.assertIsNone(collection_invalid["assessment"]["proof"])

    def test_assessment_schema_executes_timestamp_and_domain_value_grammars(self):
        schema, validator = self.assessment_schema_fixture()
        definitions = schema["$defs"]
        completed = self.sample_schema_value(
            definitions["completed"], definitions
        )
        observation = completed["assessment"]["observations"][0]
        observation["observedAt"] = "2026-08-28T12:34:56.123Z"
        observation["value"] = {
            "kind": "quantitative",
            "value": "1.25",
            "unit": "seconds",
        }
        self.assertTrue(validator.is_valid(completed))

        for value in (
            {"kind": "ordinal", "scaleId": "maturity", "level": "high"},
            {"kind": "categorical", "value": "available"},
        ):
            with self.subTest(value=value["kind"]):
                changed = copy.deepcopy(completed)
                changed["assessment"]["observations"][0]["value"] = value
                self.assertTrue(validator.is_valid(changed))

        offset_timestamp = copy.deepcopy(completed)
        offset_timestamp["assessment"]["observations"][0][
            "observedAt"
        ] = "2026-08-28T14:34:56+02:00"
        self.assertFalse(validator.is_valid(offset_timestamp))

        noncanonical_number = copy.deepcopy(completed)
        noncanonical_number["assessment"]["observations"][0]["value"][
            "value"
        ] = "01.250"
        self.assertFalse(validator.is_valid(noncanonical_number))

    def test_assessment_scalar_patterns_are_posix_compatible(self):
        evidence_definitions = self.core_companion["evidenceInputSchema"][
            "$defs"
        ]
        for name in (
            "UtcTimestamp",
            "CanonicalDecimal",
            "CanonicalText",
            "Unit",
        ):
            with self.subTest(scalar=name):
                original = evidence_definitions[name]
                translated = COMPILER.assessment_scalar_schema(original)
                self.assertNotIn("(?:", translated["pattern"])
                expected = copy.deepcopy(original)
                if name in ("CanonicalText", "Unit"):
                    expected["pattern"] = (
                        COMPILER.PORTABLE_CANONICAL_TEXT_PATTERN
                    )
                    expected["allOf"] = [
                        {
                            "not": {
                                "pattern": "^"
                                + COMPILER.ECMA_WHITESPACE_CLASS
                            }
                        },
                        {
                            "not": {
                                "pattern": COMPILER.ECMA_WHITESPACE_CLASS
                                + "$"
                            }
                        },
                    ]
                else:
                    expected["pattern"] = expected["pattern"].replace(
                        "(?:", "("
                    )
                self.assertEqual(expected, translated)

        canonical = COMPILER.assessment_scalar_schema(
            evidence_definitions["CanonicalText"]
        )
        validator = Draft202012Validator(canonical)
        for value in ("sensor", "sensor A", "sensor\nA", "sensor\x00A"):
            with self.subTest(valid=value):
                self.assertTrue(validator.is_valid(value))
        for whitespace in COMPILER.ECMA_WHITESPACE:
            for value in (whitespace + "sensor", "sensor" + whitespace):
                with self.subTest(edge=ord(whitespace)):
                    self.assertFalse(validator.is_valid(value))

    def test_trace_schema_binds_gap_slots_and_endpoints_exactly(self):
        schema, validator = self.trace_schema_fixture()
        definitions = schema["$defs"]
        baseline = self.sample_schema_value(
            definitions["traceRejected"], definitions
        )
        rejected_roots = definitions["traceRejected"]["properties"]["trace"][
            "oneOf"
        ][1]
        baseline["trace"] = self.sample_schema_value(
            rejected_roots, definitions
        )
        self.assertTrue(validator.is_valid(baseline))
        gap = baseline["trace"]["roots"][0]["result"]["gaps"][0]

        for field, invalid in (
            ("slotKind", "ownership"),
            ("slotId", "strategy-qualifies-need"),
            ("ruleId", "core.trace.slot.strategy-qualifies-need"),
        ):
            with self.subTest(axis=field):
                changed = copy.deepcopy(baseline)
                changed_gap = changed["trace"]["roots"][0]["result"]["gaps"][0]
                changed_gap["slot"][field] = invalid
                self.assertFalse(validator.is_valid(changed))

        wrong_endpoint = copy.deepcopy(baseline)
        wrong_gap = wrong_endpoint["trace"]["roots"][0]["result"]["gaps"][0]
        wrong_gap["endpoints"][0]["variable"] = "strategy"
        self.assertFalse(validator.is_valid(wrong_endpoint))

        partial_schema = rejected_roots["properties"]["roots"]["contains"][
            "properties"
        ]["result"]
        gap_schema = partial_schema["oneOf"][0]["properties"]["gaps"][
            "items"
        ]
        unbound = copy.deepcopy(baseline)
        unbound_gap = self.sample_schema_value(
            gap_schema["oneOf"][1], definitions
        )
        unbound["trace"]["roots"][0]["result"]["gaps"][0] = unbound_gap
        self.assertTrue(validator.is_valid(unbound))

        for field in ("establishedBindings", "unresolvedVariables"):
            with self.subTest(axis=f"unbound-{field}"):
                changed = copy.deepcopy(unbound)
                changed_gap = changed["trace"]["roots"][0]["result"][
                    "gaps"
                ][0]
                if field == "establishedBindings":
                    changed_gap[field][0]["variable"] = "strategy"
                else:
                    changed_gap[field][0] = "strategy"
                self.assertFalse(validator.is_valid(changed))

    def test_trace_schema_requires_every_complete_support_occurrence(self):
        schema, validator = self.trace_schema_fixture()
        definitions = schema["$defs"]
        accepted = self.sample_schema_value(
            definitions["traceAccepted"], definitions
        )
        self.assertTrue(validator.is_valid(accepted))

        for support in ("relationSupport", "ownershipSupport"):
            with self.subTest(result="accepted", support=support):
                changed = copy.deepcopy(accepted)
                changed["trace"]["roots"][0]["result"][support][0][
                    "occurrences"
                ] = []
                self.assertFalse(validator.is_valid(changed))

        rejected_roots = definitions["traceRejected"]["properties"]["trace"][
            "oneOf"
        ][1]
        mixed = self.sample_schema_value(
            definitions["traceRejected"], definitions
        )
        mixed["trace"] = self.sample_schema_value(rejected_roots, definitions)
        complete_root = self.sample_schema_value(
            rejected_roots["properties"]["roots"]["items"], definitions
        )
        mixed["trace"]["roots"].append(complete_root)
        self.assertTrue(validator.is_valid(mixed))

        for support in ("relationSupport", "ownershipSupport"):
            with self.subTest(result="mixed", support=support):
                changed = copy.deepcopy(mixed)
                changed["trace"]["roots"][1]["result"][support][0][
                    "occurrences"
                ] = []
                self.assertFalse(validator.is_valid(changed))

    def test_trace_schema_separates_local_and_global_partial_failures(self):
        schema, validator = self.trace_schema_fixture()
        definitions = schema["$defs"]
        rejected_roots = definitions["traceRejected"]["properties"]["trace"][
            "oneOf"
        ][1]
        local = self.sample_schema_value(
            definitions["traceRejected"], definitions
        )
        local["trace"] = self.sample_schema_value(rejected_roots, definitions)
        self.assertTrue(validator.is_valid(local))

        partial_schema = rejected_roots["properties"]["roots"]["contains"][
            "properties"
        ]["result"]
        local_partial, global_partial = partial_schema["oneOf"]
        local_gap_schema = local_partial["properties"]["gaps"]["items"]
        global_gap_schema = global_partial["properties"]["gaps"][
            "prefixItems"
        ][0]

        global_disposition = copy.deepcopy(local)
        global_disposition["trace"]["roots"][0]["result"]["gaps"][0][
            "disposition"
        ] = "globally-inconsistent"
        self.assertFalse(validator.is_valid(global_disposition))

        mixed_local = copy.deepcopy(local)
        mixed_local["trace"]["roots"][0]["result"]["gaps"].append(
            self.sample_schema_value(global_gap_schema, definitions)
        )
        self.assertFalse(validator.is_valid(mixed_local))

        global_result = self.sample_schema_value(global_partial, definitions)
        global_failure = copy.deepcopy(local)
        global_failure["trace"]["roots"][0]["result"] = global_result
        self.assertTrue(validator.is_valid(global_failure))

        nonempty_projection = copy.deepcopy(global_failure)
        nonempty_projection["trace"]["roots"][0]["result"][
            "variableProjections"
        ][0]["identities"].append("x")
        self.assertFalse(validator.is_valid(nonempty_projection))

        mixed_global = copy.deepcopy(global_failure)
        mixed_global["trace"]["roots"][0]["result"]["gaps"].append(
            self.sample_schema_value(local_gap_schema, definitions)
        )
        self.assertFalse(validator.is_valid(mixed_global))

        repeated_global = copy.deepcopy(global_failure)
        repeated_global["trace"]["roots"][0]["result"]["gaps"].append(
            copy.deepcopy(
                repeated_global["trace"]["roots"][0]["result"]["gaps"][0]
            )
        )
        self.assertFalse(validator.is_valid(repeated_global))

    def test_validate_schema_rejects_multi_axis_negative_mutations(self):
        schema, validator = self.validate_schema_fixture()
        definitions = schema["$defs"]

        baseline = self.validate_variant_fixture(schema, "notationAccepted")
        self.assertTrue(validator.is_valid(baseline))
        for field, invalid in (("role", "supplemental"), ("ordinal", 1)):
            with self.subTest(axis=f"model-source-{field}"):
                changed = copy.deepcopy(baseline)
                changed["context"]["authority"]["model"][field] = invalid
                self.assertFalse(validator.is_valid(changed))

        missing_notation_rule = copy.deepcopy(baseline)
        missing_notation_rule["context"]["authority"]["notationRules"].pop()
        self.assertFalse(validator.is_valid(missing_notation_rule))

        earlier_supplement = copy.deepcopy(baseline)
        earlier_supplement["context"]["supplements"] = [
            {
                "reference": "x",
                "sha256": "0" * 64,
                "diagnostics": [],
            }
        ]
        self.assertFalse(validator.is_valid(earlier_supplement))

        profile_rejected = self.validate_variant_fixture(
            schema, "profileRejected"
        )
        self.assertTrue(validator.is_valid(profile_rejected))
        profile_positive = self.validate_variant_schema(
            schema, "profileAccepted"
        )["properties"][
            "diagnostics"
        ]["properties"]["modelDiagnostics"]["items"]["oneOf"][0]
        positive_only = copy.deepcopy(profile_rejected)
        positive_only["diagnostics"]["modelDiagnostics"] = [
            self.sample_schema_value(profile_positive, definitions)
        ]
        self.assertFalse(validator.is_valid(positive_only))

        structure_rejection = self.validate_variant_schema(
            schema, "structureRejected"
        )["properties"][
            "diagnostics"
        ]["properties"]["modelDiagnostics"]["contains"]["oneOf"][0]
        wrong_stage = copy.deepcopy(profile_rejected)
        wrong_stage["diagnostics"]["modelDiagnostics"] = [
            self.sample_schema_value(structure_rejection, definitions)
        ]
        self.assertFalse(validator.is_valid(wrong_stage))

        unavailable = self.validate_variant_fixture(
            schema, "semanticsUnavailable"
        )
        binding_items = self.validate_variant_schema(
            schema, "semanticsUnavailable"
        )["properties"][
            "context"
        ]["properties"]["supplements"]["items"]["properties"][
            "diagnostics"
        ]["items"]
        binding_schema = self.resolve_local_schema(
            binding_items, definitions
        )["oneOf"][0]
        binding = self.sample_schema_value(binding_schema, definitions)
        for name in ("semanticsAccepted", "semanticsRejected"):
            with self.subTest(axis=f"binding-in-{name}"):
                changed = self.validate_variant_fixture(schema, name)
                changed["context"]["supplements"] = [
                    {
                        "reference": "x",
                        "sha256": "0" * 64,
                        "diagnostics": [binding],
                    }
                ]
                self.assertFalse(validator.is_valid(changed))

        wrong_three_contracts = copy.deepcopy(baseline)
        wrong_three_contracts["provenance"]["contracts"].append(
            copy.deepcopy(
                unavailable["provenance"]["contracts"][-1]
            )
        )
        self.assertFalse(validator.is_valid(wrong_three_contracts))

        structure_accepted = self.validate_variant_fixture(
            schema, "structureAccepted"
        )
        wrong_four_contracts = copy.deepcopy(structure_accepted)
        wrong_four_contracts["provenance"]["contracts"].pop()
        self.assertFalse(validator.is_valid(wrong_four_contracts))
        wrong_order = copy.deepcopy(structure_accepted)
        wrong_order["provenance"]["contracts"][0:2] = reversed(
            wrong_order["provenance"]["contracts"][0:2]
        )
        self.assertFalse(validator.is_valid(wrong_order))

        foreign_operation = copy.deepcopy(baseline)
        foreign_operation["provenance"]["contracts"][0]["identity"] = (
            "foreign.operation"
        )
        self.assertFalse(validator.is_valid(foreign_operation))
        foreign_profile = copy.deepcopy(baseline)
        foreign_profile["context"]["authority"]["profile"]["identity"] = (
            "foreign.profile"
        )
        self.assertFalse(validator.is_valid(foreign_profile))
        foreign_core = copy.deepcopy(structure_accepted)
        foreign_core["provenance"]["contracts"][3]["identity"] = (
            "foreign.core"
        )
        self.assertFalse(validator.is_valid(foreign_core))

        notation_for_semantics = self.validate_variant_fixture(
            schema, "notationRejected", "semantics"
        )
        self.assertEqual(
            "semantics", notation_for_semantics["request"]["level"]
        )
        self.assertEqual([], notation_for_semantics["context"]["supplements"])
        self.assertEqual(
            4, len(notation_for_semantics["provenance"]["contracts"])
        )
        self.assertTrue(validator.is_valid(notation_for_semantics))
        wrong_notation_contracts = copy.deepcopy(notation_for_semantics)
        wrong_notation_contracts["provenance"]["contracts"].pop()
        self.assertFalse(validator.is_valid(wrong_notation_contracts))

        structure_for_semantics = self.validate_variant_fixture(
            schema, "structureRejected", "semantics"
        )
        structure_for_semantics["context"]["supplements"] = [
            {"reference": "x", "sha256": "0" * 64, "diagnostics": []}
        ]
        self.assertTrue(validator.is_valid(structure_for_semantics))
        mismatched_structure_level = copy.deepcopy(structure_for_semantics)
        mismatched_structure_level["request"]["level"] = "structure"
        self.assertFalse(validator.is_valid(mismatched_structure_level))

    def test_validate_unavailable_covers_binding_core_and_combined_witnesses(self):
        schema, validator = self.validate_schema_fixture()
        definitions = schema["$defs"]
        unavailable_schema = self.validate_variant_schema(
            schema, "semanticsUnavailable"
        )
        witness_items = unavailable_schema["properties"]["execution"][
            "properties"
        ]["coreWitnesses"]["items"]
        witness_schemas = self.resolve_local_schema(
            witness_items, definitions
        )["oneOf"]
        binding_items = unavailable_schema["properties"]["context"][
            "properties"
        ]["supplements"]["items"]["properties"]["diagnostics"]["items"]
        binding_schema = self.resolve_local_schema(
            binding_items, definitions
        )["oneOf"][0]
        semantic_schema = self.validate_variant_schema(
            schema, "semanticsRejected"
        )["properties"][
            "diagnostics"
        ]["properties"]["modelDiagnostics"]["contains"]["oneOf"][0]

        binding_only = self.validate_variant_fixture(
            schema, "semanticsUnavailable"
        )
        binding_only["execution"]["coreWitnesses"] = []
        binding_only["context"]["supplements"] = [
            {
                "reference": "x",
                "sha256": "0" * 64,
                "diagnostics": [
                    self.sample_schema_value(binding_schema, definitions)
                ],
            }
        ]
        self.assertTrue(validator.is_valid(binding_only))

        core_only = self.validate_variant_fixture(
            schema, "semanticsUnavailable"
        )
        core_only["execution"]["coreWitnesses"] = [
            self.sample_schema_value(witness_schemas[0], definitions)
        ]
        self.assertEqual([], core_only["context"]["supplements"])
        self.assertTrue(validator.is_valid(core_only))

        combined = copy.deepcopy(binding_only)
        combined["execution"]["coreWitnesses"].append(
            self.sample_schema_value(witness_schemas[0], definitions)
        )
        combined["diagnostics"]["modelDiagnostics"] = [
            self.sample_schema_value(semantic_schema, definitions)
        ]
        self.assertTrue(validator.is_valid(combined))

        no_witness = copy.deepcopy(core_only)
        no_witness["execution"]["coreWitnesses"] = []
        self.assertFalse(validator.is_valid(no_witness))

        ordinal_key_gap = copy.deepcopy(binding_only)
        ordinal_key_gap["context"]["supplements"] = {
            "7": binding_only["context"]["supplements"][0]
        }
        self.assertFalse(validator.is_valid(ordinal_key_gap))

    def test_rule_definition_failure_has_no_unencodable_authority(self):
        schema = json.loads(
            COMPILER.render_schema(self.validate_contract()[3][2])
        )
        invalid = schema["$defs"]["ruleInvalid"]
        self.assertEqual(
            ["schema", "kind", "diagnostics"], invalid["required"]
        )
        self.assertNotIn("authority", invalid["properties"])

    def test_rule_authority_requires_only_available_contract_digests(self):
        schema = json.loads(
            COMPILER.render_schema(self.validate_contract()[3][2])
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
            COMPILER.render_schema(self.validate_contract()[3][4])
        )
        selection = schema["$defs"]["selectionFailure"]
        multiple = selection["oneOf"][3]
        self.assertEqual(2, multiple["properties"]["adapters"]["minItems"])

    def test_post_acquisition_view_failures_require_source_identity(self):
        schema = json.loads(
            COMPILER.render_schema(self.validate_contract()[3][4])
        )
        self.assertIn("source", schema["$defs"]["selectionFailed"]["required"])
        self.assertIn("source", schema["$defs"]["decodeFailed"]["required"])

    def test_view_failure_diagnostics_share_adapter_preparation_stage(self):
        schema = json.loads(
            COMPILER.render_schema(self.validate_contract()[3][4])
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
            COMPILER.render_schema(self.validate_contract()[3][4])
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
            COMPILER.render_schema(self.validate_contract()[3][4])
        )
        path_step = schema["$defs"]["sourceLocation"]["properties"]["path"][
            "items"
        ]
        self.assertEqual(1, path_step["properties"]["ordinal"]["minimum"])

    def test_diagnostic_schema_is_owner_inventory_exact(self):
        fragment = self.validate_contract()[4][0]
        schema = json.loads(
            COMPILER.render_schema_fragment(
                fragment, self.profile_inventory, self.core_inventory
            )
        )
        self.assertEqual("o2i.operation.diagnostic/v2", fragment.reference)
        self.assertEqual("#/$defs/preparedDiagnosticDocument", schema["$ref"])
        self.assertEqual(
            COMPILER.diagnostic_definitions(
                self.profile_inventory, self.core_inventory
            ),
            schema["$defs"],
        )
        document = schema["$defs"]["preparedDiagnosticDocument"]
        self.assertEqual(
            ["schema", "authority", "modelDiagnostics", "supplementalSources"],
            document["required"],
        )
        authority = schema["$defs"]["preparedAuthority"]
        self.assertEqual(
            ["adapter", "notationRules", "profile", "model"],
            authority["required"],
        )
        model_diagnostics = schema["$defs"]["modelDiagnostic"]["oneOf"]
        self.assertEqual(195, len(model_diagnostics))
        notation_diagnostics = [
            row
            for row in model_diagnostics
            if row["properties"]["producer"]["const"]
            == "notation-assessment"
        ]
        self.assertEqual(38, len(notation_diagnostics))
        self.assertEqual(
            {
                "archimate-notation-" + token
                for token in COMPILER.NOTATION_ISSUE_TOKENS
            },
            {
                row["properties"]["evidenceKind"]["const"]
                for row in notation_diagnostics
            },
        )
        self.assertEqual(
            {
                ("adapter", "notation", "error", "model-finding")
            },
            {
                (
                    row["properties"]["owner"]["const"],
                    row["properties"]["stage"]["const"],
                    row["properties"]["severity"]["const"],
                    row["properties"]["disposition"]["const"],
                )
                for row in notation_diagnostics
            },
        )
        self.assertNotIn("ruleId", notation_diagnostics[0]["properties"])
        notation_rules = authority["properties"]["notationRules"]
        self.assertEqual(38, notation_rules["minItems"])
        self.assertEqual(38, notation_rules["maxItems"])
        self.assertEqual(
            [
                "archimate-notation-" + token
                for token in COMPILER.NOTATION_ISSUE_TOKENS
            ],
            [
                row["properties"]["evidenceKind"]["const"]
                for row in notation_rules["prefixItems"]
            ],
        )
        notation_by_kind = {
            row["properties"]["evidenceKind"]["const"]: row
            for row in notation_diagnostics
        }
        evidence_definitions = [
            "notationOccurrenceEvidence",
            "notationValueEvidence",
            "notationReferenceEvidence",
        ]
        self.assertEqual(
            COMPILER.NOTATION_ISSUE_TOKENS,
            tuple(COMPILER.NOTATION_OBSERVATION_KINDS),
        )
        for token, kinds in COMPILER.NOTATION_OBSERVATION_KINDS.items():
            evidence = notation_by_kind["archimate-notation-" + token][
                "properties"
            ]["evidence"]
            actual_references = (
                [evidence["$ref"]]
                if len(kinds) == 1
                else [alternative["$ref"] for alternative in evidence["oneOf"]]
            )
            self.assertEqual(
                [
                    "#/$defs/notation" + kind.capitalize() + "Evidence"
                    for kind in kinds
                ],
                actual_references,
            )
        self.assertEqual(
            "#/$defs/notationOccurrenceEvidence",
            notation_by_kind["archimate-notation-model-identity-missing"]
            ["properties"]["evidence"]["$ref"],
        )
        self.assertEqual(
            {
                "#/$defs/notationOccurrenceEvidence",
                "#/$defs/notationValueEvidence",
            },
            {
                alternative["$ref"]
                for alternative in notation_by_kind[
                    "archimate-notation-model-identity-multiplicity"
                ]["properties"]["evidence"]["oneOf"]
            },
        )
        self.assertEqual(
            "#/$defs/notationReferenceEvidence",
            notation_by_kind["archimate-notation-model-identity-duplicate"]
            ["properties"]["evidence"]["$ref"],
        )
        notation_observations = [
            schema["$defs"][name]["properties"]["fields"]["prefixItems"][1][
                "properties"
            ]["values"]["items"]
            for name in evidence_definitions
        ]
        self.assertEqual(
            {"type": "string"},
            notation_observations[1]["properties"]["value"],
        )
        self.assertEqual(
            {"type": "string"},
            notation_observations[2]["properties"]["value"],
        )
        binding_diagnostics = schema["$defs"]["supplementalSources"][
            "patternProperties"
        ]["^(0|[1-9][0-9]*)$"]["properties"]["diagnostics"]["items"][
            "oneOf"
        ]
        self.assertEqual(4, len(binding_diagnostics))
        self.assertEqual(
            {"process-failure"},
            {
                row["properties"]["disposition"]["const"]
                for row in binding_diagnostics
            },
        )
        self.assertEqual(
            {"const": "supplemental-binding"},
            binding_diagnostics[0]["properties"]["producer"],
        )
        target_owner = self.find_diagnostic(
            model_diagnostics,
            "structure-assessment",
            "core.contextualization.target-owner-cardinality",
        )
        alternatives = target_owner["properties"]["evidence"]["oneOf"]
        self.assertEqual(2, len(alternatives))
        self.assertEqual(
            [(0, 0), (2, None)],
            [
                (
                    branch["properties"]["fields"]["prefixItems"][1][
                        "properties"
                    ]["values"]["minItems"],
                    branch["properties"]["fields"]["prefixItems"][1][
                        "properties"
                    ]["values"].get("maxItems"),
                )
                for branch in alternatives
            ],
        )
        semantic = self.find_diagnostic(
            model_diagnostics,
            "semantics-assessment",
            "core.collective-strategy-realization.asserted-collective-coverage",
        )
        semantic_fields = semantic["properties"]["evidence"]["oneOf"][0][
            "properties"
        ]["fields"]
        self.assertEqual(
            ["claim", "uncovered-target-member"],
            [
                field["properties"]["role"]["const"]
                for field in semantic_fields["prefixItems"]
            ],
        )

    def test_mutated_profile_inventory_digest_is_rejected(self):
        inventory = copy.deepcopy(self.profile_inventory)
        inventory["diagnostics"][0]["alternatives"][0]["fields"][0][
            "minimum"
        ] = 0
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "profile-diagnostic.json"
            path.write_text(json.dumps(inventory) + "\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "inventory digest differs"):
                COMPILER.validate(
                    PROFILE_COMPANION,
                    path,
                    CORE_OWNER_DIAGNOSTIC_INVENTORY,
                )

    def test_mutated_core_inventory_digest_is_rejected(self):
        inventory = copy.deepcopy(self.core_inventory)
        inventory["owners"]["semantics"][0]["alternatives"][0]["fields"].reverse()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "core-diagnostic.json"
            path.write_text(json.dumps(inventory) + "\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "inventory digest differs"):
                COMPILER.validate(
                    PROFILE_COMPANION,
                    PROFILE_DIAGNOSTIC_INVENTORY,
                    path,
                )

    def test_mutated_core_companion_digest_is_rejected(self):
        companion = copy.deepcopy(self.core_companion)
        companion["traceSemantics"]["variableCatalog"].reverse()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "semantics.json"
            path.write_text(json.dumps(companion) + "\n", encoding="utf-8")
            with self.assertRaisesRegex(
                ValueError, "Core companion digest differs from owner inventory"
            ):
                COMPILER.render_outputs(
                    PROFILE_COMPANION,
                    PROFILE_DIAGNOSTIC_INVENTORY,
                    CORE_OWNER_DIAGNOSTIC_INVENTORY,
                    path,
                )

    def test_semantic_role_order_is_projected_without_reconstruction(self):
        profile = copy.deepcopy(self.profile_inventory)
        core = copy.deepcopy(self.core_inventory)
        target = next(
            row
            for row in core["owners"]["semantics"]
            if row["ruleId"]
            == "core.collective-strategy-realization.asserted-collective-coverage"
        )
        target["alternatives"][0]["fields"].reverse()
        definitions = COMPILER.diagnostic_definitions(profile, core)
        diagnostic = self.find_diagnostic(
            definitions["modelDiagnostic"]["oneOf"],
            "semantics-assessment",
            target["ruleId"],
        )
        fields = diagnostic["properties"]["evidence"]["oneOf"][0][
            "properties"
        ]["fields"]["prefixItems"]
        self.assertEqual(
            ["uncovered-target-member", "claim"],
            [field["properties"]["role"]["const"] for field in fields],
        )

    def find_diagnostic(self, rows, producer, rule_id):
        matches = [
            row
            for row in rows
            if row["properties"]["producer"]["const"] == producer
            and row["properties"]["ruleId"]["const"] == rule_id
        ]
        self.assertEqual(1, len(matches))
        return matches[0]

    def test_completed_views_alone_has_the_exact_operation_envelope(self):
        document = self.validate_contract()[3][4]
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
            COMPILER.render_schema(self.validate_contract()[3][4])
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
                self.validate_contract(path)

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
