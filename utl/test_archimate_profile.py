"""Focused tests for structural ArchiMate profile contract decoding."""

from dataclasses import FrozenInstanceError
import json
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "utl"))

from archimate_profile import (  # noqa: E402
    ProfileContractError,
    decode_profile_contract,
    load_profile_contract,
)


CONTRACT_PATH = ROOT / "spc" / "contract" / "archimate-profile.json"


class ArchimateProfileContractTest(unittest.TestCase):
    def setUp(self) -> None:
        self.source = CONTRACT_PATH.read_text(encoding="utf-8")

    def payload(self) -> dict:
        return json.loads(self.source)

    def decode(self, payload: dict):
        return decode_profile_contract(json.dumps(payload))

    def pattern(self, payload: dict, identifier: str) -> dict:
        return next(
            pattern
            for pattern in payload["patternMappings"]
            if pattern["id"] == identifier
        )

    def test_loads_as_deterministic_immutable_records(self) -> None:
        payload = self.payload()
        contract = load_profile_contract(CONTRACT_PATH)

        self.assertEqual("o2i.archimate-profile/v1", contract.schema)
        self.assertEqual(payload["profileVersion"], contract.profile_version)
        self.assertEqual(
            len(payload["carrierMappings"]),
            len(contract.carrier_mappings),
        )
        self.assertEqual(
            len(payload["relationMappings"]),
            len(contract.relation_mappings),
        )
        self.assertEqual(
            len(payload["patternMappings"]),
            len(contract.pattern_mappings),
        )
        self.assertEqual(
            payload["carrierMappings"][0]["id"],
            contract.carrier_mappings[0]["id"],
        )
        with self.assertRaises(FrozenInstanceError):
            contract.profile_version = "other"

        reversed_root = dict(reversed(list(payload.items())))
        self.assertEqual(contract, self.decode(reversed_root))

    def test_accepts_semantic_registry_variation(self) -> None:
        missing = self.payload()
        missing["relationMappings"].pop()
        self.assertEqual(
            len(missing["relationMappings"]),
            len(self.decode(missing).relation_mappings),
        )

        extra = self.payload()
        added = dict(extra["relationMappings"][-1])
        added["id"] = "additional-relation"
        extra["relationMappings"].append(added)
        self.assertEqual(
            len(extra["relationMappings"]),
            len(self.decode(extra).relation_mappings),
        )

        reordered = self.payload()
        reordered["relationMappings"].reverse()
        contract = self.decode(reordered)
        self.assertEqual(
            reordered["relationMappings"][0]["id"],
            contract.relation_mappings[0]["id"],
        )

        profile_owned = self.payload()
        profile_owned["profileVersion"] = "future"
        profile_owned["relationMappings"][0]["id"] = "renamed-relation"
        relation = profile_owned["relationMappings"][0]
        relation["relationName"] = "renamed-relation"
        relation["label"] = "renamed"
        contract = self.decode(profile_owned)
        self.assertEqual("future", contract.profile_version)
        self.assertEqual(
            "renamed-relation",
            contract.relation_mappings[0]["id"],
        )

    def test_rejects_unknown_or_missing_object_field(self) -> None:
        unknown = self.payload()
        unknown["metadata"]["modelRoot"]["unknown"] = "value"
        with self.assertRaisesRegex(ProfileContractError, "unknown unknown"):
            self.decode(unknown)

        missing = self.payload()
        del missing["carrierMappings"][0]["archimateElement"]
        with self.assertRaisesRegex(
            ProfileContractError,
            "missing archimateElement",
        ):
            self.decode(missing)

    def test_rejects_duplicate_json_key(self) -> None:
        duplicate = self.source.replace(
            '"schema": "o2i.archimate-profile/v1",',
            (
                '"schema": "o2i.archimate-profile/v1",\n'
                '  "schema": "o2i.archimate-profile/v1",'
            ),
            1,
        )

        with self.assertRaisesRegex(
            ProfileContractError,
            "duplicate object key",
        ):
            decode_profile_contract(duplicate)

    def test_rejects_duplicate_mapping_id(self) -> None:
        payload = self.payload()
        relations = payload["relationMappings"]
        relations[1]["id"] = relations[0]["id"]

        with self.assertRaisesRegex(ProfileContractError, "duplicates"):
            self.decode(payload)

    def test_rejects_invalid_notation_enums(self) -> None:
        cases = (
            ("carrierMappings", 0, "archimateElement", "UnknownElement"),
            (
                "relationMappings",
                0,
                "archimateRelationship",
                "UnknownRelationship",
            ),
        )
        for section, index, field, value in cases:
            with self.subTest(field=field):
                payload = self.payload()
                payload[section][index][field] = value
                with self.assertRaisesRegex(
                    ProfileContractError,
                    "unknown notation value",
                ):
                    self.decode(payload)

        payload = self.payload()
        collective = self.pattern(
            payload,
            "collective-strategy-realization",
        )
        collective["carrier"]["junctionType"] = "xor"
        with self.assertRaisesRegex(
            ProfileContractError,
            "unknown notation value",
        ):
            self.decode(payload)

    def test_rejects_invalid_association_direction_type(self) -> None:
        payload = self.payload()
        relation = next(
            relation
            for relation in payload["relationMappings"]
            if relation["archimateRelationship"]
            != "AssociationRelationship"
        )
        relation["associationDirected"] = True

        with self.assertRaisesRegex(
            ProfileContractError,
            "only valid for an Association",
        ):
            self.decode(payload)

    def test_rejects_broken_relation_endpoint_reference(self) -> None:
        payload = self.payload()
        payload["relationMappings"][0]["source"] = "context.unknown"

        with self.assertRaisesRegex(
            ProfileContractError,
            "not internally declared",
        ):
            self.decode(payload)

    def test_rejects_broken_pattern_references(self) -> None:
        contextualization = self.payload()
        self.pattern(
            contextualization,
            "contextualization",
        )["sourceKind"] = "Unknown"
        with self.assertRaisesRegex(
            ProfileContractError,
            "not internally declared",
        ):
            self.decode(contextualization)

        collective = self.payload()
        self.pattern(
            collective,
            "collective-strategy-realization",
        )["target"][
            "endpoint"
        ] = "context.unknown"
        with self.assertRaisesRegex(
            ProfileContractError,
            "not internally declared",
        ):
            self.decode(collective)

    def test_rejects_inconsistent_metadata_contract(self) -> None:
        payload = self.payload()
        payload["metadata"]["semanticRelation"][
            "commitmentKey"
        ] = "o2i.other"

        with self.assertRaisesRegex(
            ProfileContractError,
            "commitment contracts must agree",
        ):
            self.decode(payload)

    def test_rejects_wrong_json_types_and_empty_values(self) -> None:
        wrong_type = self.payload()
        wrong_type["relationMappings"][0]["associationDirected"] = "true"
        with self.assertRaisesRegex(ProfileContractError, "must be a boolean"):
            self.decode(wrong_type)

        empty = self.payload()
        empty["relationMappings"][0]["label"] = ""
        with self.assertRaisesRegex(ProfileContractError, "nonempty string"):
            self.decode(empty)

    def test_rejects_nonstandard_json_constant(self) -> None:
        invalid = self.source.replace(
            '"profileVersion": "0.2"',
            '"profileVersion": NaN',
        )

        with self.assertRaisesRegex(
            ProfileContractError,
            "invalid JSON constant",
        ):
            decode_profile_contract(invalid)


if __name__ == "__main__":
    unittest.main()
