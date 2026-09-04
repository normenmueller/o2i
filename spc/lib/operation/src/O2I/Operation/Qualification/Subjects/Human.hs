{-# LANGUAGE ExplicitNamespaces #-}

-- | Complete terminal-neutral human projection of qualification subjects.
module O2I.Operation.Qualification.Subjects.Human
  ( type HumanQualificationSubjectsRequest
  , foldHumanQualificationSubjectsRequest
  , type HumanQualificationSubjectsContext
  , foldHumanQualificationSubjectsContext
  , type HumanQualificationSubject
  , foldHumanQualificationSubject
  , type HumanQualificationSubjectsFailure
  , foldHumanQualificationSubjectsFailure
  , type HumanQualificationSubjectsReport
  , qualificationSubjectsHumanReport
  , foldHumanQualificationSubjectsReport
  ) where

import Data.Text (Text)
import O2I.Operation.Human.Diagnostic
  ( HumanDiagnosticDocument
  , humanDiagnosticDocument
  , humanDiagnosticDocumentModelSource
  )
import O2I.Operation.Human.Failure.Internal
  ( HumanQualificationSubjectsFailure
  , foldHumanQualificationSubjectsFailure
  , projectQualificationSubjectsFailure
  )
import O2I.Operation.Human.Value
  ( HumanAdapterSelection
  , HumanInputSource
  , HumanModelIdentity
  , HumanOccurrenceIdentity
  , HumanQualifiedType
  , HumanSourceIdentity
  , HumanViewDescriptor
  , HumanViewSelector
  )
import O2I.Operation.Human.Value.Internal
  ( projectAcquiredSupplementalSource
  , projectAdapterSelection
  , projectInputSource
  , projectModelIdentity
  , projectOccurrenceIdentity
  , projectQualifiedType
  , projectViewDescriptor
  , projectViewSelector
  )
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Qualification.Subjects.Request
  ( QualificationSubjectsRequest
  , foldQualificationSubjectsRequest
  )
import O2I.Operation.Qualification.Subjects.Result
  ( DiscoveredQualificationSubject
  , PreparedQualificationSubjects
  , QualificationSubjectCategory
  , QualificationSubjectEligibility
  , QualificationSubjectsPrerequisite
  , QualificationSubjectsResult
  , discoveredQualificationSubjectCategory
  , discoveredQualificationSubjectDisplayName
  , discoveredQualificationSubjectEligibility
  , discoveredQualificationSubjectIdentity
  , discoveredQualificationSubjectOccurrence
  , discoveredQualificationSubjectQualifiedEndpoint
  , foldPreparedQualificationSubjects
  , foldQualificationSubjectsInventory
  )
import O2I.Operation.Report (ReportEnvelope)
import O2I.Operation.Report.Internal (foldQualificationSubjectsReport)
import O2I.Operation.View (selectedViewDescriptor)

-- | Exact retained qualification-subject request contract.
data HumanQualificationSubjectsRequest =
  HumanQualificationSubjectsRequest
    HumanInputSource
    HumanViewSelector
    HumanAdapterSelection
    [HumanInputSource]

-- | Complete context shared by every prepared subject-discovery branch.
data HumanQualificationSubjectsContext =
  HumanQualificationSubjectsContext
    ReportEnvelope
    HumanQualificationSubjectsRequest
    HumanSourceIdentity
    [HumanSourceIdentity]
    HumanViewDescriptor
    HumanDiagnosticDocument

-- | Exact identity, type, display name, and eligibility of one subject.
data HumanQualificationSubject =
  HumanQualificationSubject
    QualificationSubjectCategory
    HumanModelIdentity
    HumanOccurrenceIdentity
    HumanQualifiedType
    (Maybe Text)
    QualificationSubjectEligibility

-- | Complete terminal result of qualification-subject discovery.
data HumanQualificationSubjectsReport
  = HumanQualificationSubjectsFailed HumanQualificationSubjectsFailure
  | HumanQualificationSubjectsPrerequisiteRejected
      QualificationSubjectsPrerequisite
      HumanQualificationSubjectsContext
  | HumanQualificationSubjectsDiscovered
      [HumanQualificationSubject]
      [HumanQualificationSubject]
      HumanQualificationSubjectsContext

-- | Consume every exact requested qualification-subject field.
foldHumanQualificationSubjectsRequest ::
     (HumanInputSource -> HumanViewSelector -> HumanAdapterSelection -> [HumanInputSource] -> result)
  -> HumanQualificationSubjectsRequest
  -> result
foldHumanQualificationSubjectsRequest consume (HumanQualificationSubjectsRequest model view adapter supplements) =
  consume model view adapter supplements

-- | Consume every prepared qualification-subject context field.
foldHumanQualificationSubjectsContext ::
     (ReportEnvelope -> HumanQualificationSubjectsRequest -> HumanSourceIdentity -> [HumanSourceIdentity] -> HumanViewDescriptor -> HumanDiagnosticDocument -> result)
  -> HumanQualificationSubjectsContext
  -> result
foldHumanQualificationSubjectsContext consume (HumanQualificationSubjectsContext envelope request model supplements view diagnostics) =
  consume envelope request model supplements view diagnostics

-- | Consume every retained qualification-subject field.
foldHumanQualificationSubject ::
     (QualificationSubjectCategory -> HumanModelIdentity -> HumanOccurrenceIdentity -> HumanQualifiedType -> Maybe
                                                                                                               Text -> QualificationSubjectEligibility -> result)
  -> HumanQualificationSubject
  -> result
foldHumanQualificationSubject consume (HumanQualificationSubject category identity occurrence qualifiedType displayName eligibility) =
  consume category identity occurrence qualifiedType displayName eligibility

-- | Project a qualification-subject result without rendering it.
qualificationSubjectsHumanReport ::
     ToolDescriptor
  -> QualificationSubjectsResult
  -> HumanQualificationSubjectsReport
qualificationSubjectsHumanReport tool =
  foldQualificationSubjectsReport
    tool
    (HumanQualificationSubjectsFailed . projectQualificationSubjectsFailure)
    (\envelope prerequisite prepared ->
       preparedContext
         (HumanQualificationSubjectsPrerequisiteRejected prerequisite)
         envelope
         prepared)
    (\envelope inventory prepared ->
       foldQualificationSubjectsInventory
         (\needs strategies ->
            preparedContext
              (HumanQualificationSubjectsDiscovered
                 (map projectSubject needs)
                 (map projectSubject strategies))
              envelope
              prepared)
         inventory)

-- | Eliminate every closed qualification-subject report branch.
foldHumanQualificationSubjectsReport ::
     (HumanQualificationSubjectsFailure -> result)
  -> (QualificationSubjectsPrerequisite -> HumanQualificationSubjectsContext -> result)
  -> ([HumanQualificationSubject] -> [HumanQualificationSubject] -> HumanQualificationSubjectsContext -> result)
  -> HumanQualificationSubjectsReport
  -> result
foldHumanQualificationSubjectsReport failed prerequisite discovered report =
  case report of
    HumanQualificationSubjectsFailed failure -> failed failure
    HumanQualificationSubjectsPrerequisiteRejected stage context ->
      prerequisite stage context
    HumanQualificationSubjectsDiscovered needs strategies context ->
      discovered needs strategies context

preparedContext ::
     (HumanQualificationSubjectsContext -> HumanQualificationSubjectsReport)
  -> ReportEnvelope
  -> PreparedQualificationSubjects
  -> HumanQualificationSubjectsReport
preparedContext constructor envelope prepared =
  foldPreparedQualificationSubjects
    (\request view supplements diagnostics ->
       let document = humanDiagnosticDocument diagnostics
        in constructor
             (HumanQualificationSubjectsContext
                envelope
                (projectRequest request)
                (humanDiagnosticDocumentModelSource document)
                (map projectAcquiredSupplementalSource supplements)
                (projectViewDescriptor (selectedViewDescriptor view))
                document))
    prepared

projectRequest ::
     QualificationSubjectsRequest -> HumanQualificationSubjectsRequest
projectRequest =
  foldQualificationSubjectsRequest $ \model view adapter supplements ->
    HumanQualificationSubjectsRequest
      (projectInputSource model)
      (projectViewSelector view)
      (projectAdapterSelection adapter)
      (map projectInputSource supplements)

projectSubject :: DiscoveredQualificationSubject -> HumanQualificationSubject
projectSubject subject =
  HumanQualificationSubject
    (discoveredQualificationSubjectCategory subject)
    (projectModelIdentity (discoveredQualificationSubjectIdentity subject))
    (projectOccurrenceIdentity
       (discoveredQualificationSubjectOccurrence subject))
    (projectQualifiedType
       (discoveredQualificationSubjectQualifiedEndpoint subject))
    (discoveredQualificationSubjectDisplayName subject)
    (discoveredQualificationSubjectEligibility subject)
