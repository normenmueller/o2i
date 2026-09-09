module OwnerCoreCrossGeneration where

import O2I.Operation.Diagnostic
import O2I.Operation.Diagnostic.Owner
import O2I.Operation.Diagnostic.Owner.Source
import O2I.Semantics
import O2I.Structure

crossStructure ::
     PreparedScope authority profile document firstScope
  -> StructureEvidence secondScope
  -> PreparedDiagnostic authority profile document
crossStructure = structureEvidenceDiagnostic

crossSemantics ::
     PreparedScope authority profile document firstScope
  -> SemanticDiagnosticEvidence secondScope
  -> PreparedDiagnostic authority profile document
crossSemantics = semanticsEvidenceDiagnostic
