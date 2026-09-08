{-# LANGUAGE RankNTypes #-}

-- | Sole concrete IO composition for qualification-subject discovery.
module O2I.Operation.Qualification.Subjects.Runtime.Internal
  ( runQualificationSubjects
  , runQualificationSubjectsWith
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified O2I.ArchiMate.Profile.Closure as Closure
import qualified O2I.ArchiMate.Profile.Draft as Draft
import qualified O2I.ArchiMate.Profile.Notation as Notation
import qualified O2I.ArchiMate.Profile.Projection as Profile
import O2I.Core.Identity (OccurrenceIdentity)
import O2I.Operation.Acquisition
  ( AcquiredSource
  , AcquiredSupplementalSource
  , AcquisitionFailure
  , InputSource
  , acquireSource
  , acquiredModelSource
  , acquiredSourceIdentity
  , acquiredSupplementalSource
  , inputSourceReference
  )
import O2I.Operation.Adapter
  ( AdapterCollection
  , adapterDescriptorId
  , lookupAdapterContract
  , selectedAdapterDescriptor
  )
import O2I.Operation.Diagnostic
  ( noSupplementalDiagnosticGroups
  , preparedDiagnosticDocument
  )
import O2I.Operation.Diagnostic.Owner
  ( bindingDiagnosticGroups
  , foldNotationAssessmentDiagnostics
  , foldProfileAssessmentDiagnostics
  , profileActivationDiagnostics
  , semanticsEvidenceDiagnostic
  , structureEvidenceDiagnostic
  , withModelStructureAssessment
  )
import O2I.Operation.Diagnostic.Owner.Source
  ( assessOwnerSemantics
  , foldSupplementalOwnerBinding
  , withAdmittedOwnerSupplementalInputs
  , withBoundAdmittedOwnerSupplementalInputs
  )
import O2I.Operation.Failure
  ( commandFailure
  , inputAcquisitionFailure
  , preparationFailure
  )
import O2I.Operation.Preparation (withPreparedSelectedView)
import O2I.Operation.Profile (ProfileInventory)
import O2I.Operation.Provenance (SourceOrdinal, SourceRole(..), sourceOrdinal)
import O2I.Operation.Qualification.Subjects.Request
  ( QualificationSubjectsRequest
  , qualificationSubjectsAdapterId
  , qualificationSubjectsModelInput
  , qualificationSubjectsSupplementalInputs
  , qualificationSubjectsViewSelector
  )
import O2I.Operation.Qualification.Subjects.Result.Internal
import qualified O2I.Operation.Request as Request
import qualified O2I.Qualification as Qualification
import qualified O2I.Semantics as Semantics
import qualified O2I.Structure as Structure

-- | Execute one immutable discovery request through shared preparation.
runQualificationSubjects ::
     AdapterCollection
  -> ProfileInventory
  -> QualificationSubjectsRequest
  -> IO QualificationSubjectsResult
runQualificationSubjects = runQualificationSubjectsWith acquireSource

-- | Test seam for the sole physical IO boundary.
runQualificationSubjectsWith ::
     (SourceRole -> SourceOrdinal -> InputSource -> IO
                                                      (Either
                                                         AcquisitionFailure
                                                         AcquiredSource))
  -> AdapterCollection
  -> ProfileInventory
  -> QualificationSubjectsRequest
  -> IO QualificationSubjectsResult
runQualificationSubjectsWith acquire adapters profiles request = do
  acquired <-
    acquire
      ModelRole
      (sourceOrdinal 0)
      (qualificationSubjectsModelInput request)
  case acquired of
    Left failure ->
      pure
        (QualificationSubjectsFailed
           (QualificationSubjectsCommonFailure
              (commandFailure (inputAcquisitionFailure failure))))
    Right source ->
      case acquiredModelSource source of
        Nothing ->
          pure
            (internalFailure
               (QualificationSubjectsAcquiredModelRoleFailure
                  (acquiredSourceIdentity source)))
        Just model -> preparedPrefix model
  where
    preparedPrefix model =
      withPreparedSelectedView
        adapters
        profiles
        (qualificationSubjectsAdapterId request)
        (Request.qualificationRequest
           (qualificationSubjectsViewSelector request)
           (map
              inputSourceReference
              (qualificationSubjectsSupplementalInputs request)))
        model
        (pure
           . QualificationSubjectsFailed
           . QualificationSubjectsCommonFailure
           . preparationFailure)
        preparedStages
    preparedStages authority selected _ _ _ selectedView universe _ =
      case lookupAdapterContract
             (adapterDescriptorId (selectedAdapterDescriptor selected))
             adapters of
        Nothing ->
          pure
            (internalFailure
               (QualificationSubjectsSelectedAdapterContractFailure
                  (selectedAdapterDescriptor selected)))
        Just contract ->
          let notation = Notation.assessArchiMateNotation universe
           in foldNotationAssessmentDiagnostics
                (pure
                   . internalFailure
                   . QualificationSubjectsNotationContractFailure)
                (afterNotation authority selectedView universe notation)
                authority
                contract
                notation
    afterNotation authority selectedView universe notation diagnostics =
      Notation.foldStageResult
        (const
           (finishPrerequisite
              authority
              QualificationSubjectsNotationPrerequisite
              selectedView
              []
              diagnostics
              noSupplementalDiagnosticGroups))
        (afterProfile authority selectedView universe diagnostics)
        (Notation.notationConformance notation)
    afterProfile authority selectedView universe diagnostics conformant =
      let assessment = Profile.assessSelectedView conformant
          activation = profileActivationDiagnostics authority universe
       in Profile.foldProfileProjectionAssessment
            (pure
               . internalFailure
               . QualificationSubjectsProfileContractFailure)
            (\_ ->
               foldProfileAssessmentDiagnostics
                 (pure
                    . internalFailure
                    . QualificationSubjectsProfileContractFailure)
                 (\profileDiagnostics ->
                    finishPrerequisite
                      authority
                      QualificationSubjectsProfilePrerequisite
                      selectedView
                      []
                      (diagnostics <> activation <> profileDiagnostics)
                      noSupplementalDiagnosticGroups)
                 authority
                 assessment)
            (\projection ->
               foldProfileAssessmentDiagnostics
                 (pure
                    . internalFailure
                    . QualificationSubjectsProfileContractFailure)
                 (afterProfileAcceptance
                    authority
                    selectedView
                    universe
                    (diagnostics <> activation)
                    projection)
                 authority
                 assessment)
            assessment
    afterProfileAcceptance authority selectedView universe diagnostics projection profileDiagnostics = do
      acquired <-
        acquireSupplementalSources
          acquire
          (qualificationSubjectsSupplementalInputs request)
      case acquired of
        Left failure -> pure (QualificationSubjectsFailed failure)
        Right supplements ->
          withAdmittedOwnerSupplementalInputs
            authority
            supplements
            (pure
               . internalFailure
               . QualificationSubjectsSupplementalProvenanceFailure)
            (pure
               . QualificationSubjectsFailed
               . QualificationSubjectsSupplementalInputFailure)
            (\admitted ->
               assessStructure
                 authority
                 selectedView
                 universe
                 supplements
                 (diagnostics <> profileDiagnostics)
                 admitted
                 projection)
    assessStructure authority selectedView universe supplements diagnostics admitted projection =
      withModelStructureAssessment
        authority
        projection
        (pure . internalFailure . QualificationSubjectsIdentityIndexFailure)
        (pure . internalFailure . QualificationSubjectsSelectedViewScopeFailure)
        (pure . internalFailure . QualificationSubjectsStructureInputFailure)
        (\scope assessment ->
           Structure.foldStructureAssessment
             (\evidence ->
                finishPrerequisite
                  authority
                  QualificationSubjectsStructurePrerequisite
                  selectedView
                  supplements
                  (diagnostics
                     <> map
                          (structureEvidenceDiagnostic scope)
                          (NonEmpty.toList evidence))
                  noSupplementalDiagnosticGroups)
             (\graph ->
                withBoundAdmittedOwnerSupplementalInputs
                  scope
                  graph
                  admitted
                  (completeSemantics
                     authority
                     selectedView
                     universe
                     supplements
                     diagnostics
                     scope
                     graph))
             assessment)
    completeSemantics authority selectedView universe supplements diagnostics scope graph binding =
      foldSupplementalOwnerBinding
        (\bound _ ->
           let assessment = assessOwnerSemantics graph bound
               groups = bindingDiagnosticGroups binding
               complete semanticDiagnostics =
                 finishDiscovery
                   authority
                   selectedView
                   universe
                   supplements
                   (diagnostics <> semanticDiagnostics)
                   groups
                   graph
                   assessment
            in Semantics.foldSemanticAssessment
                 (complete
                    . map (semanticsEvidenceDiagnostic scope)
                    . NonEmpty.toList)
                 (complete [])
                 (const (complete []))
                 assessment)
        binding
    finishDiscovery authority selectedView universe supplements diagnostics groups graph semantics =
      case Qualification.prepareQualificationContext graph semantics of
        Left failure ->
          pure (internalFailure (QualificationSubjectsContextFailure failure))
        Right context ->
          case projectQualificationSubjects
                 universe
                 (Qualification.qualificationSubjects context) of
            Left failure -> pure (internalFailure failure)
            Right inventory ->
              pure
                (QualificationSubjectsDiscoveredResult
                   inventory
                   (prepared
                      authority
                      selectedView
                      supplements
                      diagnostics
                      groups))
    finishPrerequisite authority stage selectedView supplements diagnostics groups =
      pure
        (QualificationSubjectsPrerequisiteRejectedResult
           stage
           (prepared authority selectedView supplements diagnostics groups))
    prepared authority selectedView supplements diagnostics groups =
      PreparedQualificationSubjects
        request
        selectedView
        supplements
        (preparedDiagnosticDocument authority diagnostics groups)

acquireSupplementalSources ::
     (SourceRole -> SourceOrdinal -> InputSource -> IO
                                                      (Either
                                                         AcquisitionFailure
                                                         AcquiredSource))
  -> [InputSource]
  -> IO (Either QualificationSubjectsFailure [AcquiredSupplementalSource])
acquireSupplementalSources acquire = go 0 []
  where
    go _ acquired [] = pure (Right (reverse acquired))
    go ordinal acquired (input:remaining) = do
      result <- acquire SupplementalRole (sourceOrdinal ordinal) input
      case result of
        Left failure ->
          pure
            (Left
               (QualificationSubjectsCommonFailure
                  (commandFailure (inputAcquisitionFailure failure))))
        Right source ->
          case acquiredSupplementalSource source of
            Nothing ->
              pure
                (Left
                   (QualificationSubjectsOwnerContractFailure
                      (QualificationSubjectsAcquiredSupplementalRoleFailure
                         (acquiredSourceIdentity source))))
            Just supplemental ->
              go (ordinal + 1) (supplemental : acquired) remaining

type DisplayRecordIndex
  = Map.Map
      OccurrenceIdentity
      [(Notation.CanonicalOccurrence, [Notation.CanonicalField])]

projectQualificationSubjects ::
     Closure.ProfileAssessmentUniverse profile document
  -> Qualification.QualificationSubjects scope
  -> Either QualificationSubjectsInternalFailure QualificationSubjectsInventory
projectQualificationSubjects universe subjects = do
  records <- displayRecordIndex universe
  needs <-
    traverse
      (projectQualificationSubject QualificationNeedSubject records)
      (Qualification.qualificationNeedSubjects subjects)
  strategies <-
    traverse
      (projectQualificationSubject QualificationStrategySubject records)
      (Qualification.qualificationStrategySubjects subjects)
  pure (QualificationSubjectsInventory needs strategies)

displayRecordIndex ::
     Closure.ProfileAssessmentUniverse profile document
  -> Either QualificationSubjectsInternalFailure DisplayRecordIndex
displayRecordIndex universe =
  go
    Map.empty
    (Notation.canonicalDocumentRecords
       (Closure.assessmentCanonicalDocument universe))
  where
    go records [] = Right records
    go records (record:remaining) =
      Notation.foldCanonicalRecord
        (\occurrence _ _ _ fields ->
           case Profile.canonicalOccurrenceIdentity occurrence of
             Left defect ->
               Left
                 (QualificationSubjectsOccurrenceProjectionFailure
                    occurrence
                    defect)
             Right identity ->
               go
                 (Map.insertWith
                    (flip (<>))
                    identity
                    [(occurrence, fields)]
                    records)
                 remaining)
        record

projectQualificationSubject ::
     QualificationSubjectCategory
  -> DisplayRecordIndex
  -> Qualification.QualificationSubject
  -> Either QualificationSubjectsInternalFailure DiscoveredQualificationSubject
projectQualificationSubject category records subject =
  case Map.findWithDefault [] occurrence records of
    [(_, fields)] ->
      Right
        (DiscoveredQualificationSubject
           category
           (Qualification.qualificationSubjectIdentity subject)
           occurrence
           (Qualification.qualificationSubjectQualifiedEndpoint subject)
           (displayName fields)
           (subjectEligibility
              (Qualification.qualificationSubjectEligibility subject)))
    candidates ->
      Left
        (QualificationSubjectsOccurrenceJoinFailure
           occurrence
           (map fst candidates))
  where
    occurrence = Qualification.qualificationSubjectOccurrence subject

displayName :: [Notation.CanonicalField] -> Maybe Text
displayName fields =
  case filter isNameField fields of
    [field] ->
      case Notation.canonicalFieldScalars field of
        [scalar] ->
          Draft.foldDraftScalarValue
            Just
            (const Nothing)
            (const Nothing)
            (const Nothing)
            (\_ _ -> Nothing)
            scalar
        _ -> Nothing
    _ -> Nothing
  where
    isNameField =
      Draft.foldDraftFieldValue False True False False False
        . Notation.canonicalFieldKind

subjectEligibility ::
     Qualification.QualificationSubjectEligibility
  -> QualificationSubjectEligibility
subjectEligibility eligibility =
  case eligibility of
    Qualification.QualificationSubjectEligible -> QualificationSubjectEligible
    Qualification.QualificationSubjectIneligible ->
      QualificationSubjectIneligible
    Qualification.QualificationSubjectEligibilityUnavailable ->
      QualificationSubjectEligibilityUnavailable

internalFailure ::
     QualificationSubjectsInternalFailure -> QualificationSubjectsResult
internalFailure =
  QualificationSubjectsFailed . QualificationSubjectsOwnerContractFailure
