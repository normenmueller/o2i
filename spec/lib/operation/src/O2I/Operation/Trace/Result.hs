{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

-- | Closed terminal Trace results.
--
-- Expected pre-preparation failures remain disjoint from prepared prerequisite
-- rejection and completed Core Trace assessment.
module O2I.Operation.Trace.Result
  ( type TracePrerequisite
  , notationTracePrerequisite
  , profileTracePrerequisite
  , structureTracePrerequisite
  , semanticsTracePrerequisite
  , tracePrerequisiteText
  , foldTracePrerequisite
  , type TraceInternalFailure
  , foldTraceInternalFailure
  , type TraceFailure
  , foldTraceFailure
  , type PreparedTrace
  , preparedTraceRequest
  , preparedTraceDiagnostics
  , foldPreparedTrace
  , type TraceResult
  , foldTraceResult
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import O2I.ArchiMate.Profile.Projection (ProfileContractEvidence)
import O2I.Core.Identity
  ( IdentityIndexDefect
  , OccurrenceIdentity
  , SelectedViewScopeDefect
  )
import O2I.Operation.Adapter (AdapterDescriptor)
import O2I.Operation.Diagnostic (PreparedDiagnosticDocument)
import O2I.Operation.Diagnostic.Owner (AdapterNotationResolutionFailure)
import O2I.Operation.Failure (CommonFailure)
import O2I.Operation.Provenance (SourceIdentity, SupplementalProvenanceDefect)
import O2I.Operation.Trace.Request (TraceRequest)
import O2I.Operation.Trace.Result.Internal
import O2I.Operation.View (SelectedView)
import O2I.Semantics.Input (SupplementalInputDefect)
import O2I.Structure (StructureInputDefect)
import O2I.Trace (TraceAssessment)

-- | Closed prerequisite token for Notation rejection.
notationTracePrerequisite :: TracePrerequisite
notationTracePrerequisite = TraceNotationPrerequisite

-- | Closed prerequisite token for Profile rejection.
profileTracePrerequisite :: TracePrerequisite
profileTracePrerequisite = TraceProfilePrerequisite

-- | Closed prerequisite token for Structure rejection.
structureTracePrerequisite :: TracePrerequisite
structureTracePrerequisite = TraceStructurePrerequisite

-- | Closed prerequisite token for Semantics rejection.
semanticsTracePrerequisite :: TracePrerequisite
semanticsTracePrerequisite = TraceSemanticsPrerequisite

-- | Stable machine token for one rejected prerequisite stage.
tracePrerequisiteText :: TracePrerequisite -> Text
tracePrerequisiteText prerequisite =
  case prerequisite of
    TraceNotationPrerequisite -> "notation"
    TraceProfilePrerequisite -> "profile"
    TraceStructurePrerequisite -> "structure"
    TraceSemanticsPrerequisite -> "semantics"

-- | Consume the complete closed prerequisite vocabulary.
foldTracePrerequisite ::
     result -> result -> result -> result -> TracePrerequisite -> result
foldTracePrerequisite notation profile structure semantics prerequisite =
  case prerequisite of
    TraceNotationPrerequisite -> notation
    TraceProfilePrerequisite -> profile
    TraceStructurePrerequisite -> structure
    TraceSemanticsPrerequisite -> semantics

-- | Consume every impossible owner-contract failure without exposing its
-- representation.
foldTraceInternalFailure ::
     (SourceIdentity -> result)
  -> (AdapterDescriptor -> result)
  -> (AdapterNotationResolutionFailure -> result)
  -> (forall profile document. NonEmpty
                                 (ProfileContractEvidence profile document) -> result)
  -> (NonEmpty IdentityIndexDefect -> result)
  -> (NonEmpty SelectedViewScopeDefect -> result)
  -> (NonEmpty StructureInputDefect -> result)
  -> (NonEmpty SupplementalProvenanceDefect -> result)
  -> (NonEmpty SupplementalInputDefect -> result)
  -> ([OccurrenceIdentity] -> result)
  -> TraceInternalFailure
  -> result
foldTraceInternalFailure acquired adapter notation profile identity scope structure provenance input semantic failure =
  case failure of
    TraceAcquiredModelRoleFailure value -> acquired value
    TraceSelectedAdapterContractFailure value -> adapter value
    TraceNotationContractFailure value -> notation value
    TraceProfileContractFailure value -> profile value
    TraceIdentityIndexFailure value -> identity value
    TraceSelectedViewScopeFailure value -> scope value
    TraceStructureInputFailure value -> structure value
    TraceEmptyInputProvenanceFailure value -> provenance value
    TraceEmptyInputContractFailure value -> input value
    TraceSemanticModelContractFailure value -> semantic value

-- | Consume expected command failure or an impossible owner-contract failure.
foldTraceFailure ::
     (CommonFailure -> result)
  -> (TraceInternalFailure -> result)
  -> TraceFailure
  -> result
foldTraceFailure common internal failure =
  case failure of
    TraceCommonFailure value -> common value
    TraceOwnerContractFailure value -> internal value

-- | Exact request retained by one prepared Trace subject.
preparedTraceRequest :: PreparedTrace -> TraceRequest
preparedTraceRequest prepared =
  foldPreparedTrace (\request _ _ -> request) prepared

-- | Authority-once shared diagnostic document.
preparedTraceDiagnostics :: PreparedTrace -> PreparedDiagnosticDocument
preparedTraceDiagnostics prepared =
  foldPreparedTrace (\_ _ diagnostics -> diagnostics) prepared

-- | Eliminate one prepared subject while preserving its selected-View witness.
foldPreparedTrace ::
     (forall document. TraceRequest -> SelectedView document -> PreparedDiagnosticDocument -> result)
  -> PreparedTrace
  -> result
foldPreparedTrace consume prepared =
  case prepared of
    PreparedTrace request view diagnostics -> consume request view diagnostics

-- | Consume terminal failure, prerequisite rejection, or completed assessment.
foldTraceResult ::
     (TraceFailure -> result)
  -> (TracePrerequisite -> PreparedTrace -> result)
  -> (forall scope. TraceAssessment scope -> PreparedTrace -> result)
  -> (forall scope. TraceAssessment scope -> PreparedTrace -> result)
  -> TraceResult
  -> result
foldTraceResult failed prerequisite rejected accepted result =
  case result of
    TraceFailed failure -> failed failure
    TracePrerequisiteRejectedResult stage prepared ->
      prerequisite stage prepared
    TraceRejectedResult assessment prepared -> rejected assessment prepared
    TraceAcceptedResult assessment prepared -> accepted assessment prepared
