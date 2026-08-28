{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

-- | Closed terminal evidence-readiness results.
module O2I.Operation.Readiness.Result
  ( type ReadinessPrerequisite
  , notationReadinessPrerequisite
  , profileReadinessPrerequisite
  , structureReadinessPrerequisite
  , semanticsReadinessPrerequisite
  , readinessPrerequisiteText
  , foldReadinessPrerequisite
  , type ReadinessInternalFailure
  , foldReadinessInternalFailure
  , type ReadinessFailure
  , foldReadinessFailure
  , type ReadinessUnavailable
  , foldReadinessUnavailable
  , type PreparedReadiness
  , preparedReadinessRequest
  , preparedReadinessDiagnostics
  , foldPreparedReadiness
  , type ReadinessResult
  , foldReadinessResult
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import O2I.ArchiMate.Profile.Projection (ProfileContractEvidence)
import O2I.Core.Identity
  ( IdentityIndexDefect
  , ModelIdentity
  , OccurrenceIdentity
  , SelectedViewScopeDefect
  )
import O2I.Operation.Acquisition
  ( AcquiredReadinessSource
  , AcquiredSupplementalSource
  )
import O2I.Operation.Adapter (AdapterDescriptor)
import O2I.Operation.Diagnostic (PreparedDiagnosticDocument)
import O2I.Operation.Diagnostic.Owner (AdapterNotationResolutionFailure)
import O2I.Operation.Failure (CommonFailure)
import O2I.Operation.Provenance (SourceIdentity, SupplementalProvenanceDefect)
import O2I.Operation.Readiness.Request (ReadinessRequest)
import O2I.Operation.Readiness.Result.Internal
import O2I.Operation.View (SelectedView)
import O2I.Readiness
  ( EvidenceInputDefect
  , ReadinessAssessment
  , ReadinessSubjectUnavailableReason
  )
import O2I.Semantics.Input (SupplementalInputDefect)
import O2I.Structure (StructureInputDefect)
import O2I.Trace (TraceIdentity)

-- | Notation is the rejected prerequisite.
notationReadinessPrerequisite :: ReadinessPrerequisite
notationReadinessPrerequisite = ReadinessNotationPrerequisite

-- | Profile projection is the rejected prerequisite.
profileReadinessPrerequisite :: ReadinessPrerequisite
profileReadinessPrerequisite = ReadinessProfilePrerequisite

-- | Selected-View Structure is the rejected prerequisite.
structureReadinessPrerequisite :: ReadinessPrerequisite
structureReadinessPrerequisite = ReadinessStructurePrerequisite

-- | Model Semantics is the rejected prerequisite.
semanticsReadinessPrerequisite :: ReadinessPrerequisite
semanticsReadinessPrerequisite = ReadinessSemanticsPrerequisite

-- | Stable lowercase machine token for one prerequisite.
readinessPrerequisiteText :: ReadinessPrerequisite -> Text
readinessPrerequisiteText prerequisite =
  case prerequisite of
    ReadinessNotationPrerequisite -> "notation"
    ReadinessProfilePrerequisite -> "profile"
    ReadinessStructurePrerequisite -> "structure"
    ReadinessSemanticsPrerequisite -> "semantics"

-- | Eliminate every closed prerequisite without exposing constructors.
foldReadinessPrerequisite ::
     result -> result -> result -> result -> ReadinessPrerequisite -> result
foldReadinessPrerequisite notation profile structure semantics prerequisite =
  case prerequisite of
    ReadinessNotationPrerequisite -> notation
    ReadinessProfilePrerequisite -> profile
    ReadinessStructurePrerequisite -> structure
    ReadinessSemanticsPrerequisite -> semantics

-- | Eliminate every Operation-owner contract failure.
foldReadinessInternalFailure ::
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
  -> ReadinessInternalFailure
  -> result
foldReadinessInternalFailure model evidence supplemental adapter notation profile identity scope structure provenance semantic failure =
  case failure of
    ReadinessAcquiredModelRoleFailure value -> model value
    ReadinessAcquiredEvidenceRoleFailure value -> evidence value
    ReadinessAcquiredSupplementalRoleFailure value -> supplemental value
    ReadinessSelectedAdapterContractFailure value -> adapter value
    ReadinessNotationContractFailure value -> notation value
    ReadinessProfileContractFailure value -> profile value
    ReadinessIdentityIndexFailure value -> identity value
    ReadinessSelectedViewScopeFailure value -> scope value
    ReadinessStructureInputFailure value -> structure value
    ReadinessSupplementalProvenanceFailure value -> provenance value
    ReadinessSemanticModelContractFailure value -> semantic value

-- | Eliminate command, Readiness-input, supplemental-input, or owner failure.
foldReadinessFailure ::
     (CommonFailure -> result)
  -> (NonEmpty EvidenceInputDefect -> result)
  -> (NonEmpty SupplementalInputDefect -> result)
  -> (ReadinessInternalFailure -> result)
  -> ReadinessFailure
  -> result
foldReadinessFailure common evidence supplemental internal failure =
  case failure of
    ReadinessCommonFailure value -> common value
    ReadinessEvidenceInputFailure value -> evidence value
    ReadinessSupplementalInputFailure value -> supplemental value
    ReadinessOwnerContractFailure value -> internal value

-- | Eliminate input-binding and post-binding reconstruction unavailability.
foldReadinessUnavailable ::
     (TraceIdentity -> NonEmpty EvidenceInputDefect -> result)
  -> (ModelIdentity -> TraceIdentity -> NonEmpty
                                          ReadinessSubjectUnavailableReason -> result)
  -> ReadinessUnavailable
  -> result
foldReadinessUnavailable binding reconstruction unavailable =
  case unavailable of
    ReadinessInputBindingUnavailable trace defects -> binding trace defects
    ReadinessReconstructionUnavailable graph trace reasons ->
      reconstruction graph trace reasons

-- | Project the exact request retained by a prepared result.
preparedReadinessRequest :: PreparedReadiness -> ReadinessRequest
preparedReadinessRequest prepared =
  foldPreparedReadiness (\request _ _ _ _ -> request) prepared

-- | Project the complete prepared diagnostic document.
preparedReadinessDiagnostics :: PreparedReadiness -> PreparedDiagnosticDocument
preparedReadinessDiagnostics prepared =
  foldPreparedReadiness (\_ _ _ _ diagnostics -> diagnostics) prepared

-- | Consume the selected View, acquired sources, and prepared diagnostics.
foldPreparedReadiness ::
     (forall document. ReadinessRequest -> SelectedView document -> Maybe
                                                                      AcquiredReadinessSource -> [AcquiredSupplementalSource] -> PreparedDiagnosticDocument -> result)
  -> PreparedReadiness
  -> result
foldPreparedReadiness consume prepared =
  case prepared of
    PreparedReadiness request view evidence supplements diagnostics ->
      consume request view evidence supplements diagnostics

-- | Eliminate all five terminal Readiness result alternatives.
foldReadinessResult ::
     (ReadinessFailure -> result)
  -> (ReadinessPrerequisite -> PreparedReadiness -> result)
  -> (ReadinessUnavailable -> PreparedReadiness -> result)
  -> (forall scope. ReadinessAssessment scope -> PreparedReadiness -> result)
  -> (forall scope. ReadinessAssessment scope -> PreparedReadiness -> result)
  -> ReadinessResult
  -> result
foldReadinessResult failed prerequisite unavailable notReady ready result =
  case result of
    ReadinessFailed failure -> failed failure
    ReadinessPrerequisiteRejectedResult stage prepared ->
      prerequisite stage prepared
    ReadinessSubjectUnavailableResult reason prepared ->
      unavailable reason prepared
    ReadinessNotReadyResult assessment prepared -> notReady assessment prepared
    ReadinessReadyResult assessment prepared -> ready assessment prepared
