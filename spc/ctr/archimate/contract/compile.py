#!/usr/bin/env python3
"""Compile the closed ArchiMate Profile companion into private Haskell data."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any, Callable, Iterable


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
COMPANION = PACKAGE_ROOT / "profile.json"
DEFAULT_CORE_COMPANION = PACKAGE_ROOT.parents[1] / "lib/core/semantics.json"
GENERATED = PACKAGE_ROOT / "src/O2I/ArchiMate/Profile/Internal/Generated.hs"
EXPECTED_SHAPE_SHA256 = (
    "029fea4eb74b23939687534ac71fd52fdb5065bb9e8bb1d168f45299b7e23838"
)
EXPECTED_SHA256 = (
    "8be461eea73fee9f408fc830d7b85b4ebdf238a3f1521ecc58e56edfdccae7d2"
)
EXPECTED_CORE_SHA256 = (
    "fa431df65d5a5fdd64d91d5ad4089a3e8e31421027f4e0258370e742c8b1a333"
)
EXPECTED_FIXED_POINT_SEMANTICS_SHA256 = (
    "2bb2381468d8ec09b54879cd28d03acd0ede0ac519ba57c242979e749e233cb2"
)

EXPECTED_PROFILE_EVIDENCE_KINDS = (
    "carrier-occurrence",
    "classification-occurrence",
    "metadata-owner-and-o2i-property-occurrences",
    "property-occurrence-evidence",
    "property-slot-evidence",
    "property-value-evidence",
    "proposal-carrier-occurrence",
    "proposal-reference-incidence",
    "relationship-occurrence",
    "reserved-property-occurrence",
    "structured-carrier-occurrence",
    "structured-incidence",
)

EXPECTED_EVIDENCE_BINDING_CONTRACT = {
    "embeddedRule": "nearest-ancestor-evidenceKind",
    "generatedPropertyRule": "propertyRuleEvidence-by-applicable-leaf-suffix",
    "generatedCarrierRule": "derivedRuleEvidence.carrier",
    "generatedRelationRule": "derivedRuleEvidence.relation",
    "generatedReservedPlacementRule": "reserved-property-occurrence",
}

EXPECTED_PROPERTY_RULE_EVIDENCE = {
    "property-cardinality": "property-slot-evidence",
    "value-cardinality": "property-occurrence-evidence",
    "value-kind": "property-value-evidence",
    "value-grammar": "property-value-evidence",
    "admitted-values": "property-value-evidence",
    "value-domain": "property-value-evidence",
}

EXPECTED_DERIVED_RULE_EVIDENCE = {
    "carrier": "carrier-occurrence",
    "relation": "relationship-occurrence",
}

EXPECTED_GRAPH_FACTS = (
    "GraphMember(record)",
    "GraphSeed(viewOccurrence,record)",
    "GraphContextualizableCarrier(record,carrierMappingId)",
    "GraphContextualization(relationship,contextCarrier,contextualizedCarrier)",
    "GraphStructuredFamilyCarrier(familyId,junction)",
    "GraphStructuredFamilyIncidence(familyId,junction,relationship)",
    "GraphStructuredFamilyParticipantSegment(familyId,junction,relationship)",
    "GraphStructuredFamilyTargetSegment(familyId,junction,relationship)",
)
EXPECTED_QUALIFICATION_FACTS = (
    "QualificationMember(record)",
    "QualificationProposalCarrier(proposal)",
    "QualificationProposalRoleIncidence(proposal,reference)",
    "QualificationContextualizableProposalEndpoint(proposal,reference,roleId,endpoint)",
    "QualificationContextualizationOfProposalEndpoint(proposal,reference,endpoint,contextualization)",
    "QualificationContextOwnerRequiredByProposal(proposal,reference,endpoint,contextualization,contextOwner)",
    "QualificationContextualizationOfExactProposalEndpoint(proposal,reference,endpoint,contextOwner,contextualization)",
)

CONSEQUENCE_INTERPRETATION = {
    "BranchMember(branch,ownerRecord)": (
        "GeneratedBranchMember GeneratedOwnerRecord",
        frozenset({"branch-member"}),
        frozenset({"ownerRecord"}),
    ),
    "GraphMember(ownerRecord)": (
        "GeneratedFact (GeneratedGraphMember GeneratedOwnerRecord)",
        frozenset({"graph"}),
        frozenset({"ownerRecord"}),
    ),
    "GraphMember(includedRecord)": (
        "GeneratedFact (GeneratedGraphMember GeneratedIncludedRecord)",
        frozenset({"graph"}),
        frozenset({"includedRecord"}),
    ),
    "GraphContextualizableCarrier(ownerRecord,carrierMappingId)": (
        "GeneratedFact (GeneratedGraphContextualizableCarrier GeneratedOwnerRecord GeneratedCarrierMappingId)",
        frozenset({"graph-contextualizable-carrier"}),
        frozenset({"ownerRecord", "carrierMappingId"}),
    ),
    "GraphContextualization(ownerRecord,sourceRecord,targetRecord)": (
        "GeneratedFact (GeneratedGraphContextualization GeneratedOwnerRecord GeneratedSourceRecord GeneratedTargetRecord)",
        frozenset({"graph-contextualization"}),
        frozenset({"ownerRecord", "sourceRecord", "targetRecord"}),
    ),
    "GraphContextualization(includedRecord,sourceRecord,triggerRecord)": (
        "GeneratedFact (GeneratedGraphContextualization GeneratedIncludedRecord GeneratedSourceRecord GeneratedTriggerRecord)",
        frozenset({"graph-contextualization"}),
        frozenset({"includedRecord", "sourceRecord", "triggerRecord"}),
    ),
    "GraphStructuredFamilyCarrier(familyId,ownerRecord)": (
        "GeneratedFact (GeneratedGraphStructuredFamilyCarrier GeneratedFamilyId GeneratedOwnerRecord)",
        frozenset({"graph-structured-family-carrier"}),
        frozenset({"familyId", "ownerRecord"}),
    ),
    "GraphStructuredFamilyCarrier(familyId,includedRecord)": (
        "GeneratedFact (GeneratedGraphStructuredFamilyCarrier GeneratedFamilyId GeneratedIncludedRecord)",
        frozenset({"graph-structured-family-carrier"}),
        frozenset({"familyId", "includedRecord"}),
    ),
    "GraphStructuredFamilyIncidence(familyId,triggerRecord,includedRecord)": (
        "GeneratedFact (GeneratedGraphStructuredFamilyIncidence GeneratedFamilyId GeneratedTriggerRecord GeneratedIncludedRecord)",
        frozenset({"graph-structured-family-incidence"}),
        frozenset({"familyId", "triggerRecord", "includedRecord"}),
    ),
    "GraphStructuredFamilyParticipantSegment(familyId,junctionRecord,ownerRecord)-or-GraphStructuredFamilyTargetSegment(familyId,junctionRecord,ownerRecord)": (
        "GeneratedAlternativeFacts (GeneratedGraphStructuredFamilyParticipantSegment GeneratedFamilyId GeneratedJunctionRecord GeneratedOwnerRecord) (GeneratedGraphStructuredFamilyTargetSegment GeneratedFamilyId GeneratedJunctionRecord GeneratedOwnerRecord)",
        frozenset(
            {
                "graph-structured-family-participant-segment",
                "graph-structured-family-target-segment",
            }
        ),
        frozenset({"familyId", "junctionRecord", "ownerRecord"}),
    ),
    "QualificationMember(ownerRecord)": (
        "GeneratedFact (GeneratedQualificationMember GeneratedOwnerRecord)",
        frozenset({"qualification"}),
        frozenset({"ownerRecord"}),
    ),
    "QualificationMember(includedRecord)": (
        "GeneratedFact (GeneratedQualificationMember GeneratedIncludedRecord)",
        frozenset({"qualification"}),
        frozenset({"includedRecord"}),
    ),
    "QualificationProposalCarrier(ownerRecord)": (
        "GeneratedFact (GeneratedQualificationProposalCarrier GeneratedOwnerRecord)",
        frozenset({"qualification-proposal-carrier"}),
        frozenset({"ownerRecord"}),
    ),
    "QualificationProposalRoleIncidence(proposalRecord,ownerRecord)": (
        "GeneratedFact (GeneratedQualificationProposalRoleIncidence GeneratedProposalRecord GeneratedOwnerRecord)",
        frozenset({"qualification-proposal-role-incidence"}),
        frozenset({"proposalRecord", "ownerRecord"}),
    ),
    "QualificationProposalRoleIncidence(triggerRecord,includedRecord)": (
        "GeneratedFact (GeneratedQualificationProposalRoleIncidence GeneratedTriggerRecord GeneratedIncludedRecord)",
        frozenset({"qualification-proposal-role-incidence"}),
        frozenset({"triggerRecord", "includedRecord"}),
    ),
    "QualificationContextualizableProposalEndpoint(proposalRecord,triggerRecord,roleId,includedRecord)": (
        "GeneratedFact (GeneratedQualificationContextualizableProposalEndpoint GeneratedProposalRecord GeneratedTriggerRecord GeneratedRoleId GeneratedIncludedRecord)",
        frozenset({"qualification-contextualizable-proposal-endpoint"}),
        frozenset(
            {"proposalRecord", "triggerRecord", "roleId", "includedRecord"}
        ),
    ),
    "QualificationContextualizationOfProposalEndpoint(proposalRecord,referenceRecord,endpointRecord,includedRecord)": (
        "GeneratedFact (GeneratedQualificationContextualizationOfProposalEndpoint GeneratedProposalRecord GeneratedReferenceRecord GeneratedEndpointRecord GeneratedIncludedRecord)",
        frozenset({"qualification-contextualization-of-proposal-endpoint"}),
        frozenset(
            {"proposalRecord", "referenceRecord", "endpointRecord", "includedRecord"}
        ),
    ),
    "QualificationContextOwnerRequiredByProposal(proposalRecord,referenceRecord,endpointRecord,contextualizationRecord,includedRecord)": (
        "GeneratedFact (GeneratedQualificationContextOwnerRequiredByProposal GeneratedProposalRecord GeneratedReferenceRecord GeneratedEndpointRecord GeneratedContextualizationRecord GeneratedIncludedRecord)",
        frozenset({"qualification-context-owner-required-by-proposal"}),
        frozenset(
            {
                "proposalRecord",
                "referenceRecord",
                "endpointRecord",
                "contextualizationRecord",
                "includedRecord",
            }
        ),
    ),
    "QualificationContextualizationOfExactProposalEndpoint(proposalRecord,referenceRecord,endpointRecord,contextOwnerRecord,includedRecord)": (
        "GeneratedFact (GeneratedQualificationContextualizationOfExactProposalEndpoint GeneratedProposalRecord GeneratedReferenceRecord GeneratedEndpointRecord GeneratedContextOwnerRecord GeneratedIncludedRecord)",
        frozenset({"qualification-contextualization-of-exact-proposal-endpoint"}),
        frozenset(
            {
                "proposalRecord",
                "referenceRecord",
                "endpointRecord",
                "contextOwnerRecord",
                "includedRecord",
            }
        ),
    ),
}

ACTIVATION_PREREQUISITE_FACTS = {
    "none": frozenset(),
    "scope-seed": frozenset(),
    "either-endpoint-in-current-graph-membership": frozenset({"graph"}),
    "junction-or-non-junction-endpoint-in-current-graph-membership": frozenset(
        {"graph"}
    ),
    "target-endpoint-in-current-graph-membership": frozenset(
        {"graph-contextualizable-carrier"}
    ),
    "source-or-target-in-current-qualification-membership": frozenset(
        {"qualification"}
    ),
}

ACTIVATION_AVAILABLE_BINDINGS = {
    "ActivateGraphCarrier": frozenset({"ownerRecord", "carrierMappingId"}),
    "ActivateGraphStructuredCarrier": frozenset({"ownerRecord", "familyId"}),
    "ActivateGraphStructuredProperty": frozenset({"ownerRecord", "familyId"}),
    "ActivateGraphCommittedElement": frozenset({"ownerRecord"}),
    "ActivateGraphCommittedStructuredCarrier": frozenset(
        {"ownerRecord", "familyId"}
    ),
    "ActivateGraphCommittedRelationship": frozenset({"ownerRecord"}),
    "ActivateQualificationProposalType": frozenset({"ownerRecord"}),
    "ActivateQualificationProposalSourceKey": frozenset({"ownerRecord"}),
    "ActivateQualificationRoleKey": frozenset({"ownerRecord"}),
    "ActivateSharedUnknownProperty": frozenset({"ownerRecord"}),
    "ActivateSharedTypeKey": frozenset({"ownerRecord"}),
    "ActivateGraphRelation": frozenset({"ownerRecord"}),
    "ActivateGraphContextualizationLabel": frozenset(
        {"ownerRecord", "sourceRecord", "targetRecord"}
    ),
    "ActivateGraphContextualizationShape": frozenset(
        {"ownerRecord", "sourceRecord", "targetRecord"}
    ),
    "ActivateGraphStructuredSegment": frozenset(
        {"ownerRecord", "familyId", "junctionRecord"}
    ),
    "ActivateQualificationProposalIncidence": frozenset(
        {"ownerRecord", "proposalRecord"}
    ),
}

CLOSURE_AVAILABLE_BINDINGS = {
    "CloseGraphStableConcept": frozenset({"includedRecord"}),
    "CloseGraphRelationshipSourceEndpoint": frozenset({"includedRecord"}),
    "CloseGraphRelationshipTargetEndpoint": frozenset({"includedRecord"}),
    "CloseGraphStructuredIncidenceByTarget": frozenset(
        {"familyId", "triggerRecord", "includedRecord"}
    ),
    "CloseGraphStructuredIncidenceBySource": frozenset(
        {"familyId", "triggerRecord", "includedRecord"}
    ),
    "CloseGraphJunctionSourceEndpoint": frozenset({"includedRecord"}),
    "CloseGraphJunctionTargetEndpoint": frozenset({"includedRecord"}),
    "CloseGraphContextualization": frozenset(
        {"includedRecord", "sourceRecord", "triggerRecord"}
    ),
    "CloseGraphContextOwner": frozenset({"includedRecord"}),
    "CloseGraphStructuredCarrierFromParticipantSegment": frozenset(
        {"familyId", "includedRecord"}
    ),
    "CloseGraphStructuredCarrierFromTargetSegment": frozenset(
        {"familyId", "includedRecord"}
    ),
    "CloseGraphStructuredParticipant": frozenset({"includedRecord"}),
    "CloseGraphStructuredTarget": frozenset({"includedRecord"}),
    "CloseGraphOwnedPropertyValue": frozenset({"includedRecord"}),
    "CloseGraphPropertyDefinition": frozenset({"includedRecord"}),
    "CloseQualificationRoleIncidenceBySource": frozenset(
        {"triggerRecord", "includedRecord"}
    ),
    "CloseQualificationRoleIncidenceByTarget": frozenset(
        {"triggerRecord", "includedRecord"}
    ),
    "CloseQualificationRoleSourceEndpoint": frozenset(
        {"proposalRecord", "triggerRecord", "roleId", "includedRecord"}
    ),
    "CloseQualificationRoleTargetEndpoint": frozenset(
        {"proposalRecord", "triggerRecord", "roleId", "includedRecord"}
    ),
    "CloseQualificationOwnerContextualization": frozenset(
        {"proposalRecord", "referenceRecord", "endpointRecord", "includedRecord"}
    ),
    "CloseQualificationContextOwner": frozenset(
        {
            "proposalRecord",
            "referenceRecord",
            "endpointRecord",
            "contextualizationRecord",
            "includedRecord",
        }
    ),
    "CloseQualificationEndpointContextualization": frozenset(
        {
            "proposalRecord",
            "referenceRecord",
            "endpointRecord",
            "contextOwnerRecord",
            "includedRecord",
        }
    ),
    "CloseQualificationOwnedEndpoint": frozenset({"includedRecord"}),
    "CloseQualificationOwnedPropertyValue": frozenset({"includedRecord"}),
    "CloseQualificationPropertyDefinition": frozenset({"includedRecord"}),
}


def reject_constant(value: str) -> None:
    raise ValueError(f"invalid JSON numeric constant: {value}")


def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON object member: {key}")
        result[key] = value
    return result


def load_object(path: Path, subject: str) -> tuple[dict[str, Any], bytes]:
    payload = path.read_bytes()
    value = json.loads(
        payload.decode("utf-8"),
        object_pairs_hook=unique_object,
        parse_constant=reject_constant,
    )
    if not isinstance(value, dict):
        raise ValueError(f"{subject} must be one JSON object")
    return value, payload


def pointer(path: tuple[object, ...]) -> str:
    return "/" + "/".join(
        str(part).replace("~", "~0").replace("/", "~1") for part in path
    )


def json_kind(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, str):
        return "string"
    if isinstance(value, int):
        return "integer"
    if isinstance(value, float):
        return "number"
    if isinstance(value, list):
        return "array"
    if isinstance(value, dict):
        return "object"
    raise TypeError(type(value).__name__)


def shape_manifest(value: Any, path: tuple[object, ...] = ()) -> list[list[Any]]:
    result: list[list[Any]] = []
    kind = json_kind(value)
    here = pointer(path) if path else ""
    if isinstance(value, dict):
        keys = sorted(value)
        result.append([here, kind, keys])
        for key in keys:
            if path + (key,) == ("companionFormatContract", "shapeSha256"):
                continue
            result.extend(shape_manifest(value[key], path + (key,)))
    elif isinstance(value, list):
        result.append([here, kind, len(value)])
        for index, child in enumerate(value):
            result.extend(shape_manifest(child, path + (index,)))
    else:
        result.append([here, kind])
    return result


def sha256(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def shape_sha256(companion: dict[str, Any]) -> str:
    payload = json.dumps(
        shape_manifest(companion), ensure_ascii=False, separators=(",", ":")
    ).encode("utf-8")
    return sha256(payload)


def resolve_pointer(value: Any, path: str) -> Any:
    if not path.startswith("/"):
        raise ValueError(f"invalid JSON pointer: {path!r}")
    current = value
    for raw_token in path.removeprefix("/").split("/"):
        token = raw_token.replace("~1", "/").replace("~0", "~")
        current = current[int(token)] if isinstance(current, list) else current[token]
    return current


def require_exact(actual: Any, expected: Any, subject: str) -> None:
    if actual != expected:
        raise ValueError(f"{subject}: expected {expected!r}, got {actual!r}")


def require_list(value: Any, subject: str) -> list[Any]:
    if not isinstance(value, list):
        raise ValueError(f"{subject}: expected an array")
    return value


def require_unique_strings(value: Any, subject: str, nonempty: bool = True) -> list[str]:
    values = require_list(value, subject)
    if nonempty and not values:
        raise ValueError(f"{subject}: expected a non-empty array")
    if not all(isinstance(item, str) and item for item in values):
        raise ValueError(f"{subject}: expected non-empty string members")
    if len(values) != len(set(values)):
        raise ValueError(f"{subject}: duplicate member")
    return values


def utf8_sorted(values: Iterable[str]) -> list[str]:
    return sorted(values, key=lambda value: value.encode("utf-8"))


def require_unique_rows(rows: list[dict[str, Any]], key: str, subject: str) -> None:
    values = [row[key] for row in rows]
    if len(values) != len(set(values)):
        raise ValueError(f"{subject}: duplicate {key}")


def derive_rule_inventory(companion: dict[str, Any]) -> tuple[list[str], list[str], list[str]]:
    contract = companion["ruleIdentityContract"]
    embedded_paths = require_unique_strings(
        contract["embeddedRuleInventory"], "embedded Profile rule pointers"
    )
    embedded = [resolve_pointer(companion, path) for path in embedded_paths]
    require_unique_strings(embedded, "resolved embedded Profile rules")

    carrier_rules = [f"carrier:{row['id']}" for row in companion["carrierMappings"]]
    relation_rules = [f"relation:{row['id']}" for row in companion["relationMappings"]]
    known_keys = {
        row["key"] for row in companion["propertyMappings"]
    } | set(companion["reservedNamespace"]["bootstrapKnownKeys"])
    placement_rules = [f"reserved-placement:{key}" for key in utf8_sorted(known_keys)]
    attribute_rules = [
        row["attributeContract"]["ruleId"]
        for row in companion["relationMappings"]
        if "attributeContract" in row
    ]
    complete = utf8_sorted(
        embedded + carrier_rules + relation_rules + placement_rules + attribute_rules
    )
    require_unique_strings(complete, "derived complete Profile rule inventory")
    declared = contract["completeRuleInventory"]
    require_exact(declared, complete, "complete Profile rule inventory derivation")
    require_exact(
        contract["completeRuleInventoryDerivation"]["cardinality"],
        len(complete),
        "complete Profile rule inventory cardinality",
    )

    bootstrap = require_unique_strings(
        contract["operationBootstrapRuleInventory"], "bootstrap rule inventory"
    )
    selected = require_unique_strings(
        contract["selectedProfileRuleInventory"], "selected Profile rule inventory"
    )
    require_exact(bootstrap, utf8_sorted(bootstrap), "canonical bootstrap rule order")
    require_exact(selected, utf8_sorted(selected), "canonical selected rule order")
    require_exact(
        utf8_sorted(bootstrap + selected),
        complete,
        "disjoint complete bootstrap and selected Profile rule partition",
    )
    return complete, bootstrap, selected


def nearest_ancestor_evidence_kind(
    companion: dict[str, Any], path: str
) -> str | None:
    if not path.startswith("/"):
        raise ValueError(f"invalid JSON pointer: {path!r}")
    tokens = [
        token.replace("~1", "/").replace("~0", "~")
        for token in path.removeprefix("/").split("/")[:-1]
    ]
    current: Any = companion
    ancestors: list[Any] = []
    for token in tokens:
        current = current[int(token)] if isinstance(current, list) else current[token]
        ancestors.append(current)
    for ancestor in reversed(ancestors):
        if isinstance(ancestor, dict) and "evidenceKind" in ancestor:
            evidence_kind = ancestor["evidenceKind"]
            if not isinstance(evidence_kind, str) or not evidence_kind:
                raise ValueError(
                    f"embedded Profile rule {path}: invalid evidenceKind"
                )
            return evidence_kind
    return None


def derive_profile_defect_rule_bindings(
    companion: dict[str, Any],
) -> dict[str, str]:
    contract = companion["ruleIdentityContract"]
    require_exact(
        contract["evidenceBinding"],
        EXPECTED_EVIDENCE_BINDING_CONTRACT,
        "Profile evidence binding contract",
    )
    require_exact(
        contract["propertyRuleEvidence"],
        EXPECTED_PROPERTY_RULE_EVIDENCE,
        "Profile property rule evidence map",
    )
    require_exact(
        contract["derivedRuleEvidence"],
        EXPECTED_DERIVED_RULE_EVIDENCE,
        "Profile derived rule evidence map",
    )

    _, bootstrap_rules, selected_rules = derive_rule_inventory(companion)
    bootstrap = set(bootstrap_rules)
    selected = set(selected_rules)
    bindings: dict[str, str] = {}
    sources: dict[str, str] = {}

    def add(rule_id: str, evidence_kind: str, source: str) -> None:
        if rule_id not in selected:
            raise ValueError(
                f"unknown selected Profile defect rule binding: {rule_id!r} from {source}"
            )
        if evidence_kind not in EXPECTED_PROFILE_EVIDENCE_KINDS:
            raise ValueError(
                f"unknown Profile evidence kind {evidence_kind!r} for {rule_id!r}"
            )
        previous = bindings.get(rule_id)
        if previous is not None:
            disposition = "duplicate" if previous == evidence_kind else "contradictory"
            raise ValueError(
                f"{disposition} Profile defect rule binding for {rule_id!r}: "
                f"{sources[rule_id]} -> {previous!r}, {source} -> {evidence_kind!r}"
            )
        bindings[rule_id] = evidence_kind
        sources[rule_id] = source

    non_defect_rules: set[str] = set()
    for path in require_unique_strings(
        contract["embeddedRuleInventory"], "embedded Profile rule pointers"
    ):
        rule_id = resolve_pointer(companion, path)
        if rule_id in bootstrap:
            continue
        if path.startswith(
            ( "/viewScopeContract/graphClosureRules/",
              "/viewScopeContract/qualificationClosureRules/" )
        ):
            non_defect_rules.add(rule_id)
            continue
        if path.startswith("/propertyMappings/"):
            continue
        evidence_kind = nearest_ancestor_evidence_kind(companion, path)
        if evidence_kind is None:
            raise ValueError(
                f"missing Profile evidence binding for selected rule {rule_id!r} at {path}"
            )
        add(rule_id, evidence_kind, path)

    for rule_id in selected_rules:
        if rule_id.startswith("property:"):
            suffix = rule_id.rsplit(":", 1)[1]
            evidence_kind = contract["propertyRuleEvidence"].get(suffix)
            if evidence_kind is None:
                raise ValueError(
                    f"missing Profile property evidence binding for {rule_id!r}"
                )
            add(rule_id, evidence_kind, f"propertyRuleEvidence.{suffix}")
        elif rule_id.startswith("carrier:"):
            add(
                rule_id,
                contract["derivedRuleEvidence"]["carrier"],
                "derivedRuleEvidence.carrier",
            )
        elif rule_id.startswith(("relation:", "relation-attribute:")):
            add(
                rule_id,
                contract["derivedRuleEvidence"]["relation"],
                "derivedRuleEvidence.relation",
            )
        elif rule_id.startswith("reserved-placement:"):
            add(
                rule_id,
                "reserved-property-occurrence",
                "evidenceBinding.generatedReservedPlacementRule",
            )

    unclassified = selected.difference(bindings).difference(non_defect_rules)
    if unclassified:
        raise ValueError(
            "selected Profile rules have no defect-evidence disposition: "
            f"{utf8_sorted(unclassified)!r}"
        )
    require_exact(
        set(bindings.values()),
        set(EXPECTED_PROFILE_EVIDENCE_KINDS),
        "closed Profile evidence kind inventory",
    )
    return {rule_id: bindings[rule_id] for rule_id in utf8_sorted(bindings)}


def require_one(
    rows: Iterable[dict[str, Any]],
    predicate: Callable[[dict[str, Any]], bool],
    subject: str,
) -> dict[str, Any]:
    matches = [row for row in rows if predicate(row)]
    if len(matches) != 1:
        raise ValueError(f"{subject}: expected exactly one row, got {len(matches)}")
    return matches[0]


def require_selected_rule_ids(
    companion: dict[str, Any], rule_ids: Iterable[str], subject: str
) -> None:
    selected = set(
        require_unique_strings(
            companion["ruleIdentityContract"]["selectedProfileRuleInventory"],
            "selected Profile rule inventory",
        )
    )
    unknown = utf8_sorted(set(rule_ids).difference(selected))
    if unknown:
        raise ValueError(f"{subject} missing from selected Profile inventory: {unknown!r}")


def derive_mapping_rule_ids(
    companion: dict[str, Any],
) -> tuple[dict[str, str], dict[str, str], dict[str, str]]:
    carriers = companion["carrierMappings"]
    relations = companion["relationMappings"]
    properties = companion["propertyMappings"]
    require_unique_rows(carriers, "id", "carrier mappings")
    require_unique_rows(relations, "id", "relation mappings")
    require_unique_rows(properties, "id", "property mappings")
    carrier_rules = {row["id"]: f"carrier:{row['id']}" for row in carriers}
    relation_rules = {row["id"]: f"relation:{row['id']}" for row in relations}
    property_rules = {
        row["id"]: f"reserved-placement:{row['key']}" for row in properties
    }
    require_selected_rule_ids(
        companion,
        [*carrier_rules.values(), *relation_rules.values(), *property_rules.values()],
        "generated mapping source rules",
    )
    return carrier_rules, relation_rules, property_rules


def derive_property_runtime_plans(
    companion: dict[str, Any],
) -> list[dict[str, Any]]:
    plans: list[dict[str, Any]] = []
    for index, mapping in enumerate(companion["propertyMappings"]):
        occurrences = mapping["multiplicity"]["propertyOccurrences"]
        values = mapping["multiplicity"]["valuesPerPropertyOccurrence"]
        kind = mapping["value"]["kind"]
        require_exact(kind["expected"], "string", f"{mapping['id']} value kind")
        constraints = [
            (name, mapping["value"][name])
            for name in ("grammar", "admittedValues", "domain")
            if name in mapping["value"]
        ]
        if len(constraints) != 1:
            raise ValueError(
                f"{mapping['id']}: expected exactly one value constraint, "
                f"got {len(constraints)}"
            )
        constraint_kind, constraint = constraints[0]
        plans.append(
            {
                "authority": f"/propertyMappings/{index}",
                "id": mapping["id"],
                "key": mapping["key"],
                "owner": mapping["owner"],
                "propertyCardinality": occurrences,
                "valueCardinality": values,
                "valueKind": kind,
                "constraintKind": constraint_kind,
                "constraint": constraint,
            }
        )
    return plans


def collect_rule_paths(value: Any, path: str) -> list[str]:
    if isinstance(value, dict):
        paths: list[str] = []
        for key, child in value.items():
            child_path = f"{path}/{key}"
            if key == "ruleId":
                paths.append(child_path)
            else:
                paths.extend(collect_rule_paths(child, child_path))
        return paths
    if isinstance(value, list):
        paths = []
        for index, child in enumerate(value):
            paths.extend(collect_rule_paths(child, f"{path}/{index}"))
        return paths
    return []


def derive_pattern_runtime_rules(
    companion: dict[str, Any],
) -> list[dict[str, Any]]:
    patterns = companion["patternMappings"]
    contextualization = require_one(
        patterns,
        lambda row: row["id"] == "contextualization",
        "contextualization runtime pattern",
    )
    collective = require_one(
        patterns,
        lambda row: row["id"] == "collective-strategy-realization",
        "collective runtime pattern",
    )
    contextualization_index = patterns.index(contextualization)
    collective_index = patterns.index(collective)
    proposal = companion["qualificationProposalMapping"]

    rows = [
        ("contextualization.metadata.additional-properties", f"/patternMappings/{contextualization_index}/metadata/additionalProperties", contextualization["metadata"]["additionalProperties"]),
        ("contextualization.metadata.commitment-cardinality", f"/patternMappings/{contextualization_index}/metadata/commitmentCardinality", contextualization["metadata"]["commitmentCardinality"]),
        ("contextualization.metadata.commitment-value", f"/patternMappings/{contextualization_index}/metadata/commitmentValue", contextualization["metadata"]["commitmentValue"]),
        ("contextualization.relationship.type", f"/patternMappings/{contextualization_index}/relationship/archimateRelationship", contextualization["relationship"]["archimateRelationship"]),
        ("contextualization.relationship.directed", f"/patternMappings/{contextualization_index}/relationship/associationDirected", contextualization["relationship"]["associationDirected"]),
        ("contextualization.relationship.label", f"/patternMappings/{contextualization_index}/relationship/label", contextualization["relationship"]["label"]),
        ("collective.carrier.additional-properties", f"/patternMappings/{collective_index}/carrier/additionalO2IProperties", collective["carrier"]["additionalO2IProperties"]),
        ("collective.carrier.archimate-element", f"/patternMappings/{collective_index}/carrier/archimateElement", collective["carrier"]["archimateElement"]),
        ("collective.carrier.category", f"/patternMappings/{collective_index}/carrier/carrierCategory", collective["carrier"]["carrierCategory"]),
        ("collective.carrier.commitment-key", f"/patternMappings/{collective_index}/carrier/commitmentKey", collective["carrier"]["commitmentKey"]),
        ("collective.carrier.commitment-values", f"/patternMappings/{collective_index}/carrier/commitmentValues", collective["carrier"]["commitmentValues"]),
        ("collective.carrier.junction-type", f"/patternMappings/{collective_index}/carrier/junctionType", collective["carrier"]["junctionType"]),
        ("collective.carrier.o2i-type", f"/patternMappings/{collective_index}/carrier/o2iType", collective["carrier"]["o2iType"]),
        ("collective.junction.chains", f"/patternMappings/{collective_index}/junction/chains", collective["junction"]["chains"]),
        ("collective.segments.relationship-type", f"/patternMappings/{collective_index}/segments/archimateRelationship", collective["segments"]["archimateRelationship"]),
        ("collective.segments.directed", f"/patternMappings/{collective_index}/segments/associationDirected", collective["segments"]["associationDirected"]),
        ("collective.segments.label", f"/patternMappings/{collective_index}/segments/label", collective["segments"]["label"]),
        ("collective.segments.metadata", f"/patternMappings/{collective_index}/segments/o2iMetadata", collective["segments"]["o2iMetadata"]),
        ("qualification.carrier.archimate-element", "/qualificationProposalMapping/carrier/archimateElement", proposal["carrier"]["archimateElement"]),
        ("qualification.carrier.category", "/qualificationProposalMapping/carrier/carrierCategory", proposal["carrier"]["carrierCategory"]),
        ("qualification.carrier.commitment", "/qualificationProposalMapping/carrier/commitment", proposal["carrier"]["commitment"]),
        ("qualification.carrier.o2i-type", "/qualificationProposalMapping/carrier/o2iType", proposal["carrier"]["o2iType"]),
        ("qualification.carrier.stable-identity", "/qualificationProposalMapping/carrier/stableIdentity", proposal["carrier"]["stableIdentity"]),
        ("qualification.carrier.stable-identity-scope", "/qualificationProposalMapping/carrier/stableIdentityScope", proposal["carrier"]["stableIdentityScope"]),
        ("qualification.reference.relationship-type", "/qualificationProposalMapping/references/archimateRelationship", proposal["references"]["archimateRelationship"]),
        ("qualification.reference.directed", "/qualificationProposalMapping/references/associationDirected", proposal["references"]["associationDirected"]),
        ("qualification.reference.commitment", "/qualificationProposalMapping/references/commitment", proposal["references"]["commitment"]),
        ("qualification.reference.direction", "/qualificationProposalMapping/references/direction", proposal["references"]["direction"]),
        ("qualification.reference.role-property", "/qualificationProposalMapping/references/roleProperty", proposal["references"]["roleProperty"]),
    ]
    generated_paths = [path + "/ruleId" for _, path, _ in rows]
    declared_paths = []
    for index, pattern in enumerate(patterns):
        declared_paths.extend(collect_rule_paths(pattern, f"/patternMappings/{index}"))
    declared_paths.extend(
        collect_rule_paths(proposal, "/qualificationProposalMapping")
    )
    require_exact(
        set(generated_paths),
        set(declared_paths),
        "complete emit-capable Pattern runtime leaf coverage",
    )
    require_unique_strings(
        [subject for subject, _, _ in rows], "runtime Pattern subjects"
    )
    return [
        {
            "subject": subject,
            "authority": path,
            "ruleId": leaf["ruleId"],
            "expected": leaf["expected"],
        }
        for subject, path, leaf in rows
    ]


def inline_rule_ids(
    owner: dict[str, Any], fields: Iterable[str], subject: str
) -> list[str]:
    values = []
    for field in fields:
        leaf = owner[field]
        if not isinstance(leaf, dict) or not isinstance(leaf.get("ruleId"), str):
            raise ValueError(f"{subject}.{field}: expected an embedded ruleId")
        values.append(leaf["ruleId"])
    return values


def property_mapping_for_selector_source(
    companion: dict[str, Any], source: str
) -> dict[str, Any]:
    properties = companion["propertyMappings"]
    id_match = re.search(r"propertyMappings\[id=([^\]]+)\]", source)
    if id_match is not None:
        mapping_id = id_match.group(1)
        if mapping_id == "qualificationProposalMapping.carrier.sourceProjection.propertyMapping":
            mapping_id = companion["qualificationProposalMapping"]["carrier"][
                "sourceProjection"
            ]["propertyMapping"]
        return require_one(
            properties,
            lambda row: row["id"] == mapping_id,
            f"activation property mapping {mapping_id}",
        )
    owner_match = re.search(r"propertyMappings\[owner=([^\]]+)\]", source)
    if owner_match is not None:
        owner = owner_match.group(1)
        return require_one(
            properties,
            lambda row: row["owner"] == owner,
            f"activation property owner {owner}",
        )
    raise ValueError(f"unsupported activation property selector source: {source!r}")


def activation_source_rule_ids(
    companion: dict[str, Any], source: str
) -> list[str]:
    patterns = companion["patternMappings"]
    proposal = companion["qualificationProposalMapping"]
    carrier_rules, _, property_rules = derive_mapping_rule_ids(companion)
    if source in {
        "carrierMappings",
        "relationMappings",
        "reservedNamespace.prefix-and-global-known-key-catalog",
    }:
        return []
    if source.startswith("propertyMappings["):
        mapping = property_mapping_for_selector_source(companion, source)
        return [property_rules[mapping["id"]]]
    if source == "metadata.claimCarrier.commitmentKey":
        key = companion["metadata"]["claimCarrier"]["commitmentKey"]
        return [f"reserved-placement:{key}"]
    if source == "qualificationProposalMapping.references.roleProperty.expected":
        key = proposal["references"]["roleProperty"]["expected"]
        return [f"reserved-placement:{key}"]
    if source == "patternMappings[*].carrier":
        pattern = require_one(
            patterns,
            lambda row: "propositionFamily" in row,
            "structured proposition activation pattern",
        )
        return inline_rule_ids(
            pattern["carrier"],
            ("archimateElement", "junctionType", "o2iType"),
            "structured proposition activation carrier",
        )
    if source == "qualificationProposalMapping.carrier":
        return inline_rule_ids(
            proposal["carrier"],
            ("archimateElement", "o2iType"),
            "qualification proposal activation carrier",
        )
    if source == "patternMappings[id=contextualization].relationship":
        pattern = require_one(
            patterns,
            lambda row: row["id"] == "contextualization",
            "contextualization activation pattern",
        )
        return inline_rule_ids(
            pattern["relationship"],
            ("archimateRelationship", "associationDirected", "label"),
            "contextualization activation relationship",
        )
    if source == "patternMappings[id=contextualization]":
        context = require_one(
            companion["carrierMappings"],
            lambda row: row["carrierCategory"] == "Context",
            "context carrier mapping",
        )
        return [carrier_rules[context["id"]]]
    if source == "patternMappings[*].segments":
        pattern = require_one(
            patterns,
            lambda row: "propositionFamily" in row,
            "structured proposition activation pattern",
        )
        return inline_rule_ids(
            pattern["segments"],
            ("archimateRelationship", "associationDirected", "label"),
            "structured proposition segment activation",
        )
    if source == "qualificationProposalMapping.references":
        return inline_rule_ids(
            proposal["references"],
            (
                "archimateRelationship",
                "associationDirected",
                "direction",
                "roleProperty",
            ),
            "qualification proposal incidence activation",
        )
    raise ValueError(f"unsupported activation predicate source: {source!r}")


def raw_activation_static_source_rule_ids(
    companion: dict[str, Any],
) -> dict[str, list[str]]:
    result = {}
    for _, row in activation_rows(companion):
        values = activation_source_rule_ids(
            companion, row["selector"]["predicateSource"]
        )
        values = require_unique_strings(
            values,
            f"activation static source rules {row['constructorId']}",
            nonempty=False,
        )
        result[row["constructorId"]] = utf8_sorted(values)
    return result


def validate_activation_static_source_rule_ids(
    companion: dict[str, Any], actual: dict[str, list[str]]
) -> None:
    expected = raw_activation_static_source_rule_ids(companion)
    require_exact(
        set(actual), set(expected), "activation static source provenance constructors"
    )
    for constructor, expected_rule_ids in expected.items():
        actual_rule_ids = require_unique_strings(
            actual[constructor],
            f"activation static source provenance {constructor}",
            nonempty=False,
        )
        require_exact(
            actual_rule_ids,
            utf8_sorted(actual_rule_ids),
            f"canonical activation static source provenance {constructor}",
        )
        require_selected_rule_ids(
            companion,
            actual_rule_ids,
            f"activation static source provenance {constructor}",
        )
        require_exact(
            actual_rule_ids,
            expected_rule_ids,
            f"activation static source provenance {constructor}",
        )


def derive_activation_static_source_rule_ids(
    companion: dict[str, Any],
) -> dict[str, list[str]]:
    result = raw_activation_static_source_rule_ids(companion)
    validate_activation_static_source_rule_ids(companion, result)
    return result


def validate_core_binding(
    companion: dict[str, Any], core_companion: Path
) -> dict[str, Any]:
    core, core_bytes = load_object(core_companion, "Core companion")
    core_digest = sha256(core_bytes)
    require_exact(core_digest, EXPECTED_CORE_SHA256, "accepted Core file SHA-256")
    binding = companion["coreSemanticContractBinding"]
    require_exact(binding["subject"], "exact-bytes", "Core binding subject")
    require_exact(binding["sha256"], core_digest, "Profile-to-Core exact-byte binding")
    require_exact(binding["identity"], core["coreIdentity"]["identity"], "Core identity binding")
    require_exact(binding["version"], core["coreIdentity"]["version"], "Core version binding")
    require_exact(binding["schema"], core["schema"], "Core schema binding")
    return core


def validate_reference_integrity(companion: dict[str, Any], core: dict[str, Any]) -> None:
    carriers = companion["carrierMappings"]
    relations = companion["relationMappings"]
    properties = companion["propertyMappings"]
    patterns = companion["patternMappings"]
    require_unique_rows(carriers, "id", "carrier mappings")
    require_unique_rows(relations, "id", "relation mappings")
    require_unique_rows(properties, "id", "property mappings")
    require_unique_rows(patterns, "id", "pattern mappings")

    endpoint_pairs = {
        (row["carrierCategory"], row["o2iType"])
        for row in core["qualifiedEndpointCatalog"]
    }
    projected_pairs = {
        (row["carrierCategory"], o2i_type)
        for row in carriers
        for o2i_type in row["o2iTypes"]
    }
    missing_pairs = utf8_sorted(
        f"{category}/{o2i_type}"
        for category, o2i_type in projected_pairs.difference(endpoint_pairs)
    )
    if missing_pairs:
        raise ValueError(f"carrier projection missing in Core endpoints: {missing_pairs!r}")

    core_tokens = set(core["relationTokenCatalog"])
    relation_tokens = [row["projection"]["relationToken"] for row in relations]
    unknown_tokens = utf8_sorted(set(relation_tokens).difference(core_tokens))
    if unknown_tokens:
        raise ValueError(f"relation mappings reference unknown Core tokens: {unknown_tokens!r}")

    core_families = {row["id"]: row for row in core["structuredPropositionFamilies"]}
    property_ids = {row["id"] for row in properties}
    for pattern in patterns:
        if "propositionFamily" not in pattern:
            continue
        family_id = pattern["propositionFamily"]
        if family_id not in core_families:
            raise ValueError(f"unknown structured proposition family: {family_id}")
        family = core_families[family_id]
        require_exact(
            pattern["contributors"]["roleId"],
            family["participant"]["roleId"],
            f"{family_id} participant role binding",
        )
        require_exact(
            pattern["target"]["roleId"],
            family["target"]["roleId"],
            f"{family_id} target role binding",
        )
        property_mapping = pattern["carrier"]["participantCompletenessPropertyMapping"]
        if property_mapping not in property_ids:
            raise ValueError(f"{family_id}: unknown completeness property mapping")
        core_values = {
            row["id"] for row in family["participantCompleteness"]["values"]
        }
        mapped_values = {
            row["valueId"]
            for row in pattern["carrier"]["participantCompletenessValueProjection"]["mapping"]
        }
        require_exact(mapped_values, core_values, f"{family_id} completeness value bijection")

    proposal = companion["qualificationProposalMapping"]
    semantics = core["qualificationProposalSemantics"]
    require_exact(proposal["id"], semantics["id"], "qualification proposal identity")
    core_roles = {
        role: value["id"] for role, value in semantics["roles"].items()
    }
    profile_roles = {
        role: value["projection"]["roleId"]
        for role, value in proposal["references"]["roles"].items()
    }
    require_exact(profile_roles, core_roles, "qualification role bijection")


def applicability_subject_key(subject: dict[str, Any]) -> tuple[str, ...]:
    kind = subject["kind"]
    fields = {
        "core-relation-mapping-pair": ("relationMappingId", "coreRelationSemanticsId"),
        "contextualization-carrier-pair": ("sourceCarrierMappingId", "targetCarrierMappingId"),
        "structured-proposition-segment": ("propositionFamily", "direction"),
        "qualification-reference-role": ("proposalMappingId", "role"),
        "property-owner-family": ("propertyMappingId", "ownerFamily"),
        "carrier-construct": ("archimateConstruct",),
    }
    if kind not in fields:
        raise ValueError(f"unknown applicability subject kind: {kind}")
    return (kind, *(subject[field] for field in fields[kind]))


def carrier_mapping_for_endpoint(
    companion: dict[str, Any], core: dict[str, Any], endpoint_id: str
) -> dict[str, Any]:
    endpoint = require_one(
        core["qualifiedEndpointCatalog"],
        lambda row: row["id"] == endpoint_id,
        f"applicability Core endpoint {endpoint_id}",
    )
    return require_one(
        companion["carrierMappings"],
        lambda row: row["carrierCategory"] == endpoint["carrierCategory"]
        and endpoint["o2iType"] in row["o2iTypes"],
        f"applicability carrier for Core endpoint {endpoint_id}",
    )


def expected_relationship_applicability(
    companion: dict[str, Any], core: dict[str, Any], subject: dict[str, Any]
) -> tuple[str, bool, str, str]:
    kind = subject["kind"]
    if kind == "core-relation-mapping-pair":
        mapping = require_one(
            companion["relationMappings"],
            lambda row: row["id"] == subject["relationMappingId"],
            "applicability relation mapping",
        )
        semantic = require_one(
            core["relationSemantics"],
            lambda row: row["id"] == subject["coreRelationSemanticsId"],
            "applicability Core relation semantics",
        )
        require_exact(
            mapping["projection"]["relationToken"],
            semantic["relationToken"],
            "applicability relation token binding",
        )
        source = carrier_mapping_for_endpoint(companion, core, semantic["source"])
        target = carrier_mapping_for_endpoint(companion, core, semantic["target"])
        return (
            mapping["archimateRelationship"],
            mapping["associationDirected"],
            source["archimateElement"],
            target["archimateElement"],
        )
    if kind == "contextualization-carrier-pair":
        pattern = require_one(
            companion["patternMappings"],
            lambda row: row["id"] == "contextualization",
            "contextualization applicability pattern",
        )
        source = require_one(
            companion["carrierMappings"],
            lambda row: row["id"] == subject["sourceCarrierMappingId"],
            "contextualization applicability source carrier",
        )
        target = require_one(
            companion["carrierMappings"],
            lambda row: row["id"] == subject["targetCarrierMappingId"],
            "contextualization applicability target carrier",
        )
        return (
            pattern["relationship"]["archimateRelationship"]["expected"],
            pattern["relationship"]["associationDirected"]["expected"],
            source["archimateElement"],
            target["archimateElement"],
        )
    if kind == "structured-proposition-segment":
        pattern = require_one(
            companion["patternMappings"],
            lambda row: row.get("propositionFamily")
            == subject["propositionFamily"],
            "structured applicability pattern",
        )
        family = require_one(
            core["structuredPropositionFamilies"],
            lambda row: row["id"] == subject["propositionFamily"],
            "structured applicability Core family",
        )
        participant = carrier_mapping_for_endpoint(
            companion, core, family["participant"]["target"]
        )["archimateElement"]
        target = carrier_mapping_for_endpoint(
            companion, core, family["target"]["target"]
        )["archimateElement"]
        junction = pattern["carrier"]["archimateElement"]["expected"]
        endpoints = {
            "participant-to-junction": (participant, junction),
            "junction-to-target": (junction, target),
        }
        source_element, target_element = endpoints[subject["direction"]]
        return (
            pattern["segments"]["archimateRelationship"]["expected"],
            pattern["segments"]["associationDirected"]["expected"],
            source_element,
            target_element,
        )
    if kind == "qualification-reference-role":
        proposal = companion["qualificationProposalMapping"]
        semantics = core["qualificationProposalSemantics"]
        require_exact(
            subject["proposalMappingId"],
            proposal["id"],
            "qualification applicability proposal binding",
        )
        role = semantics["roles"][subject["role"]]
        target = carrier_mapping_for_endpoint(companion, core, role["target"])
        return (
            proposal["references"]["archimateRelationship"]["expected"],
            proposal["references"]["associationDirected"]["expected"],
            proposal["carrier"]["archimateElement"]["expected"],
            target["archimateElement"],
        )
    raise ValueError(f"not a relationship applicability subject: {kind}")


def validate_relationship_applicability(
    companion: dict[str, Any],
    core: dict[str, Any],
    decision: dict[str, Any],
    symbol_by_relationship: dict[str, str],
) -> None:
    relationship, directed, source, target = expected_relationship_applicability(
        companion, core, decision["subject"]
    )
    require_exact(
        decision["archimateRelationship"],
        relationship,
        "applicability relationship binding",
    )
    require_exact(
        decision["associationDirected"],
        directed,
        "applicability relationship direction binding",
    )
    require_exact(
        decision["sourceElement"], source, "applicability source endpoint binding"
    )
    require_exact(
        decision["targetElement"], target, "applicability target endpoint binding"
    )

    matrix_source = companion["applicabilityProvenance"]["matrixSource"]
    locator = decision["matrixSourceLocator"]
    for field in ("repository", "revision", "path"):
        require_exact(
            locator[field],
            matrix_source[field],
            f"applicability matrix source {field} binding",
        )
    if not locator["locator"]:
        raise ValueError("applicability matrix source locator must be non-empty")

    symbol = symbol_by_relationship[relationship]
    require_exact(
        decision["matrixSymbol"], symbol, "applicability matrix symbol binding"
    )
    admitted = decision["matrixAdmittedSymbols"]
    if not isinstance(admitted, str) or len(admitted) != len(set(admitted)):
        raise ValueError("applicability matrix admitted symbols must be unique text")
    expected_outcome = "applicable" if symbol in admitted else "inapplicable"
    require_exact(
        decision["outcome"],
        expected_outcome,
        "applicability matrix outcome binding",
    )


def validate_interface_applicability(
    companion: dict[str, Any], decision: dict[str, Any]
) -> None:
    subject = decision["subject"]
    kind = subject["kind"]
    required_interface = {
        "property-owner-family": "IProperties",
        "carrier-construct": "IArchimateElement",
    }[kind]
    require_exact(
        decision["requiredInterface"],
        required_interface,
        f"applicability {kind} interface binding",
    )
    require_exact(
        decision["outcome"],
        "applicable",
        f"applicability {kind} outcome binding",
    )

    locators = require_list(
        decision["sourceLocators"], f"applicability {kind} source locators"
    )
    encoded_locators = [
        json.dumps(locator, sort_keys=True, separators=(",", ":"))
        for locator in locators
    ]
    require_unique_strings(encoded_locators, f"applicability {kind} source locators")
    if kind == "property-owner-family":
        source_inventory = companion["applicabilityProvenance"][
            "propertyCarrierSources"
        ]
        unknown = [locator for locator in locators if locator not in source_inventory]
        if unknown:
            raise ValueError(
                f"applicability {kind} source locator binding: {unknown!r}"
            )
        expected_path_suffixes = {"/IProperties.java"}
    else:
        matrix_source = companion["applicabilityProvenance"]["matrixSource"]
        for locator in locators:
            for field in ("repository", "revision"):
                require_exact(
                    locator[field],
                    matrix_source[field],
                    f"applicability {kind} source {field} binding",
                )
            if not locator["locator"]:
                raise ValueError(
                    f"applicability {kind} source locator must be non-empty"
                )
        expected_path_suffixes = {
            f"/I{subject['archimateConstruct']}.java",
            "/IArchimateElement.java",
        }
    actual_path_suffixes = {
        suffix
        for suffix in expected_path_suffixes
        if any(locator["path"].endswith(suffix) for locator in locators)
    }
    if actual_path_suffixes != expected_path_suffixes:
        raise ValueError(
            f"applicability {kind} source interface binding: "
            f"expected {sorted(expected_path_suffixes)!r}"
        )


def validate_applicability(companion: dict[str, Any], core: dict[str, Any]) -> None:
    applicability = companion["applicabilityProvenance"]
    require_exact(
        applicability["archimateVersion"],
        companion["profileIdentity"]["archimateVersion"],
        "applicability ArchiMate version binding",
    )
    decisions = applicability["decisions"]
    actual = [applicability_subject_key(row["subject"]) for row in decisions]
    if len(actual) != len(set(actual)):
        raise ValueError("applicability decisions contain duplicate subjects")
    relation_pairs = {
        (
            "core-relation-mapping-pair",
            mapping["id"],
            semantic["id"],
        )
        for mapping in companion["relationMappings"]
        for semantic in core["relationSemantics"]
        if mapping["projection"]["relationToken"] == semantic["relationToken"]
    }
    context_mapping = next(row for row in companion["carrierMappings"] if row["id"] == "context")
    contextualization_pairs = {
        ("contextualization-carrier-pair", context_mapping["id"], target["id"])
        for target in companion["carrierMappings"]
        if target["id"] != context_mapping["id"]
    }
    structured_segments = {
        ("structured-proposition-segment", pattern["propositionFamily"], direction)
        for pattern in companion["patternMappings"]
        if "propositionFamily" in pattern
        for direction in ("participant-to-junction", "junction-to-target")
    }
    proposal = companion["qualificationProposalMapping"]
    qualification_roles = {
        ("qualification-reference-role", proposal["id"], role)
        for role in proposal["references"]["roles"]
    }
    property_owners = {
        ("property-owner-family", row["id"], row["owner"])
        for row in companion["propertyMappings"]
    }
    carrier_constructs = {
        ("carrier-construct", construct)
        for construct in {
            row["archimateElement"] for row in companion["carrierMappings"]
        }
        | {
            proposal["carrier"]["archimateElement"]["expected"],
            *(
                pattern["carrier"]["archimateElement"]["expected"]
                for pattern in companion["patternMappings"]
                if "carrier" in pattern
            ),
        }
    }
    expected = (
        relation_pairs
        | contextualization_pairs
        | structured_segments
        | qualification_roles
        | property_owners
        | carrier_constructs
    )
    require_exact(set(actual), expected, "complete applicability subject bijection")

    interpretations = applicability["symbolInterpretations"]
    require_unique_rows(interpretations, "symbol", "applicability matrix symbols")
    require_unique_rows(
        interpretations,
        "archimateRelationship",
        "applicability matrix relationship interpretations",
    )
    symbol_by_relationship = {
        row["archimateRelationship"]: row["symbol"] for row in interpretations
    }
    for decision in decisions:
        kind = decision["subject"]["kind"]
        if kind in {
            "core-relation-mapping-pair",
            "contextualization-carrier-pair",
            "structured-proposition-segment",
            "qualification-reference-role",
        }:
            validate_relationship_applicability(
                companion, core, decision, symbol_by_relationship
            )
        else:
            validate_interface_applicability(companion, decision)

    covered_core_relations = {
        decision["subject"]["coreRelationSemanticsId"]
        for decision in decisions
        if decision["subject"]["kind"] == "core-relation-mapping-pair"
        and decision["outcome"] == "applicable"
    }
    expected_core_relations = {row["id"] for row in core["relationSemantics"]}
    require_exact(
        covered_core_relations,
        expected_core_relations,
        "positive concrete notation coverage for every Core relation semantics",
    )


def derive_relation_projection_plans(
    companion: dict[str, Any],
) -> list[tuple[str, str, str]]:
    """Derive the positive executable relation boundary from applicability."""
    outcomes: dict[tuple[str, str, str], set[str]] = {}
    for decision in companion["applicabilityProvenance"]["decisions"]:
        subject = decision["subject"]
        if subject["kind"] != "core-relation-mapping-pair":
            continue
        key = (
            subject["relationMappingId"],
            decision["sourceElement"],
            decision["targetElement"],
        )
        outcomes.setdefault(key, set()).add(decision["outcome"])

    conflicting = sorted(
        key for key, values in outcomes.items() if len(values) != 1
    )
    if conflicting:
        raise ValueError(
            "relation projection applicability outcomes conflict: "
            f"{conflicting!r}"
        )

    return sorted(
        key
        for key, values in outcomes.items()
        if values == {"applicable"}
    )


def validate_resolution(companion: dict[str, Any]) -> None:
    identity = companion["profileIdentity"]
    require_row_keys(
        identity,
        {
            "adapterIds",
            "archimateVersion",
            "identity",
            "notation",
            "token",
            "version",
        },
        "declarative Profile descriptor",
    )
    for field in ("archimateVersion", "identity", "notation", "token", "version"):
        value = identity[field]
        if not isinstance(value, str) or not value:
            raise ValueError(
                f"declarative Profile descriptor {field}: "
                "expected a non-empty string"
            )
    require_unique_strings(
        identity["adapterIds"], "declarative Profile descriptor adapterIds"
    )
    contract = companion["compiledProfileResolutionContract"]
    require_exact(contract["owner"], "Operation", "Profile resolution owner")
    require_exact(contract["runtimeLoading"], "forbidden", "runtime Profile loading")
    require_exact(
        contract["resolutionPrecedence"],
        [
            "profile-reference-missing",
            "profile-reference-property-multiplicity",
            "profile-reference-value-multiplicity",
            "profile-reference-value-kind-invalid",
            "profile-reference-grammar-invalid",
            "profile-reference-unknown",
            "profile-resolved",
        ],
        "seven-way Profile resolution precedence",
    )
    require_exact(
        contract["inventoryEntry"]["fields"],
        ["identity", "token", "version", "notation", "adapterIds", "contractDigest"],
        "compiled Profile descriptor fields",
    )
    require_exact(
        contract["compatibilityContract"]["precedence"],
        [
            "adapter-id-not-admitted-by-profile",
            "adapter-notation-mismatch",
            "profile-adapter-compatible",
        ],
        "Profile adapter compatibility precedence",
    )


def activation_rows(
    companion: dict[str, Any],
) -> list[tuple[str, dict[str, Any]]]:
    classification = companion["viewScopeContract"]["classification"]
    rows: list[tuple[str, dict[str, Any]]] = []
    for branch in ("graph", "qualification", "shared"):
        rows.extend(
            (branch, row)
            for row in classification["directActivationRules"].get(branch, [])
        )
    for branch in ("graph", "qualification"):
        rows.extend(
            (branch, row)
            for row in classification["incidenceActivationRules"].get(branch, [])
        )
    return rows


def closure_rows(
    companion: dict[str, Any],
) -> list[tuple[str, dict[str, Any]]]:
    view_scope = companion["viewScopeContract"]
    return [
        *(("graph", row) for row in view_scope["graphClosureRules"]),
        *(("qualification", row) for row in view_scope["qualificationClosureRules"]),
    ]


def fixed_point_semantic_projection(companion: dict[str, Any]) -> dict[str, Any]:
    return {
        "activation": [
            {
                "branch": branch,
                "constructorId": row["constructorId"],
                "selector": row["selector"],
                "produces": row["produces"],
            }
            for branch, row in activation_rows(companion)
        ],
        "closure": [
            {
                "branch": branch,
                "constructorId": row["constructorId"],
                "selector": row["selector"],
                "consumes": row["consumes"],
                "produces": row["produces"],
            }
            for branch, row in closure_rows(companion)
        ],
    }


def fixed_point_semantics_sha256(companion: dict[str, Any]) -> str:
    payload = json.dumps(
        fixed_point_semantic_projection(companion),
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    return sha256(payload)


def require_row_keys(
    row: dict[str, Any], expected: set[str], subject: str
) -> None:
    require_exact(set(row), expected, f"{subject} fields")


def require_closed_vocabulary(value: Any, subject: str) -> list[str]:
    return require_unique_strings(value, subject)


def haskell_constructor(prefix: str, value: str) -> str:
    words = re.findall(r"[A-Za-z0-9]+", value)
    if not words:
        raise ValueError(f"cannot derive a Haskell constructor from {value!r}")
    return prefix + "".join(word[0].upper() + word[1:] for word in words)


def require_unique_haskell_constructors(
    prefix: str, values: Iterable[str], subject: str
) -> None:
    constructors = [haskell_constructor(prefix, value) for value in values]
    if len(constructors) != len(set(constructors)):
        raise ValueError(f"{subject}: Haskell constructor collision")


def validate_fixed_point_contract(companion: dict[str, Any]) -> None:
    view_scope = companion["viewScopeContract"]
    classification = view_scope["classification"]
    fact_algebra = classification["typedFactAlgebra"]
    require_exact(
        tuple(fact_algebra["GraphFact"]),
        EXPECTED_GRAPH_FACTS,
        "closed Graph fact algebra",
    )
    require_exact(
        tuple(fact_algebra["QualificationFact"]),
        EXPECTED_QUALIFICATION_FACTS,
        "closed Qualification fact algebra",
    )
    require_exact(
        fact_algebra["closedConstructorCounts"],
        {"activation": 16, "closure": 25},
        "closed fixed-point constructor counts",
    )
    require_exact(
        fact_algebra["dispatch"],
        "constructorId-only-ruleId-is-provenance-and-never-controls-evaluation",
        "fixed-point semantic dispatch",
    )

    activation = activation_rows(companion)
    closure = closure_rows(companion)
    require_exact(len(activation), 16, "activation constructor instance count")
    require_exact(len(closure), 25, "closure constructor instance count")

    constructor_ids = [row["constructorId"] for _, row in activation + closure]
    if len(constructor_ids) != len(set(constructor_ids)):
        raise ValueError("fixed-point constructor IDs must be unique")
    for constructor_id in constructor_ids:
        if re.fullmatch(r"[A-Z][A-Za-z0-9']*", constructor_id) is None:
            raise ValueError(f"invalid Haskell constructor ID: {constructor_id!r}")
    if not all(row["constructorId"].startswith("Activate") for _, row in activation):
        raise ValueError("activation constructor ID must start with Activate")
    if not all(row["constructorId"].startswith("Close") for _, row in closure):
        raise ValueError("closure constructor ID must start with Close")
    require_exact(
        set(ACTIVATION_AVAILABLE_BINDINGS),
        {row["constructorId"] for _, row in activation},
        "closed activation constructor interpretation",
    )
    require_exact(
        set(CLOSURE_AVAILABLE_BINDINGS),
        {row["constructorId"] for _, row in closure},
        "closed closure constructor interpretation",
    )

    rule_ids = [row["ruleId"] for _, row in activation + closure]
    if len(rule_ids) != len(set(rule_ids)):
        raise ValueError("fixed-point rule IDs must be unique")
    selected_rules = set(
        companion["ruleIdentityContract"]["selectedProfileRuleInventory"]
    )
    unknown_rules = utf8_sorted(set(rule_ids).difference(selected_rules))
    if unknown_rules:
        raise ValueError(
            f"fixed-point rule IDs missing from selected Profile inventory: {unknown_rules!r}"
        )

    activation_contract = classification["activationRuleContract"]
    activation_fields = {
        "subjectFamily": "subjectFamilyValues",
        "membershipPrerequisite": "membershipPrerequisiteValues",
        "predicateMode": "predicateModeValues",
        "predicateField": "predicateFieldValues",
        "predicateSource": "predicateSourceValues",
        "incidencePredicate": "incidencePredicateValues",
    }
    require_exact(
        activation_contract["selectorFields"],
        list(activation_fields),
        "activation selector field order",
    )
    for field, vocabulary_key in activation_fields.items():
        vocabulary = require_closed_vocabulary(
            activation_contract[vocabulary_key],
            f"activation {field} vocabulary",
        )
        actual = {row["selector"][field] for _, row in activation}
        require_exact(actual, set(vocabulary), f"activation {field} vocabulary use")
        require_unique_haskell_constructors(
            "GeneratedActivation" + haskell_constructor("", field),
            vocabulary,
            f"activation {field} vocabulary",
        )

    direct_ids = {
        id(row)
        for rows in classification["directActivationRules"].values()
        for row in rows
    }
    for branch, row in activation:
        is_shared = branch == "shared"
        expected_fields = {"ruleId", "selector", "constructorId", "produces"}
        if is_shared:
            expected_fields.add("branches")
        require_row_keys(row, expected_fields, f"activation rule {row['ruleId']}")
        require_row_keys(
            row["selector"],
            set(activation_fields),
            f"activation selector {row['ruleId']}",
        )
        if is_shared:
            require_exact(
                row["branches"],
                ["graph", "qualification"],
                f"shared activation branches {row['ruleId']}",
            )
        elif "branches" in row:
            raise ValueError(f"branch-local activation declares branches: {row['ruleId']}")
        if id(row) not in direct_ids and is_shared:
            raise ValueError("shared activation rules must be direct")
        constructor_branch = (
            "shared"
            if row["constructorId"].startswith("ActivateShared")
            else (
                "qualification"
                if row["constructorId"].startswith("ActivateQualification")
                else "graph"
            )
        )
        require_exact(
            branch,
            constructor_branch,
            f"activation constructor branch {row['constructorId']}",
        )
        require_unique_strings(row["produces"], f"activation {row['ruleId']} consequences")

    closure_contract = view_scope["closureRuleContract"]
    selector_schema = closure_contract["selectorSchema"]
    closure_fields = {
        "triggerFamily": "triggerFamilyValues",
        "triggerMembership": "triggerMembershipValues",
        "traversalDirection": "traversalDirectionValues",
        "referenceField": "referenceFieldValues",
        "includedFamily": "includedFamilyValues",
        "incidencePredicate": "incidencePredicateValues",
    }
    require_exact(
        selector_schema["fields"],
        list(closure_fields),
        "closure selector field order",
    )
    for field, vocabulary_key in closure_fields.items():
        vocabulary = require_closed_vocabulary(
            selector_schema[vocabulary_key], f"closure {field} vocabulary"
        )
        actual = {row["selector"][field] for _, row in closure}
        require_exact(actual, set(vocabulary), f"closure {field} vocabulary use")
        require_unique_haskell_constructors(
            "GeneratedClosure" + haskell_constructor("", field),
            vocabulary,
            f"closure {field} vocabulary",
        )

    for branch, row in closure:
        require_row_keys(
            row,
            {"ruleId", "selector", "constructorId", "consumes", "produces"},
            f"closure rule {row['ruleId']}",
        )
        require_row_keys(
            row["selector"], set(closure_fields), f"closure selector {row['ruleId']}"
        )
        require_exact(
            row["consumes"],
            row["selector"]["triggerMembership"],
            f"closure trigger fact {row['ruleId']}",
        )
        constructor_branch = (
            "qualification"
            if row["constructorId"].startswith("CloseQualification")
            else "graph"
        )
        require_exact(
            branch,
            constructor_branch,
            f"closure constructor branch {row['constructorId']}",
        )
        require_unique_strings(row["produces"], f"closure {row['ruleId']} consequences")

    consequence_values = {
        consequence
        for _, row in activation + closure
        for consequence in row["produces"]
    }
    unknown_consequences = utf8_sorted(
        consequence_values.difference(CONSEQUENCE_INTERPRETATION)
    )
    if unknown_consequences:
        raise ValueError(
            f"unknown fixed-point consequences: {unknown_consequences!r}"
        )

    def fact_branch(fact: str) -> str:
        return (
            "qualification" if fact.startswith("qualification") else "graph"
        )

    def rule_outputs(
        branch: str,
        row: dict[str, Any],
        available_bindings: frozenset[str],
    ) -> set[str]:
        result: set[str] = set()
        for consequence in row["produces"]:
            _, facts, bindings = CONSEQUENCE_INTERPRETATION[consequence]
            unavailable = utf8_sorted(bindings.difference(available_bindings))
            if unavailable:
                raise ValueError(
                    f"{row['constructorId']}: consequence references unavailable "
                    f"bindings {unavailable!r}"
                )
            if facts == {"branch-member"}:
                result.add(branch)
                continue
            for fact in facts:
                if fact_branch(fact) != branch:
                    raise ValueError(
                        f"{row['constructorId']}: {fact} consequence crosses branch"
                    )
                result.add(fact)
        return result

    activation_semantics: list[tuple[str, dict[str, Any], set[str], set[str]]] = []
    for branch, row in activation:
        prerequisite = row["selector"]["membershipPrerequisite"]
        dependencies = set(ACTIVATION_PREREQUISITE_FACTS[prerequisite])
        target_branches = (
            ("graph", "qualification") if branch == "shared" else (branch,)
        )
        for target_branch in target_branches:
            cross_branch = utf8_sorted(
                fact
                for fact in dependencies
                if fact_branch(fact) != target_branch
            )
            if cross_branch:
                raise ValueError(
                    f"{row['constructorId']}: activation prerequisite crosses "
                    f"branch through {cross_branch!r}"
                )
            outputs = rule_outputs(
                target_branch,
                row,
                ACTIVATION_AVAILABLE_BINDINGS[row["constructorId"]],
            )
            activation_semantics.append(
                (target_branch, row, dependencies, outputs)
            )

    closure_semantics: list[tuple[str, dict[str, Any], set[str], set[str]]] = []
    for branch, row in closure:
        trigger = row["selector"]["triggerMembership"]
        if fact_branch(trigger) != branch:
            raise ValueError(
                f"{row['constructorId']}: closure trigger crosses branch"
            )
        closure_semantics.append(
            (
                branch,
                row,
                {trigger},
                rule_outputs(
                    branch,
                    row,
                    CLOSURE_AVAILABLE_BINDINGS[row["constructorId"]],
                ),
            )
        )

    reachable = {"graph": {"graph-seed"}, "qualification": set()}
    reached_activation: set[int] = set()
    reached_closure: set[int] = set()
    changed = True
    while changed:
        changed = False
        for index, (branch, _, dependencies, outputs) in enumerate(
            activation_semantics
        ):
            if dependencies.issubset(reachable[branch]):
                reached_activation.add(index)
                new_outputs = outputs.difference(reachable[branch])
                if new_outputs:
                    reachable[branch].update(new_outputs)
                    changed = True
        for index, (branch, _, dependencies, outputs) in enumerate(
            closure_semantics
        ):
            if dependencies.issubset(reachable[branch]):
                reached_closure.add(index)
                new_outputs = outputs.difference(reachable[branch])
                if new_outputs:
                    reachable[branch].update(new_outputs)
                    changed = True

    unreachable_activation = [
        f"{branch}:{row['constructorId']}"
        for index, (branch, row, _, _) in enumerate(activation_semantics)
        if index not in reached_activation
    ]
    if unreachable_activation:
        raise ValueError(
            "activation prerequisites are not branch-locally reachable: "
            f"{unreachable_activation!r}"
        )
    unreachable_closure = [
        f"{branch}:{row['constructorId']}"
        for index, (branch, row, _, _) in enumerate(closure_semantics)
        if index not in reached_closure
    ]
    if unreachable_closure:
        raise ValueError(
            "closure triggers are not branch-locally reachable: "
            f"{unreachable_closure!r}"
        )

    require_exact(
        consequence_values,
        set(CONSEQUENCE_INTERPRETATION),
        "closed consequence interpretation",
    )
    require_exact(
        fixed_point_semantics_sha256(companion),
        EXPECTED_FIXED_POINT_SEMANTICS_SHA256,
        "accepted fixed-point semantic projection SHA-256",
    )


def validate_companion(
    companion: dict[str, Any],
    payload: bytes,
    core_companion: Path,
) -> dict[str, Any]:
    declared_shape = companion["companionFormatContract"]["shapeSha256"]
    actual_shape = shape_sha256(companion)
    require_exact(declared_shape, actual_shape, "declared Profile shape SHA-256")
    require_exact(actual_shape, EXPECTED_SHAPE_SHA256, "accepted Profile shape SHA-256")
    require_exact(sha256(payload), EXPECTED_SHA256, "accepted Profile file SHA-256")
    require_exact(companion["schema"], "o2i.archimate-profile/target-v46", "Profile schema")
    core = validate_core_binding(companion, core_companion)
    validate_resolution(companion)
    validate_reference_integrity(companion, core)
    validate_applicability(companion, core)
    derive_rule_inventory(companion)
    derive_profile_defect_rule_bindings(companion)
    validate_fixed_point_contract(companion)
    derive_mapping_rule_ids(companion)
    derive_property_runtime_plans(companion)
    derive_pattern_runtime_rules(companion)
    derive_activation_static_source_rule_ids(companion)
    derive_relation_projection_plans(companion)
    return core


def hs_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def hs_bool(value: bool) -> str:
    return "True" if value else "False"


def hs_list(values: Iterable[str], indent: int = 2) -> str:
    rows = list(values)
    if not rows:
        return "[]"
    padding = " " * indent
    return "[ " + (f"\n{padding}, ").join(rows) + f"\n{' ' * (indent - 2)}]"


def render_generated(companion: dict[str, Any]) -> str:
    rules, bootstrap_rules, selected_rules = derive_rule_inventory(companion)
    defect_rule_bindings = derive_profile_defect_rule_bindings(companion)
    carrier_rule_ids, relation_rule_ids, property_rule_ids = derive_mapping_rule_ids(
        companion
    )
    property_runtime_plans = derive_property_runtime_plans(companion)
    pattern_runtime_rules = derive_pattern_runtime_rules(companion)
    activation_static_source_rule_ids = derive_activation_static_source_rule_ids(
        companion
    )
    relation_projection_plans = derive_relation_projection_plans(companion)
    identity = companion["profileIdentity"]
    relations = companion["relationMappings"]
    properties = companion["propertyMappings"]
    carriers = companion["carrierMappings"]
    classification = companion["viewScopeContract"]["classification"]
    activation = activation_rows(companion)
    closure = closure_rows(companion)
    activation_contract = classification["activationRuleContract"]
    closure_schema = companion["viewScopeContract"]["closureRuleContract"][
        "selectorSchema"
    ]

    def text_values(values: Iterable[str]) -> str:
        return hs_list((hs_string(value) for value in values), 4)

    def typed(prefix: str, value: str) -> str:
        return haskell_constructor(prefix, value)

    def sum_type(name: str, constructors: Iterable[str]) -> str:
        rows = list(constructors)
        return (
            f"data {name}\n"
            + "  = "
            + "\n  | ".join(rows)
            + "\n  deriving (Eq, Ord, Show)"
        )

    def consequences(values: list[str]) -> str:
        rendered = [CONSEQUENCE_INTERPRETATION[value][0] for value in values]
        return (
            "GeneratedConsequences ("
            + rendered[0]
            + ") "
            + hs_list((f"({value})" for value in rendered[1:]), 6)
        )

    def cardinality(value: str) -> str:
        return {
            "exactly-one": "GeneratedExactlyOne",
            "zero-or-many": "GeneratedZeroOrMany",
        }[value]

    def runtime_expected(value: Any) -> str:
        if isinstance(value, bool):
            return f"GeneratedExpectedBoolean {hs_bool(value)}"
        if isinstance(value, str):
            return f"GeneratedExpectedText {hs_string(value)}"
        if isinstance(value, list) and all(
            isinstance(item, str) for item in value
        ):
            return f"GeneratedExpectedTexts ({text_values(value)})"
        raise ValueError(f"unsupported generated runtime expectation: {value!r}")

    carrier_values = []
    for row in carriers:
        carrier_values.append(
            "GeneratedCarrierMapping "
            + " ".join(
                [
                    hs_string(row["id"]),
                    hs_string(carrier_rule_ids[row["id"]]),
                    hs_string(row["archimateElement"]),
                    hs_string(row["carrierCategory"]),
                    text_values(row["o2iTypes"]),
                ]
            )
        )

    relation_values = []
    for row in relations:
        attribute = row.get("attributeContract")
        attribute_rule = "Nothing" if attribute is None else f"Just {hs_string(attribute['ruleId'])}"
        relation_values.append(
            "GeneratedRelationMapping "
            + " ".join(
                [
                    hs_string(row["id"]),
                    hs_string(relation_rule_ids[row["id"]]),
                    hs_string(row["archimateRelationship"]),
                    hs_bool(row["associationDirected"]),
                    hs_string(row["label"]),
                    hs_string(row["projection"]["relationToken"]),
                    f"({attribute_rule})",
                ]
            )
        )

    relation_projection_values = [
        "GeneratedRelationProjectionPlan "
        + " ".join(hs_string(value) for value in row)
        for row in relation_projection_plans
    ]

    property_values = [
        "GeneratedPropertyMapping "
        + " ".join(
            [
                hs_string(row["id"]),
                hs_string(property_rule_ids[row["id"]]),
                hs_string(row["key"]),
                hs_string(row["owner"]),
            ]
        )
        for row in properties
    ]

    property_runtime_values = []
    for plan in property_runtime_plans:
        constraint = plan["constraint"]
        constraint_constructor = {
            "admittedValues": "GeneratedAdmittedValuesConstraint",
            "domain": "GeneratedDomainConstraint",
            "grammar": "GeneratedGrammarConstraint",
        }[plan["constraintKind"]]
        property_runtime_values.append(
            "GeneratedPropertyRuntimePlan "
            + " ".join(
                [
                    hs_string(plan["id"]),
                    hs_string(plan["authority"]),
                    hs_string(plan["key"]),
                    hs_string(plan["owner"]),
                    cardinality(plan["propertyCardinality"]["expected"]),
                    hs_string(plan["propertyCardinality"]["ruleId"]),
                    cardinality(plan["valueCardinality"]["expected"]),
                    hs_string(plan["valueCardinality"]["ruleId"]),
                    hs_string(plan["valueKind"]["ruleId"]),
                    "("
                    + constraint_constructor
                    + " "
                    + hs_string(constraint["ruleId"])
                    + " ("
                    + runtime_expected(constraint["expected"])
                    + "))",
                ]
            )
        )

    pattern_runtime_values = [
        "GeneratedPatternRuntimeRule "
        + " ".join(
            [
                hs_string(row["subject"]),
                hs_string(row["authority"]),
                hs_string(row["ruleId"]),
                f"({runtime_expected(row['expected'])})",
            ]
        )
        for row in pattern_runtime_rules
    ]

    activation_values = []
    activation_projections = []
    for branch, row in activation:
        selector = row["selector"]
        branch_scope = {
            "graph": "GeneratedGraphOnly",
            "qualification": "GeneratedQualificationOnly",
            "shared": "GeneratedGraphAndQualification",
        }[branch]
        rendered_selector = (
            "GeneratedActivationSelector "
            + " ".join(
                [
                    typed("GeneratedActivationSubject", selector["subjectFamily"]),
                    typed(
                        "GeneratedActivationMembership",
                        selector["membershipPrerequisite"],
                    ),
                    typed("GeneratedActivationPredicateMode", selector["predicateMode"]),
                    typed(
                        "GeneratedActivationPredicateField",
                        selector["predicateField"],
                    ),
                    typed(
                        "GeneratedActivationPredicateSource",
                        selector["predicateSource"],
                    ),
                    typed(
                        "GeneratedActivationIncidence",
                        selector["incidencePredicate"],
                    ),
                ]
            )
        )
        activation_values.append(
            row["constructorId"] + " " + hs_string(row["ruleId"])
        )
        activation_projections.append(
            (
                row["constructorId"],
                branch_scope,
                rendered_selector,
                consequences(row["produces"]),
            )
        )

    closure_values = []
    closure_projections = []
    for branch, row in closure:
        selector = row["selector"]
        rendered_selector = (
            "GeneratedClosureSelector "
            + " ".join(
                [
                    typed("GeneratedClosureTrigger", selector["triggerFamily"]),
                    typed("GeneratedFact", selector["triggerMembership"]),
                    typed("GeneratedTraversal", selector["traversalDirection"]),
                    typed("GeneratedReference", selector["referenceField"]),
                    typed("GeneratedIncluded", selector["includedFamily"]),
                    typed(
                        "GeneratedClosureIncidence",
                        selector["incidencePredicate"],
                    ),
                ]
            )
        )
        rendered_branch = {
            "graph": "GeneratedGraphBranch",
            "qualification": "GeneratedQualificationBranch",
        }[branch]
        closure_values.append(
            row["constructorId"] + " " + hs_string(row["ruleId"])
        )
        closure_projections.append(
            (
                row["constructorId"],
                rendered_branch,
                rendered_selector,
                consequences(row["produces"]),
            )
        )

    activation_rule_type = sum_type(
        "GeneratedActivationRule",
        (row["constructorId"] + " !Text" for _, row in activation),
    )
    closure_rule_type = sum_type(
        "GeneratedClosureRule",
        (row["constructorId"] + " !Text" for _, row in closure),
    )
    activation_provenance_equations = "\n".join(
        f"generatedActivationProvenanceRuleId ({constructor} ruleId) = ruleId"
        for constructor, _, _, _ in activation_projections
    )
    activation_static_source_equations = "\n".join(
        "generatedActivationStaticSourceRuleIds "
        + f"({row['constructorId']} _) = "
        + text_values(activation_static_source_rule_ids[row["constructorId"]])
        for _, row in activation
    )
    activation_branch_equations = "\n".join(
        f"generatedActivationBranchScope ({constructor} _) = {branch}"
        for constructor, branch, _, _ in activation_projections
    )
    activation_selector_equations = "\n".join(
        f"generatedActivationSelector ({constructor} _) = {selector}"
        for constructor, _, selector, _ in activation_projections
    )
    activation_consequence_equations = "\n".join(
        f"generatedActivationConsequences ({constructor} _) = {rendered}"
        for constructor, _, _, rendered in activation_projections
    )
    closure_provenance_equations = "\n".join(
        f"generatedClosureProvenanceRuleId ({constructor} ruleId) = ruleId"
        for constructor, _, _, _ in closure_projections
    )
    closure_branch_equations = "\n".join(
        f"generatedClosureBranch ({constructor} _) = {branch}"
        for constructor, branch, _, _ in closure_projections
    )
    closure_selector_equations = "\n".join(
        f"generatedClosureSelector ({constructor} _) = {selector}"
        for constructor, _, selector, _ in closure_projections
    )
    closure_consequence_equations = "\n".join(
        f"generatedClosureConsequences ({constructor} _) = {rendered}"
        for constructor, _, _, rendered in closure_projections
    )
    activation_subject_type = sum_type(
        "GeneratedActivationSubjectFamily",
        (
            typed("GeneratedActivationSubject", value)
            for value in activation_contract["subjectFamilyValues"]
        ),
    )
    activation_membership_type = sum_type(
        "GeneratedActivationMembershipPrerequisite",
        (
            typed("GeneratedActivationMembership", value)
            for value in activation_contract["membershipPrerequisiteValues"]
        ),
    )
    activation_mode_type = sum_type(
        "GeneratedActivationPredicateMode",
        (
            typed("GeneratedActivationPredicateMode", value)
            for value in activation_contract["predicateModeValues"]
        ),
    )
    activation_field_type = sum_type(
        "GeneratedActivationPredicateField",
        (
            typed("GeneratedActivationPredicateField", value)
            for value in activation_contract["predicateFieldValues"]
        ),
    )
    activation_source_type = sum_type(
        "GeneratedActivationPredicateSource",
        (
            typed("GeneratedActivationPredicateSource", value)
            for value in activation_contract["predicateSourceValues"]
        ),
    )
    activation_incidence_type = sum_type(
        "GeneratedActivationIncidencePredicate",
        (
            typed("GeneratedActivationIncidence", value)
            for value in activation_contract["incidencePredicateValues"]
        ),
    )
    closure_trigger_type = sum_type(
        "GeneratedClosureTriggerFamily",
        (
            typed("GeneratedClosureTrigger", value)
            for value in closure_schema["triggerFamilyValues"]
        ),
    )
    fact_selector_type = sum_type(
        "GeneratedFactSelector",
        (
            typed("GeneratedFact", value)
            for value in closure_schema["triggerMembershipValues"]
        ),
    )
    traversal_type = sum_type(
        "GeneratedTraversalDirection",
        (
            typed("GeneratedTraversal", value)
            for value in closure_schema["traversalDirectionValues"]
        ),
    )
    reference_type = sum_type(
        "GeneratedReferenceField",
        (
            typed("GeneratedReference", value)
            for value in closure_schema["referenceFieldValues"]
        ),
    )
    included_type = sum_type(
        "GeneratedIncludedFamily",
        (
            typed("GeneratedIncluded", value)
            for value in closure_schema["includedFamilyValues"]
        ),
    )
    closure_incidence_type = sum_type(
        "GeneratedClosureIncidencePredicate",
        (
            typed("GeneratedClosureIncidence", value)
            for value in closure_schema["incidencePredicateValues"]
        ),
    )

    require_unique_haskell_constructors(
        "GeneratedProfileEvidence",
        EXPECTED_PROFILE_EVIDENCE_KINDS,
        "Profile evidence kind constructors",
    )
    evidence_kind_type = sum_type(
        "GeneratedProfileEvidenceKind",
        (
            haskell_constructor("GeneratedProfileEvidence", evidence_kind)
            for evidence_kind in EXPECTED_PROFILE_EVIDENCE_KINDS
        ),
    )
    evidence_names = {
        evidence_kind: haskell_constructor("", evidence_kind)
        for evidence_kind in EXPECTED_PROFILE_EVIDENCE_KINDS
    }
    defect_rule_constructors = {
        evidence_kind: f"Generated{evidence_names[evidence_kind]}DefectRule"
        for evidence_kind in EXPECTED_PROFILE_EVIDENCE_KINDS
    }
    defect_rule_type = (
        "data GeneratedProfileDefectRule "
        "(kind :: GeneratedProfileEvidenceKind) where\n"
        + "  "
        + "\n  ".join(
            defect_rule_constructors[evidence_kind]
            + " :: !Text -> GeneratedProfileDefectRule "
            + "'"
            + haskell_constructor("GeneratedProfileEvidence", evidence_kind)
            for evidence_kind in EXPECTED_PROFILE_EVIDENCE_KINDS
        )
    )
    defect_rule_id_equations = "\n".join(
        "generatedProfileDefectRuleId "
        + f"({defect_rule_constructors[evidence_kind]} ruleId) = ruleId"
        for evidence_kind in EXPECTED_PROFILE_EVIDENCE_KINDS
    )
    defect_rule_lookup_names = {
        evidence_kind: "generated"
        + evidence_names[evidence_kind]
        + "DefectRule"
        for evidence_kind in EXPECTED_PROFILE_EVIDENCE_KINDS
    }
    defect_rule_lookups = []
    for evidence_kind in EXPECTED_PROFILE_EVIDENCE_KINDS:
        function_name = defect_rule_lookup_names[evidence_kind]
        type_constructor = haskell_constructor(
            "GeneratedProfileEvidence", evidence_kind
        )
        value_constructor = defect_rule_constructors[evidence_kind]
        bound_rules = [
            rule_id
            for rule_id, bound_kind in defect_rule_bindings.items()
            if bound_kind == evidence_kind
        ]
        guards = "\n".join(
            f"  | ruleId == {hs_string(rule_id)} = "
            f"Just ({value_constructor} ruleId)"
            for rule_id in bound_rules
        )
        defect_rule_lookups.append(
            f"{function_name} :: Text -> Maybe "
            f"(GeneratedProfileDefectRule '{type_constructor})\n"
            f"{function_name} ruleId\n{guards}\n"
            "  | otherwise = Nothing"
        )
    defect_rule_lookup_exports = "\n".join(
        f"  , {defect_rule_lookup_names[evidence_kind]}"
        for evidence_kind in EXPECTED_PROFILE_EVIDENCE_KINDS
    )

    return f'''{{-# LANGUAGE DataKinds #-}}
{{-# LANGUAGE GADTs #-}}
{{-# LANGUAGE KindSignatures #-}}
{{-# LANGUAGE OverloadedStrings #-}}

-- This module is generated by contract/compile.py. Do not edit.
module O2I.ArchiMate.Profile.Internal.Generated
  ( GeneratedProfileDescriptor(..)
  , GeneratedCarrierMapping(..)
  , GeneratedRelationMapping(..)
  , GeneratedRelationProjectionPlan(..)
  , GeneratedPropertyMapping(..)
  , GeneratedCardinalityExpectation(..)
  , GeneratedRuntimeExpected(..)
  , GeneratedPropertyConstraint(..)
  , GeneratedPropertyRuntimePlan(..)
  , GeneratedPatternRuntimeRule(..)
  , GeneratedBranch(..)
  , GeneratedBranchScope(..)
  , GeneratedActivationSubjectFamily(..)
  , GeneratedActivationMembershipPrerequisite(..)
  , GeneratedActivationPredicateMode(..)
  , GeneratedActivationPredicateField(..)
  , GeneratedActivationPredicateSource(..)
  , GeneratedActivationIncidencePredicate(..)
  , GeneratedActivationSelector(..)
  , GeneratedClosureTriggerFamily(..)
  , GeneratedFactSelector(..)
  , GeneratedTraversalDirection(..)
  , GeneratedReferenceField(..)
  , GeneratedIncludedFamily(..)
  , GeneratedClosureIncidencePredicate(..)
  , GeneratedClosureSelector(..)
  , GeneratedRecordBinding(..)
  , GeneratedValueBinding(..)
  , GeneratedFactTemplate(..)
  , GeneratedConsequence(..)
  , GeneratedConsequences(..)
  , GeneratedActivationRule(..)
  , GeneratedClosureRule(..)
  , GeneratedProfileEvidenceKind(..)
  , GeneratedProfileDefectRule
  , generatedProfileDefectRuleId
{defect_rule_lookup_exports}
  , generatedActivationProvenanceRuleId
  , generatedActivationStaticSourceRuleIds
  , generatedActivationBranchScope
  , generatedActivationSelector
  , generatedActivationConsequences
  , generatedClosureProvenanceRuleId
  , generatedClosureBranch
  , generatedClosureSelector
  , generatedClosureConsequences
  , generatedProfileDescriptor
  , generatedProfileRuleIds
  , generatedBootstrapRuleIds
  , generatedSelectedProfileRuleIds
  , generatedCarrierMappings
  , generatedRelationMappings
  , generatedRelationProjectionPlans
  , generatedPropertyMappings
  , generatedPropertyRuntimePlans
  , generatedPatternRuntimeRules
  , generatedActivationRules
  , generatedClosureRules
  ) where

import Data.Text (Text)

{evidence_kind_type}

{defect_rule_type}

generatedProfileDefectRuleId :: GeneratedProfileDefectRule kind -> Text
{defect_rule_id_equations}

{chr(10).join(defect_rule_lookups)}

data GeneratedProfileDescriptor = GeneratedProfileDescriptor
  {{ generatedProfileIdentity :: !Text
  , generatedProfileToken :: !Text
  , generatedProfileVersion :: !Text
  , generatedProfileNotation :: !Text
  , generatedProfileAdapterIds :: ![Text]
  , generatedProfileContractDigest :: !Text
  }} deriving (Eq, Show)

data GeneratedCarrierMapping = GeneratedCarrierMapping
  {{ generatedCarrierMappingId :: !Text
  , generatedCarrierRuleId :: !Text
  , generatedCarrierArchiMateElement :: !Text
  , generatedCarrierCategory :: !Text
  , generatedCarrierO2ITypes :: ![Text]
  }} deriving (Eq, Show)

data GeneratedRelationMapping = GeneratedRelationMapping
  {{ generatedRelationMappingId :: !Text
  , generatedRelationRuleId :: !Text
  , generatedRelationArchiMateRelationship :: !Text
  , generatedRelationAssociationDirected :: !Bool
  , generatedRelationLabel :: !Text
  , generatedRelationToken :: !Text
  , generatedRelationAttributeRule :: !(Maybe Text)
  }} deriving (Eq, Show)

data GeneratedRelationProjectionPlan = GeneratedRelationProjectionPlan
  {{ generatedRelationProjectionMappingId :: !Text
  , generatedRelationProjectionSourceElement :: !Text
  , generatedRelationProjectionTargetElement :: !Text
  }} deriving (Eq, Ord, Show)

data GeneratedPropertyMapping = GeneratedPropertyMapping
  {{ generatedPropertyMappingId :: !Text
  , generatedPropertyRuleId :: !Text
  , generatedPropertyKey :: !Text
  , generatedPropertyOwner :: !Text
  }} deriving (Eq, Show)

data GeneratedCardinalityExpectation
  = GeneratedExactlyOne
  | GeneratedZeroOrMany
  deriving (Eq, Ord, Show)

data GeneratedRuntimeExpected
  = GeneratedExpectedText !Text
  | GeneratedExpectedBoolean !Bool
  | GeneratedExpectedTexts ![Text]
  deriving (Eq, Ord, Show)

data GeneratedPropertyConstraint
  = GeneratedAdmittedValuesConstraint !Text !GeneratedRuntimeExpected
  | GeneratedDomainConstraint !Text !GeneratedRuntimeExpected
  | GeneratedGrammarConstraint !Text !GeneratedRuntimeExpected
  deriving (Eq, Ord, Show)

data GeneratedPropertyRuntimePlan = GeneratedPropertyRuntimePlan
  {{ generatedPropertyRuntimeMappingId :: !Text
  , generatedPropertyRuntimeAuthority :: !Text
  , generatedPropertyRuntimeKey :: !Text
  , generatedPropertyRuntimeOwner :: !Text
  , generatedPropertyRuntimePropertyCardinality ::
      !GeneratedCardinalityExpectation
  , generatedPropertyRuntimePropertyCardinalityRuleId :: !Text
  , generatedPropertyRuntimeValueCardinality ::
      !GeneratedCardinalityExpectation
  , generatedPropertyRuntimeValueCardinalityRuleId :: !Text
  , generatedPropertyRuntimeValueKindRuleId :: !Text
  , generatedPropertyRuntimeConstraint :: !GeneratedPropertyConstraint
  }} deriving (Eq, Ord, Show)

data GeneratedPatternRuntimeRule = GeneratedPatternRuntimeRule
  {{ generatedPatternRuntimeSubject :: !Text
  , generatedPatternRuntimeAuthority :: !Text
  , generatedPatternRuntimeRuleId :: !Text
  , generatedPatternRuntimeExpected :: !GeneratedRuntimeExpected
  }} deriving (Eq, Ord, Show)

data GeneratedBranch
  = GeneratedGraphBranch
  | GeneratedQualificationBranch
  deriving (Eq, Ord, Show)

data GeneratedBranchScope
  = GeneratedGraphOnly
  | GeneratedQualificationOnly
  | GeneratedGraphAndQualification
  deriving (Eq, Ord, Show)

{activation_subject_type}

{activation_membership_type}

{activation_mode_type}

{activation_field_type}

{activation_source_type}

{activation_incidence_type}

data GeneratedActivationSelector = GeneratedActivationSelector
  {{ generatedActivationSubjectFamily :: !GeneratedActivationSubjectFamily
  , generatedActivationMembershipPrerequisite ::
      !GeneratedActivationMembershipPrerequisite
  , generatedActivationPredicateMode :: !GeneratedActivationPredicateMode
  , generatedActivationPredicateField :: !GeneratedActivationPredicateField
  , generatedActivationPredicateSource :: !GeneratedActivationPredicateSource
  , generatedActivationIncidencePredicate ::
      !GeneratedActivationIncidencePredicate
  }} deriving (Eq, Show)

{closure_trigger_type}

{fact_selector_type}

{traversal_type}

{reference_type}

{included_type}

{closure_incidence_type}

data GeneratedClosureSelector = GeneratedClosureSelector
  {{ generatedClosureTriggerFamily :: !GeneratedClosureTriggerFamily
  , generatedClosureTriggerFact :: !GeneratedFactSelector
  , generatedClosureTraversalDirection :: !GeneratedTraversalDirection
  , generatedClosureReferenceField :: !GeneratedReferenceField
  , generatedClosureIncludedFamily :: !GeneratedIncludedFamily
  , generatedClosureIncidencePredicate :: !GeneratedClosureIncidencePredicate
  }} deriving (Eq, Show)

data GeneratedRecordBinding
  = GeneratedOwnerRecord
  | GeneratedIncludedRecord
  | GeneratedTriggerRecord
  | GeneratedSourceRecord
  | GeneratedTargetRecord
  | GeneratedJunctionRecord
  | GeneratedProposalRecord
  | GeneratedReferenceRecord
  | GeneratedEndpointRecord
  | GeneratedContextualizationRecord
  | GeneratedContextOwnerRecord
  | GeneratedViewOccurrence
  deriving (Eq, Ord, Show)

data GeneratedValueBinding
  = GeneratedCarrierMappingId
  | GeneratedFamilyId
  | GeneratedRoleId
  deriving (Eq, Ord, Show)

data GeneratedFactTemplate
  = GeneratedGraphMember !GeneratedRecordBinding
  | GeneratedGraphContextualizableCarrier
      !GeneratedRecordBinding !GeneratedValueBinding
  | GeneratedGraphContextualization
      !GeneratedRecordBinding !GeneratedRecordBinding !GeneratedRecordBinding
  | GeneratedGraphStructuredFamilyCarrier
      !GeneratedValueBinding !GeneratedRecordBinding
  | GeneratedGraphStructuredFamilyIncidence
      !GeneratedValueBinding !GeneratedRecordBinding !GeneratedRecordBinding
  | GeneratedGraphStructuredFamilyParticipantSegment
      !GeneratedValueBinding !GeneratedRecordBinding !GeneratedRecordBinding
  | GeneratedGraphStructuredFamilyTargetSegment
      !GeneratedValueBinding !GeneratedRecordBinding !GeneratedRecordBinding
  | GeneratedQualificationMember !GeneratedRecordBinding
  | GeneratedQualificationProposalCarrier !GeneratedRecordBinding
  | GeneratedQualificationProposalRoleIncidence
      !GeneratedRecordBinding !GeneratedRecordBinding
  | GeneratedQualificationContextualizableProposalEndpoint
      !GeneratedRecordBinding !GeneratedRecordBinding !GeneratedValueBinding
      !GeneratedRecordBinding
  | GeneratedQualificationContextualizationOfProposalEndpoint
      !GeneratedRecordBinding !GeneratedRecordBinding !GeneratedRecordBinding
      !GeneratedRecordBinding
  | GeneratedQualificationContextOwnerRequiredByProposal
      !GeneratedRecordBinding !GeneratedRecordBinding !GeneratedRecordBinding
      !GeneratedRecordBinding !GeneratedRecordBinding
  | GeneratedQualificationContextualizationOfExactProposalEndpoint
      !GeneratedRecordBinding !GeneratedRecordBinding !GeneratedRecordBinding
      !GeneratedRecordBinding !GeneratedRecordBinding
  deriving (Eq, Ord, Show)

data GeneratedConsequence
  = GeneratedFact !GeneratedFactTemplate
  | GeneratedBranchMember !GeneratedRecordBinding
  | GeneratedAlternativeFacts
      !GeneratedFactTemplate !GeneratedFactTemplate
  deriving (Eq, Ord, Show)

data GeneratedConsequences = GeneratedConsequences
  !GeneratedConsequence ![GeneratedConsequence]
  deriving (Eq, Show)

{activation_rule_type}

{closure_rule_type}

generatedActivationProvenanceRuleId :: GeneratedActivationRule -> Text
{activation_provenance_equations}

generatedActivationStaticSourceRuleIds :: GeneratedActivationRule -> [Text]
{activation_static_source_equations}

generatedActivationBranchScope ::
  GeneratedActivationRule -> GeneratedBranchScope
{activation_branch_equations}

generatedActivationSelector ::
  GeneratedActivationRule -> GeneratedActivationSelector
{activation_selector_equations}

generatedActivationConsequences ::
  GeneratedActivationRule -> GeneratedConsequences
{activation_consequence_equations}

generatedClosureProvenanceRuleId :: GeneratedClosureRule -> Text
{closure_provenance_equations}

generatedClosureBranch :: GeneratedClosureRule -> GeneratedBranch
{closure_branch_equations}

generatedClosureSelector :: GeneratedClosureRule -> GeneratedClosureSelector
{closure_selector_equations}

generatedClosureConsequences :: GeneratedClosureRule -> GeneratedConsequences
{closure_consequence_equations}

generatedProfileDescriptor :: GeneratedProfileDescriptor
generatedProfileDescriptor =
  GeneratedProfileDescriptor
    {hs_string(identity['identity'])}
    {hs_string(identity['token'])}
    {hs_string(identity['version'])}
    {hs_string(identity['notation'])}
    {text_values(identity['adapterIds'])}
    {hs_string(EXPECTED_SHA256)}

generatedProfileRuleIds :: [Text]
generatedProfileRuleIds = {text_values(rules)}

generatedBootstrapRuleIds :: [Text]
generatedBootstrapRuleIds = {text_values(bootstrap_rules)}

generatedSelectedProfileRuleIds :: [Text]
generatedSelectedProfileRuleIds = {text_values(selected_rules)}

generatedCarrierMappings :: [GeneratedCarrierMapping]
generatedCarrierMappings = {hs_list(carrier_values, 4)}

generatedRelationMappings :: [GeneratedRelationMapping]
generatedRelationMappings = {hs_list(relation_values, 4)}

generatedRelationProjectionPlans :: [GeneratedRelationProjectionPlan]
generatedRelationProjectionPlans = {hs_list(relation_projection_values, 4)}

generatedPropertyMappings :: [GeneratedPropertyMapping]
generatedPropertyMappings = {hs_list(property_values, 4)}

generatedPropertyRuntimePlans :: [GeneratedPropertyRuntimePlan]
generatedPropertyRuntimePlans = {hs_list(property_runtime_values, 4)}

generatedPatternRuntimeRules :: [GeneratedPatternRuntimeRule]
generatedPatternRuntimeRules = {hs_list(pattern_runtime_values, 4)}

generatedActivationRules :: [GeneratedActivationRule]
generatedActivationRules = {hs_list(activation_values, 4)}

generatedClosureRules :: [GeneratedClosureRule]
generatedClosureRules = {hs_list(closure_values, 4)}
'''


def compile_contract(core_companion: Path) -> str:
    companion, payload = load_object(COMPANION, "Profile companion")
    validate_companion(companion, payload, core_companion)
    rendered = render_generated(companion)
    formatted = subprocess.run(
        ["hindent", "--line-length", "80"],
        input=rendered,
        text=True,
        capture_output=True,
        check=False,
    )
    if formatted.returncode != 0:
        raise ValueError(f"hindent rejected generated Profile projection: {formatted.stderr}")
    return formatted.stdout


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument(
        "--core-companion",
        type=Path,
        required=True,
        help="path to the exact authoritative Core semantic companion",
    )
    args = parser.parse_args()
    rendered = compile_contract(args.core_companion)
    if args.check:
        if not GENERATED.exists() or GENERATED.read_text(encoding="utf-8") != rendered:
            raise SystemExit(f"generated Profile projection is stale: {GENERATED}")
    else:
        GENERATED.parent.mkdir(parents=True, exist_ok=True)
        GENERATED.write_text(rendered, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
