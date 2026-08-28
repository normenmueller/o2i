-- | Selected-View evidence-readiness orchestration.
module O2I.Operation.Readiness
  ( runReadiness
  ) where

import O2I.Operation.Adapter (AdapterCollection)
import O2I.Operation.Profile (ProfileInventory)
import O2I.Operation.Readiness.Request (ReadinessRequest)
import O2I.Operation.Readiness.Result (ReadinessResult)
import qualified O2I.Operation.Readiness.Runtime.Internal as Runtime

-- | Execute the closed selected-View readiness pipeline over exact sources.
runReadiness ::
     AdapterCollection
  -> ProfileInventory
  -> ReadinessRequest
  -> IO ReadinessResult
runReadiness = Runtime.runReadiness
