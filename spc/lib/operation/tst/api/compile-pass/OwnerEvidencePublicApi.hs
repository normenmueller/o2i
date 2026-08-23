module OwnerEvidencePublicApi where

import O2I.ArchiMate.Profile.Closure
import O2I.ArchiMate.Profile.Projection
import O2I.Operation.Acquisition
import O2I.Operation.Diagnostic
import O2I.Operation.Diagnostic.Owner
import O2I.Operation.Diagnostic.Owner.Source
import O2I.Semantics
import O2I.Structure

profileActivation ::
     PreparedAuthority authority profile document
  -> ProfileAssessmentUniverse profile document
  -> [PreparedDiagnostic authority profile document]
profileActivation = profileActivationDiagnostics

profileAssessment ::
     PreparedAuthority authority profile document
  -> ProfileProjectionAssessment profile document
  -> [PreparedDiagnostic authority profile document]
profileAssessment authority assessment =
  foldProfileAssessmentDiagnostics (const []) id authority assessment

structureEvidence ::
     PreparedScope authority profile document scope
  -> StructureEvidence scope
  -> PreparedDiagnostic authority profile document
structureEvidence = structureEvidenceDiagnostic

consumeBinding ::
     WellFormedGraph scope
  -> SupplementalOwnerBinding authority profile document scope inputs
  -> ( [SupplementalDiagnosticGroup authority profile document]
     , SemanticAssessment scope)
consumeBinding graph binding =
  foldSupplementalOwnerBinding
    (\_ bound _ ->
       (bindingDiagnosticGroups binding, assessOwnerSemantics graph bound))
    binding

bindAcquired ::
     PreparedScope authority profile document scope
  -> [AcquiredSupplementalSource]
  -> WellFormedGraph scope
  -> Maybe [SupplementalDiagnosticGroup authority profile document]
bindAcquired scope sources graph =
  withSupplementalOwnerBinding
    scope
    sources
    graph
    (const Nothing)
    (const Nothing)
    (Just . fst . consumeBinding graph)

admitSupplemental :: AcquiredSource -> Maybe AcquiredSupplementalSource
admitSupplemental = acquiredSupplementalSource

consumeSupplemental :: AcquiredSupplementalSource -> AcquiredSource
consumeSupplemental = foldAcquiredSupplementalSource id

semanticEvidence ::
     PreparedScope authority profile document scope
  -> SemanticDiagnosticEvidence scope
  -> PreparedDiagnostic authority profile document
semanticEvidence = semanticsEvidenceDiagnostic
