{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE GADTs #-}

-- | Private selected-View Assessment result representation.
module O2I.Operation.Assess.Result.Internal
  ( AssessExitClass(..)
  , AssessPrerequisite(..)
  , AssessInternalFailure(..)
  , AssessFailure(..)
  , AssessUnavailable(..)
  , PreparedAssess(..)
  , AssessResult(..)
  ) where

import Data.List.NonEmpty (NonEmpty)
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
import O2I.Operation.Diagnostic (PreparedDiagnosticDocument)
import O2I.Operation.Diagnostic.Owner (AdapterNotationResolutionFailure)
import O2I.Operation.Failure (CommonFailure)
import O2I.Operation.Provenance (SourceIdentity, SupplementalProvenanceDefect)
import O2I.Operation.View (SelectedView)
import O2I.Semantics.Input (SupplementalInputDefect)
import O2I.Structure (StructureInputDefect)
import O2I.Trace (TraceIdentity)

-- | Stable report class selected before the future CLI boundary.
data AssessExitClass
  = AssessExitSuccess
  | AssessExitPrimaryNegative
  | AssessExitOperationalFailure
  | AssessExitSubjectUnavailable
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Exact prerequisite that made the selected subject unavailable.
data AssessPrerequisite
  = AssessNotationPrerequisite
  | AssessProfilePrerequisite
  | AssessStructurePrerequisite
  | AssessSemanticsPrerequisite
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Closed impossible owner-contract failures.
data AssessInternalFailure
  = AssessAcquiredModelRoleFailure !SourceIdentity
  | AssessAcquiredBundleRoleFailure !SourceIdentity
  | AssessAcquiredSupplementalRoleFailure !SourceIdentity
  | AssessSelectedAdapterContractFailure !AdapterDescriptor
  | AssessNotationContractFailure !AdapterNotationResolutionFailure
  | forall profile document. AssessProfileContractFailure
                               !(NonEmpty
                                   (ProfileContractEvidence profile document))
  | AssessIdentityIndexFailure !(NonEmpty IdentityIndexDefect)
  | AssessSelectedViewScopeFailure !(NonEmpty SelectedViewScopeDefect)
  | AssessStructureInputFailure !(NonEmpty StructureInputDefect)
  | AssessSupplementalProvenanceFailure !(NonEmpty SupplementalProvenanceDefect)
  | AssessSemanticModelContractFailure ![OccurrenceIdentity]

-- | Expected command/input failure or impossible owner-contract failure.
data AssessFailure
  = AssessCommonFailure !CommonFailure
  | AssessBundleInputFailure !(NonEmpty AssessmentInputDefect)
  | AssessSupplementalInputFailure !(NonEmpty SupplementalInputDefect)
  | AssessOwnerContractFailure !AssessInternalFailure

-- | Exact pre-assessment reason why the subject is unavailable.
data AssessUnavailable
  = AssessInputBindingUnavailable
      !TraceIdentity
      !(NonEmpty AssessmentInputDefect)
  | AssessReconstructionUnavailable
      !ModelIdentity
      !TraceIdentity
      !(NonEmpty AssessmentSubjectUnavailableReason)

-- | Prepared immutable subject shared by every non-failure result.
data PreparedAssess where
  PreparedAssess
    :: !AssessRequest
    -> !(SelectedView document)
    -> !(Maybe AcquiredAssessmentSource)
    -> ![AcquiredSupplementalSource]
    -> !PreparedDiagnosticDocument
    -> PreparedAssess

-- | Failure, unavailable subject, or one closed Assessment disposition.
data AssessResult where
  AssessFailed :: !AssessFailure -> AssessResult
  AssessPrerequisiteRejectedResult
    :: !AssessPrerequisite -> !PreparedAssess -> AssessResult
  AssessSubjectUnavailableResult
    :: !AssessUnavailable -> !PreparedAssess -> AssessResult
  AssessCollectionInvalidResult
    :: !(AssessmentResult scope) -> !PreparedAssess -> AssessResult
  AssessObservationsInvalidResult
    :: !(AssessmentResult scope) -> !PreparedAssess -> AssessResult
  AssessCompletedResult
    :: !(AssessmentResult scope) -> !PreparedAssess -> AssessResult
