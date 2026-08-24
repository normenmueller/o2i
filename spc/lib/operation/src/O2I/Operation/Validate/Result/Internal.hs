{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE GADTs #-}

-- | Private Validate result representation.
module O2I.Operation.Validate.Result.Internal
  ( ValidationDisposition(..)
  , ValidateInternalFailure(..)
  , ValidateFailure(..)
  , ValidateUnavailabilityWitness(..)
  , PreparedValidation(..)
  , ValidateResult(..)
  ) where

import Data.List.NonEmpty (NonEmpty)
import O2I.ArchiMate.Profile.Projection (ProfileContractEvidence)
import O2I.Core.Identity
  ( IdentityIndexDefect
  , ModelIdentity
  , OccurrenceIdentity
  , SelectedViewScopeDefect
  )
import O2I.Operation.Acquisition (AcquiredSupplementalSource)
import O2I.Operation.Adapter (AdapterDescriptor)
import O2I.Operation.Diagnostic (PreparedDiagnosticDocument)
import O2I.Operation.Diagnostic.Owner (AdapterNotationResolutionFailure)
import O2I.Operation.Failure (CommonFailure)
import O2I.Operation.Provenance
  ( SourceIdentity
  , SourceOrdinal
  , SupplementalProvenanceDefect
  )
import O2I.Operation.Validate.Request (ValidateRequest, ValidationLevel)
import O2I.Operation.View (SelectedView)
import O2I.Semantics
  ( CollectiveFitUnavailableReason
  , StrategyFormulationUnavailableReason
  )
import O2I.Semantics.Input (SupplementalInputDefect)
import O2I.Structure (StructureInputDefect)

-- | Aggregate terminal classification at the requested Validate level.
data ValidationDisposition
  = ValidationAccepted
  | ValidationRejected
  | ValidationUnavailable
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Closed internal owner-contract failures. These are never translated into
-- model findings or supplemental-input rejection.
data ValidateInternalFailure
  = ValidateAcquiredModelRoleFailure !SourceIdentity
  | ValidateAcquiredSupplementalRoleFailure !SourceIdentity
  | ValidateSelectedAdapterContractFailure !AdapterDescriptor
  | ValidateNotationContractFailure !AdapterNotationResolutionFailure
  | forall profile document. ValidateProfileContractFailure
                               !(NonEmpty
                                   (ProfileContractEvidence profile document))
  | ValidateIdentityIndexFailure !(NonEmpty IdentityIndexDefect)
  | ValidateSelectedViewScopeFailure !(NonEmpty SelectedViewScopeDefect)
  | ValidateStructureInputFailure !(NonEmpty StructureInputDefect)
  | ValidateSupplementalProvenanceFailure
      !(NonEmpty SupplementalProvenanceDefect)
  | ValidateSemanticUnavailableContractFailure ![OccurrenceIdentity]

-- | Expected command/input failures and impossible owner-contract failures.
data ValidateFailure
  = ValidateCommonFailure !CommonFailure
  | ValidateSupplementalInputFailure !(NonEmpty SupplementalInputDefect)
  | ValidateOwnerContractFailure !ValidateInternalFailure

-- | One Core-owned reason or source-bound Binding blocker retained without
-- manufacturing a diagnostic.
data ValidateUnavailabilityWitness
  = ValidateBindingUnavailable !SourceOrdinal
  | ValidateStrategyFormulationUnavailable
      !ModelIdentity
      !StrategyFormulationUnavailableReason
  | ValidateCollectiveFitUnavailable
      !ModelIdentity
      !(NonEmpty CollectiveFitUnavailableReason)
      ![ModelIdentity]
  | ValidateCollectiveCoverageUnavailable !ModelIdentity ![ModelIdentity]
  | ValidatePrimitiveSupportUnavailable
      !ModelIdentity
      !ModelIdentity
      !(NonEmpty CollectiveFitUnavailableReason)
      ![ModelIdentity]

-- | Prepared immutable subject shared by accepted, rejected, and unavailable
-- reports. The selected View remains existentially bound to its document.
data PreparedValidation where
  PreparedValidation
    :: !ValidateRequest
    -> !ValidationLevel
    -> !(SelectedView document)
    -> ![AcquiredSupplementalSource]
    -> !PreparedDiagnosticDocument
    -> PreparedValidation

-- | One terminal pre-preparation failure or one prepared primary report.
data ValidateResult
  = ValidateFailed !ValidateFailure
  | ValidateAccepted !PreparedValidation
  | ValidateRejected !PreparedValidation
  | ValidateUnavailable
      !(NonEmpty ValidateUnavailabilityWitness)
      !PreparedValidation
