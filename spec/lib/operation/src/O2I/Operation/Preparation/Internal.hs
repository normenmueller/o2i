-- | Private representation of the closed preparation stages.
module O2I.Operation.Preparation.Internal
  ( PreparationStage(..)
  ) where

-- | Closed stage vocabulary used by the sole preparation runtime.
data PreparationStage
  = AdapterSelectionStage
  | AdapterDecodeStage
  | CanonicalizationStage
  | ProfileMarkerStage
  | ProfileResolutionStage
  | ProfileCompatibilityStage
  | ViewSelectionStage
  deriving (Eq, Show)
