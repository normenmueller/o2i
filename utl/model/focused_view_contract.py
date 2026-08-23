"""Validate focused repository Views against the current Profile and Core."""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
import re

from repository_view_contract import (
    FrozenObject,
    ProfileContractError,
    RepositoryViewContract,
    carrier_archimate_element,
    endpoint_archimate_element,
)


SYNTAX_CONTEXTUALIZATION_VIEW = "O2I Syntax - Contextualization"
SYNTAX_COLLECTIVE_VIEW = "O2I Syntax - Collective Strategy Realization"
SYNTAX_QUALIFICATION_VIEW = "O2I Syntax - Need Qualification Proposal"
FOCUSED_VIEW_NAMES = frozenset(
    {
        SYNTAX_CONTEXTUALIZATION_VIEW,
        SYNTAX_COLLECTIVE_VIEW,
        SYNTAX_QUALIFICATION_VIEW,
    }
)

REQUIRED_CONTEXTUALIZATION_DOCUMENTATION = (
    "Visualizes the executable ArchiMate conformance pattern for "
    "contextualizing O2I Primitives and PerformanceDimensions.",
    "composition[contextualizes]",
    "visual nesting has no contextualization semantics",
    "spc/ctr/archimate/profile.json",
    "Candidate syntax exemplars, not fachliche model instances",
)
REQUIRED_COLLECTIVE_DOCUMENTATION = (
    "Visualizes the executable ArchiMate conformance pattern for one O2I "
    "CollectiveStrategyRealization.",
    "realizes segments and one AND Junction",
    "StructuredProposition carrier",
    "participant-completeness",
    "spc/ctr/archimate/profile.json",
    "syntax exemplars, not fachliche model instances",
)
REQUIRED_COLLECTIVE_ELEMENT_DOCUMENTATION = (
    "Candidate ArchiMate AND Junction carrier",
    "CollectiveStrategyRealization StructuredProposition",
    "roles follow from realizes topology",
    "participant-completeness",
    "spc/ctr/archimate/profile.json",
    "syntax exemplar is not a fachliche model instance",
)
REQUIRED_QUALIFICATION_DOCUMENTATION = (
    "Visualizes the executable ArchiMate conformance pattern for one O2I "
    "NeedQualificationProposal.",
    "Assessment carrier",
    "directed Association references",
    "o2i.role",
    "rationale and source",
    "spc/ctr/archimate/profile.json",
    "syntax exemplar, not a fachliche model instance",
)
REQUIRED_VIEW_DOCUMENTATION = {
    SYNTAX_CONTEXTUALIZATION_VIEW: REQUIRED_CONTEXTUALIZATION_DOCUMENTATION,
    SYNTAX_COLLECTIVE_VIEW: REQUIRED_COLLECTIVE_DOCUMENTATION,
    SYNTAX_QUALIFICATION_VIEW: REQUIRED_QUALIFICATION_DOCUMENTATION,
}


@dataclass(frozen=True)
class SyntaxNodeContract:
    """One exact focused-View node and its Profile metadata contract."""

    name: str
    archimate_element: str
    o2i_type: str
    metadata: FrozenObject


@dataclass(frozen=True)
class FocusedElement:
    """One resolved element occurrence displayed by a focused View."""

    identity: str
    name: str
    archimate_element: str
    properties: tuple[tuple[str, str | None], ...]
    documentation: str
    junction_type: str | None


@dataclass(frozen=True)
class FocusedRelation:
    """One resolved relationship occurrence displayed by a focused View."""

    identity: str
    source: str
    source_name: str
    source_type: str
    name: str
    archimate_relationship: str
    directed: bool
    target: str
    target_name: str
    target_type: str
    properties: tuple[tuple[str, str | None], ...]


@dataclass(frozen=True)
class FocusedView:
    """Notation-neutral resolved input for focused repository verification."""

    name: str
    elements: tuple[FocusedElement, ...]
    relations: tuple[FocusedRelation, ...]
    documentation: str


def profile_pattern(
    contract: RepositoryViewContract,
    identifier: str,
) -> FrozenObject:
    matches = [
        pattern
        for pattern in contract.pattern_mappings
        if pattern["id"] == identifier
    ]
    if len(matches) != 1:
        raise ProfileContractError(
            f"Profile contract requires exactly one {identifier!r} pattern"
        )
    return matches[0]


def words(identifier: str) -> str:
    value = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", identifier)
    return value.replace("Course Of Action", "Course of Action")


def qualification_proposal_name(qualification: FrozenObject) -> str:
    return "<Name> :: O2I " + words(qualification["carrier"]["o2iType"])


def qualification_role_name(role: FrozenObject) -> str:
    placeholder = role["role"].replace("-", " ").title()
    return f"<{placeholder}> :: O2I {words(role['o2iType'])}"


def syntax_pattern_nodes(
    contract: RepositoryViewContract,
) -> dict[str, tuple[SyntaxNodeContract, ...]]:
    """Derive every exact focused-View node from current authorities."""
    contextualization = profile_pattern(contract, "contextualization")
    collective = profile_pattern(contract, "collective-strategy-realization")
    qualification = contract.qualification_proposal
    context_carrier = carrier_archimate_element(
        contract,
        contextualization["sourceKind"],
        "Mission",
    )
    typed_metadata = contextualization["carrierMetadata"]
    return {
        SYNTAX_CONTEXTUALIZATION_VIEW: (
            SyntaxNodeContract(
                "<Name> :: O2I Driver",
                carrier_archimate_element(contract, "Primitive", "Driver"),
                "Driver",
                typed_metadata,
            ),
            SyntaxNodeContract(
                "<Name> :: O2I Mission",
                context_carrier,
                "Mission",
                typed_metadata,
            ),
            SyntaxNodeContract(
                "<Name> :: O2I Performance Dimension",
                carrier_archimate_element(
                    contract,
                    "Structuring",
                    "PerformanceDimension",
                ),
                "PerformanceDimension",
                typed_metadata,
            ),
            SyntaxNodeContract(
                "<Name> :: O2I Strategy",
                context_carrier,
                "Strategy",
                typed_metadata,
            ),
        ),
        SYNTAX_COLLECTIVE_VIEW: (
            SyntaxNodeContract(
                "<Contributor Strategy 1> :: O2I Strategy",
                endpoint_archimate_element(
                    contract,
                    collective["contributors"]["endpoint"],
                ),
                "Strategy",
                collective["endpointMetadata"],
            ),
            SyntaxNodeContract(
                "<Contributor Strategy 2> :: O2I Strategy",
                endpoint_archimate_element(
                    contract,
                    collective["contributors"]["endpoint"],
                ),
                "Strategy",
                collective["endpointMetadata"],
            ),
            SyntaxNodeContract(
                "<Name> :: O2I Collective Strategy Realization",
                collective["carrier"]["archimateElement"],
                collective["carrier"]["o2iType"],
                collective["carrierMetadata"],
            ),
            SyntaxNodeContract(
                "<Target Strategy> :: O2I Strategy",
                endpoint_archimate_element(
                    contract,
                    collective["target"]["endpoint"],
                ),
                "Strategy",
                collective["endpointMetadata"],
            ),
        ),
        SYNTAX_QUALIFICATION_VIEW: (
            SyntaxNodeContract(
                qualification_proposal_name(qualification),
                qualification["carrier"]["archimateElement"],
                qualification["carrier"]["o2iType"],
                qualification["carrier"]["metadata"],
            ),
            *(
                SyntaxNodeContract(
                    qualification_role_name(role),
                    endpoint_archimate_element(contract, role["endpoint"]),
                    role["o2iType"],
                    qualification["endpointMetadata"],
                )
                for role in qualification["references"]["roles"]
            ),
        ),
    }


def validate_focused_view(
    contract: RepositoryViewContract,
    view: FocusedView,
) -> list[str]:
    """Validate one complete focused View with no XML or file-system access."""
    contracts = syntax_pattern_nodes(contract)
    if view.name not in contracts:
        raise ProfileContractError(f"unknown focused View: {view.name}")
    errors = _node_errors(view, contracts[view.name])
    errors.extend(_documentation_errors(view))
    if view.name == SYNTAX_CONTEXTUALIZATION_VIEW:
        errors.extend(_contextualization_errors(contract, view))
    elif view.name == SYNTAX_COLLECTIVE_VIEW:
        errors.extend(_collective_errors(contract, view))
    else:
        errors.extend(_qualification_errors(contract, view))
    return errors


def _metadata_errors(
    view_name: str,
    subject: str,
    properties: tuple[tuple[str, str | None], ...],
    metadata: FrozenObject,
    expected_values: dict[str, tuple[str, ...]] | None = None,
) -> list[str]:
    if metadata["additionalO2IProperties"] != "forbidden":
        raise ProfileContractError(
            "unsupported focused-View additional metadata policy"
        )
    expected_values = expected_values or {}
    requirements = {
        requirement["key"]: requirement
        for requirement in metadata["properties"]
    }
    allowed = {
        requirement["key"]
        for requirement in metadata["properties"]
        if requirement["cardinality"] != "forbidden"
    }
    if allowed != set(metadata["allowedO2IProperties"]):
        raise ProfileContractError(
            "focused-View metadata projection has inconsistent allowed keys"
        )
    values_by_key: dict[str, list[str | None]] = {}
    for key, value in properties:
        if key.startswith("o2i."):
            values_by_key.setdefault(key, []).append(value)

    errors = []
    for key in sorted(set(values_by_key) - set(requirements)):
        errors.append(
            f"{view_name} {subject} has obsolete or uncontracted O2I "
            f"property {key!r}"
        )
    for key, requirement in sorted(requirements.items()):
        profile_cardinality = requirement["profileCardinality"]
        if (
            profile_cardinality is not None
            and profile_cardinality != "zero-or-many"
        ):
            raise ProfileContractError(
                "unsupported focused-View Profile property cardinality: "
                f"{profile_cardinality}"
            )
        value_cardinality = requirement["valueCardinality"]
        if (
            value_cardinality is not None
            and value_cardinality != "exactly-one"
        ):
            raise ProfileContractError(
                "unsupported focused-View property value cardinality: "
                f"{value_cardinality}"
            )
        values = values_by_key.get(key, [])
        cardinality = requirement["cardinality"]
        if cardinality not in {
            "forbidden",
            "exactly-one",
            "one-or-more",
            "zero-or-many",
        }:
            raise ProfileContractError(
                f"unsupported focused-View property cardinality: {cardinality}"
            )
        valid = (
            (cardinality == "forbidden" and not values)
            or (cardinality == "exactly-one" and len(values) == 1)
            or (cardinality == "one-or-more" and len(values) >= 1)
            or cardinality == "zero-or-many"
        )
        if not valid:
            errors.append(
                f"{view_name} {subject} property {key!r} requires "
                f"{cardinality}; found {len(values)}"
            )
            continue
        admitted = expected_values.get(
            requirement["role"],
            tuple(requirement["admittedValues"]),
        )
        invalid = [value for value in values if admitted and value not in admitted]
        if invalid:
            errors.append(
                f"{view_name} {subject} property {key!r} admits only "
                f"{list(admitted)!r}; found {invalid!r}"
            )
        if requirement["valueKind"] == "string" and any(
            value is None for value in values
        ):
            errors.append(
                f"{view_name} {subject} property {key!r} requires string values"
            )
        grammar = requirement["grammar"]
        if grammar is not None and grammar != "source-identity":
            raise ProfileContractError(
                f"unsupported focused-View property grammar: {grammar}"
            )
        if grammar == "source-identity" and any(
            value is None or not value.strip() for value in values
        ):
            errors.append(
                f"{view_name} {subject} property {key!r} requires a "
                "nonempty normalized source identity"
            )
    return errors


def _node_errors(
    view: FocusedView,
    contracts: tuple[SyntaxNodeContract, ...],
) -> list[str]:
    counts = Counter(
        (element.name, element.archimate_element)
        for element in view.elements
    )
    expected = {
        (contract.name, contract.archimate_element)
        for contract in contracts
    }
    errors = []
    for contract in contracts:
        key = (contract.name, contract.archimate_element)
        count = counts[key]
        if count != 1:
            errors.append(
                f"{view.name} requires node {contract.name!r} "
                f"({contract.archimate_element}) exactly once; found {count}"
            )
        for element in view.elements:
            if (element.name, element.archimate_element) == key:
                errors.extend(
                    _metadata_errors(
                        view.name,
                        f"element {contract.name!r}",
                        element.properties,
                        contract.metadata,
                        {"type": (contract.o2i_type,)},
                    )
                )
    for (name, element_type), count in sorted(counts.items()):
        if (name, element_type) not in expected:
            errors.append(
                f"{view.name} contains uncontracted focused node {name!r} "
                f"({element_type}); found {count} occurrence(s)"
            )
    return errors


def _documentation_errors(view: FocusedView) -> list[str]:
    errors = []
    for fragment in REQUIRED_VIEW_DOCUMENTATION[view.name]:
        if fragment not in view.documentation:
            errors.append(f"{view.name} documentation is missing: {fragment}")
    if view.name != SYNTAX_COLLECTIVE_VIEW:
        return errors
    if "Fit-evidence" in view.documentation:
        errors.append(
            f"{view.name} documentation contains obsolete model-owned "
            "Fit-evidence"
        )
    carrier_name = "<Name> :: O2I Collective Strategy Realization"
    carriers = [element for element in view.elements if element.name == carrier_name]
    if len(carriers) != 1:
        return errors
    documentation = carriers[0].documentation
    for fragment in REQUIRED_COLLECTIVE_ELEMENT_DOCUMENTATION:
        if fragment not in documentation:
            errors.append(
                f"{view.name} element {carrier_name!r} documentation is "
                f"missing: {fragment}"
            )
    if "Fit-evidence" in documentation:
        errors.append(
            f"{view.name} element {carrier_name!r} documentation contains "
            "obsolete model-owned Fit-evidence"
        )
    return errors


def _contextualization_errors(
    contract: RepositoryViewContract,
    view: FocusedView,
) -> list[str]:
    contextualization = profile_pattern(contract, "contextualization")
    if contextualization["targetIncomingCardinality"] != "exactly-one":
        raise ProfileContractError(
            "unsupported focused-View contextualization target cardinality: "
            f"{contextualization['targetIncomingCardinality']}"
        )
    expected_shape = (
        contextualization["label"],
        contextualization["archimateRelationship"],
        contextualization["associationDirected"],
    )
    expected_pairs = {
        ("<Name> :: O2I Mission", "<Name> :: O2I Driver"),
        (
            "<Name> :: O2I Strategy",
            "<Name> :: O2I Performance Dimension",
        ),
    }
    pair_counts = Counter(
        (relation.source_name, relation.target_name)
        for relation in view.relations
    )
    errors = []
    for relation in view.relations:
        if (relation.source_name, relation.target_name) not in expected_pairs:
            errors.append(
                f"{view.name} contains uncontracted focused relation "
                f"{relation.source_name} --{relation.name}--> "
                f"{relation.target_name}"
            )
        if (
            relation.name,
            relation.archimate_relationship,
            relation.directed,
        ) != expected_shape:
            errors.append(
                f"{view.name} has an uncontracted contextualization: "
                f"{relation.source_name} --{relation.name}--> "
                f"{relation.target_name}"
            )
        errors.extend(
            _metadata_errors(
                view.name,
                f"relationship {relation.identity!r}",
                relation.properties,
                contextualization["relationshipMetadata"],
            )
        )
    for pair in sorted(expected_pairs):
        count = pair_counts[pair]
        if count != 1:
            errors.append(
                f"{view.name} requires contextualization {pair[0]!r} to "
                f"{pair[1]!r} exactly once; found {count}"
            )
    return errors


def _collective_errors(
    contract: RepositoryViewContract,
    view: FocusedView,
) -> list[str]:
    collective = profile_pattern(contract, "collective-strategy-realization")
    carrier_name = "<Name> :: O2I Collective Strategy Realization"
    carriers = [element for element in view.elements if element.name == carrier_name]
    if len(carriers) != 1:
        return []
    carrier = carriers[0]
    expected_junction = collective["carrier"]["junctionType"]
    actual_junction = carrier.junction_type or "and"
    errors = []
    if actual_junction != expected_junction:
        errors.append(
            f"{view.name} carrier is not the contracted "
            f"{expected_junction.upper()} Junction"
        )
    expected_relation = (
        collective["segments"]["label"],
        collective["segments"]["archimateRelationship"],
        collective["segments"]["associationDirected"],
    )
    contributors = []
    targets = []
    for relation in view.relations:
        errors.extend(
            _metadata_errors(
                view.name,
                f"relationship {relation.identity!r}",
                relation.properties,
                collective["segmentMetadata"],
            )
        )
        actual_relation = (
            relation.name,
            relation.archimate_relationship,
            relation.directed,
        )
        if relation.target == carrier.identity and relation.source != carrier.identity:
            contributors.append(relation.source)
            if actual_relation != expected_relation:
                errors.append(
                    f"{view.name} contributor segment is not contracted: "
                    f"{relation.source_name} --{relation.name}--> {carrier.name}"
                )
        elif (
            relation.source == carrier.identity
            and relation.target != carrier.identity
        ):
            targets.append(relation.target)
            if actual_relation != expected_relation:
                errors.append(
                    f"{view.name} target segment is not contracted: "
                    f"{carrier.name} --{relation.name}--> {relation.target_name}"
                )
        else:
            errors.append(
                f"{view.name} relation does not participate in the collective "
                f"carrier topology: {relation.source_name} "
                f"--{relation.name}--> {relation.target_name}"
            )
    if collective["contributors"]["cardinality"] != "at-least-two":
        raise ProfileContractError("unsupported collective contributor cardinality")
    if len(set(contributors)) < 2:
        errors.append(
            f"{view.name} requires at least two distinct contributors; "
            f"found {len(set(contributors))}"
        )
    contributor_distinctness = collective["contributors"]["distinct"]
    if contributor_distinctness != "required":
        raise ProfileContractError(
            "unsupported collective contributor distinctness: "
            f"{contributor_distinctness}"
        )
    if len(contributors) != len(set(contributors)):
        errors.append(f"{view.name} repeats a contributor")
    if collective["target"]["cardinality"] != "exactly-one":
        raise ProfileContractError("unsupported collective target cardinality")
    if len(targets) != 1:
        errors.append(
            f"{view.name} requires exactly one target; found {len(targets)}"
        )
    target_distinctness = collective["target"][
        "distinctFromContributors"
    ]
    if target_distinctness != "required":
        raise ProfileContractError(
            "unsupported collective target distinctness: "
            f"{target_distinctness}"
        )
    if set(targets) & set(contributors):
        errors.append(f"{view.name} target also participates as contributor")
    return errors


def _qualification_errors(
    contract: RepositoryViewContract,
    view: FocusedView,
) -> list[str]:
    qualification = contract.qualification_proposal
    if qualification["references"]["direction"] != "proposal-to-subject":
        raise ProfileContractError(
            "unsupported qualification reference direction: "
            f"{qualification['references']['direction']}"
        )
    contextualization = profile_pattern(contract, "contextualization")
    proposal_name = qualification_proposal_name(qualification)
    proposals = [element for element in view.elements if element.name == proposal_name]
    if len(proposals) != 1:
        return []
    proposal = proposals[0]
    if qualification["carrier"]["rationale"] != (
        "exactly-one-nonempty-normalized-documentation"
    ):
        raise ProfileContractError(
            "unsupported qualification proposal rationale contract"
        )
    errors = []
    if not " ".join(proposal.documentation.split()):
        errors.append(
            f"{view.name} proposal carrier requires one nonempty rationale "
            "in its documentation"
        )
    roles = {
        role["role"]: role
        for role in qualification["references"]["roles"]
    }
    element_by_role = {}
    for role_name, role in roles.items():
        matches = [
            element
            for element in view.elements
            if element.name == qualification_role_name(role)
            and element.archimate_element
            == endpoint_archimate_element(contract, role["endpoint"])
        ]
        if len(matches) == 1:
            element_by_role[role_name] = matches[0]
    if len(element_by_role) != len(roles):
        return errors
    expected_contextualizations = {}
    for role_name, role in roles.items():
        context_type = role["contextType"]
        if context_type is None:
            continue
        context_role = next(
            (
                name
                for name, candidate in roles.items()
                if candidate["o2iKind"] == "Context"
                and candidate["o2iType"] == context_type
            ),
            None,
        )
        if context_role is None:
            raise ProfileContractError(
                f"qualification role has no projected context: {role_name}"
            )
        expected_contextualizations[
            (
                element_by_role[context_role].identity,
                element_by_role[role_name].identity,
            )
        ] = role_name

    role_by_target = {
        element.identity: role
        for role, element in element_by_role.items()
    }
    reference_counts: Counter[str] = Counter()
    contextualization_counts: Counter[str] = Counter()
    expected_reference = (
        qualification["references"]["archimateRelationship"],
        qualification["references"]["associationDirected"],
    )
    expected_contextualization = (
        contextualization["label"],
        contextualization["archimateRelationship"],
        contextualization["associationDirected"],
    )
    for relation in view.relations:
        if relation.source == proposal.identity and relation.target in role_by_target:
            role = role_by_target[relation.target]
            reference_counts[role] += 1
            if relation.name:
                errors.append(
                    f"{view.name} {role!r} reference must be unnamed; "
                    f"found {relation.name!r}"
                )
            if (
                relation.archimate_relationship,
                relation.directed,
            ) != expected_reference:
                errors.append(
                    f"{view.name} {role!r} reference requires "
                    f"{expected_reference[0]} directed="
                    f"{str(expected_reference[1]).lower()}; found "
                    f"{relation.archimate_relationship} directed="
                    f"{str(relation.directed).lower()}"
                )
            errors.extend(
                _metadata_errors(
                    view.name,
                    f"{role!r} reference {relation.identity!r}",
                    relation.properties,
                    qualification["references"]["metadata"],
                    {"role": (role,)},
                )
            )
        elif relation.target == proposal.identity and relation.source in role_by_target:
            errors.append(
                f"{view.name} reference {relation.identity!r} is reversed; "
                "expected proposal-to-subject direction"
            )
        elif (relation.source, relation.target) in expected_contextualizations:
            role = expected_contextualizations[(relation.source, relation.target)]
            contextualization_counts[role] += 1
            if (
                relation.name,
                relation.archimate_relationship,
                relation.directed,
            ) != expected_contextualization:
                errors.append(
                    f"{view.name} {role!r} endpoint contextualization is not "
                    "contracted"
                )
            errors.extend(
                _metadata_errors(
                    view.name,
                    f"{role!r} contextualization {relation.identity!r}",
                    relation.properties,
                    contextualization["relationshipMetadata"],
                )
            )
        else:
            errors.append(
                f"{view.name} contains uncontracted focused relation "
                f"{relation.source_name} --{relation.name}--> "
                f"{relation.target_name}"
            )
    for role_name, role in roles.items():
        if role["cardinality"] != "exactly-one":
            raise ProfileContractError(
                f"unsupported qualification cardinality: {role['cardinality']}"
            )
        count = reference_counts[role_name]
        if count != 1:
            errors.append(
                f"{view.name} requires exactly one {role_name!r} reference; "
                f"found {count}"
            )
        if role["contextType"] is not None:
            context_count = contextualization_counts[role_name]
            if context_count != 1:
                errors.append(
                    f"{view.name} requires exactly one contextualization for "
                    f"{role_name!r}; found {context_count}"
                )
    return errors
