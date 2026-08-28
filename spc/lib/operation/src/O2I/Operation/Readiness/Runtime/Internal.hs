{-# LANGUAGE RankNTypes #-}

-- | Sole concrete IO composition for evidence-readiness evaluation.
module O2I.Operation.Readiness.Runtime.Internal
  ( runReadiness
  , runReadinessWith
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified O2I.ArchiMate.Profile.Notation as Notation
import qualified O2I.ArchiMate.Profile.Projection as Profile
import O2I.Operation.Acquisition
  ( AcquiredReadinessSource
  , AcquiredSource
  , AcquiredSupplementalSource
  , AcquisitionFailure
  , InputSource
  , acquireSource
  , acquiredModelSource
  , acquiredReadinessSource
  , acquiredSourceBytes
  , acquiredSourceIdentity
  , acquiredSupplementalSource
  , foldAcquiredReadinessSource
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
import qualified O2I.Operation.Readiness.Request as ReadinessRequest
import O2I.Operation.Readiness.Request (ReadinessRequest)
import O2I.Operation.Readiness.Result.Internal
import qualified O2I.Operation.Request as Request
import qualified O2I.Readiness as Readiness
import qualified O2I.Semantics as Semantics
import qualified O2I.Structure as Structure

runReadiness ::
     AdapterCollection
  -> ProfileInventory
  -> ReadinessRequest
  -> IO ReadinessResult
runReadiness = runReadinessWith acquireSource

runReadinessWith ::
     (SourceRole -> SourceOrdinal -> InputSource -> IO
                                                      (Either
                                                         AcquisitionFailure
                                                         AcquiredSource))
  -> AdapterCollection
  -> ProfileInventory
  -> ReadinessRequest
  -> IO ReadinessResult
runReadinessWith acquire adapters profiles request = do
  acquired <-
    acquire
      ModelRole
      (sourceOrdinal 0)
      (ReadinessRequest.readinessModelInput request)
  case acquired of
    Left failure ->
      pure (commandFailureResult (inputAcquisitionFailure failure))
    Right source ->
      case acquiredModelSource source of
        Nothing ->
          pure
            (internalFailure
               (ReadinessAcquiredModelRoleFailure
                  (acquiredSourceIdentity source)))
        Just model -> preparedPrefix model
  where
    preparedPrefix model =
      withPreparedSelectedView
        adapters
        profiles
        (ReadinessRequest.readinessAdapterId request)
        (Request.readinessRequest
           (ReadinessRequest.readinessViewSelector request)
           (inputSourceReference
              (ReadinessRequest.readinessEvidenceInput request))
           (map
              inputSourceReference
              (ReadinessRequest.readinessSupplementalInputs request)))
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
               (ReadinessSelectedAdapterContractFailure
                  (selectedAdapterDescriptor selected)))
        Just contract ->
          let notation = Notation.assessArchiMateNotation universe
           in foldNotationAssessmentDiagnostics
                (pure . internalFailure . ReadinessNotationContractFailure)
                (afterNotation authority selectedView universe notation)
                authority
                contract
                notation
    afterNotation authority selectedView universe notation diagnostics =
      Notation.foldStageResult
        (const
           (finishPrerequisite
              authority
              ReadinessNotationPrerequisite
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
            (pure . internalFailure . ReadinessProfileContractFailure)
            (\_ ->
               foldProfileAssessmentDiagnostics
                 (pure . internalFailure . ReadinessProfileContractFailure)
                 (\profileDiagnostics ->
                    finishPrerequisite
                      authority
                      ReadinessProfilePrerequisite
                      selectedView
                      Nothing
                      []
                      (diagnostics <> activation <> profileDiagnostics)
                      noSupplementalDiagnosticGroups)
                 authority
                 assessment)
            (\projection ->
               foldProfileAssessmentDiagnostics
                 (pure . internalFailure . ReadinessProfileContractFailure)
                 (afterProfileAcceptance
                    authority
                    selectedView
                    (diagnostics <> activation)
                    projection)
                 authority
                 assessment)
            assessment
    afterProfileAcceptance authority selectedView diagnostics projection profileDiagnostics = do
      evidenceResult <- acquireEvidenceSource acquire request
      case evidenceResult of
        Left failure -> pure (ReadinessFailed failure)
        Right evidence ->
          case decodeEvidence evidence of
            Left defects ->
              pure (ReadinessFailed (ReadinessEvidenceInputFailure defects))
            Right input -> do
              supplementalResult <-
                acquireSupplementalSources
                  acquire
                  (ReadinessRequest.readinessSupplementalInputs request)
              case supplementalResult of
                Left failure -> pure (ReadinessFailed failure)
                Right supplements ->
                  withAdmittedOwnerSupplementalInputs
                    authority
                    supplements
                    (pure
                       . internalFailure
                       . ReadinessSupplementalProvenanceFailure)
                    (pure . ReadinessFailed . ReadinessSupplementalInputFailure)
                    (\admitted ->
                       assessStructure
                         authority
                         selectedView
                         evidence
                         supplements
                         (diagnostics <> profileDiagnostics)
                         input
                         admitted
                         projection)
    assessStructure authority selectedView evidence supplements diagnostics input admitted projection =
      withModelStructureAssessment
        authority
        projection
        (pure . internalFailure . ReadinessIdentityIndexFailure)
        (pure . internalFailure . ReadinessSelectedViewScopeFailure)
        (pure . internalFailure . ReadinessStructureInputFailure)
        (\scope assessment ->
           Structure.foldStructureAssessment
             (\failures ->
                finishPrerequisite
                  authority
                  ReadinessStructurePrerequisite
                  selectedView
                  (Just evidence)
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
                evidence
                supplements
                diagnostics
                input
                admitted)
             assessment)
    afterStructure authority scope selectedView evidence supplements diagnostics input admitted graph =
      Readiness.foldReadinessInputBinding
        (\unbound defects ->
           finishUnavailable
             authority
             selectedView
             evidence
             supplements
             diagnostics
             noSupplementalDiagnosticGroups
             (ReadinessInputBindingUnavailable
                (Readiness.evidencePlanTraceIdentity
                   (Readiness.readinessEvidencePlan unbound))
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
                evidence
                supplements
                diagnostics
                bound
                graph))
        (Readiness.bindReadinessInput graph input)
    completeSemantics authority scope selectedView evidence supplements diagnostics bound graph binding =
      foldSupplementalOwnerBinding
        (\admitted _ ->
           let assessment = assessOwnerSemantics graph admitted
               groups = bindingDiagnosticGroups binding
               continue =
                 finishReadiness
                   authority
                   selectedView
                   evidence
                   supplements
                   diagnostics
                   groups
                   assessment
                   bound
               rejected semanticFailures =
                 finishPrerequisite
                   authority
                   ReadinessSemanticsPrerequisite
                   selectedView
                   (Just evidence)
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
                           (ReadinessSemanticModelContractFailure
                              (Semantics.semanticCandidateOccurrences assessment)))
                    Just model -> continue model)
                 continue
                 assessment)
        binding
    finishReadiness authority selectedView evidence supplements diagnostics groups semanticAssessment bound model =
      Readiness.foldReadinessSubjectAssessment
        (\graph trace reasons ->
           finishUnavailable
             authority
             selectedView
             evidence
             supplements
             diagnostics
             groups
             (ReadinessReconstructionUnavailable graph trace reasons))
        (\subject ->
           let assessment = Readiness.assessReadiness subject
            in Readiness.foldReadinessAssessment
                 (\_ _ _ ->
                    finishAssessment
                      ReadinessNotReadyResult
                      authority
                      selectedView
                      evidence
                      supplements
                      diagnostics
                      groups
                      assessment)
                 (const
                    (finishAssessment
                       ReadinessReadyResult
                       authority
                       selectedView
                       evidence
                       supplements
                       diagnostics
                       groups
                       assessment))
                 assessment)
        (Readiness.prepareReadinessSubject model semanticAssessment bound)
    finishAssessment constructor authority selectedView evidence supplements diagnostics groups assessment =
      pure
        (constructor
           assessment
           (prepared
              authority
              selectedView
              (Just evidence)
              supplements
              diagnostics
              groups))
    finishUnavailable authority selectedView evidence supplements diagnostics groups unavailable =
      pure
        (ReadinessSubjectUnavailableResult
           unavailable
           (prepared
              authority
              selectedView
              (Just evidence)
              supplements
              diagnostics
              groups))
    finishPrerequisite authority stage selectedView evidence supplements diagnostics groups =
      pure
        (ReadinessPrerequisiteRejectedResult
           stage
           (prepared
              authority
              selectedView
              evidence
              supplements
              diagnostics
              groups))
    prepared authority selectedView evidence supplements diagnostics groups =
      PreparedReadiness
        request
        selectedView
        evidence
        supplements
        (preparedDiagnosticDocument authority diagnostics groups)

decodeEvidence ::
     AcquiredReadinessSource
  -> Either
       (NonEmpty.NonEmpty Readiness.EvidenceInputDefect)
       Readiness.ReadinessInput
decodeEvidence =
  Readiness.decodeReadinessInput (Readiness.readinessInputOrdinal 0)
    . foldAcquiredReadinessSource acquiredSourceBytes

acquireEvidenceSource ::
     (SourceRole -> SourceOrdinal -> InputSource -> IO
                                                      (Either
                                                         AcquisitionFailure
                                                         AcquiredSource))
  -> ReadinessRequest
  -> IO (Either ReadinessFailure AcquiredReadinessSource)
acquireEvidenceSource acquire request = do
  result <-
    acquire
      ReadinessRole
      (sourceOrdinal 0)
      (ReadinessRequest.readinessEvidenceInput request)
  pure
    (case result of
       Left failure ->
         Left
           (ReadinessCommonFailure
              (commandFailure (inputAcquisitionFailure failure)))
       Right source ->
         case acquiredReadinessSource source of
           Nothing ->
             Left
               (ReadinessOwnerContractFailure
                  (ReadinessAcquiredEvidenceRoleFailure
                     (acquiredSourceIdentity source)))
           Just evidence -> Right evidence)

acquireSupplementalSources ::
     (SourceRole -> SourceOrdinal -> InputSource -> IO
                                                      (Either
                                                         AcquisitionFailure
                                                         AcquiredSource))
  -> [InputSource]
  -> IO (Either ReadinessFailure [AcquiredSupplementalSource])
acquireSupplementalSources acquire = go 0 []
  where
    go _ acquired [] = pure (Right (reverse acquired))
    go ordinal acquired (input:remaining) = do
      result <- acquire SupplementalRole (sourceOrdinal ordinal) input
      case result of
        Left failure ->
          pure
            (Left
               (ReadinessCommonFailure
                  (commandFailure (inputAcquisitionFailure failure))))
        Right source ->
          case acquiredSupplementalSource source of
            Nothing ->
              pure
                (Left
                   (ReadinessOwnerContractFailure
                      (ReadinessAcquiredSupplementalRoleFailure
                         (acquiredSourceIdentity source))))
            Just supplemental ->
              go (ordinal + 1) (supplemental : acquired) remaining

commandFailureResult :: CommandFailure -> ReadinessResult
commandFailureResult = ReadinessFailed . ReadinessCommonFailure . commandFailure

commonFailureResult :: CommonFailure -> ReadinessResult
commonFailureResult = ReadinessFailed . ReadinessCommonFailure

internalFailure :: ReadinessInternalFailure -> ReadinessResult
internalFailure = ReadinessFailed . ReadinessOwnerContractFailure
