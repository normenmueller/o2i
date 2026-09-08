{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

-- | Closed terminal Qualify results.
--
-- A completed result is a formal assessment only. It carries no acceptance,
-- persistence, prioritization, mutation, or post-acceptance query operation.
module O2I.Operation.Qualify.Result
  ( type QualifyPrerequisite
  , notationQualifyPrerequisite
  , profileQualifyPrerequisite
  , structureQualifyPrerequisite
  , qualifyPrerequisiteText
  , foldQualifyPrerequisite
  , type QualifyInternalFailure
  , foldQualifyInternalFailure
  , type QualifyFailure
  , foldQualifyFailure
  , type PreparedQualify
  , preparedQualifyRequest
  , preparedQualifyDiagnostics
  , foldPreparedQualify
  , type QualifyResult
  , foldQualifyResult
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import O2I.ArchiMate.Profile.Projection (ProfileContractEvidence)
import O2I.Core.Identity (IdentityIndexDefect, SelectedViewScopeDefect)
import O2I.Operation.Acquisition (AcquiredSupplementalSource)
import O2I.Operation.Adapter (AdapterDescriptor)
import O2I.Operation.Diagnostic (PreparedDiagnosticDocument)
import O2I.Operation.Diagnostic.Owner (AdapterNotationResolutionFailure)
import O2I.Operation.Failure (CommonFailure)
import O2I.Operation.Provenance (SourceIdentity, SupplementalProvenanceDefect)
import O2I.Operation.Qualify.Request (QualifyRequest)
import O2I.Operation.Qualify.Result.Internal
import O2I.Operation.View (SelectedView)
import O2I.Qualification (QualificationAssessment, QualificationContextError)
import O2I.Semantics.Input (SupplementalInputDefect)
import O2I.Structure (StructureInputDefect)

-- | Notation is the earliest public Qualify prerequisite.
notationQualifyPrerequisite :: QualifyPrerequisite
notationQualifyPrerequisite = QualifyNotationPrerequisite

-- | Profile conformance prevented Qualify preparation.
profileQualifyPrerequisite :: QualifyPrerequisite
profileQualifyPrerequisite = QualifyProfilePrerequisite

-- | Structure conformance prevented Core Qualification evaluation.
structureQualifyPrerequisite :: QualifyPrerequisite
structureQualifyPrerequisite = QualifyStructurePrerequisite

-- | Stable machine token for one rejected prerequisite stage.
qualifyPrerequisiteText :: QualifyPrerequisite -> Text
qualifyPrerequisiteText prerequisite =
  case prerequisite of
    QualifyNotationPrerequisite -> "notation"
    QualifyProfilePrerequisite -> "profile"
    QualifyStructurePrerequisite -> "structure"

-- | Consume the complete closed prerequisite vocabulary.
foldQualifyPrerequisite ::
     result -> result -> result -> QualifyPrerequisite -> result
foldQualifyPrerequisite notation profile structure prerequisite =
  case prerequisite of
    QualifyNotationPrerequisite -> notation
    QualifyProfilePrerequisite -> profile
    QualifyStructurePrerequisite -> structure

-- | Consume every impossible owner-contract failure.
foldQualifyInternalFailure ::
     (SourceIdentity -> result)
  -> (SourceIdentity -> result)
  -> (AdapterDescriptor -> result)
  -> (AdapterNotationResolutionFailure -> result)
  -> (forall profile document. NonEmpty
                                 (ProfileContractEvidence profile document) -> result)
  -> (NonEmpty IdentityIndexDefect -> result)
  -> (NonEmpty SelectedViewScopeDefect -> result)
  -> (NonEmpty StructureInputDefect -> result)
  -> (NonEmpty SupplementalProvenanceDefect -> result)
  -> (QualificationContextError -> result)
  -> QualifyInternalFailure
  -> result
foldQualifyInternalFailure model supplemental adapter notation profile identity scope structure provenance context failure =
  case failure of
    QualifyAcquiredModelRoleFailure value -> model value
    QualifyAcquiredSupplementalRoleFailure value -> supplemental value
    QualifySelectedAdapterContractFailure value -> adapter value
    QualifyNotationContractFailure value -> notation value
    QualifyProfileContractFailure value -> profile value
    QualifyIdentityIndexFailure value -> identity value
    QualifySelectedViewScopeFailure value -> scope value
    QualifyStructureInputFailure value -> structure value
    QualifySupplementalProvenanceFailure value -> provenance value
    QualifyContextFailure value -> context value

-- | Consume expected common/input failure or internal contract failure.
foldQualifyFailure ::
     (CommonFailure -> result)
  -> (NonEmpty SupplementalInputDefect -> result)
  -> (QualifyInternalFailure -> result)
  -> QualifyFailure
  -> result
foldQualifyFailure common supplemental internal failure =
  case failure of
    QualifyCommonFailure value -> common value
    QualifySupplementalInputFailure value -> supplemental value
    QualifyOwnerContractFailure value -> internal value

-- | Exact request retained by one prepared Qualify subject.
preparedQualifyRequest :: PreparedQualify -> QualifyRequest
preparedQualifyRequest prepared =
  foldPreparedQualify (\request _ _ _ -> request) prepared

-- | Authority-once shared diagnostic document.
preparedQualifyDiagnostics :: PreparedQualify -> PreparedDiagnosticDocument
preparedQualifyDiagnostics prepared =
  foldPreparedQualify (\_ _ _ diagnostics -> diagnostics) prepared

-- | Eliminate one prepared subject while preserving its selected-View witness.
foldPreparedQualify ::
     (forall document. QualifyRequest -> SelectedView document -> [AcquiredSupplementalSource] -> PreparedDiagnosticDocument -> result)
  -> PreparedQualify
  -> result
foldPreparedQualify consume prepared =
  case prepared of
    PreparedQualify request view supplements diagnostics ->
      consume request view supplements diagnostics

-- | Consume failure, prerequisite rejection, or completed assessment.
foldQualifyResult ::
     (QualifyFailure -> result)
  -> (QualifyPrerequisite -> PreparedQualify -> result)
  -> (forall scope. QualificationAssessment scope -> PreparedQualify -> result)
  -> QualifyResult
  -> result
foldQualifyResult failed prerequisite completed result =
  case result of
    QualifyFailed failure -> failed failure
    QualifyPrerequisiteRejectedResult stage prepared ->
      prerequisite stage prepared
    QualifyCompletedResult assessment prepared -> completed assessment prepared
