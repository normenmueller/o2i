module CoreOwnerEvidenceCoercible where

import Data.Coerce (coerce)
import O2I.Semantics (SemanticAssessment, SemanticDiagnosticEvidence)
import O2I.Semantics.Input (SupplementalBinding, SupplementalBindingEvidence)
import O2I.Structure (StructureAssessment, StructureEvidence)

coerceStructureEvidence ::
     StructureEvidence firstScope -> StructureEvidence secondScope
coerceStructureEvidence = coerce

coerceStructureAssessment ::
     StructureAssessment firstScope -> StructureAssessment secondScope
coerceStructureAssessment = coerce

coerceSupplementalBinding ::
     SupplementalBinding firstScope provenance
  -> SupplementalBinding secondScope provenance
coerceSupplementalBinding = coerce

coerceSupplementalBindingEvidence ::
     SupplementalBindingEvidence firstScope provenance
  -> SupplementalBindingEvidence secondScope provenance
coerceSupplementalBindingEvidence = coerce

coerceSemanticAssessment ::
     SemanticAssessment firstScope -> SemanticAssessment secondScope
coerceSemanticAssessment = coerce

coerceSemanticDiagnosticEvidence ::
     SemanticDiagnosticEvidence firstScope
  -> SemanticDiagnosticEvidence secondScope
coerceSemanticDiagnosticEvidence = coerce
