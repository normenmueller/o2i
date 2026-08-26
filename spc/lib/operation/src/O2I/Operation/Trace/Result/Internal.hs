{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE GADTs #-}

-- | Private Trace result representation.
module O2I.Operation.Trace.Result.Internal
  ( TracePrerequisite(..)
  , TraceInternalFailure(..)
  , TraceFailure(..)
  , PreparedTrace(..)
  , TraceResult(..)
  ) where

import Data.List.NonEmpty (NonEmpty)
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
import O2I.Operation.View (SelectedView)
import O2I.Semantics.Input (SupplementalInputDefect)
import O2I.Structure (StructureInputDefect)
import O2I.Trace (TraceAssessment)

-- | Exact prerequisite stage that prevented Core Trace evaluation.
data TracePrerequisite
  = TraceNotationPrerequisite
  | TraceProfilePrerequisite
  | TraceStructurePrerequisite
  | TraceSemanticsPrerequisite
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Closed internal owner-contract failures. These are never translated into
-- model findings or ordinary Trace rejection.
data TraceInternalFailure
  = TraceAcquiredModelRoleFailure !SourceIdentity
  | TraceSelectedAdapterContractFailure !AdapterDescriptor
  | TraceNotationContractFailure !AdapterNotationResolutionFailure
  | forall profile document. TraceProfileContractFailure
                               !(NonEmpty
                                   (ProfileContractEvidence profile document))
  | TraceIdentityIndexFailure !(NonEmpty IdentityIndexDefect)
  | TraceSelectedViewScopeFailure !(NonEmpty SelectedViewScopeDefect)
  | TraceStructureInputFailure !(NonEmpty StructureInputDefect)
  | TraceEmptyInputProvenanceFailure !(NonEmpty SupplementalProvenanceDefect)
  | TraceEmptyInputContractFailure !(NonEmpty SupplementalInputDefect)
  | TraceSemanticModelContractFailure ![OccurrenceIdentity]

-- | Expected command failures and impossible owner-contract failures.
data TraceFailure
  = TraceCommonFailure !CommonFailure
  | TraceOwnerContractFailure !TraceInternalFailure

-- | Prepared immutable subject shared by every non-failure Trace result.
data PreparedTrace where
  PreparedTrace
    :: !TraceRequest
    -> !(SelectedView document)
    -> !PreparedDiagnosticDocument
    -> PreparedTrace

-- | One terminal failure, prerequisite rejection, or completed Core Trace.
data TraceResult where
  TraceFailed :: !TraceFailure -> TraceResult
  TracePrerequisiteRejectedResult
    :: !TracePrerequisite -> !PreparedTrace -> TraceResult
  TraceRejectedResult
    :: !(TraceAssessment scope) -> !PreparedTrace -> TraceResult
  TraceAcceptedResult
    :: !(TraceAssessment scope) -> !PreparedTrace -> TraceResult
