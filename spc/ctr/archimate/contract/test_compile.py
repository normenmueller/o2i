#!/usr/bin/env python3
"""Regression tests for the closed ArchiMate Profile companion compiler."""

from __future__ import annotations

import copy
import json
import os
import re
import tempfile
import unittest
from pathlib import Path

import compile as compiler


CORE_COMPANION = Path(
    os.environ.get("O2I_CORE_COMPANION", compiler.DEFAULT_CORE_COMPANION)
)


EXPECTED_ACTIVATION_CONSTRUCTORS = (
    "ActivateGraphCarrier",
    "ActivateGraphStructuredCarrier",
    "ActivateGraphStructuredProperty",
    "ActivateGraphCommittedElement",
    "ActivateGraphCommittedStructuredCarrier",
    "ActivateGraphCommittedRelationship",
    "ActivateQualificationProposalType",
    "ActivateQualificationProposalSourceKey",
    "ActivateQualificationRoleKey",
    "ActivateSharedUnknownProperty",
    "ActivateSharedTypeKey",
    "ActivateGraphRelation",
    "ActivateGraphContextualizationLabel",
    "ActivateGraphContextualizationShape",
    "ActivateGraphStructuredSegment",
    "ActivateQualificationProposalIncidence",
)

EXPECTED_CLOSURE_CONSTRUCTORS = (
    "CloseGraphStableConcept",
    "CloseGraphRelationshipSourceEndpoint",
    "CloseGraphRelationshipTargetEndpoint",
    "CloseGraphStructuredIncidenceByTarget",
    "CloseGraphStructuredIncidenceBySource",
    "CloseGraphJunctionSourceEndpoint",
    "CloseGraphJunctionTargetEndpoint",
    "CloseGraphContextualization",
    "CloseGraphContextOwner",
    "CloseGraphStructuredCarrierFromParticipantSegment",
    "CloseGraphStructuredCarrierFromTargetSegment",
    "CloseGraphStructuredParticipant",
    "CloseGraphStructuredTarget",
    "CloseGraphOwnedPropertyValue",
    "CloseGraphPropertyDefinition",
    "CloseQualificationRoleIncidenceBySource",
    "CloseQualificationRoleIncidenceByTarget",
    "CloseQualificationRoleSourceEndpoint",
    "CloseQualificationRoleTargetEndpoint",
    "CloseQualificationOwnerContextualization",
    "CloseQualificationContextOwner",
    "CloseQualificationEndpointContextualization",
    "CloseQualificationOwnedEndpoint",
    "CloseQualificationOwnedPropertyValue",
    "CloseQualificationPropertyDefinition",
)

EXPECTED_ACTIVATION_STATIC_SOURCE_RULE_IDS = {
    "ActivateGraphCarrier": [],
    "ActivateGraphStructuredCarrier": [
        "pattern.collective-strategy-realization.carrier.archimate-element",
        "pattern.collective-strategy-realization.carrier.junction-type",
        "pattern.collective-strategy-realization.carrier.o2i-type",
    ],
    "ActivateGraphStructuredProperty": [
        "reserved-placement:o2i.participant-completeness"
    ],
    "ActivateGraphCommittedElement": ["reserved-placement:o2i.commitment"],
    "ActivateGraphCommittedStructuredCarrier": [
        "reserved-placement:o2i.commitment"
    ],
    "ActivateGraphCommittedRelationship": ["reserved-placement:o2i.commitment"],
    "ActivateQualificationProposalType": [
        "qualification.proposal.carrier.archimate-element",
        "qualification.proposal.carrier.o2i-type",
    ],
    "ActivateQualificationProposalSourceKey": ["reserved-placement:o2i.source"],
    "ActivateQualificationRoleKey": ["reserved-placement:o2i.role"],
    "ActivateSharedUnknownProperty": [],
    "ActivateSharedTypeKey": ["reserved-placement:o2i.type"],
    "ActivateGraphRelation": [],
    "ActivateGraphContextualizationLabel": [
        "pattern.contextualization.relationship.directed",
        "pattern.contextualization.relationship.label",
        "pattern.contextualization.relationship.type",
    ],
    "ActivateGraphContextualizationShape": ["carrier:context"],
    "ActivateGraphStructuredSegment": [
        "pattern.collective-strategy-realization.segments.directed",
        "pattern.collective-strategy-realization.segments.label",
        "pattern.collective-strategy-realization.segments.relationship-type",
    ],
    "ActivateQualificationProposalIncidence": [
        "qualification.proposal.reference.directed",
        "qualification.proposal.reference.direction",
        "qualification.proposal.reference.relationship-type",
        "qualification.proposal.reference.role-property",
    ],
}


class ProfileCompilerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.companion, cls.payload = compiler.load_object(
            compiler.COMPANION, "Profile companion"
        )
        cls.core, cls.core_payload = compiler.load_object(
            CORE_COMPANION, "Core companion"
        )

    def test_compilation_is_deterministic_and_current(self) -> None:
        first = compiler.compile_contract(CORE_COMPANION)
        second = compiler.compile_contract(CORE_COMPANION)
        self.assertEqual(first, second)
        self.assertEqual(
            first, compiler.GENERATED.read_text(encoding="utf-8")
        )
        self.assertIn(compiler.EXPECTED_SHA256, first)

    def test_exact_profile_shape_and_contract_digests(self) -> None:
        self.assertEqual(
            compiler.shape_sha256(self.companion),
            compiler.EXPECTED_SHAPE_SHA256,
        )
        self.assertEqual(compiler.sha256(self.payload), compiler.EXPECTED_SHA256)
        self.assertEqual(
            compiler.sha256(self.core_payload), compiler.EXPECTED_CORE_SHA256
        )
        self.assertEqual(
            self.companion["coreSemanticContractBinding"]["sha256"],
            compiler.EXPECTED_CORE_SHA256,
        )
        self.assertEqual(
            compiler.fixed_point_semantics_sha256(self.companion),
            compiler.EXPECTED_FIXED_POINT_SEMANTICS_SHA256,
        )

    def test_fixed_point_constructor_instances_are_exact_and_ordered(self) -> None:
        activation = compiler.activation_rows(self.companion)
        closure = compiler.closure_rows(self.companion)
        self.assertEqual(
            tuple(row["constructorId"] for _, row in activation),
            EXPECTED_ACTIVATION_CONSTRUCTORS,
        )
        self.assertEqual(
            tuple(row["constructorId"] for _, row in closure),
            EXPECTED_CLOSURE_CONSTRUCTORS,
        )
        rule_ids = [row["ruleId"] for _, row in activation + closure]
        self.assertEqual(len(rule_ids), 41)
        self.assertEqual(len(set(rule_ids)), 41)

    def test_generated_fixed_point_shape_is_closed_and_typed(self) -> None:
        rendered = compiler.compile_contract(CORE_COMPANION)
        self.assertNotIn("generatedActivationConstructorId", rendered)
        self.assertNotIn("generatedClosureConstructorId", rendered)
        self.assertNotIn("generatedActivationBranches :: ![Text]", rendered)
        self.assertNotIn("data GeneratedActivationConstructor", rendered)
        self.assertNotIn("data GeneratedClosureConstructor", rendered)
        self.assertNotIn("GeneratedActivationRule = GeneratedActivationRule", rendered)
        self.assertNotIn("GeneratedClosureRule = GeneratedClosureRule", rendered)
        self.assertIn("data GeneratedActivationRule", rendered)
        self.assertIn("data GeneratedClosureRule", rendered)
        self.assertIn("ActivateGraphCarrier !Text", rendered)
        self.assertIn("CloseGraphStableConcept !Text", rendered)
        self.assertIn("data GeneratedFactSelector", rendered)
        self.assertIn("data GeneratedFactTemplate", rendered)
        self.assertIn(
            "generatedActivationProvenanceRuleId :: GeneratedActivationRule -> Text",
            rendered,
        )
        self.assertIn(
            "generatedActivationStaticSourceRuleIds :: GeneratedActivationRule -> [Text]",
            rendered,
        )
        self.assertIn(
            "generatedClosureProvenanceRuleId :: GeneratedClosureRule -> Text",
            rendered,
        )
        for constructors, expected_occurrences in (
            (EXPECTED_ACTIVATION_CONSTRUCTORS, 7),
            (EXPECTED_CLOSURE_CONSTRUCTORS, 6),
        ):
            first_positions = []
            last_positions = []
            for constructor in constructors:
                occurrences = list(
                    re.finditer(rf"\b{re.escape(constructor)}\b", rendered)
                )
                self.assertEqual(len(occurrences), expected_occurrences, constructor)
                first_positions.append(occurrences[0].start())
                last_positions.append(occurrences[1].start())
            self.assertEqual(first_positions, sorted(first_positions))
            self.assertEqual(last_positions, sorted(last_positions))

    def test_mapping_rule_provenance_is_derived_and_generated(self) -> None:
        carrier_rules, relation_rules, property_rules = (
            compiler.derive_mapping_rule_ids(self.companion)
        )
        self.assertEqual(carrier_rules["context"], "carrier:context")
        relation_id = self.companion["relationMappings"][0]["id"]
        self.assertEqual(relation_rules[relation_id], f"relation:{relation_id}")
        self.assertEqual(
            property_rules["property:typed-carrier:o2i.type"],
            "reserved-placement:o2i.type",
        )
        rendered = compiler.compile_contract(CORE_COMPANION)
        self.assertIn("generatedCarrierRuleId :: !Text", rendered)
        self.assertIn("generatedRelationRuleId :: !Text", rendered)
        self.assertIn("generatedPropertyRuleId :: !Text", rendered)

    def test_property_runtime_plan_inventory_is_complete_and_typed(self) -> None:
        plans = compiler.derive_property_runtime_plans(self.companion)
        self.assertEqual(
            [plan["id"] for plan in plans],
            [mapping["id"] for mapping in self.companion["propertyMappings"]],
        )
        self.assertEqual(len(plans), 6)
        self.assertEqual(
            plans[0]["authority"],
            "/propertyMappings/0",
        )
        self.assertEqual(
            plans[4]["constraint"],
            {
                "expected": "source-identity",
                "ruleId": (
                    "property:qualification-proposal-assessment:"
                    "o2i.source:value-grammar"
                ),
            },
        )
        rendered = compiler.compile_contract(CORE_COMPANION)
        self.assertIn("data GeneratedCardinalityExpectation", rendered)
        self.assertIn("data GeneratedRuntimeExpected", rendered)
        self.assertIn("data GeneratedPropertyConstraint", rendered)
        self.assertIn("data GeneratedPropertyRuntimePlan", rendered)
        self.assertIn(
            "generatedPropertyRuntimePlans :: [GeneratedPropertyRuntimePlan]",
            rendered,
        )
        self.assertEqual(
            len(
                re.findall(
                    r"^  [\[,] GeneratedPropertyRuntimePlan$",
                    rendered,
                    re.MULTILINE,
                )
            ),
            6,
        )

    def test_pattern_runtime_rule_inventory_is_complete_and_typed(self) -> None:
        rules = compiler.derive_pattern_runtime_rules(self.companion)
        self.assertEqual(len(rules), 29)
        self.assertEqual(len({rule["subject"] for rule in rules}), 29)
        self.assertNotIn(
            "qualification.carrier.rationale-normalization",
            {rule["subject"] for rule in rules},
        )
        self.assertEqual(
            {rule["ruleId"] for rule in rules},
            {
                compiler.resolve_pointer(self.companion, path)
                for path in self.companion["ruleIdentityContract"][
                    "embeddedRuleInventory"
                ]
                if path.startswith("/patternMappings/")
                or path.startswith("/qualificationProposalMapping/")
            },
        )
        rendered = compiler.compile_contract(CORE_COMPANION)
        self.assertIn("data GeneratedPatternRuntimeRule", rendered)
        self.assertIn(
            "generatedPatternRuntimeRules :: [GeneratedPatternRuntimeRule]",
            rendered,
        )
        self.assertEqual(
            len(
                re.findall(
                    r"^  [\[,] GeneratedPatternRuntimeRule$",
                    rendered,
                    re.MULTILINE,
                )
            ),
            29,
        )

    def test_unrepresented_pattern_runtime_leaf_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        drifted["patternMappings"][0]["relationship"]["runtimeLeaf"] = {
            "expected": "runtime-value",
            "ruleId": "runtime.unrepresented",
        }
        with self.assertRaisesRegex(
            ValueError,
            "complete emit-capable Pattern runtime leaf coverage",
        ):
            compiler.derive_pattern_runtime_rules(drifted)

    def test_defect_rule_evidence_bindings_are_exact_and_closed(self) -> None:
        bindings = compiler.derive_profile_defect_rule_bindings(self.companion)
        self.assertEqual(len(bindings), 126)
        self.assertNotIn(
            "qualification.proposal.carrier.rationale-normalization",
            bindings,
        )
        self.assertEqual(
            set(bindings.values()), set(compiler.EXPECTED_PROFILE_EVIDENCE_KINDS)
        )
        self.assertEqual(bindings["carrier:context"], "carrier-occurrence")
        self.assertEqual(
            bindings["classification.graph.activate.carrier"],
            "classification-occurrence",
        )
        self.assertEqual(
            bindings["property:typed-carrier:o2i.type:value-kind"],
            "property-value-evidence",
        )
        self.assertEqual(
            bindings["reserved-placement:o2i.type"],
            "reserved-property-occurrence",
        )
        self.assertNotIn("graph.relationship-source-endpoint", bindings)

    def test_generated_defect_rule_api_is_opaque_indexed_and_exact(self) -> None:
        rendered = compiler.compile_contract(CORE_COMPANION)
        export_list = rendered.split(") where", 1)[0]
        self.assertIn("{-# LANGUAGE DataKinds #-}", rendered)
        self.assertIn("{-# LANGUAGE GADTs #-}", rendered)
        self.assertIn("data GeneratedProfileEvidenceKind", rendered)
        self.assertIn(
            "data GeneratedProfileDefectRule "
            "(kind :: GeneratedProfileEvidenceKind) where",
            rendered,
        )
        self.assertIn("  , GeneratedProfileDefectRule\n", export_list)
        self.assertNotIn("GeneratedProfileDefectRule(..)", export_list)
        self.assertIn(
            "generatedProfileDefectRuleId :: "
            "GeneratedProfileDefectRule kind -> Text",
            rendered,
        )
        for evidence_kind in compiler.EXPECTED_PROFILE_EVIDENCE_KINDS:
            name = compiler.haskell_constructor("", evidence_kind)
            self.assertIn(f"generated{name}DefectRule ::", rendered)
        self.assertIn('ruleId == "carrier:context"', rendered)
        self.assertIn(
            'ruleId == "property:typed-carrier:o2i.type:value-kind"', rendered
        )

    def test_missing_embedded_evidence_binding_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        del drifted["patternMappings"][1]["segments"]["evidenceKind"]
        with self.assertRaisesRegex(ValueError, "missing Profile evidence binding"):
            compiler.derive_profile_defect_rule_bindings(drifted)

    def test_mismatched_evidence_binding_contract_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        drifted["ruleIdentityContract"]["evidenceBinding"][
            "generatedCarrierRule"
        ] = "derivedRuleEvidence.relation"
        with self.assertRaisesRegex(ValueError, "Profile evidence binding contract"):
            compiler.derive_profile_defect_rule_bindings(drifted)

    def test_unknown_evidence_kind_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        drifted["patternMappings"][0]["metadata"]["additionalProperties"][
            "evidenceKind"
        ] = "runtime-occurrence"
        with self.assertRaisesRegex(ValueError, "unknown Profile evidence kind"):
            compiler.derive_profile_defect_rule_bindings(drifted)

    def test_duplicate_generated_defect_rule_binding_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        drifted["carrierMappings"][1]["id"] = drifted["carrierMappings"][0]["id"]
        with self.assertRaisesRegex(ValueError, "duplicate member"):
            compiler.derive_profile_defect_rule_bindings(drifted)

    def test_activation_static_source_rule_provenance_is_exact(self) -> None:
        actual = compiler.derive_activation_static_source_rule_ids(self.companion)
        self.assertEqual(actual, EXPECTED_ACTIVATION_STATIC_SOURCE_RULE_IDS)
        selected = set(
            self.companion["ruleIdentityContract"][
                "selectedProfileRuleInventory"
            ]
        )
        for rule_ids in actual.values():
            self.assertEqual(rule_ids, compiler.utf8_sorted(rule_ids))
            self.assertEqual(len(rule_ids), len(set(rule_ids)))
            self.assertTrue(set(rule_ids).issubset(selected))

    def test_activation_source_rule_inventory_omission_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        drifted["ruleIdentityContract"]["selectedProfileRuleInventory"].remove(
            "pattern.collective-strategy-realization.carrier.archimate-element"
        )
        with self.assertRaisesRegex(ValueError, "missing from selected Profile inventory"):
            compiler.derive_activation_static_source_rule_ids(drifted)

    def test_activation_source_rule_rename_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        collective = next(
            row
            for row in drifted["patternMappings"]
            if "propositionFamily" in row
        )
        collective["carrier"]["archimateElement"]["ruleId"] += ".changed"
        with self.assertRaisesRegex(ValueError, "missing from selected Profile inventory"):
            compiler.derive_activation_static_source_rule_ids(drifted)

    def test_activation_source_provenance_set_mismatch_is_rejected(self) -> None:
        drifted = compiler.derive_activation_static_source_rule_ids(self.companion)
        drifted["ActivateGraphStructuredCarrier"] = drifted[
            "ActivateGraphStructuredCarrier"
        ][1:]
        with self.assertRaisesRegex(
            ValueError,
            "activation static source provenance ActivateGraphStructuredCarrier",
        ):
            compiler.validate_activation_static_source_rule_ids(
                self.companion, drifted
            )

    def test_fixed_point_contract_has_complete_producer_coverage(self) -> None:
        compiler.validate_fixed_point_contract(self.companion)

    def test_duplicate_json_member_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "duplicate.json"
            path.write_text('{"schema":"one","schema":"two"}', encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "duplicate JSON object member"):
                compiler.load_object(path, "duplicate fixture")

    def test_exact_companion_byte_drift_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        drifted["schema"] = "o2i.archimate-profile/drift"
        payload = json.dumps(drifted, ensure_ascii=False).encode("utf-8")
        with self.assertRaisesRegex(ValueError, "Profile file SHA-256"):
            compiler.validate_companion(drifted, payload, CORE_COMPANION)

    def test_core_binding_drift_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        drifted["coreSemanticContractBinding"]["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "Profile-to-Core exact-byte binding"):
            compiler.validate_core_binding(drifted, CORE_COMPANION)

    def test_descriptor_values_are_declarative_and_generated(self) -> None:
        drifted = copy.deepcopy(self.companion)
        drifted["profileIdentity"]["notation"] = "example-notation"
        drifted["profileIdentity"]["adapterIds"] = ["example-adapter"]
        compiler.validate_resolution(drifted)
        rendered = compiler.render_generated(drifted)
        self.assertIn('"example-notation"', rendered)
        self.assertIn('"example-adapter"', rendered)

    def test_applicability_matrix_is_not_generated_as_runtime_inventory(self) -> None:
        rendered = compiler.render_generated(self.companion)
        self.assertNotIn("GeneratedApplicabilityDecision", rendered)
        self.assertNotIn("generatedApplicabilityDecisions", rendered)

    def test_relation_projection_plan_contains_only_applicable_pairs(self) -> None:
        decisions = [
            row
            for row in self.companion["applicabilityProvenance"]["decisions"]
            if row["subject"]["kind"] == "core-relation-mapping-pair"
        ]
        plans = set(compiler.derive_relation_projection_plans(self.companion))
        expected = {
            (
                row["subject"]["relationMappingId"],
                row["sourceElement"],
                row["targetElement"],
            )
            for row in decisions
            if row["outcome"] == "applicable"
        }
        rejected_decisions = [
            row for row in decisions if row["outcome"] == "inapplicable"
        ]
        rejected = {
            (
                row["subject"]["relationMappingId"],
                row["sourceElement"],
                row["targetElement"],
            )
            for row in rejected_decisions
        }
        self.assertEqual(expected, plans)
        self.assertEqual(6, len(rejected_decisions))
        for row in rejected_decisions:
            self.assertNotIn(
                (
                    row["subject"]["relationMappingId"],
                    row["sourceElement"],
                    row["targetElement"],
                ),
                plans,
            )
        self.assertTrue(rejected.isdisjoint(plans))
        self.assertTrue(
            {mapping for mapping, _, _ in rejected}
            <= {mapping for mapping, _, _ in plans}
        )

    def test_descriptor_shape_and_value_kinds_are_closed(self) -> None:
        missing = copy.deepcopy(self.companion)
        del missing["profileIdentity"]["notation"]
        with self.assertRaisesRegex(
            ValueError,
            "declarative Profile descriptor fields",
        ):
            compiler.validate_resolution(missing)

        empty_adapters = copy.deepcopy(self.companion)
        empty_adapters["profileIdentity"]["adapterIds"] = []
        with self.assertRaisesRegex(
            ValueError,
            "declarative Profile descriptor adapterIds",
        ):
            compiler.validate_resolution(empty_adapters)

    def test_rule_inventory_omission_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        drifted["ruleIdentityContract"]["selectedProfileRuleInventory"].pop()
        with self.assertRaisesRegex(ValueError, "partition"):
            compiler.derive_rule_inventory(drifted)

    def test_applicability_omission_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        drifted["applicabilityProvenance"]["decisions"].pop()
        with self.assertRaisesRegex(ValueError, "applicability subject bijection"):
            compiler.validate_applicability(drifted, self.core)

    def test_relationship_applicability_bindings_are_exact(self) -> None:
        relationship_kinds = (
            "core-relation-mapping-pair",
            "contextualization-carrier-pair",
            "structured-proposition-segment",
            "qualification-reference-role",
        )
        mutations = (
            ("archimateRelationship", "UnknownRelationship", "relationship binding"),
            ("associationDirected", None, "relationship direction binding"),
            ("sourceElement", "UnknownSource", "source endpoint binding"),
            ("targetElement", "UnknownTarget", "target endpoint binding"),
        )
        for kind in relationship_kinds:
            for field, replacement, failure in mutations:
                with self.subTest(kind=kind, field=field):
                    drifted = copy.deepcopy(self.companion)
                    decision = next(
                        row
                        for row in drifted["applicabilityProvenance"]["decisions"]
                        if row["subject"]["kind"] == kind
                    )
                    decision[field] = (
                        not decision[field]
                        if replacement is None
                        else replacement
                    )
                    with self.assertRaisesRegex(ValueError, failure):
                        compiler.validate_applicability(drifted, self.core)

    def test_relationship_matrix_bindings_are_exact(self) -> None:
        relationship_kinds = (
            "core-relation-mapping-pair",
            "contextualization-carrier-pair",
            "structured-proposition-segment",
            "qualification-reference-role",
        )
        for kind in relationship_kinds:
            with self.subTest(kind=kind, field="matrixSourceLocator"):
                drifted = copy.deepcopy(self.companion)
                decision = next(
                    row
                    for row in drifted["applicabilityProvenance"]["decisions"]
                    if row["subject"]["kind"] == kind
                )
                decision["matrixSourceLocator"]["path"] = "unknown.xml"
                with self.assertRaisesRegex(ValueError, "matrix source path binding"):
                    compiler.validate_applicability(drifted, self.core)

            with self.subTest(kind=kind, field="matrixSymbol"):
                drifted = copy.deepcopy(self.companion)
                decision = next(
                    row
                    for row in drifted["applicabilityProvenance"]["decisions"]
                    if row["subject"]["kind"] == kind
                )
                decision["matrixSymbol"] = "?"
                with self.assertRaisesRegex(ValueError, "matrix symbol binding"):
                    compiler.validate_applicability(drifted, self.core)

            with self.subTest(kind=kind, field="outcome"):
                drifted = copy.deepcopy(self.companion)
                decision = next(
                    row
                    for row in drifted["applicabilityProvenance"]["decisions"]
                    if row["subject"]["kind"] == kind
                    and row["outcome"] == "applicable"
                )
                symbol = decision["matrixSymbol"]
                decision["matrixAdmittedSymbols"] = decision[
                    "matrixAdmittedSymbols"
                ].replace(symbol, "")
                with self.assertRaisesRegex(ValueError, "matrix outcome binding"):
                    compiler.validate_applicability(drifted, self.core)

    def test_interface_applicability_bindings_are_exact(self) -> None:
        expected_interfaces = {
            "property-owner-family": "IProperties",
            "carrier-construct": "IArchimateElement",
        }
        for kind, expected_interface in expected_interfaces.items():
            originals = [
                row
                for row in self.companion["applicabilityProvenance"]["decisions"]
                if row["subject"]["kind"] == kind
            ]
            for original in originals:
                subject_key = compiler.applicability_subject_key(original["subject"])
                with self.subTest(subject=subject_key, field="requiredInterface"):
                    drifted = copy.deepcopy(self.companion)
                    decision = next(
                        row
                        for row in drifted["applicabilityProvenance"]["decisions"]
                        if compiler.applicability_subject_key(row["subject"])
                        == subject_key
                    )
                    decision["requiredInterface"] = "IUnknown"
                    with self.assertRaisesRegex(
                        ValueError, f"{kind} interface binding"
                    ):
                        compiler.validate_applicability(drifted, self.core)

                with self.subTest(subject=subject_key, field="outcome"):
                    drifted = copy.deepcopy(self.companion)
                    decision = next(
                        row
                        for row in drifted["applicabilityProvenance"]["decisions"]
                        if compiler.applicability_subject_key(row["subject"])
                        == subject_key
                    )
                    decision["outcome"] = "inapplicable"
                    with self.assertRaisesRegex(ValueError, f"{kind} outcome binding"):
                        compiler.validate_applicability(drifted, self.core)

                with self.subTest(subject=subject_key, field="sourceLocators"):
                    drifted = copy.deepcopy(self.companion)
                    decision = next(
                        row
                        for row in drifted["applicabilityProvenance"]["decisions"]
                        if compiler.applicability_subject_key(row["subject"])
                        == subject_key
                    )
                    required_path = f"/{expected_interface}.java"
                    decision["sourceLocators"] = [
                        locator
                        for locator in decision["sourceLocators"]
                        if not locator["path"].endswith(required_path)
                    ]
                    with self.assertRaisesRegex(
                        ValueError, f"{kind} source interface binding"
                    ):
                        compiler.validate_applicability(drifted, self.core)

    def test_positive_relation_coverage_is_required(self) -> None:
        drifted = copy.deepcopy(self.companion)
        decisions = drifted["applicabilityProvenance"]["decisions"]
        target = next(
            row["subject"]["coreRelationSemanticsId"]
            for row in decisions
            if row["subject"]["kind"] == "core-relation-mapping-pair"
            and row["outcome"] == "applicable"
        )
        for row in decisions:
            if (
                row["subject"]["kind"] == "core-relation-mapping-pair"
                and row["subject"]["coreRelationSemanticsId"] == target
            ):
                row["matrixAdmittedSymbols"] = row[
                    "matrixAdmittedSymbols"
                ].replace(row["matrixSymbol"], "")
                row["outcome"] = "inapplicable"
        with self.assertRaisesRegex(ValueError, "positive concrete notation coverage"):
            compiler.validate_applicability(drifted, self.core)

    def test_unknown_core_relation_token_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        drifted["relationMappings"][0]["projection"]["relationToken"] = "unknown"
        with self.assertRaisesRegex(ValueError, "unknown Core tokens"):
            compiler.validate_reference_integrity(drifted, self.core)

    def test_structured_role_drift_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        collective = next(
            row
            for row in drifted["patternMappings"]
            if "propositionFamily" in row
        )
        collective["contributors"]["roleId"] = "unknown-role"
        with self.assertRaisesRegex(ValueError, "participant role binding"):
            compiler.validate_reference_integrity(drifted, self.core)

    def test_activation_constructor_omission_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        drifted["viewScopeContract"]["classification"][
            "directActivationRules"
        ]["graph"].pop()
        with self.assertRaisesRegex(ValueError, "activation constructor instance count"):
            compiler.validate_fixed_point_contract(drifted)

    def test_duplicate_fixed_point_rule_id_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        activation = compiler.activation_rows(drifted)
        activation[1][1]["ruleId"] = activation[0][1]["ruleId"]
        with self.assertRaisesRegex(ValueError, "fixed-point rule IDs must be unique"):
            compiler.validate_fixed_point_contract(drifted)

    def test_untyped_activation_selector_mutation_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        activation = compiler.activation_rows(drifted)
        activation[0][1]["selector"]["subjectFamily"] = "runtime-subject"
        with self.assertRaisesRegex(ValueError, "subjectFamily vocabulary use"):
            compiler.validate_fixed_point_contract(drifted)

    def test_consequence_mutation_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        activation = compiler.activation_rows(drifted)
        activation[0][1]["produces"][0] = "RuntimeFact(ownerRecord)"
        with self.assertRaisesRegex(ValueError, "unknown fixed-point consequences"):
            compiler.validate_fixed_point_contract(drifted)

    def test_graph_qualification_constructor_swap_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        activation = compiler.activation_rows(drifted)
        activation[0][1]["constructorId"], activation[6][1]["constructorId"] = (
            activation[6][1]["constructorId"],
            activation[0][1]["constructorId"],
        )
        with self.assertRaisesRegex(ValueError, "activation constructor branch"):
            compiler.validate_fixed_point_contract(drifted)

    def test_graph_qualification_closure_constructor_swap_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        closure = compiler.closure_rows(drifted)
        closure[0][1]["constructorId"], closure[15][1]["constructorId"] = (
            closure[15][1]["constructorId"],
            closure[0][1]["constructorId"],
        )
        with self.assertRaisesRegex(ValueError, "closure constructor branch"):
            compiler.validate_fixed_point_contract(drifted)

    def test_constructor_selector_swap_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        activation = compiler.activation_rows(drifted)
        activation[0][1]["selector"], activation[3][1]["selector"] = (
            activation[3][1]["selector"],
            activation[0][1]["selector"],
        )
        with self.assertRaisesRegex(ValueError, "semantic projection SHA-256"):
            compiler.validate_fixed_point_contract(drifted)

    def test_qualification_prerequisite_on_graph_activation_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        activation = compiler.activation_rows(drifted)
        relation = next(
            row
            for _, row in activation
            if row["constructorId"] == "ActivateGraphRelation"
        )
        relation["selector"]["membershipPrerequisite"] = (
            "source-or-target-in-current-qualification-membership"
        )
        with self.assertRaisesRegex(ValueError, "prerequisite crosses branch"):
            compiler.validate_fixed_point_contract(drifted)

    def test_missing_branch_local_producer_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        activation = compiler.activation_rows(drifted)
        carrier = next(
            row
            for _, row in activation
            if row["constructorId"] == "ActivateGraphCarrier"
        )
        carrier["produces"].remove(
            "GraphContextualizableCarrier(ownerRecord,carrierMappingId)"
        )
        with self.assertRaisesRegex(ValueError, "not branch-locally reachable"):
            compiler.validate_fixed_point_contract(drifted)

    def test_cyclic_activation_prerequisite_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        activation = compiler.activation_rows(drifted)
        carrier = next(
            row
            for _, row in activation
            if row["constructorId"] == "ActivateGraphCarrier"
        )
        carrier["selector"]["membershipPrerequisite"] = (
            "target-endpoint-in-current-graph-membership"
        )
        with self.assertRaisesRegex(ValueError, "not branch-locally reachable"):
            compiler.validate_fixed_point_contract(drifted)

    def test_consequence_with_unavailable_binding_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        activation = compiler.activation_rows(drifted)
        carrier = next(
            row
            for _, row in activation
            if row["constructorId"] == "ActivateGraphCarrier"
        )
        carrier["produces"][0] = "GraphMember(includedRecord)"
        with self.assertRaisesRegex(ValueError, "unavailable bindings"):
            compiler.validate_fixed_point_contract(drifted)

    def test_cross_branch_producer_mutation_is_rejected(self) -> None:
        drifted = copy.deepcopy(self.companion)
        activation = compiler.activation_rows(drifted)
        graph_consequence = activation[0][1]["produces"][1]
        qualification_consequence = activation[6][1]["produces"][1]
        activation[0][1]["produces"][1] = qualification_consequence
        activation[6][1]["produces"][1] = graph_consequence
        with self.assertRaisesRegex(ValueError, "consequence crosses branch"):
            compiler.validate_fixed_point_contract(drifted)

    def test_rule_id_rename_does_not_change_semantic_projection(self) -> None:
        drifted = copy.deepcopy(self.companion)
        rows = compiler.activation_rows(drifted) + compiler.closure_rows(drifted)
        renames = {
            row["ruleId"]: f"renamed.fixed-point.{index:02d}"
            for index, (_, row) in enumerate(rows)
        }

        def rename(value: object) -> object:
            if isinstance(value, dict):
                return {key: rename(child) for key, child in value.items()}
            if isinstance(value, list):
                return [rename(child) for child in value]
            return renames.get(value, value) if isinstance(value, str) else value

        renamed = rename(drifted)
        self.assertIsInstance(renamed, dict)
        renamed_rows = compiler.activation_rows(renamed) + compiler.closure_rows(
            renamed
        )
        self.assertEqual(
            {row["ruleId"] for _, row in renamed_rows}, set(renames.values())
        )
        self.assertEqual(
            compiler.fixed_point_semantic_projection(self.companion),
            compiler.fixed_point_semantic_projection(renamed),
        )
        compiler.validate_fixed_point_contract(renamed)

    def test_profile_bytes_mutation_is_rejected_even_when_shape_is_stable(self) -> None:
        drifted = copy.deepcopy(self.companion)
        activation = compiler.activation_rows(drifted)
        activation[0][1]["constructorId"] = "ActivateRuntimeCarrier"
        drifted["companionFormatContract"]["shapeSha256"] = (
            compiler.shape_sha256(drifted)
        )
        payload = json.dumps(drifted, ensure_ascii=False).encode("utf-8")
        with self.assertRaisesRegex(ValueError, "Profile file SHA-256"):
            compiler.validate_companion(drifted, payload, CORE_COMPANION)


if __name__ == "__main__":
    unittest.main()
