module ValidationCollectiveParallelCommitment where

import qualified O2I.Validation as Validation

rewriteCollectiveCommitment ::
     Validation.RawCollectiveStrategyRealization
  -> Validation.RawCollectiveStrategyRealization
rewriteCollectiveCommitment proposition =
  proposition {Validation.rawCommitment = undefined}
