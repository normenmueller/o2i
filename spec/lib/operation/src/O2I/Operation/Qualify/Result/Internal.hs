{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE GADTs #-}

-- | Private Qualify result representation.
module O2I.Operation.Qualify.Result.Internal
  ( QualifyPrerequisite(..)
  , QualifyInternalFailure(..)
  , QualifyFailure(..)
  , PreparedQualify(..)
  , QualifyResult(..)
  ) where

import Data.List.NonEmpty (NonEmpty)
import O2I.ArchiMate.Profile.Projection (ProfileContractEvidence)
import O2I.Core.Identity (IdentityIndexDefect, SelectedViewScopeDefect)
import O2I.Operation.Acquisition (AcquiredSupplementalSource)
import O2I.Operation.Adapter (AdapterDescriptor)
import O2I.Operation.Diagnostic (PreparedDiagnosticDocument)
import O2I.Operation.Diagnostic.Owner (AdapterNotationResolutionFailure)
import O2I.Operation.Failure (CommonFailure)
import O2I.Operation.Provenance (SourceIdentity, SupplementalProvenanceDefect)
import O2I.Operation.Qualify.Request (QualifyRequest)
import O2I.Operation.View (SelectedView)
import O2I.Qualification (QualificationAssessment, QualificationContextError)
import O2I.Semantics.Input (SupplementalInputDefect)
import O2I.Structure (StructureInputDefect)

-- | Exact prerequisite stage that prevented Core Qualification evaluation.
data QualifyPrerequisite
  = QualifyNotationPrerequisite
  | QualifyProfilePrerequisite
  | QualifyStructurePrerequisite
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Closed impossible owner-contract failures.
data QualifyInternalFailure
  = QualifyAcquiredModelRoleFailure !SourceIdentity
  | QualifyAcquiredSupplementalRoleFailure !SourceIdentity
  | QualifySelectedAdapterContractFailure !AdapterDescriptor
  | QualifyNotationContractFailure !AdapterNotationResolutionFailure
  | forall profile document. QualifyProfileContractFailure
                               !(NonEmpty
                                   (ProfileContractEvidence profile document))
  | QualifyIdentityIndexFailure !(NonEmpty IdentityIndexDefect)
  | QualifySelectedViewScopeFailure !(NonEmpty SelectedViewScopeDefect)
  | QualifyStructureInputFailure !(NonEmpty StructureInputDefect)
  | QualifySupplementalProvenanceFailure
      !(NonEmpty SupplementalProvenanceDefect)
  | QualifyContextFailure !QualificationContextError

-- | Expected command/input failure or impossible owner-contract failure.
data QualifyFailure
  = QualifyCommonFailure !CommonFailure
  | QualifySupplementalInputFailure !(NonEmpty SupplementalInputDefect)
  | QualifyOwnerContractFailure !QualifyInternalFailure

-- | Prepared immutable subject shared by every non-failure Qualify result.
data PreparedQualify where
  PreparedQualify
    :: !QualifyRequest
    -> !(SelectedView document)
    -> ![AcquiredSupplementalSource]
    -> !PreparedDiagnosticDocument
    -> PreparedQualify

-- | Terminal failure, prerequisite rejection, or completed assessment.
data QualifyResult where
  QualifyFailed :: !QualifyFailure -> QualifyResult
  QualifyPrerequisiteRejectedResult
    :: !QualifyPrerequisite -> !PreparedQualify -> QualifyResult
  QualifyCompletedResult
    :: !(QualificationAssessment scope) -> !PreparedQualify -> QualifyResult
