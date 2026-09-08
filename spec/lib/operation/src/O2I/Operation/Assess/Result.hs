{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

-- | Closed terminal selected-View evidence-assessment results.
module O2I.Operation.Assess.Result
  ( type AssessExitClass
  , assessSuccessExit
  , assessPrimaryNegativeExit
  , assessOperationalFailureExit
  , assessSubjectUnavailableExit
  , assessExitClassText
  , assessExitCode
  , foldAssessExitClass
  , type AssessPrerequisite
  , notationAssessPrerequisite
  , profileAssessPrerequisite
  , structureAssessPrerequisite
  , semanticsAssessPrerequisite
  , assessPrerequisiteText
  , foldAssessPrerequisite
  , type AssessInternalFailure
  , foldAssessInternalFailure
  , type AssessFailure
  , foldAssessFailure
  , type AssessUnavailable
  , foldAssessUnavailable
  , type PreparedAssess
  , preparedAssessRequest
  , preparedAssessDiagnostics
  , foldPreparedAssess
  , type AssessResult
  , assessResultExitClass
  , foldAssessResult
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.ArchiMate.Profile.Projection (ProfileContractEvidence)
import O2I.Assessment
  ( AssessmentInputDefect
  , AssessmentResult
  , AssessmentSubjectUnavailableReason
  )
import O2I.Core.Identity
  ( IdentityIndexDefect
  , ModelIdentity
  , OccurrenceIdentity
  , SelectedViewScopeDefect
  )
import O2I.Operation.Acquisition
  ( AcquiredAssessmentSource
  , AcquiredSupplementalSource
  )
import O2I.Operation.Adapter (AdapterDescriptor)
import O2I.Operation.Assess.Request (AssessRequest)
import O2I.Operation.Assess.Result.Internal
import O2I.Operation.Diagnostic (PreparedDiagnosticDocument)
import O2I.Operation.Diagnostic.Owner (AdapterNotationResolutionFailure)
import O2I.Operation.Failure (CommonFailure)
import O2I.Operation.Provenance (SourceIdentity, SupplementalProvenanceDefect)
import O2I.Operation.View (SelectedView)
import O2I.Semantics.Input (SupplementalInputDefect)
import O2I.Structure (StructureInputDefect)
import O2I.Trace (TraceIdentity)

-- | Successful assessment with every submitted observation assessed.
assessSuccessExit :: AssessExitClass
assessSuccessExit = AssessExitSuccess

-- | Primary negative result caused by invalid collection or item evidence.
assessPrimaryNegativeExit :: AssessExitClass
assessPrimaryNegativeExit = AssessExitPrimaryNegative

-- | Operational failure before a machine assessment result exists.
assessOperationalFailureExit :: AssessExitClass
assessOperationalFailureExit = AssessExitOperationalFailure

-- | Domain assessment could not start because its subject was unavailable.
assessSubjectUnavailableExit :: AssessExitClass
assessSubjectUnavailableExit = AssessExitSubjectUnavailable

-- | Stable machine token for one report class.
assessExitClassText :: AssessExitClass -> Text
assessExitClassText classification =
  case classification of
    AssessExitSuccess -> "success"
    AssessExitPrimaryNegative -> "primary-negative"
    AssessExitOperationalFailure -> "operational-failure"
    AssessExitSubjectUnavailable -> "subject-unavailable"

-- | Stable process code reserved for the future thin CLI composition.
assessExitCode :: AssessExitClass -> Natural
assessExitCode classification =
  case classification of
    AssessExitSuccess -> 0
    AssessExitPrimaryNegative -> 1
    AssessExitOperationalFailure -> 2
    AssessExitSubjectUnavailable -> 3

-- | Eliminate one closed assessment exit class.
foldAssessExitClass ::
     result -> result -> result -> result -> AssessExitClass -> result
foldAssessExitClass success negative operational unavailable classification =
  case classification of
    AssessExitSuccess -> success
    AssessExitPrimaryNegative -> negative
    AssessExitOperationalFailure -> operational
    AssessExitSubjectUnavailable -> unavailable

-- | Notation prevented preparation of the assessment subject.
notationAssessPrerequisite :: AssessPrerequisite
notationAssessPrerequisite = AssessNotationPrerequisite

-- | Profile resolution prevented preparation of the assessment subject.
profileAssessPrerequisite :: AssessPrerequisite
profileAssessPrerequisite = AssessProfilePrerequisite

-- | Structure prevented preparation of the assessment subject.
structureAssessPrerequisite :: AssessPrerequisite
structureAssessPrerequisite = AssessStructurePrerequisite

-- | Semantics prevented preparation of the assessment subject.
semanticsAssessPrerequisite :: AssessPrerequisite
semanticsAssessPrerequisite = AssessSemanticsPrerequisite

-- | Stable machine token for one rejected prerequisite.
assessPrerequisiteText :: AssessPrerequisite -> Text
assessPrerequisiteText prerequisite =
  case prerequisite of
    AssessNotationPrerequisite -> "notation"
    AssessProfilePrerequisite -> "profile"
    AssessStructurePrerequisite -> "structure"
    AssessSemanticsPrerequisite -> "semantics"

-- | Eliminate one closed rejected prerequisite.
foldAssessPrerequisite ::
     result -> result -> result -> result -> AssessPrerequisite -> result
foldAssessPrerequisite notation profile structure semantics prerequisite =
  case prerequisite of
    AssessNotationPrerequisite -> notation
    AssessProfilePrerequisite -> profile
    AssessStructurePrerequisite -> structure
    AssessSemanticsPrerequisite -> semantics

-- | Eliminate one package-internal owner-contract failure.
foldAssessInternalFailure ::
     (SourceIdentity -> result)
  -> (SourceIdentity -> result)
  -> (SourceIdentity -> result)
  -> (AdapterDescriptor -> result)
  -> (AdapterNotationResolutionFailure -> result)
  -> (forall profile document. NonEmpty
                                 (ProfileContractEvidence profile document) -> result)
  -> (NonEmpty IdentityIndexDefect -> result)
  -> (NonEmpty SelectedViewScopeDefect -> result)
  -> (NonEmpty StructureInputDefect -> result)
  -> (NonEmpty SupplementalProvenanceDefect -> result)
  -> ([OccurrenceIdentity] -> result)
  -> AssessInternalFailure
  -> result
foldAssessInternalFailure model bundle supplemental adapter notation profile identity scope structure provenance semantic failure =
  case failure of
    AssessAcquiredModelRoleFailure value -> model value
    AssessAcquiredBundleRoleFailure value -> bundle value
    AssessAcquiredSupplementalRoleFailure value -> supplemental value
    AssessSelectedAdapterContractFailure value -> adapter value
    AssessNotationContractFailure value -> notation value
    AssessProfileContractFailure value -> profile value
    AssessIdentityIndexFailure value -> identity value
    AssessSelectedViewScopeFailure value -> scope value
    AssessStructureInputFailure value -> structure value
    AssessSupplementalProvenanceFailure value -> provenance value
    AssessSemanticModelContractFailure value -> semantic value

-- | Eliminate one terminal assessment operation failure.
foldAssessFailure ::
     (CommonFailure -> result)
  -> (NonEmpty AssessmentInputDefect -> result)
  -> (NonEmpty SupplementalInputDefect -> result)
  -> (AssessInternalFailure -> result)
  -> AssessFailure
  -> result
foldAssessFailure common bundle supplemental internal failure =
  case failure of
    AssessCommonFailure value -> common value
    AssessBundleInputFailure value -> bundle value
    AssessSupplementalInputFailure value -> supplemental value
    AssessOwnerContractFailure value -> internal value

-- | Eliminate one assessment-subject unavailability branch.
foldAssessUnavailable ::
     (TraceIdentity -> NonEmpty AssessmentInputDefect -> result)
  -> (ModelIdentity -> TraceIdentity -> NonEmpty
                                          AssessmentSubjectUnavailableReason -> result)
  -> AssessUnavailable
  -> result
foldAssessUnavailable binding reconstruction unavailable =
  case unavailable of
    AssessInputBindingUnavailable trace defects -> binding trace defects
    AssessReconstructionUnavailable graph trace reasons ->
      reconstruction graph trace reasons

-- | Project the exact request retained by a prepared assessment.
preparedAssessRequest :: PreparedAssess -> AssessRequest
preparedAssessRequest prepared =
  foldPreparedAssess (\request _ _ _ _ -> request) prepared

-- | Project the complete prepared diagnostic document.
preparedAssessDiagnostics :: PreparedAssess -> PreparedDiagnosticDocument
preparedAssessDiagnostics prepared =
  foldPreparedAssess (\_ _ _ _ diagnostics -> diagnostics) prepared

-- | Eliminate a prepared assessment without exposing its constructor.
foldPreparedAssess ::
     (forall document. AssessRequest -> SelectedView document -> Maybe
                                                                   AcquiredAssessmentSource -> [AcquiredSupplementalSource] -> PreparedDiagnosticDocument -> result)
  -> PreparedAssess
  -> result
foldPreparedAssess consume prepared =
  case prepared of
    PreparedAssess request view bundle supplements diagnostics ->
      consume request view bundle supplements diagnostics

-- | Classify every terminal result for future thin CLI composition.
assessResultExitClass :: AssessResult -> AssessExitClass
assessResultExitClass result =
  case result of
    AssessFailed _ -> AssessExitOperationalFailure
    AssessPrerequisiteRejectedResult _ _ -> AssessExitSubjectUnavailable
    AssessSubjectUnavailableResult _ _ -> AssessExitSubjectUnavailable
    AssessCollectionInvalidResult _ _ -> AssessExitPrimaryNegative
    AssessObservationsInvalidResult _ _ -> AssessExitPrimaryNegative
    AssessCompletedResult _ _ -> AssessExitSuccess

-- | Eliminate every closed terminal assessment result branch.
foldAssessResult ::
     (AssessFailure -> result)
  -> (AssessPrerequisite -> PreparedAssess -> result)
  -> (AssessUnavailable -> PreparedAssess -> result)
  -> (forall scope. AssessmentResult scope -> PreparedAssess -> result)
  -> (forall scope. AssessmentResult scope -> PreparedAssess -> result)
  -> (forall scope. AssessmentResult scope -> PreparedAssess -> result)
  -> AssessResult
  -> result
foldAssessResult failed prerequisite unavailable collection invalid completed result =
  case result of
    AssessFailed failure -> failed failure
    AssessPrerequisiteRejectedResult stage prepared ->
      prerequisite stage prepared
    AssessSubjectUnavailableResult reason prepared ->
      unavailable reason prepared
    AssessCollectionInvalidResult assessment prepared ->
      collection assessment prepared
    AssessObservationsInvalidResult assessment prepared ->
      invalid assessment prepared
    AssessCompletedResult assessment prepared -> completed assessment prepared
