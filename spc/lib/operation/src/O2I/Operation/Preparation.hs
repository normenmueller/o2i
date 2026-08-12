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

modelAcquisitionStage :: PreparationStage
modelAcquisitionStage = ModelAcquisitionStage

capabilityInputAcquisitionStage :: PreparationStage
capabilityInputAcquisitionStage = CapabilityInputAcquisitionStage

adapterSelectionStage :: PreparationStage
adapterSelectionStage = AdapterSelectionStage

adapterDecodeStage :: PreparationStage
adapterDecodeStage = AdapterDecodeStage

canonicalizationStage :: PreparationStage
canonicalizationStage = CanonicalizationStage

profileMarkerStage :: PreparationStage
profileMarkerStage = ProfileMarkerStage

profileResolutionStage :: PreparationStage
profileResolutionStage = ProfileResolutionStage

profileCompatibilityStage :: PreparationStage
profileCompatibilityStage = ProfileCompatibilityStage

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

requiredPreparation :: PreparationRequirement
requiredPreparation = RequiredPreparation

omittedPreparation :: PreparationRequirement
omittedPreparation = OmittedPreparation

-- | Consume required or explicitly omitted preparation.
foldPreparationRequirement ::
     result -> result -> PreparationRequirement -> result
foldPreparationRequirement required omitted requirement =
  case requirement of
    RequiredPreparation -> required
    OmittedPreparation -> omitted

preparationStepStage :: PreparationStep -> PreparationStage
preparationStepStage (PreparationStep stage _) = stage

preparationStepRequirement :: PreparationStep -> PreparationRequirement
preparationStepRequirement (PreparationStep _ requirement) = requirement

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

preparationPlanRequest :: PreparationPlan -> RequestedContract
preparationPlanRequest (PreparationPlan request _) = request

preparationPlanSteps :: PreparationPlan -> NonEmpty PreparationStep
preparationPlanSteps (PreparationPlan _ steps) = steps

foldPreparationPlan ::
     (RequestedContract -> NonEmpty PreparationStep -> result)
  -> PreparationPlan
  -> result
foldPreparationPlan consume (PreparationPlan request steps) =
  consume request steps
