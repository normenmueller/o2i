module OwnerCoreCrossGeneration where

import O2I.Core.Identity
import O2I.Operation.Diagnostic
import O2I.Operation.Diagnostic.Owner
import O2I.Operation.Diagnostic.Owner.Source
import O2I.Semantics
import O2I.Structure

crossStructure ::
     ScopedModelOwnerSource firstScope
  -> StructureEvidence secondScope
  -> Diagnostic
crossStructure = structureEvidenceDiagnostic

crossBinding ::
     SupplementalOwnerBinding firstScope inputs
  -> SupplementalOwnerBindingEvidence secondScope inputs
  -> Diagnostic
crossBinding = bindingEvidenceDiagnostic

crossSemantics ::
     ScopedModelOwnerSource firstScope
  -> SemanticAssessment firstScope
  -> SemanticDiagnosticEvidence secondScope
  -> SemanticEvidenceConversion
crossSemantics = semanticsEvidenceDiagnostic
