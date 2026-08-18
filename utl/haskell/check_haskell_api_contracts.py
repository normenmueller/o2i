#!/usr/bin/env python3

"""Check public API and private type-safety compile contracts."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


ERROR_CODE = re.compile(r"GHC-\d+")
CORE_EXPOSED_MODULES = frozenset(
    {
        "O2I.Core.Contract",
        "O2I.Core.Graph.Observation",
        "O2I.Core.Identity",
        "O2I.Core.Rule.Catalog",
        "O2I.Semantics",
        "O2I.Semantics.Input",
        "O2I.Structure",
    }
)
CORE_SOURCE_FILES = frozenset(
    {
        "src/O2I/Core/Contract.hs",
        "src/O2I/Core/Contract/Generated.hs",
        "src/O2I/Core/Contract/Internal.hs",
        "src/O2I/Core/Graph/Commitment.hs",
        "src/O2I/Core/Graph/Observation.hs",
        "src/O2I/Core/Graph/Observation/Index.hs",
        "src/O2I/Core/Graph/Observation/Internal.hs",
        "src/O2I/Core/Identity.hs",
        "src/O2I/Core/Identity/Internal.hs",
        "src/O2I/Core/Rule/Catalog.hs",
        "src/O2I/Core/Rule/Catalog/Definition.hs",
        "src/O2I/Core/Rule/Catalog/Definition/CapabilityInput.hs",
        "src/O2I/Core/Rule/Catalog/Definition/Qualification.hs",
        "src/O2I/Core/Rule/Catalog/Definition/ReadinessAndAssessment.hs",
        "src/O2I/Core/Rule/Catalog/Definition/Semantics.hs",
        "src/O2I/Core/Rule/Catalog/Definition/Structure.hs",
        "src/O2I/Core/Rule/Catalog/Definition/Trace.hs",
        "src/O2I/Core/Rule/Catalog/Internal.hs",
        "src/O2I/Input/Internal/Binding.hs",
        "src/O2I/Input/Internal/Decode.hs",
        "src/O2I/Input/Internal/Json.hs",
        "src/O2I/Input/Internal/Set.hs",
        "src/O2I/Input/Internal/Text.hs",
        "src/O2I/Input/Internal/Types.hs",
        "src/O2I/Semantics.hs",
        "src/O2I/Semantics/Contextualization.hs",
        "src/O2I/Semantics/Eval.hs",
        "src/O2I/Semantics/Family/CollectiveStrategyRealization.hs",
        "src/O2I/Semantics/Index.hs",
        "src/O2I/Semantics/Input.hs",
        "src/O2I/Semantics/Internal.hs",
        "src/O2I/Semantics/SituatedNeed.hs",
        "src/O2I/Semantics/Strategy.hs",
        "src/O2I/Semantics/Vocabulary.hs",
        "src/O2I/Structure.hs",
        "src/O2I/Structure/Index.hs",
        "src/O2I/Structure/Internal.hs",
        "src/O2I/Structure/Proposition.hs",
    }
)


@dataclass(frozen=True)
class CompileFailure:
    source: str
    diagnostics: tuple[tuple[str, int], ...]


@dataclass(frozen=True)
class PackageContract:
    package: str
    compile_passes: tuple[str, ...]
    compile_failures: tuple[CompileFailure, ...]


@dataclass(frozen=True)
class PrivateCompileFailure:
    source: str
    diagnostics: tuple[tuple[str, int], ...]


@dataclass(frozen=True)
class EvidenceRecordUpdate:
    module: str
    evidence_type: str
    projection: str


CONTRACTS = (
    PackageContract(
        "o2i-core",
        (
            "spc/lib/core/tst/api/compile-pass/PublicApi.hs",
            "spc/lib/core/tst/api/compile-pass/IdentityPublicApi.hs",
            "spc/lib/core/tst/api/compile-pass/"
            "CoreGraphObservationPublicApi.hs",
            "spc/lib/core/tst/api/compile-pass/"
            "CoreRuleCatalogPublicApi.hs",
            "spc/lib/core/tst/api/compile-pass/StructurePublicApi.hs",
            "spc/lib/core/tst/api/compile-pass/"
            "SupplementalInputPublicApi.hs",
            "spc/lib/core/tst/api/compile-pass/SemanticsPublicApi.hs",
        ),
        (
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "CoreContractOpaqueConstructors.hs",
                (("GHC-01928", 14),),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "IdentityOpaqueConstructors.hs",
                (("GHC-01928", 7),),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "IdentityInternalModule.hs",
                (("GHC-87110", 1),),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "CoreGraphObservationOpaqueConstructors.hs",
                (("GHC-01928", 1),),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "CoreGraphObservationInternalModule.hs",
                (("GHC-87110", 1),),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "CoreRuleCatalogOpaqueConstructors.hs",
                (("GHC-01928", 1),),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "CoreRuleCatalogInternalModule.hs",
                (("GHC-87110", 1),),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "StructureOpaqueConstructors.hs",
                (("GHC-01928", 1), ("GHC-88464", 2)),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "StructureEvidenceConstruction.hs",
                (("GHC-01928", 12),),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "StructureInternalModule.hs",
                (("GHC-87110", 1),),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "StructureLegacyDefectConsumers.hs",
                (("GHC-88464", 4),),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "SupplementalInputOpaqueConstructors.hs",
                (("GHC-88464", 1),),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "SupplementalInputEvidenceConstruction.hs",
                (("GHC-01928", 19),),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "SupplementalInputLegacyConsumers.hs",
                (("GHC-87110", 1),),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "SemanticsOpaqueConstructors.hs",
                (("GHC-01928", 2), ("GHC-88464", 1)),
            ),
            CompileFailure(
                "spc/lib/core/tst/api/compile-fail/"
                "SemanticsInternalModule.hs",
                (("GHC-87110", 1),),
            ),
        ),
    ),
    PackageContract(
        "o2i-inspection",
        ("spc/lib/inspection/tst/api/compile-pass/PublicApi.hs",),
        (
            CompileFailure(
                "spc/lib/inspection/tst/api/compile-fail/"
                "ForeignAdapterLocation.hs",
                (("GHC-83865", 1),),
            ),
            CompileFailure(
                "spc/lib/inspection/tst/api/compile-fail/"
                "HiddenNormalization.hs",
                (("GHC-76037", 6),),
            ),
            CompileFailure(
                "spc/lib/inspection/tst/api/compile-fail/"
                "HiddenSourceBinding.hs",
                (("GHC-76037", 2),),
            ),
            CompileFailure(
                "spc/lib/inspection/tst/api/compile-fail/"
                "OpaqueConstructors.hs",
                (("GHC-22385", 1),),
            ),
        ),
    ),
    PackageContract(
        "o2i-archimate-profile",
        ("spc/ctr/archimate/tst/api/compile-pass/PublicApi.hs",),
        (
            CompileFailure(
                "spc/ctr/archimate/tst/api/compile-fail/"
                "DraftOpaqueConstructor.hs",
                (("GHC-01928", 1),),
            ),
            CompileFailure(
                "spc/ctr/archimate/tst/api/compile-fail/"
                "ResolutionOpaqueConstructor.hs",
                (("GHC-01928", 1),),
            ),
            CompileFailure(
                "spc/ctr/archimate/tst/api/compile-fail/"
                "ClosureOpaqueConstructor.hs",
                (("GHC-01928", 1),),
            ),
            CompileFailure(
                "spc/ctr/archimate/tst/api/compile-fail/"
                "CrossDocumentView.hs",
                (("GHC-25897", 1),),
            ),
            CompileFailure(
                "spc/ctr/archimate/tst/api/compile-fail/"
                "ProjectionWithoutConformance.hs",
                (("GHC-83865", 1),),
            ),
            CompileFailure(
                "spc/ctr/archimate/tst/api/compile-fail/"
                "ProjectionOpaqueConstructor.hs",
                (("GHC-01928", 1),),
            ),
            CompileFailure(
                "spc/ctr/archimate/tst/api/compile-fail/"
                "DraftIdentityRoleMismatch.hs",
                (("GHC-83865", 1),),
            ),
            CompileFailure(
                "spc/ctr/archimate/tst/api/compile-fail/"
                "ProfileDescriptorRecordUpdate.hs",
                (("GHC-22385", 1),),
            ),
            CompileFailure(
                "spc/ctr/archimate/tst/api/compile-fail/"
                "HiddenInternalModule.hs",
                (("GHC-87110", 1),),
            ),
        ),
    ),
    PackageContract(
        "o2i-operation",
        ("spc/lib/operation/tst/api/compile-pass/PublicApi.hs",),
        (
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/HiddenInternalModule.hs",
                (("GHC-87110", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "DiagnosticAdapterOwnerHiddenModule.hs",
                (("GHC-87110", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/OpaqueConstructors.hs",
                (("GHC-01928", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "AdapterContractOpaqueConstructors.hs",
                (("GHC-01928", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "AdapterWrongStageDiagnostic.hs",
                (("GHC-83865", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "AdapterRuleScopeEscape.hs",
                (("GHC-25897", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "AdapterRuleCrossScope.hs",
                (("GHC-25897", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "AdapterRuleCoercibleScope.hs",
                (("GHC-25897", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "AdapterExecutionOpaqueConstructor.hs",
                (("GHC-01928", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "ProfileHiddenInternalModule.hs",
                (("GHC-87110", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "ProfileOpaqueConstructors.hs",
                (("GHC-01928", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "EncodingHiddenInternalModule.hs",
                (("GHC-87110", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "EncodingOpaqueConstructors.hs",
                (("GHC-61948", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "MachineHiddenInternalModule.hs",
                (("GHC-87110", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "ToolDescriptorOpaqueConstructor.hs",
                (("GHC-01928", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "AdapterInventoryDocumentOpaqueConstructor.hs",
                (("GHC-01928", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "ProfileInventoryDocumentOpaqueConstructor.hs",
                (("GHC-01928", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "RuleInventoryDocumentOpaqueConstructor.hs",
                (("GHC-01928", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "RuleExplanationDocumentOpaqueConstructor.hs",
                (("GHC-01928", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "ViewDiscoveryDocumentOpaqueConstructor.hs",
                (("GHC-01928", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "DiscoveryProfileHiddenInternalModule.hs",
                (("GHC-87110", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "DiscoveryRuleHiddenInternalModule.hs",
                (("GHC-87110", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "DiscoveryViewHiddenInternalModule.hs",
                (("GHC-87110", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "SchemaGeneratedHiddenModule.hs",
                (("GHC-87110", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "MachineDocumentTypeSeparation.hs",
                (("GHC-83865", 5),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "SchemaHiddenInternalModule.hs",
                (("GHC-87110", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "SchemaOpaqueConstructors.hs",
                (("GHC-01928", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "ViewHiddenInternalModule.hs",
                (("GHC-87110", 1),),
            ),
            CompileFailure(
                "spc/lib/operation/tst/api/compile-fail/"
                "ViewOpaqueConstructors.hs",
                (("GHC-88464", 1),),
            ),
        ),
    ),
)

PRIVATE_COMPILE_FAILURES = (
    PrivateCompileFailure(
        "spc/lib/core/tst/internal/compile-fail/"
        "GraphCarrierModelIdentityInjection.hs",
        (("GHC-83865", 1),),
    ),
    PrivateCompileFailure(
        "spc/lib/core/tst/internal/compile-fail/IdentityCrossScope.hs",
        (("GHC-25897", 1),),
    ),
)


EVIDENCE_RECORD_UPDATES = (
    EvidenceRecordUpdate(
        "O2I.Structure",
        "QualifiedEndpointCatalogMembershipEvidence",
        "qualifiedEndpointCatalogMembershipSubject",
    ),
    EvidenceRecordUpdate(
        "O2I.Structure",
        "ContextualizationSourceCategoryEvidence",
        "contextualizationSourceCategorySegment",
    ),
    EvidenceRecordUpdate(
        "O2I.Structure",
        "ContextualizationTargetCategoryEvidence",
        "contextualizationTargetCategorySegment",
    ),
    EvidenceRecordUpdate(
        "O2I.Structure",
        "ContextualizationTargetOwnerCardinalityEvidence",
        "contextualizationTargetOwnerCardinalityMember",
    ),
    EvidenceRecordUpdate(
        "O2I.Structure",
        "SemanticRelationCompatibilityEvidence",
        "semanticRelationCompatibilityRelation",
    ),
    EvidenceRecordUpdate(
        "O2I.Structure",
        "StructuredPropositionIdentityEvidence",
        "structuredPropositionIdentitySubject",
    ),
    EvidenceRecordUpdate(
        "O2I.Structure",
        "CollectiveParticipantTypeEvidence",
        "collectiveParticipantTypeClaim",
    ),
    EvidenceRecordUpdate(
        "O2I.Structure",
        "CollectiveParticipantCardinalityEvidence",
        "collectiveParticipantCardinalityClaim",
    ),
    EvidenceRecordUpdate(
        "O2I.Structure",
        "CollectiveParticipantUniquenessEvidence",
        "collectiveParticipantUniquenessClaim",
    ),
    EvidenceRecordUpdate(
        "O2I.Structure",
        "CollectiveTargetTypeEvidence",
        "collectiveTargetTypeClaim",
    ),
    EvidenceRecordUpdate(
        "O2I.Structure",
        "CollectiveTargetCardinalityEvidence",
        "collectiveTargetCardinalityClaim",
    ),
    EvidenceRecordUpdate(
        "O2I.Structure",
        "CollectiveTargetDistinctnessEvidence",
        "collectiveTargetDistinctnessClaim",
    ),
    EvidenceRecordUpdate(
        "O2I.Semantics.Input",
        "SupplementalInvalidUtf8Evidence",
        "supplementalInvalidUtf8InputOrdinal",
    ),
    EvidenceRecordUpdate(
        "O2I.Semantics.Input",
        "SupplementalInvalidJsonSyntaxEvidence",
        "supplementalInvalidJsonSyntaxInputOrdinal",
    ),
    EvidenceRecordUpdate(
        "O2I.Semantics.Input",
        "SupplementalDuplicateObjectMemberEvidence",
        "supplementalDuplicateObjectMemberInputOrdinal",
    ),
    EvidenceRecordUpdate(
        "O2I.Semantics.Input",
        "SupplementalTopLevelObjectRequiredEvidence",
        "supplementalTopLevelObjectInputOrdinal",
    ),
    EvidenceRecordUpdate(
        "O2I.Semantics.Input",
        "SupplementalTypeMemberInvalidEvidence",
        "supplementalTypeMemberInputOrdinal",
    ),
    EvidenceRecordUpdate(
        "O2I.Semantics.Input",
        "SupplementalPayloadTypeNotAdmittedEvidence",
        "supplementalPayloadTypeNotAdmittedInputOrdinal",
    ),
    EvidenceRecordUpdate(
        "O2I.Semantics.Input",
        "SupplementalRequiredMemberMissingEvidence",
        "supplementalRequiredMemberMissingInputOrdinal",
    ),
    EvidenceRecordUpdate(
        "O2I.Semantics.Input",
        "SupplementalUnknownMemberEvidence",
        "supplementalUnknownMemberInputOrdinal",
    ),
    EvidenceRecordUpdate(
        "O2I.Semantics.Input",
        "SupplementalValueKindInvalidEvidence",
        "supplementalValueKindInputOrdinal",
    ),
    EvidenceRecordUpdate(
        "O2I.Semantics.Input",
        "SupplementalScalarGrammarInvalidEvidence",
        "supplementalScalarGrammarInputOrdinal",
    ),
    EvidenceRecordUpdate(
        "O2I.Semantics.Input",
        "SupplementalArrayCardinalityInvalidEvidence",
        "supplementalArrayCardinalityInputOrdinal",
    ),
    EvidenceRecordUpdate(
        "O2I.Semantics.Input",
        "SupplementalArrayDistinctnessInvalidEvidence",
        "supplementalArrayDistinctnessInputOrdinal",
    ),
    EvidenceRecordUpdate(
        "O2I.Semantics.Input",
        "SupplementalSubjectCardinalityInvalidEvidence",
        "supplementalSubjectCardinalityPayloadType",
    ),
    EvidenceRecordUpdate(
        "O2I.Semantics.Input",
        "SupplementalIdentityUnknownEvidence",
        "supplementalIdentityUnknownInputOrdinal",
    ),
    EvidenceRecordUpdate(
        "O2I.Semantics.Input",
        "SupplementalIdentityAmbiguousEvidence",
        "supplementalIdentityAmbiguousInputOrdinal",
    ),
    EvidenceRecordUpdate(
        "O2I.Semantics.Input",
        "SupplementalIdentityWrongTypeEvidence",
        "supplementalIdentityWrongTypeInputOrdinal",
    ),
    EvidenceRecordUpdate(
        "O2I.Semantics.Input",
        "SupplementalIdentityOutOfSelectedViewEvidence",
        "supplementalIdentityOutOfViewInputOrdinal",
    ),
    EvidenceRecordUpdate(
        "O2I.Semantics.Input",
        "SupplementalModelIdentityUnicodeScalarInvalidEvidence",
        "supplementalUnicodeScalarInputOrdinal",
    ),
    EvidenceRecordUpdate(
        "O2I.Semantics.Input",
        "SupplementalModelIdentityContainsNulEvidence",
        "supplementalModelIdentityNulInputOrdinal",
    ),
)


def parse_diagnostics(output: str) -> list[dict[str, object]]:
    diagnostics = []
    for line in output.splitlines():
        if not line.startswith("{"):
            continue
        try:
            value = json.loads(line)
        except json.JSONDecodeError as error:
            raise ValueError(f"invalid GHC JSON diagnostic: {line}") from error
        if isinstance(value, dict) and (
            "messageClass" in value or "severity" in value
        ):
            diagnostics.append(value)
    return diagnostics


def error_code(diagnostic: dict[str, object]) -> str | None:
    severity = diagnostic.get("severity")
    code = diagnostic.get("code")
    if severity == "Error" and isinstance(code, int):
        return f"GHC-{code:05d}"

    message_class = diagnostic.get("messageClass")
    if not isinstance(message_class, str) or "SevError" not in message_class:
        return None
    match = ERROR_CODE.search(message_class)
    return match.group(0) if match else None


def diagnostic_file(
    root: Path, diagnostic: dict[str, object]
) -> Path | None:
    span = diagnostic.get("span")
    if not isinstance(span, dict):
        return None
    name = span.get("file")
    if not isinstance(name, str):
        return None
    path = Path(name)
    return (path if path.is_absolute() else root / path).resolve()


def compiler_command(
    project_dir: Path,
    project_file: str | None,
    build_dir: Path,
    package: str,
    source: Path,
    output_dir: Path,
) -> list[str]:
    command = [
        "cabal",
        "-v0",
        f"--project-dir={project_dir}",
    ]
    if project_file is not None:
        command.append(f"--project-file={project_file}")
    return command + [
        f"--builddir={build_dir}", "exec",
        "--",
        "ghc",
        "-v0",
        "-fno-code",
        "-fforce-recomp",
        "-fmax-errors=1000",
        "-fdiagnostics-as-json",
        f"-odir={output_dir}",
        f"-hidir={output_dir}",
        f"-stubdir={output_dir}",
        "-package",
        package,
        str(source),
    ]


def cabal_library_field(package: Path, field: str) -> frozenset[str]:
    cabal_files = tuple(package.glob("*.cabal"))
    if len(cabal_files) != 1:
        raise RuntimeError(
            f"expected exactly one Cabal file in {package}, "
            f"found {len(cabal_files)}"
        )
    lines = cabal_files[0].read_text().splitlines()
    in_library = False
    collecting = False
    values = []
    for line in lines:
        if line == "library":
            in_library = True
            continue
        if in_library and line and not line[0].isspace():
            break
        if not in_library:
            continue
        if line.startswith(f"  {field}:"):
            collecting = True
            values.append(line.split(":", 1)[1])
            continue
        if collecting:
            if line.startswith("    "):
                values.append(line)
                continue
            break
    if not values:
        raise RuntimeError(f"missing library field {field} in {cabal_files[0]}")
    return frozenset(
        token
        for value in values
        for token in value.replace(",", " ").split()
    )


def check_core_package_inventory(package: Path) -> None:
    actual_sources = frozenset(
        source.relative_to(package).as_posix()
        for source in (package / "src").rglob("*.hs")
    )
    if actual_sources != CORE_SOURCE_FILES:
        missing = sorted(CORE_SOURCE_FILES - actual_sources)
        unexpected = sorted(actual_sources - CORE_SOURCE_FILES)
        raise RuntimeError(
            "o2i-core source inventory differs: "
            f"missing={missing}, unexpected={unexpected}"
        )
    exposed = cabal_library_field(package, "exposed-modules")
    if exposed != CORE_EXPOSED_MODULES:
        missing = sorted(CORE_EXPOSED_MODULES - exposed)
        unexpected = sorted(exposed - CORE_EXPOSED_MODULES)
        raise RuntimeError(
            "o2i-core exposed-module inventory differs: "
            f"missing={missing}, unexpected={unexpected}"
        )
def private_compiler_command(
    project_dir: Path,
    project_file: str | None,
    build_dir: Path,
    source: Path,
    source_dir: Path,
    output_dir: Path,
) -> list[str]:
    command = [
        "cabal",
        "-v0",
        f"--project-dir={project_dir}",
    ]
    if project_file is not None:
        command.append(f"--project-file={project_file}")
    return command + [
        f"--builddir={build_dir}", "exec",
        "--",
        "ghc",
        "-v0",
        "-fno-code",
        "-fforce-recomp",
        "-fmax-errors=1000",
        "-fdiagnostics-as-json",
        f"-i{source_dir}",
        f"-odir={output_dir}",
        f"-hidir={output_dir}",
        f"-stubdir={output_dir}",
        str(source),
    ]


def compile_source(
    root: Path,
    project_dir: Path,
    project_file: str | None,
    build_dir: Path,
    package: str,
    source_name: str,
) -> subprocess.CompletedProcess[str]:
    source = (root / source_name).resolve()
    with tempfile.TemporaryDirectory(prefix="o2i-api-contract.") as temporary:
        command = compiler_command(
            project_dir,
            project_file,
            build_dir,
            package,
            source,
            Path(temporary),
        )
        return subprocess.run(
            command,
            cwd=root,
            capture_output=True,
            text=True,
            check=False,
        )


def check_evidence_record_update_inventory() -> None:
    domain_counts = Counter(
        contract.module for contract in EVIDENCE_RECORD_UPDATES
    )
    expected_domains = Counter(
        {"O2I.Structure": 12, "O2I.Semantics.Input": 19}
    )
    identities = {
        (contract.module, contract.evidence_type, contract.projection)
        for contract in EVIDENCE_RECORD_UPDATES
    }
    if len(EVIDENCE_RECORD_UPDATES) != 31:
        raise RuntimeError(
            "Evidence record-update inventory must contain exactly 31 cases"
        )
    if domain_counts != expected_domains:
        raise RuntimeError(
            "Evidence record-update domains differ: "
            f"expected {expected_domains}, found {domain_counts}"
        )
    if len(identities) != len(EVIDENCE_RECORD_UPDATES):
        raise RuntimeError("Evidence record-update inventory contains duplicates")


def check_evidence_record_updates(
    root: Path,
    project_dir: Path,
    project_file: str | None,
    build_dir: Path,
) -> None:
    check_evidence_record_update_inventory()
    executed = 0
    for ordinal, contract in enumerate(EVIDENCE_RECORD_UPDATES, start=1):
        with tempfile.TemporaryDirectory(
            prefix=f"o2i-evidence-update-{ordinal:02d}."
        ) as temporary:
            temporary_path = Path(temporary)
            source = temporary_path / "EvidenceRecordUpdateCase.hs"
            source.write_text(
                "module EvidenceRecordUpdateCase where\n\n"
                f"import {contract.module}\n\n"
                f"forge :: {contract.evidence_type} "
                f"-> {contract.evidence_type}\n"
                "forge evidence =\n"
                f"  evidence {{{contract.projection} = undefined}}\n"
            )
            result = subprocess.run(
                compiler_command(
                    project_dir,
                    project_file,
                    build_dir,
                    "o2i-core",
                    source,
                    temporary_path,
                ),
                cwd=root,
                capture_output=True,
                text=True,
                check=False,
            )
            assert_compile_failure_at(
                root,
                source,
                f"Evidence record update {ordinal:02d} "
                f"({contract.evidence_type})",
                (("GHC-22385", 1),),
                result,
            )
            executed += 1
    if executed != 31:
        raise RuntimeError(
            f"Evidence record-update execution count differs: {executed}"
        )


def compile_private_source(
    root: Path,
    project_dir: Path,
    project_file: str | None,
    build_dir: Path,
    source_name: str,
) -> subprocess.CompletedProcess[str]:
    source = (root / source_name).resolve()
    source_dir = (root / "spc/lib/core/src").resolve()
    with tempfile.TemporaryDirectory(
        prefix="o2i-private-contract."
    ) as temporary:
        command = private_compiler_command(
            project_dir,
            project_file,
            build_dir,
            source,
            source_dir,
            Path(temporary),
        )
        return subprocess.run(
            command,
            cwd=root,
            capture_output=True,
            text=True,
            check=False,
        )


def combined_output(result: subprocess.CompletedProcess[str]) -> str:
    return result.stdout + result.stderr


def check_compile_pass(
    root: Path,
    project_dir: Path,
    project_file: str | None,
    build_dir: Path,
    contract: PackageContract,
) -> None:
    for source_name in contract.compile_passes:
        result = compile_source(
            root,
            project_dir,
            project_file,
            build_dir,
            contract.package,
            source_name,
        )
        if result.returncode != 0:
            raise RuntimeError(
                f"{source_name} external client control failed:\n"
                + combined_output(result)
            )


def check_compile_failure(
    root: Path,
    project_dir: Path,
    project_file: str | None,
    build_dir: Path,
    package: str,
    failure: CompileFailure,
) -> None:
    result = compile_source(
        root, project_dir, project_file, build_dir, package, failure.source
    )
    assert_compile_failure(
        root, failure.source, failure.diagnostics, result
    )


def check_private_compile_failure(
    root: Path,
    project_dir: Path,
    project_file: str | None,
    build_dir: Path,
    failure: PrivateCompileFailure,
) -> None:
    result = compile_private_source(
        root, project_dir, project_file, build_dir, failure.source
    )
    assert_compile_failure(
        root, failure.source, failure.diagnostics, result
    )


def assert_compile_failure(
    root: Path,
    source_name: str,
    expected_diagnostics: tuple[tuple[str, int], ...],
    result: subprocess.CompletedProcess[str],
) -> None:
    source = (root / source_name).resolve()
    assert_compile_failure_at(
        root, source, source_name, expected_diagnostics, result
    )


def assert_compile_failure_at(
    root: Path,
    source: Path,
    display_name: str,
    expected_diagnostics: tuple[tuple[str, int], ...],
    result: subprocess.CompletedProcess[str],
) -> None:
    output = combined_output(result)
    if result.returncode == 0:
        raise RuntimeError(f"{display_name} unexpectedly compiled")

    diagnostics = parse_diagnostics(output)
    source = source.resolve()
    foreign = [
        diagnostic
        for diagnostic in diagnostics
        if diagnostic_file(root, diagnostic) != source
    ]
    if foreign:
        raise RuntimeError(
            f"{display_name} produced non-local diagnostics:\n{output}"
        )

    actual = Counter(
        code for diagnostic in diagnostics if (code := error_code(diagnostic))
    )
    expected = Counter(dict(expected_diagnostics))
    if actual != expected:
        raise RuntimeError(
            f"{display_name} diagnostics differ: expected {expected}, "
            f"found {actual}\n{output}"
        )


def check_contracts(
    root: Path,
    project_dir: Path,
    build_dir: Path,
    packages: frozenset[str] | None = None,
    project_file: str | None = None,
) -> None:
    selected = tuple(
        contract
        for contract in CONTRACTS
        if packages is None or contract.package in packages
    )
    if packages is not None:
        known = {contract.package for contract in CONTRACTS}
        unknown = packages - known
        if unknown:
            raise ValueError(
                "unknown API-contract packages: " + ", ".join(sorted(unknown))
            )

    core_selected = packages is None or "o2i-core" in packages
    if core_selected:
        check_core_package_inventory(root / "spc/lib/core")
    for contract in selected:
        check_compile_pass(
            root, project_dir, project_file, build_dir, contract
        )
        for failure in contract.compile_failures:
            check_compile_failure(
                root,
                project_dir,
                project_file,
                build_dir,
                contract.package,
                failure,
            )
    if core_selected:
        check_evidence_record_updates(
            root, project_dir, project_file, build_dir
        )
        for failure in PRIVATE_COMPILE_FAILURES:
            check_private_compile_failure(
                root,
                project_dir,
                project_file,
                build_dir,
                failure,
            )


def parse_args(arguments: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check public and private Haskell compile contracts."
    )
    parser.add_argument("--project-dir", type=Path)
    parser.add_argument("--builddir", type=Path)
    parser.add_argument(
        "--project-file",
        help="Cabal project file name relative to --project-dir.",
    )
    parser.add_argument(
        "--package",
        action="append",
        dest="packages",
        help="Limit checks to one package; repeat for multiple packages.",
    )
    parser.add_argument(
        "--core-package-root",
        type=Path,
        help="Check only the exact o2i-core package inventory at this path.",
    )
    return parser.parse_args(arguments)


def main(arguments: Iterable[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if arguments is None else arguments)
    root = Path(__file__).resolve().parents[2]
    try:
        if args.core_package_root is not None:
            check_core_package_inventory(args.core_package_root.resolve())
            print("[o2i|info] o2i-core package inventory passed.")
            return 0
        if args.project_dir is None or args.builddir is None:
            raise ValueError(
                "--project-dir and --builddir are required for compile checks"
            )
        check_contracts(
            root,
            args.project_dir.resolve(),
            args.builddir.resolve(),
            frozenset(args.packages) if args.packages else None,
            args.project_file,
        )
    except (OSError, RuntimeError, ValueError) as error:
        print(f"[o2i|error] {error}", file=sys.stderr)
        return 1
    print("[o2i|info] Haskell compile contracts passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
