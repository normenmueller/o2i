{-# LANGUAGE RankNTypes #-}

-- | Sole concrete IO composition for formal qualification assessment.
module O2I.Operation.Qualify.Runtime.Internal
  ( runQualify
  , runQualifyWith
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified O2I.ArchiMate.Profile.Notation as Notation
import qualified O2I.ArchiMate.Profile.Projection as Profile
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
  ( CommandFailure
  , CommonFailure
  , commandFailure
  , inputAcquisitionFailure
  , preparationFailure
  )
import O2I.Operation.Preparation (withPreparedSelectedView)
import O2I.Operation.Profile (ProfileInventory)
import O2I.Operation.Provenance (SourceOrdinal, SourceRole(..), sourceOrdinal)
import O2I.Operation.Qualify.Request
  ( QualifyRequest
  , qualifyAdapterId
  , qualifyModelInput
  , qualifyNeedSelectors
  , qualifyStrategySelectors
  , qualifySupplementalInputs
  , qualifyViewSelector
  )
import O2I.Operation.Qualify.Result.Internal
import qualified O2I.Operation.Request as Request
import qualified O2I.Qualification as Qualification
import qualified O2I.Semantics as Semantics
import qualified O2I.Structure as Structure

-- | Execute one immutable Qualify request through shared preparation.
runQualify ::
     AdapterCollection -> ProfileInventory -> QualifyRequest -> IO QualifyResult
runQualify = runQualifyWith acquireSource

-- | Test seam for the sole physical IO boundary.
runQualifyWith ::
     (SourceRole -> SourceOrdinal -> InputSource -> IO
                                                      (Either
                                                         AcquisitionFailure
                                                         AcquiredSource))
  -> AdapterCollection
  -> ProfileInventory
  -> QualifyRequest
  -> IO QualifyResult
runQualifyWith acquire adapters profiles request = do
  acquired <- acquire ModelRole (sourceOrdinal 0) (qualifyModelInput request)
  case acquired of
    Left failure ->
      pure (commandFailureResult (inputAcquisitionFailure failure))
    Right source ->
      case acquiredModelSource source of
        Nothing ->
          pure
            (internalFailure
               (QualifyAcquiredModelRoleFailure (acquiredSourceIdentity source)))
        Just model -> preparedPrefix model
  where
    preparedPrefix model =
      withPreparedSelectedView
        adapters
        profiles
        (qualifyAdapterId request)
        (Request.qualificationRequest
           (qualifyViewSelector request)
           (map inputSourceReference (qualifySupplementalInputs request)))
        model
        (pure . commonFailureResult . preparationFailure)
        preparedStages
    preparedStages authority selected _ _ _ selectedView universe _ =
      case lookupAdapterContract
             (adapterDescriptorId (selectedAdapterDescriptor selected))
             adapters of
        Nothing ->
          pure
            (internalFailure
               (QualifySelectedAdapterContractFailure
                  (selectedAdapterDescriptor selected)))
        Just contract ->
          let notation = Notation.assessArchiMateNotation universe
           in foldNotationAssessmentDiagnostics
                (pure . internalFailure . QualifyNotationContractFailure)
                (afterNotation authority selectedView universe notation)
                authority
                contract
                notation
    afterNotation authority selectedView universe notation diagnostics =
      Notation.foldStageResult
        (const
           (finishPrerequisite
              authority
              QualifyNotationPrerequisite
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
            (pure . internalFailure . QualifyProfileContractFailure)
            (\_ ->
               foldProfileAssessmentDiagnostics
                 (pure . internalFailure . QualifyProfileContractFailure)
                 (\profileDiagnostics ->
                    finishPrerequisite
                      authority
                      QualifyProfilePrerequisite
                      selectedView
                      []
                      (diagnostics <> activation <> profileDiagnostics)
                      noSupplementalDiagnosticGroups)
                 authority
                 assessment)
            (\projection ->
               foldProfileAssessmentDiagnostics
                 (pure . internalFailure . QualifyProfileContractFailure)
                 (afterProfileAcceptance
                    authority
                    selectedView
                    (diagnostics <> activation)
                    projection)
                 authority
                 assessment)
            assessment
    afterProfileAcceptance authority selectedView diagnostics projection profileDiagnostics = do
      acquired <-
        acquireSupplementalSources acquire (qualifySupplementalInputs request)
      case acquired of
        Left failure -> pure (QualifyFailed failure)
        Right supplements ->
          withAdmittedOwnerSupplementalInputs
            authority
            supplements
            (pure . internalFailure . QualifySupplementalProvenanceFailure)
            (pure . QualifyFailed . QualifySupplementalInputFailure)
            (\admitted ->
               assessStructure
                 authority
                 selectedView
                 supplements
                 (diagnostics <> profileDiagnostics)
                 admitted
                 projection)
    assessStructure authority selectedView supplements diagnostics admitted projection =
      withModelStructureAssessment
        authority
        projection
        (pure . internalFailure . QualifyIdentityIndexFailure)
        (pure . internalFailure . QualifySelectedViewScopeFailure)
        (pure . internalFailure . QualifyStructureInputFailure)
        (\scope assessment ->
           Structure.foldStructureAssessment
             (\evidence ->
                finishPrerequisite
                  authority
                  QualifyStructurePrerequisite
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
                     supplements
                     diagnostics
                     scope
                     graph
                     projection))
             assessment)
    completeSemantics authority selectedView supplements diagnostics scope graph projection binding =
      foldSupplementalOwnerBinding
        (\bound _ ->
           let assessment = assessOwnerSemantics graph bound
               groups = bindingDiagnosticGroups binding
               complete semanticDiagnostics =
                 finishQualification
                   authority
                   selectedView
                   supplements
                   (diagnostics <> semanticDiagnostics)
                   groups
                   graph
                   assessment
                   projection
            in Semantics.foldSemanticAssessment
                 (complete
                    . map (semanticsEvidenceDiagnostic scope)
                    . NonEmpty.toList)
                 (complete [])
                 (const (complete []))
                 assessment)
        binding
    finishQualification authority selectedView supplements diagnostics groups graph semantics projection =
      case Qualification.prepareQualificationContext graph semantics of
        Left failure -> pure (internalFailure (QualifyContextFailure failure))
        Right context ->
          let subjects = Qualification.qualificationSubjects context
              selectedNeeds =
                case qualifyNeedSelectors request of
                  [] ->
                    map
                      (Qualification.qualificationNeedSelector
                         . Qualification.qualificationSubjectIdentity)
                      (Qualification.qualificationNeedSubjects subjects)
                  needs -> map Qualification.qualificationNeedSelector needs
              selectedStrategies =
                fmap
                  Qualification.qualificationStrategySelector
                  (qualifyStrategySelectors request)
              proposals =
                map
                  profileProposalInput
                  (Profile.profileQualificationProposals projection)
              assessment =
                Qualification.assessQualification
                  context
                  selectedNeeds
                  selectedStrategies
                  proposals
           in pure
                (QualifyCompletedResult
                   assessment
                   (PreparedQualify
                      request
                      selectedView
                      supplements
                      (preparedDiagnosticDocument authority diagnostics groups)))
    finishPrerequisite authority stage selectedView supplements diagnostics groups =
      pure
        (QualifyPrerequisiteRejectedResult
           stage
           (PreparedQualify
              request
              selectedView
              supplements
              (preparedDiagnosticDocument authority diagnostics groups)))

profileProposalInput ::
     Profile.QualificationProposal -> Qualification.QualificationProposalInput
profileProposalInput proposal =
  Qualification.qualificationProposalInput
    (Profile.qualificationProposalOccurrence proposal)
    (Profile.qualificationProposalIdentity proposal)
    (Profile.qualificationRationaleValue
       <$> Profile.qualificationProposalRationale proposal)
    (map profileSource (Profile.qualificationProposalSources proposal))
    (map profileReference (Profile.qualificationProposalReferences proposal))
  where
    profileSource source =
      ( Profile.qualificationSourceOccurrence source
      , Profile.qualificationSourceValue source)
    profileReference reference =
      ( Profile.qualificationReferenceOccurrence reference
      , Profile.qualificationReferenceRole reference
      , Profile.qualificationReferenceTarget reference)

acquireSupplementalSources ::
     (SourceRole -> SourceOrdinal -> InputSource -> IO
                                                      (Either
                                                         AcquisitionFailure
                                                         AcquiredSource))
  -> [InputSource]
  -> IO (Either QualifyFailure [AcquiredSupplementalSource])
acquireSupplementalSources acquire = go 0 []
  where
    go _ acquired [] = pure (Right (reverse acquired))
    go ordinal acquired (input:remaining) = do
      result <- acquire SupplementalRole (sourceOrdinal ordinal) input
      case result of
        Left failure ->
          pure
            (Left
               (QualifyCommonFailure
                  (commandFailure (inputAcquisitionFailure failure))))
        Right source ->
          case acquiredSupplementalSource source of
            Nothing ->
              pure
                (Left
                   (QualifyOwnerContractFailure
                      (QualifyAcquiredSupplementalRoleFailure
                         (acquiredSourceIdentity source))))
            Just supplemental ->
              go (ordinal + 1) (supplemental : acquired) remaining

commandFailureResult :: CommandFailure -> QualifyResult
commandFailureResult = QualifyFailed . QualifyCommonFailure . commandFailure

commonFailureResult :: CommonFailure -> QualifyResult
commonFailureResult = QualifyFailed . QualifyCommonFailure

internalFailure :: QualifyInternalFailure -> QualifyResult
internalFailure = QualifyFailed . QualifyOwnerContractFailure
