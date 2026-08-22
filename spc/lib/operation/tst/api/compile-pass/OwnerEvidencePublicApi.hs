module OwnerEvidencePublicApi where

import O2I.ArchiMate.Profile.Closure
import O2I.ArchiMate.Profile.Projection
import O2I.ArchiMate.Profile.Resolution
import O2I.Core.Identity
import O2I.Operation.Acquisition
import O2I.Operation.Diagnostic
import O2I.Operation.Diagnostic.Owner
import O2I.Operation.Diagnostic.Owner.Source
import O2I.Semantics
import O2I.Structure

profileActivation ::
     ModelOwnerSource document
  -> SelectedArchiMateProfile profile
  -> ProfileAssessmentUniverse profile document
  -> [Diagnostic]
profileActivation = profileActivationDiagnostics

profileAssessment ::
     ModelOwnerSource document
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
     ScopedModelOwnerSource scope -> StructureEvidence scope -> Diagnostic
structureEvidence = structureEvidenceDiagnostic

bindingEvidence ::
     SupplementalOwnerBinding scope inputs
  -> SupplementalOwnerBindingEvidence scope inputs
  -> Diagnostic
bindingEvidence = bindingEvidenceDiagnostic

consumeBinding ::
     WellFormedGraph scope
  -> SupplementalOwnerBinding scope inputs
  -> ([Diagnostic], SemanticAssessment scope)
consumeBinding graph binding =
  foldSupplementalOwnerBinding
    (\bound evidence ->
       ( map (bindingEvidenceDiagnostic binding) evidence
       , assessOwnerSemantics graph bound))
    binding

bindAcquired :: [AcquiredSource] -> WellFormedGraph scope -> Maybe [Diagnostic]
bindAcquired sources graph =
  withSupplementalOwnerBinding
    sources
    graph
    (const Nothing)
    (const Nothing)
    (Just . fst . consumeBinding graph)

admitModel :: AcquiredSource -> Maybe AcquiredModelSource
admitModel = acquiredModelSource

semanticEvidence ::
     ScopedModelOwnerSource scope
  -> SemanticAssessment scope
  -> SemanticDiagnosticEvidence scope
  -> SemanticEvidenceConversion
semanticEvidence = semanticsEvidenceDiagnostic

consumeSemanticConversion :: SemanticEvidenceConversion -> Maybe Diagnostic
consumeSemanticConversion = foldSemanticEvidenceConversion Nothing Just
