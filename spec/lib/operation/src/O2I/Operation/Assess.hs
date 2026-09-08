-- | Selected-View evidence-assessment orchestration.
module O2I.Operation.Assess
  ( runAssess
  ) where

import O2I.Operation.Adapter (AdapterCollection)
import O2I.Operation.Assess.Request (AssessRequest)
import O2I.Operation.Assess.Result (AssessResult)
import qualified O2I.Operation.Assess.Runtime.Internal as Runtime
import O2I.Operation.Profile (ProfileInventory)

-- | Execute the closed selected-View Assessment pipeline over exact sources.
runAssess ::
     AdapterCollection -> ProfileInventory -> AssessRequest -> IO AssessResult
runAssess = Runtime.runAssess
