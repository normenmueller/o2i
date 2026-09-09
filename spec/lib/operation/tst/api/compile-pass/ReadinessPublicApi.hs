module ReadinessPublicApi where

import Data.ByteString (ByteString)
import O2I.Operation.Acquisition (InputSource)
import O2I.Operation.Adapter (AdapterCollection)
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Profile (ProfileInventory)
import O2I.Operation.Readiness (runReadiness)
import O2I.Operation.Readiness.Machine
  ( encodeReadinessResultDocument
  , readinessResultDocument
  )
import O2I.Operation.Readiness.Request (readinessRequest)
import O2I.Operation.Readiness.Result (ReadinessFailure)
import O2I.Operation.View (ViewSelector)

readinessDocument ::
     ToolDescriptor
  -> AdapterCollection
  -> ProfileInventory
  -> InputSource
  -> ViewSelector
  -> InputSource
  -> [InputSource]
  -> IO (Either ReadinessFailure ByteString)
readinessDocument tool adapters profiles model view evidence supplements =
  fmap
    (fmap encodeReadinessResultDocument . readinessResultDocument tool)
    (runReadiness
       adapters
       profiles
       (readinessRequest model view Nothing evidence supplements))
