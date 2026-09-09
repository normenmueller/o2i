{-# LANGUAGE RankNTypes #-}

-- | Sole concrete IO composition for cumulative Validate execution.
module O2I.Operation.Validate.Runtime.Internal
  ( runValidate
  , runValidateWith
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.List.NonEmpty (NonEmpty)
import qualified O2I.ArchiMate.Profile.Notation as Notation
import qualified O2I.ArchiMate.Profile.Projection as Profile
import O2I.Core.Identity (ModelIdentity)
import O2I.Operation.Acquisition
  ( AcquiredSource
  , AcquiredSupplementalSource
  , AcquisitionFailure
  , InputSource
  , acquireSource
  , acquiredModelSource
  , acquiredSourceIdentity
  , acquiredSupplementalSource
  , foldAcquiredSupplementalSource
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
  ( SupplementalOwnerBindingGroup
  , assessOwnerSemantics
  , foldSupplementalOwnerBinding
  , foldSupplementalOwnerBindingGroup
  , withAdmittedOwnerSupplementalInputs
  , withBoundAdmittedOwnerSupplementalInputs
  )
import O2I.Operation.Failure
  ( CommonFailure
  , commandFailure
  , inputAcquisitionFailure
  , preparationFailure
  )
import O2I.Operation.Preparation (withPreparedSelectedView)
import O2I.Operation.Profile (ProfileInventory)
import O2I.Operation.Provenance
  ( SourceOrdinal
  , SourceRole(..)
  , sourceIdentityOrdinal
  , sourceOrdinal
  )
import O2I.Operation.Request (validationRequest)
import O2I.Operation.Validate.Request
  ( ValidateRequest
  , notationValidationLevel
  , profileValidationLevel
  , semanticsValidationLevel
  , structureValidationLevel
  , validateAdapterId
  , validateModelInput
  , validateRequestLevel
  , validateSupplementalInputs
  , validateViewSelector
  )
import O2I.Operation.Validate.Result.Internal
import qualified O2I.Semantics as Semantics
import qualified O2I.Structure as Structure

-- | Execute one immutable request with fail-fast acquisition and cumulative
-- first-stage assessment.
runValidate ::
     AdapterCollection
  -> ProfileInventory
  -> ValidateRequest
  -> IO ValidateResult
runValidate = runValidateWith acquireSource

-- | Test seam for the sole physical IO boundary. Production execution fixes
-- this function to 'acquireSource'; all decoding and assessment remain pure.
runValidateWith ::
     (SourceRole -> SourceOrdinal -> InputSource -> IO
                                                      (Either
                                                         AcquisitionFailure
                                                         AcquiredSource))
  -> AdapterCollection
  -> ProfileInventory
  -> ValidateRequest
  -> IO ValidateResult
runValidateWith acquire adapters profiles request = do
  acquired <- acquire ModelRole (sourceOrdinal 0) (validateModelInput request)
  case acquired of
    Left failure ->
      pure
        (commonFailureResult (commandFailure (inputAcquisitionFailure failure)))
    Right source ->
      case acquiredModelSource source of
        Nothing ->
          pure
            (internalFailureResult
               (ValidateAcquiredModelRoleFailure (acquiredSourceIdentity source)))
        Just model -> preparedPrefix model
  where
    preparedPrefix model =
      withPreparedSelectedView
        adapters
        profiles
        (validateAdapterId request)
        (validationRequest
           (validateViewSelector request)
           (map inputSourceReference (validateSupplementalInputs request)))
        model
        (pure . commonFailureResult . preparationFailure)
        preparedStages
    preparedStages authority selected _ _ _ selectedView universe _ =
      case lookupAdapterContract
             (adapterDescriptorId (selectedAdapterDescriptor selected))
             adapters of
        Nothing ->
          pure
            (internalFailureResult
               (ValidateSelectedAdapterContractFailure
                  (selectedAdapterDescriptor selected)))
        Just contract ->
          let notation = Notation.assessArchiMateNotation universe
           in foldNotationAssessmentDiagnostics
                (pure . internalFailureResult . ValidateNotationContractFailure)
                (afterNotation authority selectedView universe notation)
                authority
                contract
                notation
    afterNotation authority selectedView universe notation diagnostics =
      Notation.foldStageResult
        (const
           (finishPrepared
              authority
              ValidationRejected
              notationValidationLevel
              Nothing
              selectedView
              []
              diagnostics
              noSupplementalDiagnosticGroups))
        (\conformant ->
           if validateRequestLevel request == notationValidationLevel
             then finishPrepared
                    authority
                    ValidationAccepted
                    notationValidationLevel
                    Nothing
                    selectedView
                    []
                    diagnostics
                    noSupplementalDiagnosticGroups
             else afterProfile authority selectedView universe conformant)
        (Notation.notationConformance notation)
    afterProfile authority selectedView universe conformant =
      let assessment = Profile.assessSelectedView conformant
          activation = profileActivationDiagnostics authority universe
       in Profile.foldProfileProjectionAssessment
            (pure . internalFailureResult . ValidateProfileContractFailure)
            (\_ ->
               foldProfileAssessmentDiagnostics
                 (pure . internalFailureResult . ValidateProfileContractFailure)
                 (\diagnostics ->
                    finishPrepared
                      authority
                      ValidationRejected
                      profileValidationLevel
                      Nothing
                      selectedView
                      []
                      (activation <> diagnostics)
                      noSupplementalDiagnosticGroups)
                 authority
                 assessment)
            (\projection ->
               foldProfileAssessmentDiagnostics
                 (pure . internalFailureResult . ValidateProfileContractFailure)
                 (\diagnostics ->
                    if validateRequestLevel request == profileValidationLevel
                      then finishPrepared
                             authority
                             ValidationAccepted
                             profileValidationLevel
                             Nothing
                             selectedView
                             []
                             (activation <> diagnostics)
                             noSupplementalDiagnosticGroups
                      else afterProfileAcceptance
                             authority
                             selectedView
                             (activation <> diagnostics)
                             projection)
                 authority
                 assessment)
            assessment
    afterProfileAcceptance authority selectedView diagnostics projection =
      if validateRequestLevel request == semanticsValidationLevel
        then do
          acquired <-
            acquireSupplementalSources
              acquire
              (validateSupplementalInputs request)
          case acquired of
            Left failure -> pure (ValidateFailed failure)
            Right supplements ->
              withAdmittedOwnerSupplementalInputs
                authority
                supplements
                (pure
                   . internalFailureResult
                   . ValidateSupplementalProvenanceFailure)
                (pure . ValidateFailed . ValidateSupplementalInputFailure)
                (\admitted ->
                   assessStructure
                     authority
                     selectedView
                     supplements
                     diagnostics
                     (Just admitted)
                     projection)
        else assessStructure
               authority
               selectedView
               []
               diagnostics
               Nothing
               projection
    assessStructure authority selectedView supplements diagnostics admitted projection =
      withModelStructureAssessment
        authority
        projection
        (pure . internalFailureResult . ValidateIdentityIndexFailure)
        (pure . internalFailureResult . ValidateSelectedViewScopeFailure)
        (pure . internalFailureResult . ValidateStructureInputFailure)
        (\scope assessment ->
           Structure.foldStructureAssessment
             (\evidence ->
                finishPrepared
                  authority
                  ValidationRejected
                  structureValidationLevel
                  Nothing
                  selectedView
                  supplements
                  (diagnostics
                     <> map
                          (structureEvidenceDiagnostic scope)
                          (NonEmpty.toList evidence))
                  noSupplementalDiagnosticGroups)
             (\graph ->
                case admitted of
                  Nothing ->
                    finishPrepared
                      authority
                      ValidationAccepted
                      structureValidationLevel
                      Nothing
                      selectedView
                      supplements
                      diagnostics
                      noSupplementalDiagnosticGroups
                  Just inputs ->
                    withBoundAdmittedOwnerSupplementalInputs
                      scope
                      graph
                      inputs
                      (completeSemantics
                         authority
                         selectedView
                         supplements
                         diagnostics
                         scope
                         graph))
             assessment)
    completeSemantics authority selectedView supplements diagnostics scope graph binding =
      foldSupplementalOwnerBinding
        (\bound groups ->
           let unavailable = any bindingGroupHasDiagnostics groups
               semanticAssessment = assessOwnerSemantics graph bound
               finish disposition witnesses semanticDiagnostics =
                 finishPrepared
                   authority
                   disposition
                   semanticsValidationLevel
                   witnesses
                   selectedView
                   supplements
                   (diagnostics <> semanticDiagnostics)
                   (bindingDiagnosticGroups binding)
            in Semantics.foldSemanticAssessment
                 (\evidence ->
                    finish
                      (if unavailable
                         then ValidationUnavailable
                         else ValidationRejected)
                      (if unavailable
                         then NonEmpty.nonEmpty (bindingWitnesses groups)
                         else Nothing)
                      (map
                         (semanticsEvidenceDiagnostic scope)
                         (NonEmpty.toList evidence)))
                 (finishSemanticUnavailable
                    authority
                    selectedView
                    supplements
                    diagnostics
                    binding
                    groups
                    semanticAssessment)
                 (const
                    (finish
                       (if unavailable
                          then ValidationUnavailable
                          else ValidationAccepted)
                       (if unavailable
                          then NonEmpty.nonEmpty (bindingWitnesses groups)
                          else Nothing)
                       []))
                 semanticAssessment)
        binding
    finishSemanticUnavailable authority selectedView supplements diagnostics binding groups assessment =
      case semanticUnavailabilityWitnesses assessment of
        Nothing ->
          pure
            (internalFailureResult
               (ValidateSemanticUnavailableContractFailure
                  (Semantics.semanticCandidateOccurrences assessment)))
        Just semanticWitnesses ->
          finishPrepared
            authority
            ValidationUnavailable
            semanticsValidationLevel
            (Just
               (NonEmpty.fromList
                  (bindingWitnesses groups <> NonEmpty.toList semanticWitnesses)))
            selectedView
            supplements
            diagnostics
            (bindingDiagnosticGroups binding)
    finishPrepared authority disposition completed witnesses selectedView supplements diagnostics groups =
      let prepared =
            PreparedValidation
              request
              completed
              selectedView
              supplements
              (preparedDiagnosticDocument authority diagnostics groups)
       in pure
            (case disposition of
               ValidationAccepted -> ValidateAccepted prepared
               ValidationRejected -> ValidateRejected prepared
               ValidationUnavailable ->
                 case witnesses of
                   Just values -> ValidateUnavailable values prepared
                   Nothing ->
                     ValidateFailed
                       (ValidateOwnerContractFailure
                          (ValidateSemanticUnavailableContractFailure [])))

bindingWitnesses ::
     [SupplementalOwnerBindingGroup scope inputs]
  -> [ValidateUnavailabilityWitness]
bindingWitnesses = concatMap bindingWitness
  where
    bindingWitness =
      foldSupplementalOwnerBindingGroup $ \source evidence ->
        if null evidence
          then []
          else [ ValidateBindingUnavailable
                   (sourceIdentityOrdinal
                      (foldAcquiredSupplementalSource
                         acquiredSourceIdentity
                         source))
               ]

semanticUnavailabilityWitnesses ::
     Semantics.SemanticAssessment scope
  -> Maybe (NonEmpty ValidateUnavailabilityWitness)
semanticUnavailabilityWitnesses assessment = do
  strategies <-
    traverse
      strategyWitness
      (filter
         ((== Semantics.SubjectUnavailable)
            . Semantics.strategyFormulationDisposition)
         (Semantics.strategyFormulationAssessments assessment))
  collectives <-
    traverse
      collectiveWitnesses
      (filter
         ((== Semantics.SubjectUnavailable)
            . Semantics.collectiveStrategyRealizationDisposition)
         (Semantics.collectiveStrategyRealizationAssessments assessment))
  NonEmpty.nonEmpty (strategies <> concat collectives)

strategyWitness ::
     Semantics.StrategyFormulationAssessment scope
  -> Maybe ValidateUnavailabilityWitness
strategyWitness assessment =
  ValidateStrategyFormulationUnavailable
    (Semantics.strategyFormulationSubject assessment)
    <$> Semantics.strategyFormulationUnavailableReason assessment

collectiveWitnesses ::
     Semantics.CollectiveStrategyRealizationAssessment scope
  -> Maybe [ValidateUnavailabilityWitness]
collectiveWitnesses assessment = do
  components <- Semantics.collectiveStrategyRealizationComponents assessment
  fit <- fitWitnesses claim components
  primitives <-
    traverse
      (primitiveWitness claim)
      (filter
         ((== Semantics.ComponentUnavailable)
            . Semantics.primitiveSupportDisposition)
         (Semantics.collectivePrimitiveSupportAssessments components))
  let coverage =
        if Semantics.collectiveCoverageDisposition components
             == Semantics.ComponentUnavailable
          then [ ValidateCollectiveCoverageUnavailable
                   claim
                   (Semantics.collectiveCoverageBlockingStrategies components)
               ]
          else []
      witnesses = fit <> coverage <> primitives
  if null witnesses
    then Nothing
    else Just witnesses
  where
    claim = Semantics.collectiveStrategyRealizationSubject assessment

fitWitnesses ::
     ModelIdentity
  -> Semantics.CollectiveStrategyRealizationComponents scope
  -> Maybe [ValidateUnavailabilityWitness]
fitWitnesses claim components
  | Semantics.collectiveFitDisposition components
      == Semantics.ComponentUnavailable = do
    reasons <-
      NonEmpty.nonEmpty (Semantics.collectiveFitUnavailableReasons components)
    pure
      [ ValidateCollectiveFitUnavailable
          claim
          reasons
          (Semantics.collectiveFitBlockingStrategies components)
      ]
  | otherwise = Just []

primitiveWitness ::
     ModelIdentity
  -> Semantics.ParticipantPrimitiveSupportAssessment
  -> Maybe ValidateUnavailabilityWitness
primitiveWitness claim assessment = do
  reasons <-
    NonEmpty.nonEmpty (Semantics.primitiveSupportUnavailableReasons assessment)
  pure
    (ValidatePrimitiveSupportUnavailable
       claim
       (Semantics.primitiveSupportParticipant assessment)
       reasons
       (Semantics.primitiveSupportBlockingStrategies assessment))

bindingGroupHasDiagnostics :: SupplementalOwnerBindingGroup scope inputs -> Bool
bindingGroupHasDiagnostics =
  foldSupplementalOwnerBindingGroup (\_ evidence -> not (null evidence))

acquireSupplementalSources ::
     (SourceRole -> SourceOrdinal -> InputSource -> IO
                                                      (Either
                                                         AcquisitionFailure
                                                         AcquiredSource))
  -> [InputSource]
  -> IO (Either ValidateFailure [AcquiredSupplementalSource])
acquireSupplementalSources acquire = go 0 []
  where
    go _ acquired [] = pure (Right (reverse acquired))
    go ordinal acquired (input:remaining) = do
      result <- acquire SupplementalRole (sourceOrdinal ordinal) input
      case result of
        Left failure ->
          pure
            (Left
               (ValidateCommonFailure
                  (commandFailure (inputAcquisitionFailure failure))))
        Right source ->
          case acquiredSupplementalSource source of
            Nothing ->
              pure
                (Left
                   (ValidateOwnerContractFailure
                      (ValidateAcquiredSupplementalRoleFailure
                         (acquiredSourceIdentity source))))
            Just supplemental ->
              go (ordinal + 1) (supplemental : acquired) remaining

commonFailureResult :: CommonFailure -> ValidateResult
commonFailureResult = ValidateFailed . ValidateCommonFailure

internalFailureResult :: ValidateInternalFailure -> ValidateResult
internalFailureResult = ValidateFailed . ValidateOwnerContractFailure
