"""Tests for the current Profile/Core repository-View projection."""

from dataclasses import FrozenInstanceError
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "utl" / "model"))

import repository_view_contract as contract_module  # noqa: E402
from repository_view_contract import (  # noqa: E402
    CORE_PATH,
    PROFILE_PATH,
    ProfileContractError,
    RepositoryViewContract,
    load_repository_view_contract,
)


project_validated_contract = (
    contract_module._project_validated_repository_view_contract
)


def set_path(value: object, path: tuple[object, ...], replacement: object) -> None:
    """Replace one exact JSON path in a test companion."""
    current = value
    for part in path[:-1]:
        current = current[part]  # type: ignore[index]
    current[path[-1]] = replacement  # type: ignore[index]


def changed(value: object, suffix: str) -> object:
    """Return a type-compatible value observably different from ``value``."""
    if isinstance(value, bool):
        return not value
    if isinstance(value, str):
        return f"{value}-mutation-{suffix}"
    if isinstance(value, list):
        return [f"mutation-{suffix}"]
    raise TypeError(type(value).__name__)


def frozen(value: object) -> object:
    """Express the public immutable representation of one JSON value."""
    if isinstance(value, list):
        return tuple(frozen(item) for item in value)
    if isinstance(value, dict):
        return {key: frozen(item) for key, item in value.items()}
    return value


class RepositoryViewContractTest(unittest.TestCase):
    """Keep repository checks bound to the exact current authorities."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.profile_source = PROFILE_PATH.read_bytes()
        cls.core_source = CORE_PATH.read_bytes()
        cls.profile = json.loads(cls.profile_source)
        cls.core = json.loads(cls.core_source)
        cls.contract = load_repository_view_contract()

    def load_sources(
        self,
        profile_source: bytes,
        core_source: bytes,
    ) -> RepositoryViewContract:
        """Load exact byte sources through the production authority boundary."""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            profile_path = root / "profile.json"
            core_path = root / "semantics.json"
            profile_path.write_bytes(profile_source)
            core_path.write_bytes(core_source)
            return load_repository_view_contract(profile_path, core_path)

    def applicable_decisions(self, profile: dict) -> list[dict]:
        return [
            decision
            for decision in profile["applicabilityProvenance"]["decisions"]
            if decision["subject"]["kind"]
            == "core-relation-mapping-pair"
            and decision["outcome"] == "applicable"
        ]

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

    def property_mapping(self, profile: dict, identifier: str) -> dict:
        return next(
            mapping
            for mapping in profile["propertyMappings"]
            if mapping["id"] == identifier
        )

    def requirement(self, metadata: object, role: str) -> object:
        return next(
            requirement
            for requirement in metadata["properties"]
            if requirement["role"] == role
        )

    def assert_projection_matches_sources(
        self,
        contract: RepositoryViewContract,
        profile: dict,
        core: dict,
    ) -> None:
        """Check every projected row and field against its current owner."""
        self.assertEqual(profile["schema"], contract.schema)
        self.assertEqual(
            profile["profileIdentity"]["version"],
            contract.profile_version,
        )

        carriers = profile["carrierMappings"]
        self.assertEqual(len(carriers), len(contract.carrier_mappings))
        for source, projected in zip(carriers, contract.carrier_mappings):
            self.assertEqual(source["id"], projected["id"])
            self.assertEqual(source["carrierCategory"], projected["o2iKind"])
            self.assertEqual(frozen(source["o2iTypes"]), projected["o2iTypes"])
            self.assertEqual(
                source["archimateElement"],
                projected["archimateElement"],
            )

        syntax_by_id = {
            row["id"]: row
            for row in profile["relationMappings"]
        }
        semantic_by_id = {
            row["id"]: row
            for row in core["relationSemantics"]
        }
        decisions = self.applicable_decisions(profile)
        self.assertEqual(len(decisions), len(contract.relation_mappings))
        for decision, projected in zip(decisions, contract.relation_mappings):
            subject = decision["subject"]
            syntax = syntax_by_id[subject["relationMappingId"]]
            semantic = semantic_by_id[subject["coreRelationSemanticsId"]]
            self.assertEqual(
                f"{semantic['id']}@{syntax['id']}",
                projected["id"],
            )
            self.assertEqual(semantic["id"], projected["relationName"])
            self.assertEqual(semantic["source"], projected["source"])
            self.assertEqual(semantic["target"], projected["target"])
            self.assertEqual(syntax["label"], projected["label"])
            self.assertEqual(
                syntax["archimateRelationship"],
                projected["archimateRelationship"],
            )
            self.assertEqual(
                syntax["associationDirected"],
                projected["associationDirected"],
            )

        patterns = {
            row["id"]: row
            for row in profile["patternMappings"]
        }
        self.assertEqual(
            [row["id"] for row in profile["patternMappings"]],
            [row["id"] for row in contract.pattern_mappings],
        )
        contextualization = patterns["contextualization"]
        contextualization_semantics = core["contextualizationSemantics"]
        projected_contextualization = contract.pattern_mappings[0]
        self.assertEqual(
            contextualization["relationship"]["archimateRelationship"][
                "expected"
            ],
            projected_contextualization["archimateRelationship"],
        )
        self.assertEqual(
            contextualization["relationship"]["label"]["expected"],
            projected_contextualization["label"],
        )
        self.assertEqual(
            contextualization["relationship"]["associationDirected"][
                "expected"
            ],
            projected_contextualization["associationDirected"],
        )
        self.assertEqual(
            contextualization_semantics["sourceCategory"],
            projected_contextualization["sourceKind"],
        )
        self.assertEqual(
            frozen(contextualization_semantics["targetCategories"]),
            projected_contextualization["targetKinds"],
        )
        self.assertEqual(
            contextualization_semantics["targetOwnerCardinality"],
            projected_contextualization["targetIncomingCardinality"],
        )

        collective = patterns["collective-strategy-realization"]
        family = self.family(core, collective["propositionFamily"])
        projected_collective = contract.pattern_mappings[1]
        for field in ("o2iType", "archimateElement", "junctionType"):
            self.assertEqual(
                collective["carrier"][field]["expected"],
                projected_collective["carrier"][field],
            )
        for field in (
            "archimateRelationship",
            "label",
            "associationDirected",
        ):
            self.assertEqual(
                collective["segments"][field]["expected"],
                projected_collective["segments"][field],
            )
        self.assertEqual(
            family["participant"]["target"],
            projected_collective["contributors"]["endpoint"],
        )
        self.assertEqual(
            family["participant"]["cardinality"],
            projected_collective["contributors"]["cardinality"],
        )
        self.assertEqual(
            "required"
            if family["participant"]["uniqueness"] == "distinct"
            else "forbidden",
            projected_collective["contributors"]["distinct"],
        )
        self.assertEqual(
            family["target"]["target"],
            projected_collective["target"]["endpoint"],
        )
        self.assertEqual(
            family["target"]["cardinality"],
            projected_collective["target"]["cardinality"],
        )
        self.assertEqual(
            "required"
            if family["target"]["distinctFromParticipants"]
            else "forbidden",
            projected_collective["target"]["distinctFromContributors"],
        )

        typed = profile["metadata"]["typedCarrier"]
        claim = profile["metadata"]["claimCarrier"]
        typed_type = self.requirement(contract.typed_claim_metadata, "type")
        typed_commitment = self.requirement(
            contract.typed_claim_metadata,
            "commitment",
        )
        self.assertEqual(typed["typeKey"], typed_type["key"])
        self.assertEqual(typed["cardinality"], typed_type["cardinality"])
        self.assertEqual(claim["commitmentKey"], typed_commitment["key"])
        self.assertEqual(
            claim["cardinality"],
            typed_commitment["cardinality"],
        )
        self.assertEqual(
            frozen(claim["commitmentValues"]),
            typed_commitment["admittedValues"],
        )

        context_metadata = projected_contextualization[
            "relationshipMetadata"
        ]
        context_commitment = self.requirement(
            context_metadata,
            "commitment",
        )
        self.assertEqual(
            contextualization["metadata"]["additionalProperties"][
                "expected"
            ],
            context_metadata["additionalO2IProperties"],
        )
        self.assertEqual(
            contextualization["metadata"]["commitmentCardinality"][
                "expected"
            ],
            context_commitment["cardinality"],
        )
        self.assertEqual(
            frozen(
                contextualization["metadata"]["commitmentValue"][
                    "expected"
                ]
            ),
            context_commitment["admittedValues"],
        )
        self.assertEqual(
            contract.typed_claim_metadata,
            projected_contextualization["carrierMetadata"],
        )

        completeness = self.property_mapping(
            profile,
            collective["carrier"][
                "participantCompletenessPropertyMapping"
            ],
        )
        collective_metadata = projected_collective["carrierMetadata"]
        collective_type = self.requirement(collective_metadata, "type")
        collective_commitment = self.requirement(
            collective_metadata,
            "commitment",
        )
        collective_completeness = self.requirement(
            collective_metadata,
            "participant-completeness",
        )
        self.assertEqual(typed["typeKey"], collective_type["key"])
        self.assertEqual(
            collective["carrier"]["o2iType"]["expected"],
            collective_type["admittedValues"][0],
        )
        self.assertEqual(
            collective["carrier"]["commitmentKey"]["expected"],
            collective_commitment["key"],
        )
        self.assertEqual(
            frozen(
                collective["carrier"]["commitmentValues"]["expected"]
            ),
            collective_commitment["admittedValues"],
        )
        self.assertEqual(completeness["key"], collective_completeness["key"])
        self.assertEqual(
            completeness["multiplicity"]["propertyOccurrences"]["expected"],
            collective_completeness["cardinality"],
        )
        self.assertEqual(
            frozen(completeness["value"]["admittedValues"]["expected"]),
            collective_completeness["admittedValues"],
        )
        self.assertEqual(
            collective["segments"]["o2iMetadata"]["expected"],
            projected_collective["segmentMetadata"][
                "additionalO2IProperties"
            ],
        )
        self.assertEqual(
            contract.typed_claim_metadata,
            projected_collective["endpointMetadata"],
        )

        proposal = profile["qualificationProposalMapping"]
        semantics = core["qualificationProposalSemantics"]
        projected_proposal = contract.qualification_proposal
        carrier = projected_proposal["carrier"]
        self.assertEqual(proposal["id"], projected_proposal["id"])
        self.assertEqual(
            proposal["carrier"]["archimateElement"]["expected"],
            carrier["archimateElement"],
        )
        self.assertEqual(
            proposal["carrier"]["o2iType"]["expected"],
            carrier["o2iType"],
        )
        self.assertEqual(semantics["rationale"], carrier["rationale"])
        proposal_type = self.requirement(carrier["metadata"], "type")
        proposal_source = self.requirement(carrier["metadata"], "source")
        proposal_commitment = self.requirement(
            carrier["metadata"],
            "commitment",
        )
        source = self.property_mapping(
            profile,
            proposal["carrier"]["sourceProjection"]["propertyMapping"],
        )
        self.assertEqual(typed["typeKey"], proposal_type["key"])
        self.assertEqual(
            (proposal["carrier"]["o2iType"]["expected"],),
            proposal_type["admittedValues"],
        )
        self.assertEqual(source["key"], proposal_source["key"])
        self.assertEqual("one-or-more", proposal_source["cardinality"])
        self.assertEqual(
            source["value"]["kind"]["expected"],
            proposal_source["valueKind"],
        )
        self.assertEqual(
            source["value"]["grammar"]["expected"],
            proposal_source["grammar"],
        )
        self.assertEqual(
            source["multiplicity"]["propertyOccurrences"]["expected"],
            proposal_source["profileCardinality"],
        )
        self.assertEqual(
            source["multiplicity"]["valuesPerPropertyOccurrence"][
                "expected"
            ],
            proposal_source["valueCardinality"],
        )
        self.assertEqual(
            proposal["carrier"]["commitment"]["expected"],
            proposal_commitment["cardinality"],
        )

        references = projected_proposal["references"]
        for field in (
            "archimateRelationship",
            "associationDirected",
            "direction",
        ):
            self.assertEqual(
                proposal["references"][field]["expected"],
                references[field],
            )
        reference_role = self.requirement(references["metadata"], "role")
        reference_commitment = self.requirement(
            references["metadata"],
            "commitment",
        )
        self.assertEqual(
            proposal["references"]["roleProperty"]["expected"],
            reference_role["key"],
        )
        self.assertEqual(
            frozen(semantics["routingContract"]["roleOrder"]),
            reference_role["admittedValues"],
        )
        self.assertEqual(
            proposal["references"]["commitment"]["expected"],
            reference_commitment["cardinality"],
        )
        endpoints = {
            endpoint["id"]: endpoint
            for endpoint in core["qualifiedEndpointCatalog"]
        }
        self.assertEqual(
            semantics["routingContract"]["roleOrder"],
            [role["role"] for role in references["roles"]],
        )
        for role in references["roles"]:
            name = role["role"]
            semantic_role = semantics["roles"][name]
            endpoint = endpoints[semantic_role["target"]]
            self.assertEqual(semantic_role["target"], role["endpoint"])
            self.assertEqual(semantic_role["cardinality"], role["cardinality"])
            self.assertEqual(endpoint["carrierCategory"], role["o2iKind"])
            self.assertEqual(endpoint["o2iType"], role["o2iType"])
            self.assertEqual(endpoint.get("contextType"), role["contextType"])
        self.assertEqual(
            contract.typed_claim_metadata,
            projected_proposal["endpointMetadata"],
        )

    def test_loads_one_deterministic_immutable_current_projection(self) -> None:
        repeated = load_repository_view_contract()
        copied = self.load_sources(self.profile_source, self.core_source)
        pure = project_validated_contract(self.profile, self.core)

        self.assertEqual(self.contract, repeated)
        self.assertEqual(self.contract, copied)
        self.assertEqual(self.contract, pure)
        self.assert_projection_matches_sources(
            self.contract,
            self.profile,
            self.core,
        )
        with self.assertRaises(FrozenInstanceError):
            self.contract.profile_version = "other"
        with self.assertRaises(TypeError):
            self.contract.typed_claim_metadata["properties"][0][
                "key"
            ] = "other"

    def test_exact_byte_integrity_is_separate_from_projection(self) -> None:
        cases = (
            (
                "profile",
                self.profile_source + b"\n",
                self.core_source,
                "accepted Profile file SHA-256",
            ),
            (
                "core",
                self.profile_source,
                self.core_source + b"\n",
                "accepted Core file SHA-256",
            ),
        )
        for name, profile_source, core_source, message in cases:
            with self.subTest(name=name):
                with self.assertRaisesRegex(ProfileContractError, message):
                    self.load_sources(profile_source, core_source)

    def test_compiler_loading_failures_share_the_contract_boundary(self) -> None:
        compiler_module = "o2i_current_archimate_profile_compiler"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            invalid = root / "invalid-compiler.py"
            invalid.write_text("def invalid(:\n", encoding="utf-8")
            cases = (
                ("missing", root / "missing-compiler.py", FileNotFoundError),
                ("not-importable", invalid, SyntaxError),
            )
            for name, compiler_path, cause_type in cases:
                with self.subTest(name=name):
                    with mock.patch.object(
                        contract_module,
                        "PROFILE_COMPILER_PATH",
                        compiler_path,
                    ), mock.patch.dict(
                        sys.modules,
                        {compiler_module: None},
                    ):
                        with self.assertRaisesRegex(
                            ProfileContractError,
                            "cannot load current Profile/Core authority",
                        ) as raised:
                            load_repository_view_contract()
                    self.assertIsInstance(raised.exception.__cause__, cause_type)

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
            with self.subTest(name=name):
                with self.assertRaises(ProfileContractError) as raised:
                    self.load_sources(source, self.core_source)
                self.assertIsNotNone(raised.exception.__cause__)

    def test_every_profile_identity_and_carrier_field_is_projected(self) -> None:
        identity_cases = (
            (("schema",), "schema"),
            (("profileIdentity", "version"), "profile_version"),
        )
        for path, field in identity_cases:
            with self.subTest(path=path):
                profile = copy.deepcopy(self.profile)
                original = profile
                for part in path:
                    original = original[part]
                set_path(profile, path, changed(original, field))
                candidate = project_validated_contract(profile, self.core)
                self.assertNotEqual(self.contract, candidate)
                self.assert_projection_matches_sources(candidate, profile, self.core)

        carrier_fields = (
            "id",
            "carrierCategory",
            "o2iTypes",
            "archimateElement",
        )
        for index, row in enumerate(self.profile["carrierMappings"]):
            for field in carrier_fields:
                with self.subTest(carrier=index, field=field):
                    profile = copy.deepcopy(self.profile)
                    replacement = changed(row[field], f"carrier-{index}-{field}")
                    profile["carrierMappings"][index][field] = replacement
                    candidate = project_validated_contract(
                        profile,
                        self.core,
                    )
                    self.assertNotEqual(self.contract, candidate)
                    self.assert_projection_matches_sources(
                        candidate,
                        profile,
                        self.core,
                    )

    def test_every_relation_owner_field_is_projected(self) -> None:
        decisions = self.applicable_decisions(self.profile)
        used_syntax = {
            decision["subject"]["relationMappingId"]
            for decision in decisions
        }
        used_semantics = {
            decision["subject"]["coreRelationSemanticsId"]
            for decision in decisions
        }
        self.assertEqual(
            {row["id"] for row in self.profile["relationMappings"]},
            used_syntax,
        )
        self.assertEqual(
            {row["id"] for row in self.core["relationSemantics"]},
            used_semantics,
        )

        for index, row in enumerate(self.profile["relationMappings"]):
            for field in (
                "id",
                "label",
                "archimateRelationship",
                "associationDirected",
            ):
                with self.subTest(syntax=index, field=field):
                    profile = copy.deepcopy(self.profile)
                    replacement = changed(row[field], f"syntax-{index}-{field}")
                    profile["relationMappings"][index][field] = replacement
                    if field == "id":
                        for decision in profile["applicabilityProvenance"][
                            "decisions"
                        ]:
                            subject = decision["subject"]
                            if subject.get("relationMappingId") == row["id"]:
                                subject["relationMappingId"] = replacement
                    candidate = project_validated_contract(
                        profile,
                        self.core,
                    )
                    self.assertNotEqual(self.contract, candidate)
                    self.assert_projection_matches_sources(
                        candidate,
                        profile,
                        self.core,
                    )

        for index, row in enumerate(self.core["relationSemantics"]):
            for field in ("id", "source", "target"):
                with self.subTest(semantics=index, field=field):
                    core = copy.deepcopy(self.core)
                    replacement = changed(row[field], f"core-{index}-{field}")
                    core["relationSemantics"][index][field] = replacement
                    profile = self.profile
                    if field == "id":
                        profile = copy.deepcopy(self.profile)
                        for decision in profile["applicabilityProvenance"][
                            "decisions"
                        ]:
                            subject = decision["subject"]
                            if subject.get("coreRelationSemanticsId") == row["id"]:
                                subject["coreRelationSemanticsId"] = replacement
                    candidate = project_validated_contract(profile, core)
                    self.assertNotEqual(self.contract, candidate)
                    self.assert_projection_matches_sources(
                        candidate,
                        profile,
                        core,
                    )

    def test_every_applicable_decision_field_controls_projection(self) -> None:
        all_decisions = self.profile["applicabilityProvenance"]["decisions"]
        applicable_indexes = [
            index
            for index, decision in enumerate(all_decisions)
            if decision["subject"]["kind"]
            == "core-relation-mapping-pair"
            and decision["outcome"] == "applicable"
        ]
        for projection_index, decision_index in enumerate(applicable_indexes):
            for field in ("kind", "outcome"):
                with self.subTest(decision=projection_index, field=field):
                    profile = copy.deepcopy(self.profile)
                    decision = profile["applicabilityProvenance"]["decisions"][
                        decision_index
                    ]
                    if field == "kind":
                        decision["subject"][field] = "other"
                    else:
                        decision[field] = "inapplicable"
                    candidate = project_validated_contract(
                        profile,
                        self.core,
                    )
                    expected = (
                        self.contract.relation_mappings[:projection_index]
                        + self.contract.relation_mappings[projection_index + 1 :]
                    )
                    self.assertEqual(expected, candidate.relation_mappings)
                    self.assert_projection_matches_sources(
                        candidate,
                        profile,
                        self.core,
                    )

            for field, rows_key in (
                ("relationMappingId", "relationMappings"),
                ("coreRelationSemanticsId", "relationSemantics"),
            ):
                with self.subTest(decision=projection_index, field=field):
                    profile = copy.deepcopy(self.profile)
                    core = copy.deepcopy(self.core)
                    decision = profile["applicabilityProvenance"]["decisions"][
                        decision_index
                    ]
                    rows = (
                        profile[rows_key]
                        if rows_key == "relationMappings"
                        else core[rows_key]
                    )
                    old_id = decision["subject"][field]
                    source = next(row for row in rows if row["id"] == old_id)
                    clone = copy.deepcopy(source)
                    clone["id"] = f"{old_id}-mutation-{projection_index}"
                    rows.append(clone)
                    decision["subject"][field] = clone["id"]
                    candidate = project_validated_contract(profile, core)
                    self.assertNotEqual(self.contract, candidate)
                    self.assert_projection_matches_sources(
                        candidate,
                        profile,
                        core,
                    )

    def test_every_pattern_projection_field_follows_its_owner(self) -> None:
        contextualization = self.pattern(self.profile, "contextualization")
        contextualization_index = self.profile["patternMappings"].index(
            contextualization
        )
        collective = self.pattern(
            self.profile,
            "collective-strategy-realization",
        )
        collective_index = self.profile["patternMappings"].index(collective)
        profile_paths = (
            *(
                (
                    "patternMappings",
                    contextualization_index,
                    "relationship",
                    field,
                    "expected",
                )
                for field in (
                    "archimateRelationship",
                    "label",
                    "associationDirected",
                )
            ),
            *(
                (
                    "patternMappings",
                    collective_index,
                    group,
                    field,
                    "expected",
                )
                for group, fields in (
                    (
                        "carrier",
                        ("o2iType", "archimateElement", "junctionType"),
                    ),
                    (
                        "segments",
                        (
                            "archimateRelationship",
                            "label",
                            "associationDirected",
                        ),
                    ),
                )
                for field in fields
            ),
        )
        for path in profile_paths:
            with self.subTest(profile_path=path):
                profile = copy.deepcopy(self.profile)
                original = profile
                for part in path:
                    original = original[part]
                set_path(profile, path, changed(original, "pattern"))
                candidate = project_validated_contract(profile, self.core)
                self.assertNotEqual(self.contract, candidate)
                self.assert_projection_matches_sources(candidate, profile, self.core)

        family = self.family(self.core, collective["propositionFamily"])
        family_index = self.core["structuredPropositionFamilies"].index(family)
        core_paths = (
            ("contextualizationSemantics", "sourceCategory"),
            ("contextualizationSemantics", "targetCategories"),
            ("contextualizationSemantics", "targetOwnerCardinality"),
            *(
                ("structuredPropositionFamilies", family_index, group, field)
                for group, fields in (
                    (
                        "participant",
                        ("target", "cardinality", "uniqueness"),
                    ),
                    (
                        "target",
                        (
                            "target",
                            "cardinality",
                            "distinctFromParticipants",
                        ),
                    ),
                )
                for field in fields
            ),
        )
        for path in core_paths:
            with self.subTest(core_path=path):
                core = copy.deepcopy(self.core)
                original = core
                for part in path:
                    original = original[part]
                set_path(core, path, changed(original, "pattern-core"))
                candidate = project_validated_contract(self.profile, core)
                self.assertNotEqual(self.contract, candidate)
                self.assert_projection_matches_sources(candidate, self.profile, core)

    def test_every_focused_metadata_field_controls_projection(self) -> None:
        contextualization = self.pattern(self.profile, "contextualization")
        context_index = self.profile["patternMappings"].index(
            contextualization
        )
        collective = self.pattern(
            self.profile,
            "collective-strategy-realization",
        )
        collective_index = self.profile["patternMappings"].index(collective)
        completeness_id = collective["carrier"][
            "participantCompletenessPropertyMapping"
        ]
        completeness_index = next(
            index
            for index, mapping in enumerate(self.profile["propertyMappings"])
            if mapping["id"] == completeness_id
        )
        paths = (
            ("metadata", "typedCarrier", "typeKey"),
            ("metadata", "typedCarrier", "cardinality"),
            ("metadata", "claimCarrier", "commitmentKey"),
            ("metadata", "claimCarrier", "cardinality"),
            ("metadata", "claimCarrier", "commitmentValues"),
            (
                "patternMappings",
                context_index,
                "metadata",
                "additionalProperties",
                "expected",
            ),
            (
                "patternMappings",
                context_index,
                "metadata",
                "commitmentCardinality",
                "expected",
            ),
            (
                "patternMappings",
                context_index,
                "metadata",
                "commitmentValue",
                "expected",
            ),
            (
                "patternMappings",
                collective_index,
                "carrier",
                "commitmentKey",
                "expected",
            ),
            (
                "patternMappings",
                collective_index,
                "carrier",
                "commitmentValues",
                "expected",
            ),
            (
                "patternMappings",
                collective_index,
                "segments",
                "o2iMetadata",
                "expected",
            ),
            (
                "propertyMappings",
                completeness_index,
                "key",
            ),
            (
                "propertyMappings",
                completeness_index,
                "multiplicity",
                "propertyOccurrences",
                "expected",
            ),
            (
                "propertyMappings",
                completeness_index,
                "value",
                "admittedValues",
                "expected",
            ),
        )
        for path in paths:
            with self.subTest(path=path):
                profile = copy.deepcopy(self.profile)
                original = profile
                for part in path:
                    original = original[part]
                replacement = changed(original, "focused-metadata")
                set_path(profile, path, replacement)
                if path in (
                    ("metadata", "typedCarrier", "typeKey"),
                    (
                        "patternMappings",
                        collective_index,
                        "carrier",
                        "commitmentKey",
                        "expected",
                    ),
                    ("propertyMappings", completeness_index, "key"),
                ):
                    allowed = profile["patternMappings"][collective_index][
                        "carrier"
                    ]["additionalO2IProperties"]["expected"]
                    allowed[allowed.index(original)] = replacement
                candidate = project_validated_contract(profile, self.core)
                self.assertNotEqual(self.contract, candidate)
                self.assert_projection_matches_sources(
                    candidate,
                    profile,
                    self.core,
                )

    def test_every_qualification_field_controls_projection(self) -> None:
        proposal = self.profile["qualificationProposalMapping"]
        source_id = proposal["carrier"]["sourceProjection"][
            "propertyMapping"
        ]
        source_index = next(
            index
            for index, mapping in enumerate(self.profile["propertyMappings"])
            if mapping["id"] == source_id
        )
        profile_paths = (
            ("qualificationProposalMapping", "id"),
            *(
                ("qualificationProposalMapping", "carrier", field, "expected")
                for field in (
                    "archimateElement",
                    "o2iType",
                    "commitment",
                )
            ),
            *(
                (
                    "qualificationProposalMapping",
                    "references",
                    field,
                    "expected",
                )
                for field in (
                    "archimateRelationship",
                    "associationDirected",
                    "direction",
                    "roleProperty",
                    "commitment",
                )
            ),
            ("propertyMappings", source_index, "key"),
            (
                "propertyMappings",
                source_index,
                "multiplicity",
                "propertyOccurrences",
                "expected",
            ),
            (
                "propertyMappings",
                source_index,
                "multiplicity",
                "valuesPerPropertyOccurrence",
                "expected",
            ),
            (
                "propertyMappings",
                source_index,
                "value",
                "kind",
                "expected",
            ),
            (
                "propertyMappings",
                source_index,
                "value",
                "grammar",
                "expected",
            ),
        )
        for path in profile_paths:
            with self.subTest(profile_path=path):
                profile = copy.deepcopy(self.profile)
                original = profile
                for part in path:
                    original = original[part]
                set_path(profile, path, changed(original, "qualification"))
                candidate = project_validated_contract(profile, self.core)
                self.assertNotEqual(self.contract, candidate)
                self.assert_projection_matches_sources(
                    candidate,
                    profile,
                    self.core,
                )

        semantics = self.core["qualificationProposalSemantics"]
        core_paths = [
            ("qualificationProposalSemantics", "rationale"),
        ]
        for role, role_contract in semantics["roles"].items():
            core_paths.extend(
                (
                    ("qualificationProposalSemantics", "roles", role, "target"),
                    (
                        "qualificationProposalSemantics",
                        "roles",
                        role,
                        "cardinality",
                    ),
                )
            )
            endpoint_index = next(
                index
                for index, endpoint in enumerate(
                    self.core["qualifiedEndpointCatalog"]
                )
                if endpoint["id"] == role_contract["target"]
            )
            core_paths.extend(
                (
                    (
                        "qualifiedEndpointCatalog",
                        endpoint_index,
                        "carrierCategory",
                    ),
                    (
                        "qualifiedEndpointCatalog",
                        endpoint_index,
                        "o2iType",
                    ),
                )
            )
            if "contextType" in self.core["qualifiedEndpointCatalog"][
                endpoint_index
            ]:
                core_paths.append(
                    (
                        "qualifiedEndpointCatalog",
                        endpoint_index,
                        "contextType",
                    )
                )
        for path in core_paths:
            with self.subTest(core_path=path):
                core = copy.deepcopy(self.core)
                original = core
                for part in path:
                    original = original[part]
                replacement = changed(original, "qualification-core")
                set_path(core, path, replacement)
                if path[-1] == "target":
                    endpoint = next(
                        endpoint
                        for endpoint in core["qualifiedEndpointCatalog"]
                        if endpoint["id"] == original
                    )
                    endpoint["id"] = replacement
                candidate = project_validated_contract(self.profile, core)
                self.assertNotEqual(self.contract, candidate)
                self.assert_projection_matches_sources(
                    candidate,
                    self.profile,
                    core,
                )

        core = copy.deepcopy(self.core)
        core["qualificationProposalSemantics"]["routingContract"][
            "roleOrder"
        ].reverse()
        candidate = project_validated_contract(self.profile, core)
        self.assertNotEqual(self.contract, candidate)
        self.assert_projection_matches_sources(candidate, self.profile, core)

    def test_unsupported_qualification_source_contract_fails_targetedly(
        self,
    ) -> None:
        core = copy.deepcopy(self.core)
        core["qualificationProposalSemantics"]["sources"] = "zero-or-more"
        with self.assertRaisesRegex(
            ProfileContractError,
            "unsupported qualification source cardinality: zero-or-more",
        ):
            project_validated_contract(self.profile, core)

    def test_pattern_and_family_selectors_fail_targetedly(self) -> None:
        cases = (
            (
                "contextualization",
                "missing pattern mapping identity: contextualization",
            ),
            (
                "collective-strategy-realization",
                "missing pattern mapping identity: collective-strategy-realization",
            ),
        )
        for identifier, message in cases:
            with self.subTest(identifier=identifier):
                profile = copy.deepcopy(self.profile)
                self.pattern(profile, identifier)["id"] = f"{identifier}-other"
                with self.assertRaisesRegex(ProfileContractError, message):
                    project_validated_contract(profile, self.core)

        profile = copy.deepcopy(self.profile)
        collective = self.pattern(profile, "collective-strategy-realization")
        core = copy.deepcopy(self.core)
        family = copy.deepcopy(
            self.family(core, collective["propositionFamily"])
        )
        family["id"] = "collective-family-other"
        family["participant"]["target"] = "mutation.family.target"
        core["structuredPropositionFamilies"].append(family)
        collective["propositionFamily"] = family["id"]
        candidate = project_validated_contract(profile, core)
        self.assertNotEqual(self.contract, candidate)
        self.assert_projection_matches_sources(candidate, profile, core)

    def test_missing_relation_references_fail_targetedly(self) -> None:
        decision = self.applicable_decisions(self.profile)[0]
        decision_index = self.profile["applicabilityProvenance"][
            "decisions"
        ].index(decision)
        cases = (
            ("relationMappingId", "missing relation mapping identity: absent"),
            (
                "coreRelationSemanticsId",
                "missing Core relation identity: absent",
            ),
        )
        for field, message in cases:
            with self.subTest(field=field):
                profile = copy.deepcopy(self.profile)
                profile["applicabilityProvenance"]["decisions"][
                    decision_index
                ]["subject"][field] = "absent"
                with self.assertRaisesRegex(ProfileContractError, message):
                    project_validated_contract(profile, self.core)


if __name__ == "__main__":
    unittest.main()
