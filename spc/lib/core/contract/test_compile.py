#!/usr/bin/env python3

import copy
import importlib.util
import json
import re
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("compile_core_contract", HERE / "compile.py")
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("cannot load Core contract compiler")
COMPILER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COMPILER)

SUPPLEMENTAL_RULE_CONSTRUCTOR_ORACLE = {
    "utf8": "GeneratedSupplementalUtf8RuleIdentity",
    "jsonSyntax": "GeneratedSupplementalJsonSyntaxRuleIdentity",
    "duplicateMember": "GeneratedSupplementalDuplicateMemberRuleIdentity",
    "topLevelObject": "GeneratedSupplementalTopLevelObjectRuleIdentity",
    "typeMember": "GeneratedSupplementalTypeMemberRuleIdentity",
    "admittedType": "GeneratedSupplementalAdmittedTypeRuleIdentity",
    "requiredMember": "GeneratedSupplementalRequiredMemberRuleIdentity",
    "unknownMember": "GeneratedSupplementalUnknownMemberRuleIdentity",
    "valueKind": "GeneratedSupplementalValueKindRuleIdentity",
    "scalarGrammar": "GeneratedSupplementalScalarGrammarRuleIdentity",
    "arrayCardinality": "GeneratedSupplementalArrayCardinalityRuleIdentity",
    "arrayDistinctness": "GeneratedSupplementalArrayDistinctnessRuleIdentity",
    "subjectCardinality": "GeneratedSupplementalSubjectCardinalityRuleIdentity",
    "identityUnknown": "GeneratedSupplementalIdentityUnknownRuleIdentity",
    "identityAmbiguous": "GeneratedSupplementalIdentityAmbiguousRuleIdentity",
    "identityWrongType": "GeneratedSupplementalIdentityWrongTypeRuleIdentity",
    "identityOutOfSelectedView": (
        "GeneratedSupplementalIdentityOutOfSelectedViewRuleIdentity"
    ),
    "modelIdentityUnicodeScalar": (
        "GeneratedSupplementalModelIdentityUnicodeScalarRuleIdentity"
    ),
    "modelIdentityNul": "GeneratedSupplementalModelIdentityNulRuleIdentity",
}


class CoreContractCompilerTest(unittest.TestCase):
    def setUp(self):
        self.companion = json.loads(COMPILER.COMPANION.read_text(encoding="utf-8"))

    def compile_value(self, value):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "semantics.json"
            path.write_text(
                json.dumps(value, indent=2, ensure_ascii=False) + "\n",
                encoding="utf-8",
            )
            with patch.object(COMPILER, "COMPANION", path):
                return COMPILER.compile_contract()

    def refresh_declared_shape(self, value):
        value["companionFormatContract"]["shapeSha256"] = (
            COMPILER.shape_sha256(value)
        )

    def semantic_evidence_contract(self, companion):
        rules = COMPILER.rule_inventory(companion)
        semantic_rules = COMPILER.rule_stage_partition(companion, rules)["semantics"]
        return COMPILER.semantic_evidence_contract(companion, semantic_rules)

    def assert_supplemental_rule_associations(self, rendered):
        rule_ids = self.companion["supplementalInputContract"]["ruleIds"]
        self.assertEqual(
            set(SUPPLEMENTAL_RULE_CONSTRUCTOR_ORACLE),
            set(rule_ids),
        )
        expected_constructors = [
            SUPPLEMENTAL_RULE_CONSTRUCTOR_ORACLE[key] for key in rule_ids
        ]

        data_match = re.search(
            r"data GeneratedSupplementalRuleIdentity\n"
            r"(?P<body>.*?)\n  deriving \(Bounded, Enum, Eq, Ord, Show\)",
            rendered,
            re.DOTALL,
        )
        self.assertIsNotNone(data_match)
        data_constructors = re.findall(
            r"^  (?:=|\|) (\w+)$",
            data_match.group("body"),
            re.MULTILINE,
        )
        self.assertEqual(expected_constructors, data_constructors)

        inventory_match = re.search(
            r"generatedSupplementalRuleIdentities =\n"
            r"(?P<body>.*?)\n\n",
            rendered,
            re.DOTALL,
        )
        self.assertIsNotNone(inventory_match)
        inventory_constructors = re.findall(
            r"GeneratedSupplemental\w+RuleIdentity",
            inventory_match.group("body"),
        )
        self.assertEqual(expected_constructors, inventory_constructors)

        projection_start = rendered.index(
            "generatedSupplementalRuleIdentityText value ="
        )
        projection_end = rendered.index(
            "\ngeneratedSupplementalRuleIdentities ::", projection_start
        )
        projection = rendered[projection_start:projection_end]
        for key, rule in rule_ids.items():
            constructor = SUPPLEMENTAL_RULE_CONSTRUCTOR_ORACLE[key]
            literal = json.dumps(rule, ensure_ascii=True)
            self.assertRegex(
                projection,
                rf"    {constructor} ->(?: |\n      ){re.escape(literal)}",
            )
            self.assertEqual(3, len(re.findall(rf"\b{constructor}\b", rendered)))

    def test_canonical_companion_compiles_deterministically(self):
        first = COMPILER.compile_contract()
        second = COMPILER.compile_contract()
        self.assertEqual(first, second)
        self.assertIn(
            f'contractSha256 =\n  "{COMPILER.EXPECTED_SHA256}"',
            first,
        )
        self.assertIn("data GeneratedQualifiedEndpoint", first)
        self.assertIn("generatedCarrierCategories", first)
        self.assertIn("lookupGeneratedCarrierCategory", first)
        self.assertIn("generatedO2ITypes", first)
        self.assertIn("lookupGeneratedO2IType", first)
        self.assertIn("data GeneratedRelationToken", first)
        self.assertIn("data GeneratedSemanticRelation", first)
        self.assertIn("data GeneratedStructuredPropositionFamily", first)
        self.assertIn("data GeneratedQualificationProposalRole", first)
        self.assertIn("generatedQualificationProposalRoles", first)
        self.assertIn("lookupGeneratedQualificationProposalRole", first)
        self.assertIn("generatedParticipantCompletenessValues", first)
        self.assertIn("lookupGeneratedParticipantCompletenessId", first)
        self.assertIn("lookupGeneratedParticipantCompletenessToken", first)
        self.assertIn("generatedQualifiedEndpointRows", first)
        self.assertIn("generatedSemanticRelationRows", first)
        self.assertIn("generatedStructuredFamilyRows", first)
        self.assertIn("data GeneratedSemanticEvidenceSchema", first)
        self.assertIn("data GeneratedSemanticRuleIdentity", first)
        self.assertIn("data GeneratedSemanticRule", first)
        self.assertIn("generatedSemanticRuleIdentities ::", first)
        self.assertIn("generatedSemanticEvidenceSchemaFields", first)
        self.assertIn("generatedSemanticRuleEvidenceSchema", first)
        self.assertEqual(
            6,
            len(
                re.findall(
                    r"^  Generated\w+Witness\n"
                    r"    :: GeneratedSemanticEvidenceSchemaWitness",
                    first,
                    re.MULTILINE,
                )
            ),
        )
        self.assertEqual(
            25,
            len(
                re.findall(
                    r"^  \w+Rule\n"
                    r"    :: GeneratedSemanticRule '",
                    first,
                    re.MULTILINE,
                )
            ),
        )
        self.assertEqual(
            58,
            len(
                re.findall(
                    r"^  (?:=|\|) \w+RuleIdentity$",
                    first,
                    re.MULTILINE,
                )
            ),
        )
        self.assertRegex(
            first,
            r"semanticsRuleIds =\n"
            r"  generatedSemanticRuleIdentityText "
            r"<\$> generatedSemanticRuleIdentities",
        )
        self.assert_supplemental_rule_associations(first)

    def test_supplemental_constructor_association_mutation_is_rejected(self):
        canonical = COMPILER.supplemental_rule_identity_associations

        def mutate(companion):
            associations = canonical(companion)
            utf8_constructor, utf8_text = associations["utf8"]
            json_constructor, json_text = associations["jsonSyntax"]
            associations["utf8"] = (json_constructor, utf8_text)
            associations["jsonSyntax"] = (utf8_constructor, json_text)
            return associations

        with patch.object(
            COMPILER, "supplemental_rule_identity_associations", mutate
        ):
            rendered = COMPILER.compile_contract()
        with self.assertRaises(AssertionError):
            self.assert_supplemental_rule_associations(rendered)

    def test_supplemental_complete_key_binding_mutation_is_rejected(self):
        canonical = COMPILER.supplemental_rule_identity_associations

        def mutate(companion):
            associations = canonical(companion)
            associations["utf8"], associations["jsonSyntax"] = (
                associations["jsonSyntax"],
                associations["utf8"],
            )
            return associations

        with patch.object(
            COMPILER, "supplemental_rule_identity_associations", mutate
        ):
            rendered = COMPILER.compile_contract()
        with self.assertRaises(AssertionError):
            self.assert_supplemental_rule_associations(rendered)

    def test_duplicate_object_member_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "semantics.json"
            path.write_text('{"schema":"one","schema":"two"}\n', encoding="utf-8")
            with patch.object(COMPILER, "COMPANION", path):
                with self.assertRaisesRegex(ValueError, "duplicate JSON object member"):
                    COMPILER.compile_contract()

    def test_shape_drift_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        changed["unexpected"] = True
        self.refresh_declared_shape(changed)
        with self.assertRaisesRegex(ValueError, "accepted shape SHA-256"):
            self.compile_value(changed)

    def test_missing_member_is_rejected_after_shape_recalculation(self):
        changed = copy.deepcopy(self.companion)
        del changed["traceSemantics"]
        self.refresh_declared_shape(changed)
        with self.assertRaisesRegex(ValueError, "accepted shape SHA-256"):
            self.compile_value(changed)

    def test_wrong_json_kind_is_rejected_after_shape_recalculation(self):
        changed = copy.deepcopy(self.companion)
        changed["traceSemantics"] = []
        self.refresh_declared_shape(changed)
        with self.assertRaisesRegex(ValueError, "accepted shape SHA-256"):
            self.compile_value(changed)

    def test_same_kind_scalar_mutation_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        changed["coreIdentity"]["version"] = "0.3.1"
        with self.assertRaisesRegex(ValueError, "Core identity"):
            self.compile_value(changed)

    def test_unchecked_same_kind_scalar_mutation_is_rejected_by_file_digest(self):
        changed = copy.deepcopy(self.companion)
        changed["futureGraphExchangeBoundary"]["status"] += "-drift"
        with self.assertRaisesRegex(ValueError, "accepted file SHA-256"):
            self.compile_value(changed)

    def test_selected_view_precedence_regression_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        precedence = changed["selectedViewDependencyContract"]["outcomePrecedence"]
        precedence[2], precedence[3] = precedence[3], precedence[2]
        with self.assertRaisesRegex(ValueError, "selected View identity precedence"):
            self.compile_value(changed)

    def test_evidence_precedence_regression_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        precedence = changed["evidenceInputDecoderContract"][
            "identityResolutionPrecedence"
        ]
        precedence[2], precedence[3] = precedence[3], precedence[2]
        with self.assertRaisesRegex(ValueError, "evidence identity precedence"):
            self.compile_value(changed)

    def test_rule_inventory_drift_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        inventory = changed["ruleIdentityContract"]["completeRuleInventory"]
        inventory[-1] += "-drift"
        with self.assertRaisesRegex(ValueError, "complete Core rule inventory derivation"):
            self.compile_value(changed)

    def test_rule_stage_partition_overlap_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        partition = changed["ruleExplanationContract"]["stagePartition"]
        partition["trace"][0] = partition["structure"][0]
        rules = COMPILER.rule_inventory(changed)
        with self.assertRaisesRegex(ValueError, "Core rule stage partition"):
            COMPILER.rule_stage_partition(changed, rules)

    def test_rule_stage_partition_omission_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        partition = changed["ruleExplanationContract"]["stagePartition"]
        del partition["trace"][0]
        rules = COMPILER.rule_inventory(changed)
        with self.assertRaisesRegex(
            ValueError, "complete disjoint Core rule stage partition"
        ):
            COMPILER.rule_stage_partition(changed, rules)

    def test_rule_stage_partition_order_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        partition = changed["ruleExplanationContract"]["stagePartition"]
        partition["trace"][0], partition["trace"][1] = (
            partition["trace"][1],
            partition["trace"][0],
        )
        rules = COMPILER.rule_inventory(changed)
        with self.assertRaisesRegex(ValueError, "canonical Core rule stage trace"):
            COMPILER.rule_stage_partition(changed, rules)

    def test_semantic_rule_inventory_distinguishes_identity_from_evidence_keys(self):
        rules = COMPILER.rule_inventory(self.companion)
        stages = COMPILER.rule_stage_partition(self.companion, rules)
        schemas, mappings = self.semantic_evidence_contract(self.companion)
        self.assertEqual(193, len(rules))
        self.assertEqual(39, len(stages["semantics"]))
        self.assertEqual(
            {
                "FitClaimKey": ["claim"],
                "NeedKey": ["need"],
                "NeedMemberKey": ["need", "member"],
                "ParticipantClaimKey": ["claim", "participant"],
                "StrategyKey": ["strategy"],
                "StrategyMemberKey": ["strategy", "member"],
            },
            schemas,
        )
        self.assertEqual(25, len(mappings))
        self.assertTrue(set(mappings).issubset(stages["semantics"]))
        self.assertNotIn("core.contextualization.asserted-dependency", mappings)
        self.assertNotIn(
            "core.collective-strategy-realization.asserted-completeness",
            mappings,
        )

    def test_semantic_rule_without_evidence_key_mapping_is_admitted(self):
        changed = copy.deepcopy(self.companion)
        mappings = changed["proofSupportContract"]["evidenceKeyByRule"]
        del mappings["core.situated-need.driver-cardinality"]
        _, compiled_mappings = self.semantic_evidence_contract(changed)
        self.assertNotIn("core.situated-need.driver-cardinality", compiled_mappings)

    def test_duplicate_semantic_evidence_key_mapping_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        rule = "core.situated-need.driver-cardinality"
        changed["structuredPropositionFamilies"][0]["evidenceKeyByRule"][rule] = (
            "FitClaimKey"
        )
        with self.assertRaisesRegex(
            ValueError, "duplicate semantic evidence-key mapping"
        ):
            self.semantic_evidence_contract(changed)

    def test_unknown_semantic_evidence_key_schema_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        mappings = changed["proofSupportContract"]["evidenceKeyByRule"]
        mappings["core.situated-need.driver-cardinality"] = "UnknownKey"
        with self.assertRaisesRegex(ValueError, "unknown schema UnknownKey"):
            self.semantic_evidence_contract(changed)

    def test_non_semantics_evidence_key_mapping_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        mappings = changed["proofSupportContract"]["evidenceKeyByRule"]
        mappings["core.structure.contextualization-cardinality"] = (
            "NeedKey"
        )
        with self.assertRaisesRegex(ValueError, "non-semantics rule"):
            self.semantic_evidence_contract(changed)

    def test_unused_semantic_evidence_key_schema_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        schemas = changed["proofSupportContract"]["evidenceKeySchemas"]
        schemas["UnusedKey"] = ["unused"]
        with self.assertRaisesRegex(ValueError, "unused semantic evidence"):
            self.semantic_evidence_contract(changed)

    def test_empty_semantic_evidence_key_schema_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        schemas = changed["proofSupportContract"]["evidenceKeySchemas"]
        schemas["NeedKey"] = []
        with self.assertRaisesRegex(ValueError, "expected a non-empty array"):
            self.semantic_evidence_contract(changed)

    def test_duplicate_semantic_evidence_key_field_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        schemas = changed["proofSupportContract"]["evidenceKeySchemas"]
        schemas["NeedMemberKey"][1] = "need"
        with self.assertRaisesRegex(ValueError, "duplicate member"):
            self.semantic_evidence_contract(changed)

    def test_duplicate_semantic_evidence_key_schema_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        family = changed["structuredPropositionFamilies"][0]
        family["evidenceKeySchemas"]["NeedKey"] = ["need"]
        with self.assertRaisesRegex(ValueError, "duplicate semantic evidence"):
            self.semantic_evidence_contract(changed)

    def test_semantic_schema_constructor_collision_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        proof = changed["proofSupportContract"]
        proof["evidenceKeySchemas"]["Need-Key"] = proof[
            "evidenceKeySchemas"
        ].pop("NeedKey")
        for rule, schema in proof["evidenceKeyByRule"].items():
            if schema == "NeedKey":
                proof["evidenceKeyByRule"][rule] = "Need-Key"
        family = changed["structuredPropositionFamilies"][0]
        family["evidenceKeySchemas"]["Need Key"] = ["needAlias"]
        family["evidenceKeyByRule"][
            "core.collective-strategy-realization.fit-target-binding"
        ] = "Need Key"
        with self.assertRaisesRegex(
            ValueError, "semantic evidence-key schema catalog"
        ):
            self.semantic_evidence_contract(changed)

    def test_semantic_rule_constructor_collision_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "semantic rule catalog"):
            COMPILER.semantic_evidence_contract(
                {
                    "proofSupportContract": {
                        "evidenceKeySchemas": {"Key": ["value"]},
                        "evidenceKeyByRule": {
                            "core.a-b": "Key",
                            "core.a b": "Key",
                        },
                    },
                    "structuredPropositionFamilies": [],
                },
                ["core.a b", "core.a-b"],
            )

    def test_strategy_semantic_obligations_are_semantic_rules(self):
        strategy = self.companion["strategyFormulationSemantics"]
        self.assertEqual(
            set(strategy["ruleIds"]),
            set(strategy["semanticObligations"]),
        )
        self.assertEqual(22, len(strategy["ruleIds"]))
        semantic_rules = set(
            self.companion["ruleExplanationContract"]["stagePartition"][
                "semantics"
            ]
        )
        removed_rules = {
            "core.strategy-formulation.anchoring.decision-level",
            "core.strategy-formulation.anchoring.decision-paths",
            "core.strategy-formulation.anchoring.implementation-logic",
            "core.strategy-formulation.anchoring.period",
            "core.strategy-formulation.anchoring.responsibilities",
            "core.strategy-formulation.anchoring.responsibility-scope",
            "core.strategy-formulation.derived-guardrails",
            "core.strategy-formulation.fit-rationale",
            "core.strategy-formulation.positioning",
            "core.strategy-formulation.scope",
            "core.strategy-formulation.strategy-binding",
            "core.strategy-formulation.trade-offs",
        }
        self.assertTrue(removed_rules.issubset(semantic_rules))
        self.assertTrue(set(strategy["ruleIds"].values()).issubset(semantic_rules))

    def test_unknown_semantic_relation_source_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        changed["relationSemantics"][0]["source"] = "context.unknown"
        with self.assertRaisesRegex(ValueError, "unknown source endpoint"):
            self.compile_value(changed)

    def test_unknown_semantic_relation_token_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        changed["relationSemantics"][0]["relationToken"] = "unknown"
        with self.assertRaisesRegex(ValueError, "unknown relation token"):
            self.compile_value(changed)

    def test_unknown_structured_family_endpoint_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        changed["structuredPropositionFamilies"][0]["target"]["target"] = (
            "context.unknown"
        )
        with self.assertRaisesRegex(ValueError, "unknown target endpoint"):
            self.compile_value(changed)

    def test_qualification_role_order_must_cover_the_closed_catalog(self):
        changed = copy.deepcopy(self.companion)
        changed["qualificationProposalSemantics"]["routingContract"][
            "roleOrder"
        ][-1] = "unknown"
        with self.assertRaisesRegex(
            ValueError, "qualification proposal role catalog membership"
        ):
            self.compile_value(changed)

    def test_duplicate_qualification_role_identity_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        roles = changed["qualificationProposalSemantics"]["roles"]
        roles["strategy"]["id"] = roles["need"]["id"]
        with self.assertRaisesRegex(
            ValueError, "qualification proposal role identity catalog"
        ):
            self.compile_value(changed)

    def test_unknown_qualification_role_target_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        changed["qualificationProposalSemantics"]["roles"]["need"][
            "target"
        ] = "context.unknown"
        with self.assertRaisesRegex(
            ValueError, "qualification proposal role need: unknown target endpoint"
        ):
            self.compile_value(changed)

    def test_duplicate_participant_completeness_identity_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        values = changed["structuredPropositionFamilies"][0][
            "participantCompleteness"
        ]["values"]
        values[1]["id"] = values[0]["id"]
        with self.assertRaisesRegex(
            ValueError, "participant completeness identity catalog"
        ):
            self.compile_value(changed)

    def test_duplicate_participant_completeness_token_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        values = changed["structuredPropositionFamilies"][0][
            "participantCompleteness"
        ]["values"]
        values[1]["token"] = values[0]["token"]
        with self.assertRaisesRegex(
            ValueError, "participant completeness token catalog"
        ):
            self.compile_value(changed)

    def test_haskell_constructor_collision_is_rejected(self):
        changed = copy.deepcopy(self.companion)
        tokens = changed["relationTokenCatalog"]
        replacement = "contributes to"
        replaced = tokens[-1]
        tokens[-1] = replacement
        for relation in changed["relationSemantics"]:
            if relation["relationToken"] == replaced:
                relation["relationToken"] = replacement
        with self.assertRaisesRegex(ValueError, "Haskell constructor collision"):
            self.compile_value(changed)


if __name__ == "__main__":
    unittest.main()
