module StrategyRelationCrossScope where

import Data.Coerce (coerce)
import O2I.Semantics (StrategyRelationAssessment)

crossScope ::
     StrategyRelationAssessment firstScope
  -> StrategyRelationAssessment secondScope
crossScope = coerce
