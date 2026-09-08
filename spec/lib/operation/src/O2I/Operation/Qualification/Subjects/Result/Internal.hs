{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE GADTs #-}

-- | Private qualification-subject discovery result representation.
module O2I.Operation.Qualification.Subjects.Result.Internal
  ( QualificationSubjectsPrerequisite(..)
  , QualificationSubjectCategory(..)
  , QualificationSubjectEligibility(..)
  , DiscoveredQualificationSubject(..)
  , QualificationSubjectsInventory(..)
  , QualificationSubjectsInternalFailure(..)
  , QualificationSubjectsFailure(..)
  , PreparedQualificationSubjects(..)
  , QualificationSubjectsResult(..)
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import O2I.ArchiMate.Profile.Notation (CanonicalOccurrence)
import O2I.ArchiMate.Profile.Projection (ProfileContractEvidence)
import O2I.Core.Contract (CoreQualifiedEndpointId)
import O2I.Core.Identity
  ( IdentityIndexDefect
  , ModelIdentity
  , OccurrenceIdentity
  , OccurrenceIdentityDefect
  , SelectedViewScopeDefect
  )
import O2I.Operation.Acquisition (AcquiredSupplementalSource)
import O2I.Operation.Adapter (AdapterDescriptor)
import O2I.Operation.Diagnostic (PreparedDiagnosticDocument)
import O2I.Operation.Diagnostic.Owner (AdapterNotationResolutionFailure)
import O2I.Operation.Failure (CommonFailure)
import O2I.Operation.Provenance (SourceIdentity, SupplementalProvenanceDefect)
import O2I.Operation.Qualification.Subjects.Request
  ( QualificationSubjectsRequest
  )
import O2I.Operation.View (SelectedView)
import O2I.Qualification (QualificationContextError)
import O2I.Semantics.Input (SupplementalInputDefect)
import O2I.Structure (StructureInputDefect)

-- | Closed subject category owned by the discovery capability.
data QualificationSubjectCategory
  = QualificationNeedSubject
  | QualificationStrategySubject
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Closed Core-owned eligibility projected without reinterpretation.
data QualificationSubjectEligibility
  = QualificationSubjectEligible
  | QualificationSubjectIneligible
  | QualificationSubjectEligibilityUnavailable
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | One scope-free public discovery row.
data DiscoveredQualificationSubject =
  DiscoveredQualificationSubject
    !QualificationSubjectCategory
    !ModelIdentity
    !OccurrenceIdentity
    !CoreQualifiedEndpointId
    !(Maybe Text)
    !QualificationSubjectEligibility

-- | Canonical Need and Strategy inventories.
data QualificationSubjectsInventory =
  QualificationSubjectsInventory
    ![DiscoveredQualificationSubject]
    ![DiscoveredQualificationSubject]

-- | Exact prerequisite stage that prevented subject discovery.
data QualificationSubjectsPrerequisite
  = QualificationSubjectsNotationPrerequisite
  | QualificationSubjectsProfilePrerequisite
  | QualificationSubjectsStructurePrerequisite
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Closed impossible owner-contract failures.
data QualificationSubjectsInternalFailure
  = QualificationSubjectsAcquiredModelRoleFailure !SourceIdentity
  | QualificationSubjectsAcquiredSupplementalRoleFailure !SourceIdentity
  | QualificationSubjectsSelectedAdapterContractFailure !AdapterDescriptor
  | QualificationSubjectsNotationContractFailure
      !AdapterNotationResolutionFailure
  | forall profile document. QualificationSubjectsProfileContractFailure
                               !(NonEmpty
                                   (ProfileContractEvidence profile document))
  | QualificationSubjectsIdentityIndexFailure !(NonEmpty IdentityIndexDefect)
  | QualificationSubjectsSelectedViewScopeFailure
      !(NonEmpty SelectedViewScopeDefect)
  | QualificationSubjectsStructureInputFailure !(NonEmpty StructureInputDefect)
  | QualificationSubjectsSupplementalProvenanceFailure
      !(NonEmpty SupplementalProvenanceDefect)
  | QualificationSubjectsContextFailure !QualificationContextError
  | QualificationSubjectsOccurrenceProjectionFailure
      !CanonicalOccurrence
      !OccurrenceIdentityDefect
  | QualificationSubjectsOccurrenceJoinFailure
      !OccurrenceIdentity
      ![CanonicalOccurrence]

-- | Expected command failure or impossible owner-contract failure.
data QualificationSubjectsFailure
  = QualificationSubjectsCommonFailure !CommonFailure
  | QualificationSubjectsSupplementalInputFailure
      !(NonEmpty SupplementalInputDefect)
  | QualificationSubjectsOwnerContractFailure
      !QualificationSubjectsInternalFailure

-- | Prepared immutable subject shared by every non-failure result.
data PreparedQualificationSubjects where
  PreparedQualificationSubjects
    :: !QualificationSubjectsRequest
    -> !(SelectedView document)
    -> ![AcquiredSupplementalSource]
    -> !PreparedDiagnosticDocument
    -> PreparedQualificationSubjects

-- | Terminal failure, prerequisite rejection, or discovered Core subjects.
data QualificationSubjectsResult where
  QualificationSubjectsFailed
    :: !QualificationSubjectsFailure -> QualificationSubjectsResult
  QualificationSubjectsPrerequisiteRejectedResult
    :: !QualificationSubjectsPrerequisite
    -> !PreparedQualificationSubjects
    -> QualificationSubjectsResult
  QualificationSubjectsDiscoveredResult
    :: !QualificationSubjectsInventory
    -> !PreparedQualificationSubjects
    -> QualificationSubjectsResult
