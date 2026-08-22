module OwnerEvidencePublicApi where

import O2I.ArchiMate.Profile.Closure
import O2I.ArchiMate.Profile.Projection
import O2I.ArchiMate.Profile.Resolution
import O2I.Core.Identity
import O2I.Operation.Diagnostic
import O2I.Operation.Diagnostic.Owner
import O2I.Operation.Provenance
import O2I.Semantics
import O2I.Semantics.Input
import O2I.Structure

profileActivation ::
     SourceIdentity
  -> SelectedArchiMateProfile profile
  -> ProfileAssessmentUniverse profile document
  -> [Diagnostic]
profileActivation = profileActivationDiagnostics

profileAssessment ::
     SourceIdentity
  -> SelectedArchiMateProfile profile
  -> ProfileAssessmentUniverse profile document
  -> ProfileProjectionAssessment profile document
  -> [Diagnostic]
profileAssessment source selected universe assessment =
  foldProfileAssessmentDiagnostics
    (const [])
    id
    source
    selected
    universe
    assessment

structureEvidence ::
     SourceIdentity
  -> SelectedViewScope scope
  -> StructureEvidence scope
  -> Diagnostic
structureEvidence = structureEvidenceDiagnostic

bindingEvidence ::
     SourceIdentity
  -> SupplementalBinding scope
  -> SupplementalBindingEvidence scope
  -> Diagnostic
bindingEvidence = bindingEvidenceDiagnostic

semanticEvidence ::
     SourceIdentity
  -> SemanticAssessment scope
  -> SemanticDiagnosticEvidence scope
  -> SemanticEvidenceConversion
semanticEvidence = semanticsEvidenceDiagnostic

consumeSemanticConversion :: SemanticEvidenceConversion -> Maybe Diagnostic
consumeSemanticConversion = foldSemanticEvidenceConversion Nothing Just
