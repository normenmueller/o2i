{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Explicit deterministic bootstrap stages for one Operation request.
--
-- A plan describes orchestration only. It neither executes nor reinterprets
-- Acquisition, Adapter, Profile, View, or capability-owned input semantics.
module O2I.Operation.Preparation
  ( type PreparationStage
  , modelAcquisitionStage
  , capabilityInputAcquisitionStage
  , adapterSelectionStage
  , adapterDecodeStage
  , canonicalizationStage
  , profileMarkerStage
  , profileResolutionStage
  , profileCompatibilityStage
  , viewSelectionStage
  , preparationStageText
  , foldPreparationStage
  , type PreparationRequirement
  , requiredPreparation
  , omittedPreparation
  , foldPreparationRequirement
  , type PreparationStep
  , preparationStepStage
  , preparationStepRequirement
  , foldPreparationStep
  , type PreparationPlan
  , preparationPlan
  , preparationPlanRequest
  , preparationPlanSteps
  , foldPreparationPlan
  ) where

import Data.List.NonEmpty (NonEmpty(..))
import Data.Text (Text)
import O2I.Operation.Preparation.Internal
import O2I.Operation.Request

-- | Stage that acquires the primary model source.
modelAcquisitionStage :: PreparationStage
modelAcquisitionStage = ModelAcquisitionStage

-- | Stage that acquires capability-owned supplemental inputs.
capabilityInputAcquisitionStage :: PreparationStage
capabilityInputAcquisitionStage = CapabilityInputAcquisitionStage

-- | Stage that selects one adapter from the static collection.
adapterSelectionStage :: PreparationStage
adapterSelectionStage = AdapterSelectionStage

-- | Stage that decodes the model with the selected adapter.
adapterDecodeStage :: PreparationStage
adapterDecodeStage = AdapterDecodeStage

-- | Stage that builds the profile-neutral canonical document.
canonicalizationStage :: PreparationStage
canonicalizationStage = CanonicalizationStage

-- | Stage that extracts exact Profile marker evidence.
profileMarkerStage :: PreparationStage
profileMarkerStage = ProfileMarkerStage

-- | Stage that resolves marker evidence to one compiled Profile.
profileResolutionStage :: PreparationStage
profileResolutionStage = ProfileResolutionStage

-- | Stage that checks the Profile against the selected adapter contract.
profileCompatibilityStage :: PreparationStage
profileCompatibilityStage = ProfileCompatibilityStage

-- | Stage that selects one exact canonical View.
viewSelectionStage :: PreparationStage
viewSelectionStage = ViewSelectionStage

-- | Stable machine identity of one preparation stage.
preparationStageText :: PreparationStage -> Text
preparationStageText stage =
  case stage of
    ModelAcquisitionStage -> "model-acquisition"
    CapabilityInputAcquisitionStage -> "capability-input-acquisition"
    AdapterSelectionStage -> "adapter-selection"
    AdapterDecodeStage -> "adapter-decode"
    CanonicalizationStage -> "canonicalization"
    ProfileMarkerStage -> "profile-marker"
    ProfileResolutionStage -> "profile-resolution"
    ProfileCompatibilityStage -> "profile-compatibility"
    ViewSelectionStage -> "view-selection"

-- | Consume every closed preparation stage.
foldPreparationStage ::
     result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> PreparationStage
  -> result
foldPreparationStage model inputs selection decode canonical marker profile compatibility view stage =
  case stage of
    ModelAcquisitionStage -> model
    CapabilityInputAcquisitionStage -> inputs
    AdapterSelectionStage -> selection
    AdapterDecodeStage -> decode
    CanonicalizationStage -> canonical
    ProfileMarkerStage -> marker
    ProfileResolutionStage -> profile
    ProfileCompatibilityStage -> compatibility
    ViewSelectionStage -> view

-- | Mark a preparation stage as mandatory for the request.
requiredPreparation :: PreparationRequirement
requiredPreparation = RequiredPreparation

-- | Mark a preparation stage as explicitly unnecessary for the request.
omittedPreparation :: PreparationRequirement
omittedPreparation = OmittedPreparation

-- | Consume required or explicitly omitted preparation.
foldPreparationRequirement ::
     result -> result -> PreparationRequirement -> result
foldPreparationRequirement required omitted requirement =
  case requirement of
    RequiredPreparation -> required
    OmittedPreparation -> omitted

-- | Project the stage represented by one preparation step.
preparationStepStage :: PreparationStep -> PreparationStage
preparationStepStage (PreparationStep stage _) = stage

-- | Project whether one preparation step is required or omitted.
preparationStepRequirement :: PreparationStep -> PreparationRequirement
preparationStepRequirement (PreparationStep _ requirement) = requirement

-- | Consume both immutable fields of one preparation step.
foldPreparationStep ::
     (PreparationStage -> PreparationRequirement -> result)
  -> PreparationStep
  -> result
foldPreparationStep consume (PreparationStep stage requirement) =
  consume stage requirement

-- | Derive the canonical plan without evaluating any capability payload.
--
-- Model bootstrap and View selection are always required. Capability input
-- acquisition is explicitly omitted only when the exact request has none.
preparationPlan :: RequestedContract -> PreparationPlan
preparationPlan request = PreparationPlan request steps
  where
    steps =
      PreparationStep ModelAcquisitionStage RequiredPreparation
        :| [ PreparationStep
               CapabilityInputAcquisitionStage
               (if null inputReferences
                  then OmittedPreparation
                  else RequiredPreparation)
           , PreparationStep AdapterSelectionStage RequiredPreparation
           , PreparationStep AdapterDecodeStage RequiredPreparation
           , PreparationStep CanonicalizationStage RequiredPreparation
           , PreparationStep ProfileMarkerStage RequiredPreparation
           , PreparationStep ProfileResolutionStage RequiredPreparation
           , PreparationStep ProfileCompatibilityStage RequiredPreparation
           , PreparationStep ViewSelectionStage RequiredPreparation
           ]
    inputReferences = capabilityInputReferences (requestedInputs request)

-- | Project the immutable request that determined the plan.
preparationPlanRequest :: PreparationPlan -> RequestedContract
preparationPlanRequest (PreparationPlan request _) = request

-- | Return every preparation step in execution order.
preparationPlanSteps :: PreparationPlan -> NonEmpty PreparationStep
preparationPlanSteps (PreparationPlan _ steps) = steps

-- | Consume the request and ordered steps of one preparation plan.
foldPreparationPlan ::
     (RequestedContract -> NonEmpty PreparationStep -> result)
  -> PreparationPlan
  -> result
foldPreparationPlan consume (PreparationPlan request steps) =
  consume request steps
