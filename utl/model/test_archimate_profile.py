"""Focused tests for structural ArchiMate profile contract decoding."""

from dataclasses import FrozenInstanceError
import json
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "utl" / "model"))

from archimate_profile import (  # noqa: E402
    ProfileContractError,
    decode_profile_contract,
    load_profile_contract,
)


CONTRACT_PATH = ROOT / "spc" / "ctr" / "archimate" / "profile.json"


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

        self.assertEqual("o2i.archimate-profile/v2", contract.schema)
        self.assertEqual(payload["profileVersion"], contract.profile_version)
        self.assertEqual(
            payload["applicabilityProvenance"]["archimateStandardVersion"],
            contract.applicability_provenance["archimateStandardVersion"],
        )
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
        directs = next(
            relation
            for relation in contract.relation_mappings
            if relation["id"] == "strategy-directs-strategy"
        )
        self.assertEqual(
            "InfluenceRelationship",
            directs["archimateRelationship"],
        )
        self.assertFalse(directs["associationDirected"])
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
            '"schema": "o2i.archimate-profile/v2",',
            (
                '"schema": "o2i.archimate-profile/v2",\n'
                '  "schema": "o2i.archimate-profile/v2",'
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

    def test_rejects_missing_or_malformed_applicability_provenance(
        self,
    ) -> None:
        missing = self.payload()
        del missing["applicabilityProvenance"]
        with self.assertRaisesRegex(
            ProfileContractError,
            "missing applicabilityProvenance",
        ):
            self.decode(missing)

        wrong_standard = self.payload()
        wrong_standard["applicabilityProvenance"][
            "archimateStandardVersion"
        ] = "3.1"
        with self.assertRaisesRegex(
            ProfileContractError,
            "unsupported value",
        ):
            self.decode(wrong_standard)

        wrong_revision = self.payload()
        wrong_revision["applicabilityProvenance"][
            "matrixImplementation"
        ]["revision"] = "B5BD0038"
        with self.assertRaisesRegex(
            ProfileContractError,
            "full lowercase 40-hex revision",
        ):
            self.decode(wrong_revision)

        wrong_uri = self.payload()
        wrong_uri["applicabilityProvenance"][
            "matrixImplementation"
        ]["repositoryUri"] = "github.com/archimatetool/archi"
        with self.assertRaisesRegex(
            ProfileContractError,
            "absolute HTTPS repository URI",
        ):
            self.decode(wrong_uri)

    def test_rejects_nonportable_matrix_path(self) -> None:
        for path in ("../relationships.xml", "/relationships.xml"):
            with self.subTest(path=path):
                payload = self.payload()
                payload["applicabilityProvenance"][
                    "matrixImplementation"
                ]["repositoryRelativePath"] = path
                with self.assertRaisesRegex(
                    ProfileContractError,
                    "portable repository-relative path",
                ):
                    self.decode(payload)

    def test_rejects_unknown_or_duplicate_applicability_decision(
        self,
    ) -> None:
        unknown = self.payload()
        unknown["applicabilityProvenance"]["decisions"][0][
            "relationMappingId"
        ] = "unknown-mapping"
        with self.assertRaisesRegex(
            ProfileContractError,
            "not internally declared",
        ):
            self.decode(unknown)

        duplicate = self.payload()
        decision = duplicate["applicabilityProvenance"]["decisions"][0]
        duplicate["applicabilityProvenance"]["decisions"].append(
            dict(decision)
        )
        with self.assertRaisesRegex(ProfileContractError, "duplicates"):
            self.decode(duplicate)

    def test_rejects_coordinate_or_symbol_mismatch(self) -> None:
        wrong_coordinate = self.payload()
        wrong_coordinate["applicabilityProvenance"]["decisions"][0][
            "sourceElement"
        ] = "Goal"
        with self.assertRaisesRegex(
            ProfileContractError,
            "carrier coordinates must resolve to Grouping -> Grouping",
        ):
            self.decode(wrong_coordinate)

        wrong_symbol = self.payload()
        wrong_symbol["applicabilityProvenance"][
            "symbolInterpretations"
        ][0]["archimateRelationship"] = "AssociationRelationship"
        with self.assertRaisesRegex(
            ProfileContractError,
            "matrixSymbol must resolve to InfluenceRelationship",
        ):
            self.decode(wrong_symbol)

        unknown_symbol = self.payload()
        unknown_symbol["applicabilityProvenance"]["decisions"][0][
            "matrixSymbol"
        ] = "x"
        with self.assertRaisesRegex(
            ProfileContractError,
            "not internally declared",
        ):
            self.decode(unknown_symbol)

        unused_symbol = self.payload()
        unused_symbol["applicabilityProvenance"][
            "symbolInterpretations"
        ].append(
            {
                "symbol": "o",
                "archimateRelationship": "AssociationRelationship",
            }
        )
        with self.assertRaisesRegex(
            ProfileContractError,
            "must contain only used symbols",
        ):
            self.decode(unused_symbol)

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
            '"profileVersion": "0.3"',
            '"profileVersion": NaN',
        )

        with self.assertRaisesRegex(
            ProfileContractError,
            "invalid JSON constant",
        ):
            decode_profile_contract(invalid)


if __name__ == "__main__":
    unittest.main()
