{-# LANGUAGE RankNTypes #-}

-- | Sole concrete IO composition for selected-View evidence assessment.
module O2I.Operation.Assess.Runtime.Internal
  ( runAssess
  , runAssessWith
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified O2I.ArchiMate.Profile.Notation as Notation
import qualified O2I.ArchiMate.Profile.Projection as Profile
import qualified O2I.Assessment as Assessment
import O2I.Operation.Acquisition
  ( AcquiredAssessmentSource
  , AcquiredSource
  , AcquiredSupplementalSource
  , AcquisitionFailure
  , InputSource
  , acquireSource
  , acquiredAssessmentSource
  , acquiredModelSource
  , acquiredSourceBytes
  , acquiredSourceIdentity
  , acquiredSupplementalSource
  , foldAcquiredAssessmentSource
  , inputSourceReference
  )
import O2I.Operation.Adapter
  ( AdapterCollection
  , adapterDescriptorId
  , lookupAdapterContract
  , selectedAdapterDescriptor
  )
import qualified O2I.Operation.Assess.Request as AssessRequest
import O2I.Operation.Assess.Request (AssessRequest)
import O2I.Operation.Assess.Result.Internal
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
import qualified O2I.Operation.Request as Request
import qualified O2I.Semantics as Semantics
import qualified O2I.Structure as Structure

runAssess ::
     AdapterCollection -> ProfileInventory -> AssessRequest -> IO AssessResult
runAssess = runAssessWith acquireSource

runAssessWith ::
     (SourceRole -> SourceOrdinal -> InputSource -> IO
                                                      (Either
                                                         AcquisitionFailure
                                                         AcquiredSource))
  -> AdapterCollection
  -> ProfileInventory
  -> AssessRequest
  -> IO AssessResult
runAssessWith acquire adapters profiles request = do
  acquired <-
    acquire ModelRole (sourceOrdinal 0) (AssessRequest.assessModelInput request)
  case acquired of
    Left failure ->
      pure (commandFailureResult (inputAcquisitionFailure failure))
    Right source ->
      case acquiredModelSource source of
        Nothing ->
          pure
            (internalFailure
               (AssessAcquiredModelRoleFailure (acquiredSourceIdentity source)))
        Just model -> preparedPrefix model
  where
    preparedPrefix model =
      withPreparedSelectedView
        adapters
        profiles
        (AssessRequest.assessAdapterId request)
        (Request.assessmentRequest
           (AssessRequest.assessViewSelector request)
           (inputSourceReference (AssessRequest.assessBundleInput request))
           (map
              inputSourceReference
              (AssessRequest.assessSupplementalInputs request)))
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
               (AssessSelectedAdapterContractFailure
                  (selectedAdapterDescriptor selected)))
        Just contract ->
          let notation = Notation.assessArchiMateNotation universe
           in foldNotationAssessmentDiagnostics
                (pure . internalFailure . AssessNotationContractFailure)
                (afterNotation authority selectedView universe notation)
                authority
                contract
                notation
    afterNotation authority selectedView universe notation diagnostics =
      Notation.foldStageResult
        (const
           (finishPrerequisite
              authority
              AssessNotationPrerequisite
              selectedView
              Nothing
              []
              diagnostics
              noSupplementalDiagnosticGroups))
        (afterProfile authority selectedView universe diagnostics)
        (Notation.notationConformance notation)
    afterProfile authority selectedView universe diagnostics conformant =
      let assessment = Profile.assessSelectedView conformant
          activation = profileActivationDiagnostics authority universe
       in Profile.foldProfileProjectionAssessment
            (pure . internalFailure . AssessProfileContractFailure)
            (\_ ->
               foldProfileAssessmentDiagnostics
                 (pure . internalFailure . AssessProfileContractFailure)
                 (\profileDiagnostics ->
                    finishPrerequisite
                      authority
                      AssessProfilePrerequisite
                      selectedView
                      Nothing
                      []
                      (diagnostics <> activation <> profileDiagnostics)
                      noSupplementalDiagnosticGroups)
                 authority
                 assessment)
            (\projection ->
               foldProfileAssessmentDiagnostics
                 (pure . internalFailure . AssessProfileContractFailure)
                 (afterProfileAcceptance
                    authority
                    selectedView
                    (diagnostics <> activation)
                    projection)
                 authority
                 assessment)
            assessment
    afterProfileAcceptance authority selectedView diagnostics projection profileDiagnostics = do
      bundleResult <- acquireAssessmentSource acquire request
      case bundleResult of
        Left failure -> pure (AssessFailed failure)
        Right bundle ->
          case decodeBundle bundle of
            Left defects ->
              pure (AssessFailed (AssessBundleInputFailure defects))
            Right input -> do
              supplementalResult <-
                acquireSupplementalSources
                  acquire
                  (AssessRequest.assessSupplementalInputs request)
              case supplementalResult of
                Left failure -> pure (AssessFailed failure)
                Right supplements ->
                  withAdmittedOwnerSupplementalInputs
                    authority
                    supplements
                    (pure
                       . internalFailure
                       . AssessSupplementalProvenanceFailure)
                    (pure . AssessFailed . AssessSupplementalInputFailure)
                    (\admitted ->
                       assessStructure
                         authority
                         selectedView
                         bundle
                         supplements
                         (diagnostics <> profileDiagnostics)
                         input
                         admitted
                         projection)
    assessStructure authority selectedView bundle supplements diagnostics input admitted projection =
      withModelStructureAssessment
        authority
        projection
        (pure . internalFailure . AssessIdentityIndexFailure)
        (pure . internalFailure . AssessSelectedViewScopeFailure)
        (pure . internalFailure . AssessStructureInputFailure)
        (\scope assessment ->
           Structure.foldStructureAssessment
             (\failures ->
                finishPrerequisite
                  authority
                  AssessStructurePrerequisite
                  selectedView
                  (Just bundle)
                  supplements
                  (diagnostics
                     <> map
                          (structureEvidenceDiagnostic scope)
                          (NonEmpty.toList failures))
                  noSupplementalDiagnosticGroups)
             (afterStructure
                authority
                scope
                selectedView
                bundle
                supplements
                diagnostics
                input
                admitted)
             assessment)
    afterStructure authority scope selectedView bundle supplements diagnostics input admitted graph =
      Assessment.foldAssessmentInputBinding
        (\unbound defects ->
           finishUnavailable
             authority
             selectedView
             bundle
             supplements
             diagnostics
             noSupplementalDiagnosticGroups
             (AssessInputBindingUnavailable
                (Assessment.assessmentBundleTraceIdentity unbound)
                defects))
        (\bound ->
           withBoundAdmittedOwnerSupplementalInputs
             scope
             graph
             admitted
             (completeSemantics
                authority
                scope
                selectedView
                bundle
                supplements
                diagnostics
                bound
                graph))
        (Assessment.bindAssessmentBundleInput graph input)
    completeSemantics authority scope selectedView bundle supplements diagnostics bound graph binding =
      foldSupplementalOwnerBinding
        (\admitted _ ->
           let assessment = assessOwnerSemantics graph admitted
               groups = bindingDiagnosticGroups binding
               continue =
                 finishAssessment
                   authority
                   selectedView
                   bundle
                   supplements
                   diagnostics
                   groups
                   assessment
                   bound
               rejected semanticFailures =
                 finishPrerequisite
                   authority
                   AssessSemanticsPrerequisite
                   selectedView
                   (Just bundle)
                   supplements
                   (diagnostics
                      <> map
                           (semanticsEvidenceDiagnostic scope)
                           (NonEmpty.toList semanticFailures))
                   groups
            in Semantics.foldSemanticAssessment
                 rejected
                 (case Semantics.semanticallyValidModel assessment of
                    Nothing ->
                      pure
                        (internalFailure
                           (AssessSemanticModelContractFailure
                              (Semantics.semanticCandidateOccurrences assessment)))
                    Just model -> continue model)
                 continue
                 assessment)
        binding
    finishAssessment authority selectedView bundle supplements diagnostics groups semanticAssessment bound model =
      Assessment.foldAssessmentSubjectAssessment
        (\graph trace reasons ->
           finishUnavailable
             authority
             selectedView
             bundle
             supplements
             diagnostics
             groups
             (AssessReconstructionUnavailable graph trace reasons))
        (\subject ->
           let result = Assessment.assessEvidence subject
               constructor =
                 case Assessment.assessmentDisposition result of
                   Assessment.AssessmentInputInvalidDisposition ->
                     AssessCollectionInvalidResult
                   Assessment.AssessmentObservationsInvalidDisposition ->
                     AssessObservationsInvalidResult
                   Assessment.AssessmentEvidenceAssessedDisposition ->
                     AssessCompletedResult
            in pure
                 (constructor
                    result
                    (prepared
                       authority
                       selectedView
                       (Just bundle)
                       supplements
                       diagnostics
                       groups)))
        (Assessment.prepareAssessmentSubject model semanticAssessment bound)
    finishUnavailable authority selectedView bundle supplements diagnostics groups unavailable =
      pure
        (AssessSubjectUnavailableResult
           unavailable
           (prepared
              authority
              selectedView
              (Just bundle)
              supplements
              diagnostics
              groups))
    finishPrerequisite authority stage selectedView bundle supplements diagnostics groups =
      pure
        (AssessPrerequisiteRejectedResult
           stage
           (prepared
              authority
              selectedView
              bundle
              supplements
              diagnostics
              groups))
    prepared authority selectedView bundle supplements diagnostics groups =
      PreparedAssess
        request
        selectedView
        bundle
        supplements
        (preparedDiagnosticDocument authority diagnostics groups)

decodeBundle ::
     AcquiredAssessmentSource
  -> Either
       (NonEmpty.NonEmpty Assessment.AssessmentInputDefect)
       Assessment.AssessmentBundleInput
decodeBundle =
  Assessment.decodeAssessmentBundleInput (Assessment.assessmentInputOrdinal 0)
    . foldAcquiredAssessmentSource acquiredSourceBytes

acquireAssessmentSource ::
     (SourceRole -> SourceOrdinal -> InputSource -> IO
                                                      (Either
                                                         AcquisitionFailure
                                                         AcquiredSource))
  -> AssessRequest
  -> IO (Either AssessFailure AcquiredAssessmentSource)
acquireAssessmentSource acquire request = do
  result <-
    acquire
      AssessmentRole
      (sourceOrdinal 0)
      (AssessRequest.assessBundleInput request)
  pure
    (case result of
       Left failure ->
         Left
           (AssessCommonFailure
              (commandFailure (inputAcquisitionFailure failure)))
       Right source ->
         case acquiredAssessmentSource source of
           Nothing ->
             Left
               (AssessOwnerContractFailure
                  (AssessAcquiredBundleRoleFailure
                     (acquiredSourceIdentity source)))
           Just bundle -> Right bundle)

acquireSupplementalSources ::
     (SourceRole -> SourceOrdinal -> InputSource -> IO
                                                      (Either
                                                         AcquisitionFailure
                                                         AcquiredSource))
  -> [InputSource]
  -> IO (Either AssessFailure [AcquiredSupplementalSource])
acquireSupplementalSources acquire = go 0 []
  where
    go _ acquired [] = pure (Right (reverse acquired))
    go ordinal acquired (input:remaining) = do
      result <- acquire SupplementalRole (sourceOrdinal ordinal) input
      case result of
        Left failure ->
          pure
            (Left
               (AssessCommonFailure
                  (commandFailure (inputAcquisitionFailure failure))))
        Right source ->
          case acquiredSupplementalSource source of
            Nothing ->
              pure
                (Left
                   (AssessOwnerContractFailure
                      (AssessAcquiredSupplementalRoleFailure
                         (acquiredSourceIdentity source))))
            Just supplemental ->
              go (ordinal + 1) (supplemental : acquired) remaining

commandFailureResult :: CommandFailure -> AssessResult
commandFailureResult = AssessFailed . AssessCommonFailure . commandFailure

commonFailureResult :: CommonFailure -> AssessResult
commonFailureResult = AssessFailed . AssessCommonFailure

internalFailure :: AssessInternalFailure -> AssessResult
internalFailure = AssessFailed . AssessOwnerContractFailure
