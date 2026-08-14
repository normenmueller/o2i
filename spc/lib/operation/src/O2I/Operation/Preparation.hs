{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed stage classifications from the sole post-acquisition preparation
-- runtime. They identify runtime boundaries but do not define a separately
-- executable or ordered plan.
--
-- Model acquisition belongs to the command boundary. This prefix selects and
-- prepares the View and Profile material required by later Notation and Profile
-- assessment. Capability-owned supplemental acquisition is outside the prefix
-- and begins only after those later assessments have accepted both.
module O2I.Operation.Preparation
  ( type PreparationStage
  , adapterSelectionStage
  , adapterDecodeStage
  , canonicalizationStage
  , profileMarkerStage
  , profileResolutionStage
  , profileCompatibilityStage
  , viewSelectionStage
  , preparationStageText
  , foldPreparationStage
  ) where

import Data.Text (Text)
import O2I.Operation.Preparation.Internal

-- | Stage that selects one adapter from the static collection.
adapterSelectionStage :: PreparationStage
adapterSelectionStage = AdapterSelectionStage

-- | Stage that decodes the model with the selected adapter.
adapterDecodeStage :: PreparationStage
adapterDecodeStage = AdapterDecodeStage

-- | Stage that builds the Profile-neutral canonical document.
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
    AdapterSelectionStage -> "adapter-selection"
    AdapterDecodeStage -> "adapter-decode"
    CanonicalizationStage -> "canonicalization"
    ProfileMarkerStage -> "profile-marker"
    ProfileResolutionStage -> "profile-resolution"
    ProfileCompatibilityStage -> "profile-compatibility"
    ViewSelectionStage -> "view-selection"

-- | Consume every closed stage classification.
foldPreparationStage ::
     result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> PreparationStage
  -> result
foldPreparationStage selection decode canonical marker profile compatibility view stage =
  case stage of
    AdapterSelectionStage -> selection
    AdapterDecodeStage -> decode
    CanonicalizationStage -> canonical
    ProfileMarkerStage -> marker
    ProfileResolutionStage -> profile
    ProfileCompatibilityStage -> compatibility
    ViewSelectionStage -> view
