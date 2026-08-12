{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed common command and preparation failures.
--
-- These wrappers preserve the original Acquisition, Adapter, Profile, and
-- View values. They add orchestration classification only and never translate
-- or reinterpret an owning authority's semantics.
module O2I.Operation.Failure
  ( type CommandFailure
  , inputAcquisitionFailure
  , commandFailureCode
  , foldCommandFailure
  , type PreparationFailure
  , adapterSelectionFailure
  , adapterDecodeFailure
  , profileMarkerFailure
  , profileResolutionFailure
  , profileCompatibilityFailure
  , viewSelectionFailure
  , preparationFailureCode
  , preparationFailureStage
  , foldPreparationFailure
  , type CommonFailure
  , commandFailure
  , preparationFailure
  , commonFailureCode
  , foldCommonFailure
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import O2I.ArchiMate.Profile.Notation (MarkerCandidate)
import O2I.Operation.Acquisition (AcquisitionFailure)
import O2I.Operation.Adapter
  ( AdapterDescriptor
  , AdapterDiagnostic
  , AdapterExecution
  , AdapterSelection
  , AdapterSelectionError
  , foldAdapterExecution
  , foldAdapterSelection
  , foldDecodeOutcome
  )
import O2I.Operation.Failure.Internal
import O2I.Operation.Preparation
import O2I.Operation.Profile
  ( ProfileCompatibility
  , ProfileMarkerEvidenceOutcome
  , ProfileResolution
  , foldProfileCompatibility
  , foldProfileMarkerEvidenceOutcome
  , foldProfileResolution
  )
import O2I.Operation.Rule.Catalog (operationRuleIdText, operationRuleIdentity)
import O2I.Operation.View
  ( ViewSelection
  , ViewSelectionFailure
  , foldViewSelection
  )

inputAcquisitionFailure :: AcquisitionFailure -> CommandFailure
inputAcquisitionFailure = CommandInputAcquisitionFailure

commandFailureCode :: CommandFailure -> Text
commandFailureCode (CommandInputAcquisitionFailure _) = "command.input-io"

foldCommandFailure :: (AcquisitionFailure -> result) -> CommandFailure -> result
foldCommandFailure acquisition (CommandInputAcquisitionFailure failure) =
  acquisition failure

adapterSelectionFailure :: AdapterSelection -> Maybe PreparationFailure
adapterSelectionFailure =
  foldAdapterSelection
    (Just . AdapterSelectionPreparationFailure)
    (const Nothing)

adapterDecodeFailure :: AdapterExecution -> Maybe PreparationFailure
adapterDecodeFailure execution =
  foldAdapterExecution
    (\descriptor _ outcome ->
       foldDecodeOutcome
         (Just . AdapterDecodePreparationFailure descriptor)
         (const Nothing)
         outcome)
    execution

profileMarkerFailure :: ProfileMarkerEvidenceOutcome -> Maybe PreparationFailure
profileMarkerFailure =
  foldProfileMarkerEvidenceOutcome
    (Just . ProfileMarkerPreparationFailure)
    (const Nothing)

profileResolutionFailure :: ProfileResolution -> Maybe PreparationFailure
profileResolutionFailure outcome =
  foldProfileResolution
    (\_ _ -> failed)
    (\_ _ _ -> failed)
    (\_ _ _ _ -> failed)
    (\_ _ _ _ -> failed)
    (\_ _ _ -> failed)
    (\_ _ _ -> failed)
    (const Nothing)
    outcome
  where
    failed = Just (ProfileResolutionPreparationFailure outcome)

profileCompatibilityFailure :: ProfileCompatibility -> Maybe PreparationFailure
profileCompatibilityFailure outcome =
  foldProfileCompatibility
    (\_ _ _ _ -> failed)
    (\_ _ _ _ _ -> failed)
    (\_ _ _ -> Nothing)
    outcome
  where
    failed = Just (ProfileCompatibilityPreparationFailure outcome)

viewSelectionFailure :: ViewSelection -> Maybe PreparationFailure
viewSelectionFailure =
  foldViewSelection (Just . ViewSelectionPreparationFailure) (const Nothing)

-- | Stable failure code derived from the exact closed branch.
preparationFailureCode :: PreparationFailure -> Text
preparationFailureCode failure =
  case failure of
    AdapterSelectionPreparationFailure _ -> "preparation.adapter-selection"
    AdapterDecodePreparationFailure _ _ -> "preparation.adapter-decode"
    ProfileMarkerPreparationFailure _ -> "preparation.profile-marker"
    ProfileResolutionPreparationFailure outcome ->
      foldProfileResolution
        (\rule _ -> ruleCode rule)
        (\rule _ _ -> ruleCode rule)
        (\rule _ _ _ -> ruleCode rule)
        (\rule _ _ _ -> ruleCode rule)
        (\rule _ _ -> ruleCode rule)
        (\rule _ _ -> ruleCode rule)
        (const "preparation.profile-resolution")
        outcome
    ProfileCompatibilityPreparationFailure outcome ->
      foldProfileCompatibility
        (\rule _ _ _ -> ruleCode rule)
        (\rule _ _ _ _ -> ruleCode rule)
        (\_ _ _ -> "preparation.profile-compatibility")
        outcome
    ViewSelectionPreparationFailure _ -> "preparation.view-selection"
  where
    ruleCode rule = operationRuleIdText (operationRuleIdentity rule)

preparationFailureStage :: PreparationFailure -> PreparationStage
preparationFailureStage failure =
  case failure of
    AdapterSelectionPreparationFailure _ -> adapterSelectionStage
    AdapterDecodePreparationFailure _ _ -> adapterDecodeStage
    ProfileMarkerPreparationFailure _ -> profileMarkerStage
    ProfileResolutionPreparationFailure _ -> profileResolutionStage
    ProfileCompatibilityPreparationFailure _ -> profileCompatibilityStage
    ViewSelectionPreparationFailure _ -> viewSelectionStage

foldPreparationFailure ::
     (AdapterSelectionError -> result)
  -> (AdapterDescriptor -> NonEmpty AdapterDiagnostic -> result)
  -> ([MarkerCandidate] -> result)
  -> (ProfileResolution -> result)
  -> (ProfileCompatibility -> result)
  -> (ViewSelectionFailure -> result)
  -> PreparationFailure
  -> result
foldPreparationFailure selection decode marker profile compatibility view failure =
  case failure of
    AdapterSelectionPreparationFailure value -> selection value
    AdapterDecodePreparationFailure descriptor diagnostics ->
      decode descriptor diagnostics
    ProfileMarkerPreparationFailure candidates -> marker candidates
    ProfileResolutionPreparationFailure outcome -> profile outcome
    ProfileCompatibilityPreparationFailure outcome -> compatibility outcome
    ViewSelectionPreparationFailure value -> view value

commandFailure :: CommandFailure -> CommonFailure
commandFailure = CommonCommandFailure

preparationFailure :: PreparationFailure -> CommonFailure
preparationFailure = CommonPreparationFailure

commonFailureCode :: CommonFailure -> Text
commonFailureCode failure =
  case failure of
    CommonCommandFailure value -> commandFailureCode value
    CommonPreparationFailure value -> preparationFailureCode value

foldCommonFailure ::
     (CommandFailure -> result)
  -> (PreparationFailure -> result)
  -> CommonFailure
  -> result
foldCommonFailure command preparation failure =
  case failure of
    CommonCommandFailure value -> command value
    CommonPreparationFailure value -> preparation value
