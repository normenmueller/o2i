{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

-- | Closed terminal qualification-subject discovery results.
module O2I.Operation.Qualification.Subjects.Result
  ( type QualificationSubjectsPrerequisite
  , notationQualificationSubjectsPrerequisite
  , profileQualificationSubjectsPrerequisite
  , structureQualificationSubjectsPrerequisite
  , qualificationSubjectsPrerequisiteText
  , foldQualificationSubjectsPrerequisite
  , type QualificationSubjectCategory
  , needQualificationSubjectCategory
  , strategyQualificationSubjectCategory
  , qualificationSubjectCategoryText
  , foldQualificationSubjectCategory
  , type QualificationSubjectEligibility
  , eligibleQualificationSubject
  , ineligibleQualificationSubject
  , unavailableQualificationSubjectEligibility
  , qualificationSubjectEligibilityText
  , foldQualificationSubjectEligibility
  , type DiscoveredQualificationSubject
  , discoveredQualificationSubjectCategory
  , discoveredQualificationSubjectIdentity
  , discoveredQualificationSubjectOccurrence
  , discoveredQualificationSubjectQualifiedEndpoint
  , discoveredQualificationSubjectDisplayName
  , discoveredQualificationSubjectEligibility
  , foldDiscoveredQualificationSubject
  , type QualificationSubjectsInventory
  , qualificationInventoryNeedSubjects
  , qualificationInventoryStrategySubjects
  , foldQualificationSubjectsInventory
  , type QualificationSubjectsInternalFailure
  , foldQualificationSubjectsInternalFailure
  , type QualificationSubjectsFailure
  , foldQualificationSubjectsFailure
  , type PreparedQualificationSubjects
  , preparedQualificationSubjectsRequest
  , preparedQualificationSubjectsSupplementalSources
  , preparedQualificationSubjectsDiagnostics
  , foldPreparedQualificationSubjects
  , type QualificationSubjectsResult
  , foldQualificationSubjectsResult
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
import O2I.Operation.Qualification.Subjects.Result.Internal
import O2I.Operation.View (SelectedView)
import O2I.Qualification (QualificationContextError)
import O2I.Semantics.Input (SupplementalInputDefect)
import O2I.Structure (StructureInputDefect)

-- | Notation is the earliest public discovery prerequisite.
notationQualificationSubjectsPrerequisite :: QualificationSubjectsPrerequisite
notationQualificationSubjectsPrerequisite =
  QualificationSubjectsNotationPrerequisite

-- | Profile conformance prevented subject discovery.
profileQualificationSubjectsPrerequisite :: QualificationSubjectsPrerequisite
profileQualificationSubjectsPrerequisite =
  QualificationSubjectsProfilePrerequisite

-- | Structure conformance prevented Core subject discovery.
structureQualificationSubjectsPrerequisite :: QualificationSubjectsPrerequisite
structureQualificationSubjectsPrerequisite =
  QualificationSubjectsStructurePrerequisite

-- | Stable machine token for one rejected prerequisite stage.
qualificationSubjectsPrerequisiteText ::
     QualificationSubjectsPrerequisite -> Text
qualificationSubjectsPrerequisiteText prerequisite =
  case prerequisite of
    QualificationSubjectsNotationPrerequisite -> "notation"
    QualificationSubjectsProfilePrerequisite -> "profile"
    QualificationSubjectsStructurePrerequisite -> "structure"

-- | Consume the complete closed prerequisite vocabulary.
foldQualificationSubjectsPrerequisite ::
     result -> result -> result -> QualificationSubjectsPrerequisite -> result
foldQualificationSubjectsPrerequisite notation profile structure prerequisite =
  case prerequisite of
    QualificationSubjectsNotationPrerequisite -> notation
    QualificationSubjectsProfilePrerequisite -> profile
    QualificationSubjectsStructurePrerequisite -> structure

-- | Need row category for closed machine projection.
needQualificationSubjectCategory :: QualificationSubjectCategory
needQualificationSubjectCategory = QualificationNeedSubject

-- | Strategy row category for closed machine projection.
strategyQualificationSubjectCategory :: QualificationSubjectCategory
strategyQualificationSubjectCategory = QualificationStrategySubject

-- | Stable machine token for one discovery category.
qualificationSubjectCategoryText :: QualificationSubjectCategory -> Text
qualificationSubjectCategoryText category =
  case category of
    QualificationNeedSubject -> "need"
    QualificationStrategySubject -> "strategy"

-- | Consume both closed discovery categories.
foldQualificationSubjectCategory ::
     result -> result -> QualificationSubjectCategory -> result
foldQualificationSubjectCategory need strategy category =
  case category of
    QualificationNeedSubject -> need
    QualificationStrategySubject -> strategy

-- | Core proved the discovered subject eligible.
eligibleQualificationSubject :: QualificationSubjectEligibility
eligibleQualificationSubject = QualificationSubjectEligible

-- | Core proved the discovered subject ineligible.
ineligibleQualificationSubject :: QualificationSubjectEligibility
ineligibleQualificationSubject = QualificationSubjectIneligible

-- | Core could not establish the eligibility prerequisite.
unavailableQualificationSubjectEligibility :: QualificationSubjectEligibility
unavailableQualificationSubjectEligibility =
  QualificationSubjectEligibilityUnavailable

-- | Stable machine token for one Core-owned eligibility disposition.
qualificationSubjectEligibilityText :: QualificationSubjectEligibility -> Text
qualificationSubjectEligibilityText eligibility =
  case eligibility of
    QualificationSubjectEligible -> "eligible"
    QualificationSubjectIneligible -> "ineligible"
    QualificationSubjectEligibilityUnavailable -> "eligibility-unavailable"

-- | Consume every closed eligibility disposition.
foldQualificationSubjectEligibility ::
     result -> result -> result -> QualificationSubjectEligibility -> result
foldQualificationSubjectEligibility eligible ineligible unavailable eligibility =
  case eligibility of
    QualificationSubjectEligible -> eligible
    QualificationSubjectIneligible -> ineligible
    QualificationSubjectEligibilityUnavailable -> unavailable

-- | Recover the fixed Need or Strategy category.
discoveredQualificationSubjectCategory ::
     DiscoveredQualificationSubject -> QualificationSubjectCategory
discoveredQualificationSubjectCategory (DiscoveredQualificationSubject category _ _ _ _ _) =
  category

-- | Recover the exact stable model identity.
discoveredQualificationSubjectIdentity ::
     DiscoveredQualificationSubject -> ModelIdentity
discoveredQualificationSubjectIdentity (DiscoveredQualificationSubject _ identity _ _ _ _) =
  identity

-- | Recover the exact selected-View occurrence identity.
discoveredQualificationSubjectOccurrence ::
     DiscoveredQualificationSubject -> OccurrenceIdentity
discoveredQualificationSubjectOccurrence (DiscoveredQualificationSubject _ _ occurrence _ _ _) =
  occurrence

-- | Recover the Core-owned qualified O2I endpoint.
discoveredQualificationSubjectQualifiedEndpoint ::
     DiscoveredQualificationSubject -> CoreQualifiedEndpointId
discoveredQualificationSubjectQualifiedEndpoint (DiscoveredQualificationSubject _ _ _ endpoint _ _) =
  endpoint

-- | Recover the optional projection-only native display name.
discoveredQualificationSubjectDisplayName ::
     DiscoveredQualificationSubject -> Maybe Text
discoveredQualificationSubjectDisplayName (DiscoveredQualificationSubject _ _ _ _ displayName _) =
  displayName

-- | Recover the Core-owned eligibility disposition.
discoveredQualificationSubjectEligibility ::
     DiscoveredQualificationSubject -> QualificationSubjectEligibility
discoveredQualificationSubjectEligibility (DiscoveredQualificationSubject _ _ _ _ _ eligibility) =
  eligibility

-- | Consume every field of one immutable discovery row.
foldDiscoveredQualificationSubject ::
     (QualificationSubjectCategory -> ModelIdentity -> OccurrenceIdentity -> CoreQualifiedEndpointId -> Maybe
                                                                                                          Text -> QualificationSubjectEligibility -> result)
  -> DiscoveredQualificationSubject
  -> result
foldDiscoveredQualificationSubject consume subject =
  case subject of
    DiscoveredQualificationSubject category identity occurrence endpoint displayName eligibility ->
      consume category identity occurrence endpoint displayName eligibility

-- | Recover the canonical Need rows.
qualificationInventoryNeedSubjects ::
     QualificationSubjectsInventory -> [DiscoveredQualificationSubject]
qualificationInventoryNeedSubjects (QualificationSubjectsInventory needs _) =
  needs

-- | Recover the canonical Strategy rows.
qualificationInventoryStrategySubjects ::
     QualificationSubjectsInventory -> [DiscoveredQualificationSubject]
qualificationInventoryStrategySubjects (QualificationSubjectsInventory _ strategies) =
  strategies

-- | Consume both canonical subject inventories.
foldQualificationSubjectsInventory ::
     ([DiscoveredQualificationSubject] -> [DiscoveredQualificationSubject] -> result)
  -> QualificationSubjectsInventory
  -> result
foldQualificationSubjectsInventory consume inventory =
  case inventory of
    QualificationSubjectsInventory needs strategies -> consume needs strategies

-- | Consume every impossible owner-contract failure.
foldQualificationSubjectsInternalFailure ::
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
  -> (CanonicalOccurrence -> OccurrenceIdentityDefect -> result)
  -> (OccurrenceIdentity -> [CanonicalOccurrence] -> result)
  -> QualificationSubjectsInternalFailure
  -> result
foldQualificationSubjectsInternalFailure model supplemental adapter notation profile identity scope structure provenance context projection join failure =
  case failure of
    QualificationSubjectsAcquiredModelRoleFailure value -> model value
    QualificationSubjectsAcquiredSupplementalRoleFailure value ->
      supplemental value
    QualificationSubjectsSelectedAdapterContractFailure value -> adapter value
    QualificationSubjectsNotationContractFailure value -> notation value
    QualificationSubjectsProfileContractFailure value -> profile value
    QualificationSubjectsIdentityIndexFailure value -> identity value
    QualificationSubjectsSelectedViewScopeFailure value -> scope value
    QualificationSubjectsStructureInputFailure value -> structure value
    QualificationSubjectsSupplementalProvenanceFailure value -> provenance value
    QualificationSubjectsContextFailure value -> context value
    QualificationSubjectsOccurrenceProjectionFailure occurrence defect ->
      projection occurrence defect
    QualificationSubjectsOccurrenceJoinFailure occurrence candidates ->
      join occurrence candidates

-- | Consume expected command failure or impossible owner-contract failure.
foldQualificationSubjectsFailure ::
     (CommonFailure -> result)
  -> (NonEmpty SupplementalInputDefect -> result)
  -> (QualificationSubjectsInternalFailure -> result)
  -> QualificationSubjectsFailure
  -> result
foldQualificationSubjectsFailure common supplemental internal failure =
  case failure of
    QualificationSubjectsCommonFailure value -> common value
    QualificationSubjectsSupplementalInputFailure value -> supplemental value
    QualificationSubjectsOwnerContractFailure value -> internal value

-- | Exact request retained by one prepared discovery subject.
preparedQualificationSubjectsRequest ::
     PreparedQualificationSubjects -> QualificationSubjectsRequest
preparedQualificationSubjectsRequest prepared =
  foldPreparedQualificationSubjects (\request _ _ _ -> request) prepared

-- | Acquired supplemental sources retained in request order.
preparedQualificationSubjectsSupplementalSources ::
     PreparedQualificationSubjects -> [AcquiredSupplementalSource]
preparedQualificationSubjectsSupplementalSources prepared =
  foldPreparedQualificationSubjects (\_ _ supplements _ -> supplements) prepared

-- | Authority-once shared diagnostic document.
preparedQualificationSubjectsDiagnostics ::
     PreparedQualificationSubjects -> PreparedDiagnosticDocument
preparedQualificationSubjectsDiagnostics prepared =
  foldPreparedQualificationSubjects (\_ _ _ diagnostics -> diagnostics) prepared

-- | Eliminate one prepared subject while preserving its selected-View witness.
foldPreparedQualificationSubjects ::
     (forall document. QualificationSubjectsRequest -> SelectedView document -> [AcquiredSupplementalSource] -> PreparedDiagnosticDocument -> result)
  -> PreparedQualificationSubjects
  -> result
foldPreparedQualificationSubjects consume prepared =
  case prepared of
    PreparedQualificationSubjects request view supplements diagnostics ->
      consume request view supplements diagnostics

-- | Consume failure, prerequisite rejection, or discovered subjects.
foldQualificationSubjectsResult ::
     (QualificationSubjectsFailure -> result)
  -> (QualificationSubjectsPrerequisite -> PreparedQualificationSubjects -> result)
  -> (QualificationSubjectsInventory -> PreparedQualificationSubjects -> result)
  -> QualificationSubjectsResult
  -> result
foldQualificationSubjectsResult failed prerequisite discovered result =
  case result of
    QualificationSubjectsFailed failure -> failed failure
    QualificationSubjectsPrerequisiteRejectedResult stage prepared ->
      prerequisite stage prepared
    QualificationSubjectsDiscoveredResult subjects prepared ->
      discovered subjects prepared
