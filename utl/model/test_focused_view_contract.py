"""Targeted mutation tests for Profile-projected focused Views."""

from __future__ import annotations

from dataclasses import replace
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "utl" / "model"))

from focused_view_contract import (  # noqa: E402
    REQUIRED_COLLECTIVE_ELEMENT_DOCUMENTATION,
    REQUIRED_VIEW_DOCUMENTATION,
    SYNTAX_COLLECTIVE_VIEW,
    SYNTAX_CONTEXTUALIZATION_VIEW,
    SYNTAX_QUALIFICATION_VIEW,
    FocusedElement,
    FocusedRelation,
    FocusedView,
    profile_pattern,
    qualification_proposal_name,
    qualification_role_name,
    syntax_pattern_nodes,
    validate_focused_view,
)
from repository_view_contract import (  # noqa: E402
    FrozenObject,
    ProfileContractError,
    load_repository_view_contract,
)


def replace_path(
    value: object,
    path: tuple[object, ...],
    replacement: object,
) -> object:
    """Replace one leaf in an immutable projected contract."""
    if not path:
        return replacement
    head, *tail = path
    if isinstance(value, FrozenObject):
        return FrozenObject(
            tuple(
                (
                    key,
                    replace_path(item, tuple(tail), replacement)
                    if key == head
                    else item,
                )
                for key, item in value.fields
            )
        )
    if isinstance(value, tuple) and isinstance(head, int):
        return value[:head] + (
            replace_path(value[head], tuple(tail), replacement),
        ) + value[head + 1 :]
    raise AssertionError((type(value).__name__, path))


class FocusedViewContractTest(unittest.TestCase):
    """Exercise every focused carrier with precise contract failures."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = load_repository_view_contract()
        cls.views = {
            name: cls._target_view(name)
            for name in (
                SYNTAX_CONTEXTUALIZATION_VIEW,
                SYNTAX_COLLECTIVE_VIEW,
                SYNTAX_QUALIFICATION_VIEW,
            )
        }

    @classmethod
    def _properties(
        cls,
        metadata: object,
        *,
        o2i_type: str | None = None,
        role: str | None = None,
    ) -> tuple[tuple[str, str], ...]:
        values = {
            "type": o2i_type,
            "commitment": "candidate",
            "participant-completeness": "open",
            "source": "urn:o2i:test-source",
            "role": role,
        }
        properties = []
        for requirement in metadata["properties"]:
            if requirement["cardinality"] == "forbidden":
                continue
            value = values[requirement["role"]]
            if value is None:
                raise AssertionError(requirement["role"])
            properties.append((requirement["key"], value))
        return tuple(properties)

    @classmethod
    def _elements(cls, view_name: str) -> tuple[FocusedElement, ...]:
        elements = []
        for index, node in enumerate(
            syntax_pattern_nodes(cls.contract)[view_name]
        ):
            documentation = ""
            junction_type = None
            if view_name == SYNTAX_COLLECTIVE_VIEW and index == 2:
                documentation = " ".join(
                    REQUIRED_COLLECTIVE_ELEMENT_DOCUMENTATION
                )
                junction_type = "and"
            if view_name == SYNTAX_QUALIFICATION_VIEW and index == 0:
                documentation = "A concrete nonempty proposal rationale."
            elements.append(
                FocusedElement(
                    identity=f"element-{index}",
                    name=node.name,
                    archimate_element=node.archimate_element,
                    properties=cls._properties(
                        node.metadata,
                        o2i_type=node.o2i_type,
                    ),
                    documentation=documentation,
                    junction_type=junction_type,
                )
            )
        return tuple(elements)

    @classmethod
    def _relation(
        cls,
        identity: str,
        source: FocusedElement,
        target: FocusedElement,
        *,
        name: str,
        relationship: str,
        directed: bool,
        metadata: object,
        role: str | None = None,
    ) -> FocusedRelation:
        return FocusedRelation(
            identity=identity,
            source=source.identity,
            source_name=source.name,
            source_type=source.archimate_element,
            name=name,
            archimate_relationship=relationship,
            directed=directed,
            target=target.identity,
            target_name=target.name,
            target_type=target.archimate_element,
            properties=cls._properties(metadata, role=role),
        )

    @classmethod
    def _target_view(cls, view_name: str) -> FocusedView:
        elements = cls._elements(view_name)
        by_name = {element.name: element for element in elements}
        contextualization = profile_pattern(
            cls.contract,
            "contextualization",
        )
        context_shape = {
            "name": contextualization["label"],
            "relationship": contextualization["archimateRelationship"],
            "directed": contextualization["associationDirected"],
            "metadata": contextualization["relationshipMetadata"],
        }
        relations = []
        if view_name == SYNTAX_CONTEXTUALIZATION_VIEW:
            for index, (source, target) in enumerate(
                (
                    (
                        "<Name> :: O2I Mission",
                        "<Name> :: O2I Driver",
                    ),
                    (
                        "<Name> :: O2I Strategy",
                        "<Name> :: O2I Performance Dimension",
                    ),
                )
            ):
                relations.append(
                    cls._relation(
                        f"context-{index}",
                        by_name[source],
                        by_name[target],
                        **context_shape,
                    )
                )
        elif view_name == SYNTAX_COLLECTIVE_VIEW:
            collective = profile_pattern(
                cls.contract,
                "collective-strategy-realization",
            )
            carrier = by_name[
                "<Name> :: O2I Collective Strategy Realization"
            ]
            pairs = (
                (by_name["<Contributor Strategy 1> :: O2I Strategy"], carrier),
                (by_name["<Contributor Strategy 2> :: O2I Strategy"], carrier),
                (carrier, by_name["<Target Strategy> :: O2I Strategy"]),
            )
            for index, (source, target) in enumerate(pairs):
                relations.append(
                    cls._relation(
                        f"segment-{index}",
                        source,
                        target,
                        name=collective["segments"]["label"],
                        relationship=collective["segments"][
                            "archimateRelationship"
                        ],
                        directed=collective["segments"][
                            "associationDirected"
                        ],
                        metadata=collective["segmentMetadata"],
                    )
                )
        else:
            qualification = cls.contract.qualification_proposal
            proposal = by_name[qualification_proposal_name(qualification)]
            roles = {
                role["role"]: role
                for role in qualification["references"]["roles"]
            }
            role_elements = {
                role: by_name[qualification_role_name(contract)]
                for role, contract in roles.items()
            }
            for role, target in role_elements.items():
                relations.append(
                    cls._relation(
                        f"reference-{role}",
                        proposal,
                        target,
                        name="",
                        relationship=qualification["references"][
                            "archimateRelationship"
                        ],
                        directed=qualification["references"][
                            "associationDirected"
                        ],
                        metadata=qualification["references"]["metadata"],
                        role=role,
                    )
                )
            context_by_type = {
                role["o2iType"]: role_elements[name]
                for name, role in roles.items()
                if role["o2iKind"] == "Context"
            }
            for role, role_contract in roles.items():
                if role_contract["contextType"] is None:
                    continue
                relations.append(
                    cls._relation(
                        f"context-{role}",
                        context_by_type[role_contract["contextType"]],
                        role_elements[role],
                        **context_shape,
                    )
                )
        return FocusedView(
            name=view_name,
            elements=elements,
            relations=tuple(relations),
            documentation=" ".join(REQUIRED_VIEW_DOCUMENTATION[view_name]),
        )

    def assert_error(self, view: FocusedView, fragment: str) -> None:
        errors = validate_focused_view(self.contract, view)
        self.assertTrue(
            any(fragment in error for error in errors),
            f"{fragment!r} not found in {errors!r}",
        )

    def test_all_exact_target_views_are_accepted(self) -> None:
        for name, view in self.views.items():
            with self.subTest(view=name):
                self.assertEqual([], validate_focused_view(self.contract, view))

    def test_node_multiset_exposes_missing_duplicate_name_and_type(self) -> None:
        view = self.views[SYNTAX_CONTEXTUALIZATION_VIEW]
        node = view.elements[0]
        cases = (
            (
                replace(view, elements=view.elements[1:]),
                "exactly once; found 0",
            ),
            (
                replace(view, elements=view.elements + (node,)),
                "exactly once; found 2",
            ),
            (
                replace(
                    view,
                    elements=(replace(node, name="Wrong name"),) + view.elements[1:],
                ),
                "contains uncontracted focused node 'Wrong name'",
            ),
            (
                replace(
                    view,
                    elements=(
                        replace(node, archimate_element="Assessment"),
                    )
                    + view.elements[1:],
                ),
                "contains uncontracted focused node",
            ),
        )
        for candidate, fragment in cases:
            with self.subTest(fragment=fragment):
                self.assert_error(candidate, fragment)

    def test_typed_carrier_metadata_is_exact(self) -> None:
        view = self.views[SYNTAX_CONTEXTUALIZATION_VIEW]
        node = view.elements[0]
        cases = (
            ((), "property 'o2i.commitment' requires exactly-one; found 0"),
            (
                node.properties + (("o2i.type", "Driver"),),
                "property 'o2i.type' requires exactly-one; found 2",
            ),
            (
                (("o2i.type", "Strategy"), ("o2i.commitment", "candidate")),
                "property 'o2i.type' admits only ['Driver']",
            ),
            (
                node.properties + (("o2i.kind", "Primitive"),),
                "obsolete or uncontracted O2I property 'o2i.kind'",
            ),
        )
        for properties, fragment in cases:
            with self.subTest(fragment=fragment):
                candidate = replace(
                    view,
                    elements=(replace(node, properties=properties),)
                    + view.elements[1:],
                )
                self.assert_error(candidate, fragment)

    def test_contextualization_shape_and_metadata_are_exact(self) -> None:
        view = self.views[SYNTAX_CONTEXTUALIZATION_VIEW]
        relation = view.relations[0]
        cases = (
            (
                replace(view, relations=view.relations[1:]),
                "requires contextualization",
            ),
            (
                replace(view, relations=view.relations + (relation,)),
                "exactly once; found 2",
            ),
            (
                replace(
                    view,
                    relations=(replace(relation, name="wrong"),)
                    + view.relations[1:],
                ),
                "has an uncontracted contextualization",
            ),
            (
                replace(
                    view,
                    relations=(
                        replace(
                            relation,
                            archimate_relationship="AssociationRelationship",
                            directed=True,
                        ),
                    )
                    + view.relations[1:],
                ),
                "has an uncontracted contextualization",
            ),
            (
                replace(
                    view,
                    relations=(replace(relation, properties=()),)
                    + view.relations[1:],
                ),
                "property 'o2i.commitment' requires exactly-one; found 0",
            ),
        )
        for candidate, fragment in cases:
            with self.subTest(fragment=fragment):
                self.assert_error(candidate, fragment)

    def test_contextualization_cardinality_is_an_explicit_boundary(self) -> None:
        patterns = replace_path(
            self.contract.pattern_mappings,
            (0, "targetIncomingCardinality"),
            "zero-or-many",
        )
        candidate = replace(self.contract, pattern_mappings=patterns)
        with self.assertRaisesRegex(
            ProfileContractError,
            "unsupported focused-View contextualization target cardinality: "
            "zero-or-many",
        ):
            validate_focused_view(
                candidate,
                self.views[SYNTAX_CONTEXTUALIZATION_VIEW],
            )

    def test_collective_carrier_metadata_and_documentation_are_exact(self) -> None:
        view = self.views[SYNTAX_COLLECTIVE_VIEW]
        carrier = view.elements[2]
        cases = (
            (
                replace(carrier, junction_type="or"),
                "carrier is not the contracted AND Junction",
            ),
            (
                replace(
                    carrier,
                    properties=tuple(
                        item
                        for item in carrier.properties
                        if item[0] != "o2i.participant-completeness"
                    ),
                ),
                "property 'o2i.participant-completeness' requires exactly-one",
            ),
            (
                replace(
                    carrier,
                    properties=carrier.properties
                    + (("o2i.collective-fit-evidence", "pending"),),
                ),
                "obsolete or uncontracted O2I property",
            ),
            (
                replace(
                    carrier,
                    documentation=carrier.documentation + " Fit-evidence",
                ),
                "contains obsolete model-owned Fit-evidence",
            ),
        )
        for candidate_carrier, fragment in cases:
            with self.subTest(fragment=fragment):
                candidate = replace(
                    view,
                    elements=view.elements[:2]
                    + (candidate_carrier,)
                    + view.elements[3:],
                )
                self.assert_error(candidate, fragment)
        obsolete_view_documentation = replace(
            view,
            documentation=view.documentation.replace(
                "participant-completeness",
                "Fit-evidence",
            ),
        )
        self.assert_error(
            obsolete_view_documentation,
            "documentation is missing: participant-completeness",
        )
        self.assert_error(
            obsolete_view_documentation,
            "documentation contains obsolete model-owned Fit-evidence",
        )

    def test_collective_topology_rejects_gaps_repeats_and_wrong_segments(self) -> None:
        view = self.views[SYNTAX_COLLECTIVE_VIEW]
        relation = view.relations[0]
        cases = (
            (
                replace(view, relations=view.relations[1:]),
                "requires at least two distinct contributors; found 1",
            ),
            (
                replace(view, relations=view.relations + (relation,)),
                "repeats a contributor",
            ),
            (
                replace(
                    view,
                    relations=(replace(relation, name="wrong"),)
                    + view.relations[1:],
                ),
                "contributor segment is not contracted",
            ),
            (
                replace(
                    view,
                    relations=(replace(relation, properties=(("o2i.kind", "x"),)),)
                    + view.relations[1:],
                ),
                "obsolete or uncontracted O2I property 'o2i.kind'",
            ),
        )
        for candidate, fragment in cases:
            with self.subTest(fragment=fragment):
                self.assert_error(candidate, fragment)

    def test_collective_distinctness_fields_control_topology(self) -> None:
        view = self.views[SYNTAX_COLLECTIVE_VIEW]
        repeated = replace(view, relations=view.relations + (view.relations[0],))
        self.assert_error(repeated, "repeats a contributor")
        contributor = view.elements[0]
        target_relation = replace(
            view.relations[2],
            target=contributor.identity,
            target_name=contributor.name,
            target_type=contributor.archimate_element,
        )
        overlapping = replace(
            view,
            relations=view.relations[:2] + (target_relation,),
        )
        self.assert_error(
            overlapping,
            "target also participates as contributor",
        )
        cases = (
            (
                (1, "contributors", "distinct"),
                "forbidden",
                "unsupported collective contributor distinctness: forbidden",
            ),
            (
                (1, "target", "distinctFromContributors"),
                "forbidden",
                "unsupported collective target distinctness: forbidden",
            ),
        )
        for path, value, message in cases:
            with self.subTest(path=path):
                patterns = replace_path(
                    self.contract.pattern_mappings,
                    path,
                    value,
                )
                unsupported = replace(
                    self.contract,
                    pattern_mappings=patterns,
                )
                with self.assertRaisesRegex(ProfileContractError, message):
                    validate_focused_view(unsupported, view)

    def test_qualification_carrier_requires_type_source_and_rationale(self) -> None:
        view = self.views[SYNTAX_QUALIFICATION_VIEW]
        proposal = view.elements[0]
        cases = (
            (
                replace(
                    proposal,
                    properties=tuple(
                        item for item in proposal.properties if item[0] != "o2i.source"
                    ),
                ),
                "property 'o2i.source' requires one-or-more; found 0",
            ),
            (
                replace(
                    proposal,
                    properties=proposal.properties + (("o2i.source", ""),),
                ),
                "requires a nonempty normalized source identity",
            ),
            (
                replace(
                    proposal,
                    properties=(("o2i.type", "NeedQualificationProposal"),)
                    + (("o2i.source", None),),
                ),
                "property 'o2i.source' requires string values",
            ),
            (
                replace(
                    proposal,
                    properties=proposal.properties
                    + (("o2i.commitment", "candidate"),),
                ),
                "property 'o2i.commitment' requires forbidden; found 1",
            ),
            (
                replace(proposal, documentation="  "),
                "requires one nonempty rationale",
            ),
        )
        for candidate_proposal, fragment in cases:
            with self.subTest(fragment=fragment):
                candidate = replace(
                    view,
                    elements=(candidate_proposal,) + view.elements[1:],
                )
                self.assert_error(candidate, fragment)

    def test_qualification_direction_and_property_shapes_are_explicit(self) -> None:
        view = self.views[SYNTAX_QUALIFICATION_VIEW]
        qualification = replace_path(
            self.contract.qualification_proposal,
            ("references", "direction"),
            "subject-to-proposal",
        )
        candidate = replace(
            self.contract,
            qualification_proposal=qualification,
        )
        with self.assertRaisesRegex(
            ProfileContractError,
            "unsupported qualification reference direction: "
            "subject-to-proposal",
        ):
            validate_focused_view(candidate, view)

        cases = (
            (
                "profileCardinality",
                "exactly-one",
                "unsupported focused-View Profile property cardinality: "
                "exactly-one",
            ),
            (
                "valueCardinality",
                "zero-or-many",
                "unsupported focused-View property value cardinality: "
                "zero-or-many",
            ),
        )
        for field, value, message in cases:
            with self.subTest(field=field):
                qualification = replace_path(
                    self.contract.qualification_proposal,
                    ("carrier", "metadata", "properties", 1, field),
                    value,
                )
                candidate = replace(
                    self.contract,
                    qualification_proposal=qualification,
                )
                with self.assertRaisesRegex(ProfileContractError, message):
                    validate_focused_view(candidate, view)

    def test_each_qualification_reference_is_exact_and_directed(self) -> None:
        view = self.views[SYNTAX_QUALIFICATION_VIEW]
        for index, relation in enumerate(view.relations[:4]):
            role = relation.properties[0][1]
            remaining = view.relations[:index] + view.relations[index + 1 :]
            cases = (
                (
                    replace(view, relations=remaining),
                    f"requires exactly one {role!r} reference; found 0",
                ),
                (
                    replace(view, relations=view.relations + (relation,)),
                    f"requires exactly one {role!r} reference; found 2",
                ),
                (
                    replace(
                        view,
                        relations=view.relations[:index]
                        + (
                            replace(
                                relation,
                                source=relation.target,
                                source_name=relation.target_name,
                                source_type=relation.target_type,
                                target=relation.source,
                                target_name=relation.source_name,
                                target_type=relation.source_type,
                            ),
                        )
                        + view.relations[index + 1 :],
                    ),
                    "is reversed; expected proposal-to-subject direction",
                ),
                (
                    replace(
                        view,
                        relations=view.relations[:index]
                        + (
                            replace(
                                relation,
                                archimate_relationship="CompositionRelationship",
                                directed=False,
                            ),
                        )
                        + view.relations[index + 1 :],
                    ),
                    "reference requires AssociationRelationship directed=true",
                ),
                (
                    replace(
                        view,
                        relations=view.relations[:index]
                        + (replace(relation, name="wrong-name"),)
                        + view.relations[index + 1 :],
                    ),
                    f"{role!r} reference must be unnamed; found 'wrong-name'",
                ),
                (
                    replace(
                        view,
                        relations=view.relations[:index]
                        + (replace(relation, properties=(("o2i.role", "wrong"),)),)
                        + view.relations[index + 1 :],
                    ),
                    f"admits only [{role!r}]",
                ),
                (
                    replace(
                        view,
                        relations=view.relations[:index]
                        + (
                            replace(
                                relation,
                                properties=relation.properties
                                + (("o2i.commitment", "candidate"),),
                            ),
                        )
                        + view.relations[index + 1 :],
                    ),
                    "property 'o2i.commitment' requires forbidden; found 1",
                ),
            )
            for candidate, fragment in cases:
                with self.subTest(role=role, fragment=fragment):
                    self.assert_error(candidate, fragment)

    def test_qualification_endpoint_contexts_are_explicit_and_committed(self) -> None:
        view = self.views[SYNTAX_QUALIFICATION_VIEW]
        for index, relation in enumerate(view.relations[4:], start=4):
            role = relation.identity.removeprefix("context-")
            cases = (
                (
                    replace(
                        view,
                        relations=view.relations[:index]
                        + view.relations[index + 1 :],
                    ),
                    f"requires exactly one contextualization for {role!r}; found 0",
                ),
                (
                    replace(
                        view,
                        relations=view.relations[:index]
                        + (replace(relation, name="wrong"),)
                        + view.relations[index + 1 :],
                    ),
                    "endpoint contextualization is not contracted",
                ),
                (
                    replace(
                        view,
                        relations=view.relations[:index]
                        + (replace(relation, properties=()),)
                        + view.relations[index + 1 :],
                    ),
                    "property 'o2i.commitment' requires exactly-one; found 0",
                ),
            )
            for candidate, fragment in cases:
                with self.subTest(role=role, fragment=fragment):
                    self.assert_error(candidate, fragment)


if __name__ == "__main__":
    unittest.main()
