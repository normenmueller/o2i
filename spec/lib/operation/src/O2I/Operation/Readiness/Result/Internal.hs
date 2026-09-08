{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE GADTs #-}

-- | Private Readiness result representation.
module O2I.Operation.Readiness.Result.Internal
  ( ReadinessPrerequisite(..)
  , ReadinessInternalFailure(..)
  , ReadinessFailure(..)
  , ReadinessUnavailable(..)
  , PreparedReadiness(..)
  , ReadinessResult(..)
  ) where

import Data.List.NonEmpty (NonEmpty)
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
import O2I.Operation.View (SelectedView)
import O2I.Readiness
  ( EvidenceInputDefect
  , ReadinessAssessment
  , ReadinessSubjectUnavailableReason
  )
import O2I.Semantics.Input (SupplementalInputDefect)
import O2I.Structure (StructureInputDefect)
import O2I.Trace (TraceIdentity)

-- | Exact prerequisite stage that prevented Core Readiness evaluation.
data ReadinessPrerequisite
  = ReadinessNotationPrerequisite
  | ReadinessProfilePrerequisite
  | ReadinessStructurePrerequisite
  | ReadinessSemanticsPrerequisite
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Closed impossible owner-contract failures.
data ReadinessInternalFailure
  = ReadinessAcquiredModelRoleFailure !SourceIdentity
  | ReadinessAcquiredEvidenceRoleFailure !SourceIdentity
  | ReadinessAcquiredSupplementalRoleFailure !SourceIdentity
  | ReadinessSelectedAdapterContractFailure !AdapterDescriptor
  | ReadinessNotationContractFailure !AdapterNotationResolutionFailure
  | forall profile document. ReadinessProfileContractFailure
                               !(NonEmpty
                                   (ProfileContractEvidence profile document))
  | ReadinessIdentityIndexFailure !(NonEmpty IdentityIndexDefect)
  | ReadinessSelectedViewScopeFailure !(NonEmpty SelectedViewScopeDefect)
  | ReadinessStructureInputFailure !(NonEmpty StructureInputDefect)
  | ReadinessSupplementalProvenanceFailure
      !(NonEmpty SupplementalProvenanceDefect)
  | ReadinessSemanticModelContractFailure ![OccurrenceIdentity]

-- | Expected command/input failure or impossible owner-contract failure.
data ReadinessFailure
  = ReadinessCommonFailure !CommonFailure
  | ReadinessEvidenceInputFailure !(NonEmpty EvidenceInputDefect)
  | ReadinessSupplementalInputFailure !(NonEmpty SupplementalInputDefect)
  | ReadinessOwnerContractFailure !ReadinessInternalFailure

-- | Exact pre-assessment reason why the Readiness subject is unavailable.
data ReadinessUnavailable
  = ReadinessInputBindingUnavailable
      !TraceIdentity
      !(NonEmpty EvidenceInputDefect)
  | ReadinessReconstructionUnavailable
      !ModelIdentity
      !TraceIdentity
      !(NonEmpty ReadinessSubjectUnavailableReason)

-- | Prepared immutable subject shared by every non-failure result.
data PreparedReadiness where
  PreparedReadiness
    :: !ReadinessRequest
    -> !(SelectedView document)
    -> !(Maybe AcquiredReadinessSource)
    -> ![AcquiredSupplementalSource]
    -> !PreparedDiagnosticDocument
    -> PreparedReadiness

-- | Terminal failure, prerequisite, unavailable subject, or assessment.
data ReadinessResult where
  ReadinessFailed :: !ReadinessFailure -> ReadinessResult
  ReadinessPrerequisiteRejectedResult
    :: !ReadinessPrerequisite -> !PreparedReadiness -> ReadinessResult
  ReadinessSubjectUnavailableResult
    :: !ReadinessUnavailable -> !PreparedReadiness -> ReadinessResult
  ReadinessNotReadyResult
    :: !(ReadinessAssessment scope) -> !PreparedReadiness -> ReadinessResult
  ReadinessReadyResult
    :: !(ReadinessAssessment scope) -> !PreparedReadiness -> ReadinessResult
