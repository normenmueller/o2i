-- | Private representation of deterministic preparation plans.
module O2I.Operation.Preparation.Internal
  ( PreparationStage(..)
  , PreparationRequirement(..)
  , PreparationStep(..)
  , PreparationPlan(..)
  ) where

import Data.List.NonEmpty (NonEmpty)
import O2I.Operation.Request (RequestedContract)

-- | Closed bootstrap stage before a capability evaluator may run.
data PreparationStage
  = ModelAcquisitionStage
  | CapabilityInputAcquisitionStage
  | AdapterSelectionStage
  | AdapterDecodeStage
  | CanonicalizationStage
  | ProfileMarkerStage
  | ProfileResolutionStage
  | ProfileCompatibilityStage
  | ViewSelectionStage
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Whether one stage is required by the exact request.
data PreparationRequirement
  = RequiredPreparation
  | OmittedPreparation
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | One stage and its request-derived requirement.
data PreparationStep =
  PreparationStep !PreparationStage !PreparationRequirement
  deriving (Eq, Ord, Show)

-- | Canonical non-empty plan bound to one exact request.
data PreparationPlan =
  PreparationPlan !RequestedContract !(NonEmpty PreparationStep)
  deriving (Show)
