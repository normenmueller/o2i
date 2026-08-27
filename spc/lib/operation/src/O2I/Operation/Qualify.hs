-- | Selected-View formal qualification orchestration.
--
-- The runtime prepares and assesses an immutable model, routes every projected
-- proposal exactly once through Core, and returns complete requested-pair
-- outcomes without accepting or mutating any proposition.
module O2I.Operation.Qualify
  ( runQualify
  ) where

import O2I.Operation.Qualify.Runtime.Internal (runQualify)
