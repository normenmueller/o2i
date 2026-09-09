module OwnerEvidencePublicApi where

import O2I.ArchiMate.Profile.Closure
import O2I.ArchiMate.Profile.Notation
import O2I.ArchiMate.Profile.Projection
import O2I.Operation.Acquisition
import O2I.Operation.Adapter
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

notationAssessment ::
     PreparedAuthority authority profile document
  -> CompiledAdapterContract
  -> NotationResult profile document
  -> Either
       AdapterNotationResolutionFailure
       [PreparedDiagnostic authority profile document]
notationAssessment authority contract =
  foldNotationAssessmentDiagnostics Left Right authority contract

notationEvidence ::
     PreparedDiagnostic authority profile document
  -> Maybe ArchiMateNotationIssue
notationEvidence =
  foldPreparedDiagnostic
    (foldAdapterNotationDiagnostic (\_ _ issue -> Just issue))
    (const Nothing)
    (const Nothing)
    (const Nothing)
    (const Nothing)
    (const Nothing)
    (const Nothing)
    (const Nothing)

structureEvidence ::
     PreparedScope authority profile document scope
  -> StructureEvidence scope
  -> PreparedDiagnostic authority profile document
structureEvidence = structureEvidenceDiagnostic

consumeBinding ::
     WellFormedGraph scope
  -> SupplementalOwnerBinding authority profile document scope inputs
  -> ( SupplementalDiagnosticGroups authority profile document
     , SemanticAssessment scope)
consumeBinding graph binding =
  foldSupplementalOwnerBinding
    (\bound _ ->
       (bindingDiagnosticGroups binding, assessOwnerSemantics graph bound))
    binding

bindAcquired ::
     PreparedAuthority authority profile document
  -> PreparedScope authority profile document scope
  -> [AcquiredSupplementalSource]
  -> WellFormedGraph scope
  -> Maybe (SupplementalDiagnosticGroups authority profile document)
bindAcquired authority scope sources graph =
  withAdmittedOwnerSupplementalInputs
    authority
    sources
    (const Nothing)
    (const Nothing)
    (\admitted ->
       withBoundAdmittedOwnerSupplementalInputs
         scope
         graph
         admitted
         (Just . fst . consumeBinding graph))

admitSupplemental :: AcquiredSource -> Maybe AcquiredSupplementalSource
admitSupplemental = acquiredSupplementalSource

consumeSupplemental :: AcquiredSupplementalSource -> AcquiredSource
consumeSupplemental = foldAcquiredSupplementalSource id

semanticEvidence ::
     PreparedScope authority profile document scope
  -> SemanticDiagnosticEvidence scope
  -> PreparedDiagnostic authority profile document
semanticEvidence = semanticsEvidenceDiagnostic
