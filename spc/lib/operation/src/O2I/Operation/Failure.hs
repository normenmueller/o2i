{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

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
  , type ProfileResolutionFailure
  , profileResolutionFailure
  , foldProfileResolutionFailure
  , type ProfileCompatibilityFailure
  , profileCompatibilityFailure
  , foldProfileCompatibilityFailure
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
import O2I.ArchiMate.Profile.Draft (DraftScalar, DraftValueKind)
import O2I.ArchiMate.Profile.Notation (CanonicalProperty, MarkerCandidate)
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
  , ResolvedProfile
  , foldProfileCompatibility
  , foldProfileMarkerEvidenceOutcome
  , foldProfileResolution
  )
import O2I.Operation.Rule.Catalog
  ( OperationRule
  , operationRuleIdText
  , operationRuleIdentity
  )
import O2I.Operation.View
  ( ViewSelection
  , ViewSelectionFailure
  , foldViewSelection
  )

-- | Lift one source-acquisition failure into the command boundary.
inputAcquisitionFailure :: AcquisitionFailure -> CommandFailure
inputAcquisitionFailure = CommandInputAcquisitionFailure

-- | Stable machine code for one command failure.
commandFailureCode :: CommandFailure -> Text
commandFailureCode (CommandInputAcquisitionFailure _) = "command.input-io"

-- | Consume the acquisition cause of one command failure.
foldCommandFailure :: (AcquisitionFailure -> result) -> CommandFailure -> result
foldCommandFailure acquisition (CommandInputAcquisitionFailure failure) =
  acquisition failure

-- | Project an adapter-selection failure, or 'Nothing' on success.
adapterSelectionFailure :: AdapterSelection -> Maybe PreparationFailure
adapterSelectionFailure =
  foldAdapterSelection
    (Just . AdapterSelectionPreparationFailure)
    (const Nothing)

-- | Project an adapter-decode failure, or 'Nothing' on success.
adapterDecodeFailure :: AdapterExecution -> Maybe PreparationFailure
adapterDecodeFailure execution =
  foldAdapterExecution
    (\descriptor _ outcome ->
       foldDecodeOutcome
         (Just . AdapterDecodePreparationFailure descriptor)
         (const Nothing)
         outcome)
    execution

-- | Project missing or invalid marker evidence, or 'Nothing' on success.
profileMarkerFailure :: ProfileMarkerEvidenceOutcome -> Maybe PreparationFailure
profileMarkerFailure =
  foldProfileMarkerEvidenceOutcome
    (Just . ProfileMarkerPreparationFailure)
    (const Nothing)

-- | Project the exact rejected Profile-resolution branch.
profileResolutionFailure :: ProfileResolution -> Maybe ProfileResolutionFailure
profileResolutionFailure =
  foldProfileResolution
    (\rule key -> Just (ProfileReferenceMissingFailure rule key))
    (\rule key occurrences ->
       Just (ProfileReferencePropertyMultiplicityFailure rule key occurrences))
    (\rule key occurrence occurrences ->
       Just
         (ProfileReferenceValueMultiplicityFailure
            rule
            key
            occurrence
            occurrences))
    (\rule key occurrence kind ->
       Just (ProfileReferenceValueKindInvalidFailure rule key occurrence kind))
    (\rule key occurrence ->
       Just (ProfileReferenceGrammarInvalidFailure rule key occurrence))
    (\rule key reference ->
       Just (ProfileReferenceUnknownFailure rule key reference))
    (\_resolved -> Nothing)

-- | Consume every rejected Profile-resolution branch and exact field.
foldProfileResolutionFailure ::
     (OperationRule -> Text -> result)
  -> (OperationRule -> Text -> [CanonicalProperty] -> result)
  -> (OperationRule -> Text -> CanonicalProperty -> [DraftScalar] -> result)
  -> (OperationRule -> Text -> DraftScalar -> DraftValueKind -> result)
  -> (OperationRule -> Text -> DraftScalar -> result)
  -> (OperationRule -> Text -> Text -> result)
  -> ProfileResolutionFailure
  -> result
foldProfileResolutionFailure missing properties values kind grammar unknown failure =
  case failure of
    ProfileReferenceMissingFailure rule key -> missing rule key
    ProfileReferencePropertyMultiplicityFailure rule key occurrences ->
      properties rule key occurrences
    ProfileReferenceValueMultiplicityFailure rule key occurrence occurrences ->
      values rule key occurrence occurrences
    ProfileReferenceValueKindInvalidFailure rule key occurrence actual ->
      kind rule key occurrence actual
    ProfileReferenceGrammarInvalidFailure rule key occurrence ->
      grammar rule key occurrence
    ProfileReferenceUnknownFailure rule key reference ->
      unknown rule key reference

-- | Project the exact rejected Profile/Adapter compatibility branch.
profileCompatibilityFailure ::
     ProfileCompatibility -> Maybe ProfileCompatibilityFailure
profileCompatibilityFailure =
  foldProfileCompatibility
    (\rule profile adapter admitted ->
       Just (ProfileAdapterIdNotAdmittedFailure rule profile adapter admitted))
    (\rule profile adapter profileNotation adapterNotation ->
       Just
         (ProfileAdapterNotationMismatchFailure
            rule
            profile
            adapter
            profileNotation
            adapterNotation))
    (\_profile _adapter _notation -> Nothing)

-- | Consume both rejected Profile/Adapter compatibility branches.
foldProfileCompatibilityFailure ::
     (OperationRule -> ResolvedProfile -> AdapterDescriptor -> [Text] -> result)
  -> (OperationRule -> ResolvedProfile -> AdapterDescriptor -> Text -> Text -> result)
  -> ProfileCompatibilityFailure
  -> result
foldProfileCompatibilityFailure notAdmitted mismatch failure =
  case failure of
    ProfileAdapterIdNotAdmittedFailure rule profile adapter admitted ->
      notAdmitted rule profile adapter admitted
    ProfileAdapterNotationMismatchFailure rule profile adapter profileNotation adapterNotation ->
      mismatch rule profile adapter profileNotation adapterNotation

-- | Project a View-selection failure, or 'Nothing' on success.
viewSelectionFailure :: ViewSelection document -> Maybe PreparationFailure
viewSelectionFailure =
  foldViewSelection (Just . ViewSelectionPreparationFailure) (const Nothing)

-- | Stable failure code derived from the exact closed branch.
preparationFailureCode :: PreparationFailure -> Text
preparationFailureCode failure =
  case failure of
    AdapterSelectionPreparationFailure _ -> "preparation.adapter-selection"
    AdapterDecodePreparationFailure _ _ -> "preparation.adapter-decode"
    ProfileMarkerPreparationFailure _ -> "preparation.profile-marker"
    ProfileResolutionPreparationFailure failureValue ->
      foldProfileResolutionFailure
        (\rule _ -> ruleCode rule)
        (\rule _ _ -> ruleCode rule)
        (\rule _ _ _ -> ruleCode rule)
        (\rule _ _ _ -> ruleCode rule)
        (\rule _ _ -> ruleCode rule)
        (\rule _ _ -> ruleCode rule)
        failureValue
    ProfileCompatibilityPreparationFailure failureValue ->
      foldProfileCompatibilityFailure
        (\rule _ _ _ -> ruleCode rule)
        (\rule _ _ _ _ -> ruleCode rule)
        failureValue
    ViewSelectionPreparationFailure _ -> "preparation.view-selection"
  where
    ruleCode rule = operationRuleIdText (operationRuleIdentity rule)

-- | Preparation stage at which the exact failure occurred.
preparationFailureStage :: PreparationFailure -> PreparationStage
preparationFailureStage failure =
  case failure of
    AdapterSelectionPreparationFailure _ -> adapterSelectionStage
    AdapterDecodePreparationFailure _ _ -> adapterDecodeStage
    ProfileMarkerPreparationFailure _ -> profileMarkerStage
    ProfileResolutionPreparationFailure _ -> profileResolutionStage
    ProfileCompatibilityPreparationFailure _ -> profileCompatibilityStage
    ViewSelectionPreparationFailure _ -> viewSelectionStage

-- | Consume every closed preparation-failure cause.
foldPreparationFailure ::
     (AdapterSelectionError -> result)
  -> (AdapterDescriptor -> NonEmpty AdapterDiagnostic -> result)
  -> ([MarkerCandidate] -> result)
  -> (ProfileResolutionFailure -> result)
  -> (ProfileCompatibilityFailure -> result)
  -> (forall document. ViewSelectionFailure document -> result)
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

-- | Lift one command failure into the common failure boundary.
commandFailure :: CommandFailure -> CommonFailure
commandFailure = CommonCommandFailure

-- | Lift one preparation failure into the common failure boundary.
preparationFailure :: PreparationFailure -> CommonFailure
preparationFailure = CommonPreparationFailure

-- | Stable machine code derived from the retained failure branch.
commonFailureCode :: CommonFailure -> Text
commonFailureCode failure =
  case failure of
    CommonCommandFailure value -> commandFailureCode value
    CommonPreparationFailure value -> preparationFailureCode value

-- | Consume either common failure category.
foldCommonFailure ::
     (CommandFailure -> result)
  -> (PreparationFailure -> result)
  -> CommonFailure
  -> result
foldCommonFailure command preparation failure =
  case failure of
    CommonCommandFailure value -> command value
    CommonPreparationFailure value -> preparation value
