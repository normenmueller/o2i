module OwnerCoreCrossGeneration where

import O2I.Core.Identity
import O2I.Operation.Diagnostic
import O2I.Operation.Diagnostic.Owner
import O2I.Operation.Provenance
import O2I.Semantics
import O2I.Semantics.Input
import O2I.Structure

crossStructure ::
     SourceIdentity
  -> SelectedViewScope firstScope
  -> StructureEvidence secondScope
  -> Diagnostic
crossStructure = structureEvidenceDiagnostic

crossBinding ::
     SourceIdentity
  -> SupplementalBinding firstScope
  -> SupplementalBindingEvidence secondScope
  -> Diagnostic
crossBinding = bindingEvidenceDiagnostic

crossSemantics ::
     SourceIdentity
  -> SemanticAssessment firstScope
  -> SemanticDiagnosticEvidence secondScope
  -> SemanticEvidenceConversion
crossSemantics = semanticsEvidenceDiagnostic
