"""Tests for the current Profile/Core repository-View projection."""

from dataclasses import FrozenInstanceError
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "utl" / "model"))

from repository_view_contract import (  # noqa: E402
    CORE_PATH,
    PROFILE_PATH,
    ProfileContractError,
    load_repository_view_contract,
)


def set_path(value: object, path: tuple[object, ...], replacement: object) -> None:
    """Replace one exact JSON path in a test companion."""
    current = value
    for part in path[:-1]:
        current = current[part]  # type: ignore[index]
    current[path[-1]] = replacement  # type: ignore[index]


class RepositoryViewContractTest(unittest.TestCase):
    """Keep repository checks bound to the exact current authorities."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.profile_source = PROFILE_PATH.read_bytes()
        cls.core_source = CORE_PATH.read_bytes()
        cls.profile = json.loads(cls.profile_source)
        cls.core = json.loads(cls.core_source)

    def load_copies(self, profile: object, core: object):
        """Load mutated companions through the production authority path."""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            profile_path = root / "profile.json"
            core_path = root / "semantics.json"
            profile_path.write_text(
                json.dumps(profile, ensure_ascii=False),
                encoding="utf-8",
            )
            core_path.write_text(
                json.dumps(core, ensure_ascii=False),
                encoding="utf-8",
            )
            return load_repository_view_contract(profile_path, core_path)

    def assert_rejected(self, profile: object, core: object) -> None:
        with self.assertRaises(ProfileContractError):
            self.load_copies(profile, core)

    def applicable_decision(self, profile: dict) -> dict:
        return next(
            decision
            for decision in profile["applicabilityProvenance"]["decisions"]
            if decision["subject"]["kind"]
            == "core-relation-mapping-pair"
            and decision["outcome"] == "applicable"
        )

    def pattern(self, profile: dict, identifier: str) -> dict:
        return next(
            pattern
            for pattern in profile["patternMappings"]
            if pattern["id"] == identifier
        )

    def family(self, core: dict, identifier: str) -> dict:
        return next(
            family
            for family in core["structuredPropositionFamilies"]
            if family["id"] == identifier
        )

    def test_loads_one_deterministic_immutable_current_projection(self) -> None:
        contract = load_repository_view_contract()
        repeated = load_repository_view_contract()

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            profile_path = root / "profile.json"
            core_path = root / "semantics.json"
            profile_path.write_bytes(self.profile_source)
            core_path.write_bytes(self.core_source)
            copied = load_repository_view_contract(profile_path, core_path)

        self.assertEqual(contract, repeated)
        self.assertEqual(contract, copied)
        self.assertEqual(
            "o2i.archimate-profile/target-v46",
            contract.schema,
        )
        self.assertEqual("0.3.0", contract.profile_version)
        self.assertEqual(
            len(self.profile["carrierMappings"]),
            len(contract.carrier_mappings),
        )
        self.assertEqual(
            sum(
                decision["subject"]["kind"]
                == "core-relation-mapping-pair"
                and decision["outcome"] == "applicable"
                for decision in self.profile["applicabilityProvenance"][
                    "decisions"
                ]
            ),
            len(contract.relation_mappings),
        )
        self.assertEqual(
            {"contextualization", "collective-strategy-realization"},
            {pattern["id"] for pattern in contract.pattern_mappings},
        )
        with self.assertRaises(FrozenInstanceError):
            contract.profile_version = "other"

    def test_projects_facts_from_their_current_owners(self) -> None:
        contract = load_repository_view_contract()
        context = next(
            mapping
            for mapping in contract.carrier_mappings
            if mapping["id"] == "context"
        )
        contributions = {
            (
                mapping["archimateRelationship"],
                mapping["associationDirected"],
            )
            for mapping in contract.relation_mappings
            if mapping["relationName"]
            == "strategy-contributes-to-strategy"
        }
        contextualization = next(
            pattern
            for pattern in contract.pattern_mappings
            if pattern["id"] == "contextualization"
        )
        collective = next(
            pattern
            for pattern in contract.pattern_mappings
            if pattern["id"] == "collective-strategy-realization"
        )

        self.assertEqual("Context", context["o2iKind"])
        self.assertEqual("Grouping", context["archimateElement"])
        self.assertEqual(
            {
                ("AssociationRelationship", True),
                ("InfluenceRelationship", False),
                ("RealizationRelationship", False),
            },
            contributions,
        )
        self.assertEqual("Context", contextualization["sourceKind"])
        self.assertEqual(
            ("Primitive", "Structuring"),
            contextualization["targetKinds"],
        )
        self.assertEqual(
            "at-least-two",
            collective["contributors"]["cardinality"],
        )
        self.assertEqual(
            "exactly-one",
            collective["target"]["cardinality"],
        )

    def test_rejects_malformed_duplicate_and_stale_profile_inputs(self) -> None:
        cases = {
            "malformed": b"{",
            "duplicate-key": self.profile_source.replace(
                b"{",
                b'{"schema":"duplicate",',
                1,
            ),
            "stale-v2": b'{"schema":"o2i.archimate-profile/v2"}',
        }
        for name, source in cases.items():
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                profile_path = root / "profile.json"
                core_path = root / "semantics.json"
                profile_path.write_bytes(source)
                core_path.write_bytes(self.core_source)
                with self.assertRaises(ProfileContractError):
                    load_repository_view_contract(profile_path, core_path)

    def test_rejects_unbound_or_inconsistent_companions(self) -> None:
        unbound = copy.deepcopy(self.profile)
        unbound["coreSemanticContractBinding"]["sha256"] = "0" * 64
        self.assert_rejected(unbound, self.core)

        inconsistent = copy.deepcopy(self.core)
        inconsistent["schema"] = "other"
        self.assert_rejected(self.profile, inconsistent)

    def test_rejects_every_profile_projection_mutation(self) -> None:
        decision = self.applicable_decision(self.profile)
        decision_index = self.profile["applicabilityProvenance"][
            "decisions"
        ].index(decision)
        contextualization = self.pattern(self.profile, "contextualization")
        contextualization_index = self.profile["patternMappings"].index(
            contextualization
        )
        collective = self.pattern(
            self.profile,
            "collective-strategy-realization",
        )
        collective_index = self.profile["patternMappings"].index(collective)
        cases = (
            (("schema",), "other"),
            (("profileIdentity", "version"), "other"),
            (("carrierMappings", 0, "id"), "other"),
            (("carrierMappings", 0, "carrierCategory"), "Primitive"),
            (("carrierMappings", 0, "o2iTypes", 0), "Other"),
            (("carrierMappings", 0, "archimateElement"), "Goal"),
            (("relationMappings", 0, "id"), "other"),
            (("relationMappings", 0, "label"), "other"),
            (
                ("relationMappings", 0, "archimateRelationship"),
                "InfluenceRelationship",
            ),
            (("relationMappings", 0, "associationDirected"), True),
            (
                (
                    "applicabilityProvenance",
                    "decisions",
                    decision_index,
                    "subject",
                    "kind",
                ),
                "other",
            ),
            (
                (
                    "applicabilityProvenance",
                    "decisions",
                    decision_index,
                    "subject",
                    "relationMappingId",
                ),
                "other",
            ),
            (
                (
                    "applicabilityProvenance",
                    "decisions",
                    decision_index,
                    "subject",
                    "coreRelationSemanticsId",
                ),
                "other",
            ),
            (
                (
                    "applicabilityProvenance",
                    "decisions",
                    decision_index,
                    "outcome",
                ),
                "inapplicable",
            ),
            (
                ("patternMappings", contextualization_index, "id"),
                "other",
            ),
            (
                (
                    "patternMappings",
                    contextualization_index,
                    "relationship",
                    "label",
                    "expected",
                ),
                "other",
            ),
            (
                (
                    "patternMappings",
                    contextualization_index,
                    "relationship",
                    "archimateRelationship",
                    "expected",
                ),
                "AssociationRelationship",
            ),
            (
                (
                    "patternMappings",
                    contextualization_index,
                    "relationship",
                    "associationDirected",
                    "expected",
                ),
                True,
            ),
            (
                (
                    "patternMappings",
                    collective_index,
                    "id",
                ),
                "other",
            ),
            (
                (
                    "patternMappings",
                    collective_index,
                    "propositionFamily",
                ),
                "other",
            ),
            (
                (
                    "patternMappings",
                    collective_index,
                    "carrier",
                    "o2iType",
                    "expected",
                ),
                "Other",
            ),
            (
                (
                    "patternMappings",
                    collective_index,
                    "carrier",
                    "archimateElement",
                    "expected",
                ),
                "Grouping",
            ),
            (
                (
                    "patternMappings",
                    collective_index,
                    "carrier",
                    "junctionType",
                    "expected",
                ),
                "or",
            ),
            (
                (
                    "patternMappings",
                    collective_index,
                    "segments",
                    "archimateRelationship",
                    "expected",
                ),
                "AssociationRelationship",
            ),
            (
                (
                    "patternMappings",
                    collective_index,
                    "segments",
                    "label",
                    "expected",
                ),
                "other",
            ),
            (
                (
                    "patternMappings",
                    collective_index,
                    "segments",
                    "associationDirected",
                    "expected",
                ),
                True,
            ),
        )
        for path, replacement in cases:
            with self.subTest(path=path):
                profile = copy.deepcopy(self.profile)
                set_path(profile, path, replacement)
                self.assert_rejected(profile, self.core)

    def test_rejects_every_core_projection_mutation(self) -> None:
        decision = self.applicable_decision(self.profile)
        relation_id = decision["subject"]["coreRelationSemanticsId"]
        relation = next(
            relation
            for relation in self.core["relationSemantics"]
            if relation["id"] == relation_id
        )
        relation_index = self.core["relationSemantics"].index(relation)
        family = self.family(
            self.core,
            "collective-strategy-realization",
        )
        family_index = self.core["structuredPropositionFamilies"].index(
            family
        )
        cases = (
            (("relationSemantics", relation_index, "id"), "other"),
            (("relationSemantics", relation_index, "source"), "context.need"),
            (("relationSemantics", relation_index, "target"), "context.need"),
            (("contextualizationSemantics", "sourceCategory"), "Primitive"),
            (
                ("contextualizationSemantics", "targetCategories", 0),
                "Context",
            ),
            (
                ("contextualizationSemantics", "targetOwnerCardinality"),
                "zero-or-one",
            ),
            (
                (
                    "structuredPropositionFamilies",
                    family_index,
                    "id",
                ),
                "other",
            ),
            (
                (
                    "structuredPropositionFamilies",
                    family_index,
                    "participant",
                    "target",
                ),
                "context.need",
            ),
            (
                (
                    "structuredPropositionFamilies",
                    family_index,
                    "participant",
                    "cardinality",
                ),
                "exactly-one",
            ),
            (
                (
                    "structuredPropositionFamilies",
                    family_index,
                    "participant",
                    "uniqueness",
                ),
                "duplicates-allowed",
            ),
            (
                (
                    "structuredPropositionFamilies",
                    family_index,
                    "target",
                    "target",
                ),
                "context.need",
            ),
            (
                (
                    "structuredPropositionFamilies",
                    family_index,
                    "target",
                    "cardinality",
                ),
                "zero-or-one",
            ),
            (
                (
                    "structuredPropositionFamilies",
                    family_index,
                    "target",
                    "distinctFromParticipants",
                ),
                False,
            ),
        )
        for path, replacement in cases:
            with self.subTest(path=path):
                core = copy.deepcopy(self.core)
                set_path(core, path, replacement)
                self.assert_rejected(self.profile, core)


if __name__ == "__main__":
    unittest.main()
